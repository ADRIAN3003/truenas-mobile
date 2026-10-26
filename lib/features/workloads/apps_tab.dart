import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/api/workloads_api.dart';
import '../../core/models/workloads.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glass.dart';
import '../../shared/haptics.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/connect_dialogs.dart';
import '../../shared/formatting.dart';
import '../../shared/viz_colors.dart';
import '../../shared/widgets.dart';
import '../sharing/sharing_widgets.dart';
import '../storage/storage_helpers.dart';
import 'app_catalog_screen.dart';
import 'app_icon.dart';
import 'app_screen.dart';
import 'update_all_apps.dart';
import 'workload_widgets.dart';

class _Workloads {
  const _Workloads({
    required this.apps,
    required this.vms,
    required this.containers,
    required this.containerActions,
    required this.canBulk,
    required this.canInstall,
  });

  final List<TrueNasApp> apps;

  /// Null when the server can't list VMs (no permission or no support).
  final List<VirtualMachine>? vms;

  /// Null when the server has no container system.
  final List<LinuxContainer>? containers;
  final List<WorkloadAction> containerActions;

  /// Whether the server can update all apps in one job.
  final bool canBulk;

  /// Whether apps can be installed from the catalog.
  final bool canInstall;
}

const _appActions = [
  WorkloadAction.start,
  WorkloadAction.stop,
  WorkloadAction.restart,
];
const _vmActions = [
  WorkloadAction.start,
  WorkloadAction.stop,
  WorkloadAction.restart,
  WorkloadAction.powerOff,
];

/// Docker apps, virtual machines and containers.
class AppsTab extends StatefulWidget {
  const AppsTab({super.key, required this.session, this.onUpdateCount});

  final TrueNasSession session;

  /// Told how many apps have an update each time the list is loaded, so the
  /// tab's badge follows what this tab shows.
  final ValueChanged<int>? onUpdateCount;

  @override
  State<AppsTab> createState() => _AppsTabState();
}

class _AppsTabState extends State<AppsTab> with LoadState<AppsTab, _Workloads> {
  /// Keys (`app:x`, `vm:1`, `ct:x`) of workloads with an action in flight.
  final _busy = <String>{};

  /// The server's bulk job (Update all, or an action on the selected apps)
  /// while it runs, polled by [_poll]. It outlives this screen: [initState]
  /// picks it up again.
  AppBulkRun? _bulkRun;
  Timer? _poller;
  var _polling = false;

  /// Looks at the list again a few seconds after an app was seen deploying
  /// or stopping (an install, a configuration change), until it settles.
  Timer? _settling;

  /// Apps ticked while choosing which to act on, or null when not choosing.
  Set<String>? _selected;

  WorkloadsApi get _api => widget.session.workloads;

  @override
  Future<_Workloads> fetch() async {
    Future<T?> optional<T>(Future<T> Function() f) async {
      try {
        return await f();
      } catch (_) {
        return null;
      }
    }

    final backend = await _api.containerBackend();
    final (
      apps,
      vms,
      containers,
      containerActions,
      canBulk,
      canInstall,
    ) = await (
      _api.apps(),
      optional(_api.vms),
      backend == ContainerBackend.none
          ? Future<List<LinuxContainer>?>.value()
          : optional(_api.containers),
      _api.containerActions(),
      _api.canBulk(),
      _api.canInstall(),
    ).wait;
    widget.onUpdateCount?.call(apps.where((a) => a.upgradeAvailable).length);
    _settling?.cancel();
    if (apps.any(
      (a) =>
          a.state == WorkloadState.deploying ||
          a.state == WorkloadState.stopping,
    )) {
      _settling = Timer(const Duration(seconds: 5), () {
        if (mounted) load();
      });
    }
    return _Workloads(
      apps: apps,
      vms: vms,
      containers: containers,
      containerActions: containerActions,
      canBulk: canBulk,
      canInstall: canInstall,
    );
  }

  @override
  void initState() {
    super.initState();
    _resumeRun();
  }

  @override
  void dispose() {
    _poller?.cancel();
    _settling?.cancel();
    super.dispose();
  }

  /// Picks up a bulk job already running on the server, such as one started
  /// before the app was closed or from the web UI.
  Future<void> _resumeRun() async {
    try {
      final run = await _api.activeBulkRun();
      if (run != null && mounted) _watch(run);
    } catch (_) {
      // Not being able to look is the same as nothing running.
    }
  }

  void _watch(AppBulkRun run) {
    setState(() => _bulkRun = run);
    _poller?.cancel();
    _poller = Timer.periodic(const Duration(seconds: 2), (_) => _poll());
  }

  /// Follows the job and refreshes the list so each app's new version shows as
  /// the server gets to it. A dropped connection just skips a round.
  Future<void> _poll() async {
    final run = _bulkRun;
    if (run == null || _polling) return;
    _polling = true;
    try {
      final latest = await _api.bulkRun(run.jobId);
      await load();
      if (!mounted) return;
      if (latest != null && latest.isActive) {
        setState(() => _bulkRun = latest);
      } else {
        _poller?.cancel();
        setState(() => _bulkRun = null);
        _finished(latest ?? run);
      }
    } catch (_) {
      // Try again on the next tick.
    } finally {
      _polling = false;
    }
  }

  void _finished(AppBulkRun run) {
    final l10n = AppLocalizations.of(context);
    final failed = run.failed;
    if (failed.isEmpty) {
      Haptics.confirm();
    } else {
      Haptics.warning();
    }
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          failed.isEmpty
              ? l10n.appsBulkDone(run.apps.length, run.action.name)
              : l10n.appsBulkPartial(
                  run.apps.length - failed.length,
                  run.apps.length,
                  failed.keys.join(', '),
                  run.action.name,
                ),
        ),
      ),
    );
  }

  Future<void> _run(
    String key,
    String name,
    WorkloadAction action,
    Future<void> Function() run, {
    bool isVm = false,
  }) async {
    final ok = await runWorkloadAction(
      context,
      name: name,
      action: action,
      run: run,
      isVm: isVm,
      onConfirmed: () => setState(() => _busy.add(key)),
    );
    if (!ok && !_busy.contains(key)) return;
    await load();
    if (mounted) setState(() => _busy.remove(key));
  }

  /// Which apps [action] applies to: updates for those with one, start for
  /// those that are down, stop and restart for those that are up.
  static bool _applies(AppBulkAction action, TrueNasApp app) =>
      switch (action) {
        AppBulkAction.upgrade => app.upgradeAvailable,
        AppBulkAction.start => !app.state.isUp,
        AppBulkAction.stop || AppBulkAction.restart => app.state.isUp,
      };

  /// Asks the user to confirm [action] on [apps] where it needs it (start does
  /// not), hands it to the server as one job and follows it. The server does
  /// the work, so the user can leave; an app that fails does not stop the rest.
  Future<void> _bulk(AppBulkAction action, List<TrueNasApp> apps) async {
    if (apps.isEmpty || _bulkRun != null) return;
    final l10n = AppLocalizations.of(context);
    final messenger = ScaffoldMessenger.of(context);
    final Future<bool> ask = switch (action) {
      AppBulkAction.upgrade => confirmAction(
        context,
        title: l10n.appsUpdateAllTitle(apps.length),
        body: l10n.appsUpdateAllBody,
        details: UpdateAllList(apps: apps),
        confirmLabel: l10n.appsBulkUpdate,
        cancelLabel: l10n.cancel,
      ),
      AppBulkAction.start => Future.value(true),
      AppBulkAction.stop => confirmAction(
        context,
        title: l10n.appsBulkStopTitle(apps.length),
        body: l10n.appsBulkStopBody,
        details: UpdateAllList(apps: apps, showVersions: false),
        confirmLabel: l10n.actionStop,
        cancelLabel: l10n.cancel,
      ),
      AppBulkAction.restart => confirmAction(
        context,
        title: l10n.appsBulkRestartTitle(apps.length),
        body: l10n.appsBulkRestartBody,
        details: UpdateAllList(apps: apps, showVersions: false),
        confirmLabel: l10n.actionRestart,
        cancelLabel: l10n.cancel,
      ),
    };
    if (!await ask || !mounted) return;
    try {
      final id = await _api.bulk(action, [for (final app in apps) app.name]);
      final run = await _api.bulkRun(id);
      if (!mounted) return;
      setState(() => _selected = null);
      if (run != null && run.isActive) {
        _watch(run);
      } else {
        // Already over by the time it was looked up.
        await load();
        if (mounted && run != null) _finished(run);
      }
    } catch (error) {
      Haptics.warning();
      messenger.showSnackBar(
        SnackBar(content: Text(describeConnectError(l10n, error))),
      );
    }
  }

  /// How far the running job has got, from what the apps look like now:
  /// updated apps lost their update, started ones run, stopped ones are
  /// stopped. A restart leaves no mark, so its progress is unknown.
  BulkProgress _progress(AppBulkRun run, List<TrueNasApp> apps) {
    final byName = {for (final app in apps) app.name: app};
    int count(bool Function(TrueNasApp) test) => [
      for (final name in run.apps)
        if (byName[name] case final app? when test(app)) name,
    ].length;
    return (
      action: run.action,
      total: run.apps.length,
      done: switch (run.action) {
        AppBulkAction.upgrade => count((a) => !a.upgradeAvailable),
        AppBulkAction.start => count((a) => a.state == WorkloadState.running),
        AppBulkAction.stop => count((a) => a.state == WorkloadState.stopped),
        AppBulkAction.restart => null,
      },
    );
  }

  /// Whether the running job still has to do [app].
  bool _waitingForRun(TrueNasApp app) =>
      _bulkRun != null &&
      _bulkRun!.apps.contains(app.name) &&
      _applies(_bulkRun!.action, app);

  void _toggle(String name) => setState(() {
    final selected = _selected!;
    if (!selected.remove(name)) selected.add(name);
  });

  Future<void> _openCatalog() async {
    final installed = await Navigator.push<bool>(
      context,
      MaterialPageRoute<bool>(
        builder: (_) => AppCatalogScreen(session: widget.session),
      ),
    );
    if (installed == true) await load();
  }

  Future<void> _openApp(TrueNasApp app) async {
    await Navigator.push(
      context,
      MaterialPageRoute<void>(
        builder: (_) => AppScreen(session: widget.session, app: app),
      ),
    );
    await load();
  }

  @override
  Widget build(BuildContext context) {
    return AsyncBody<_Workloads>(
      value: data,
      error: error,
      onRefresh: load,
      builder: (w) {
        final selected = _selected;
        final picked = [
          for (final app in w.apps)
            if (selected?.contains(app.name) ?? false) app,
        ];
        return Stack(
          children: [
            _list(context, w),
            if (selected != null && picked.isNotEmpty)
              Positioned(
                left: 16,
                right: 16,
                bottom: ChromeInsets.of(context).bottom,
                child: AppsBulkBar(
                  options: [
                    for (final action in AppBulkAction.values)
                      (
                        action: action,
                        count: picked.where((a) => _applies(action, a)).length,
                      ),
                  ],
                  onPressed: (action) => _bulk(action, [
                    for (final app in picked)
                      if (_applies(action, app)) app,
                  ]),
                ),
              ),
          ],
        );
      },
    );
  }

  /// The buttons beside the "Apps" heading: install, and picking apps.
  Widget? _trailing(_Workloads w, Set<String>? selected) {
    final l10n = AppLocalizations.of(context);
    final canSelect = w.canBulk && w.apps.isNotEmpty && _bulkRun == null;
    if (selected != null) {
      return Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextButton(
            onPressed: () =>
                setState(() => _selected = {for (final a in w.apps) a.name}),
            child: Text(l10n.appsSelectAll),
          ),
          TextButton(
            onPressed: () => setState(() => _selected = null),
            child: Text(l10n.done),
          ),
        ],
      );
    }
    if (!canSelect && !w.canInstall) return null;
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        if (canSelect)
          TextButton(
            onPressed: () => setState(() => _selected = {}),
            child: Text(l10n.appsSelect),
          ),
        if (w.canInstall)
          IconButton(
            tooltip: l10n.appInstallTitle,
            icon: const Icon(Icons.add_circle_outline),
            onPressed: _openCatalog,
          ),
      ],
    );
  }

  Widget _list(BuildContext context, _Workloads w) {
    final l10n = AppLocalizations.of(context);
    final selected = _selected;
    return ListView(
      padding: ChromeInsets.pad(
        context,
        EdgeInsets.fromLTRB(16, 0, 16, selected == null ? 24 : 96),
      ),
      children: [
        if (appsWithUpdates(w.apps) case final updates
            when w.canBulk && (updates.isNotEmpty || _bulkRun != null)) ...[
          UpdateAllCard(
            count: updates.length,
            progress: _bulkRun == null ? null : _progress(_bulkRun!, w.apps),
            onPressed: () => _bulk(AppBulkAction.upgrade, updates),
          ),
          const SizedBox(height: 8),
        ],
        ...groupedSection(
          selected == null
              ? l10n.appsTitle
              : l10n.appsSelectedCount(selected.length),
          empty: l10n.appsEmpty,
          trailing: _trailing(w, selected),
          [
            for (final app in w.apps)
              ListTile(
                leading: AppIcon(url: app.iconUrl),
                title: Text(app.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        if (app.title != null && app.title != app.name)
                          app.title!,
                        app.version,
                      ].join(' · '),
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: 12,
                      runSpacing: 4,
                      children: [
                        WorkloadStateLabel(state: app.state),
                        if (app.upgradeAvailable)
                          StatusLabel(
                            icon: Icons.upgrade,
                            color: VizColors.of(context).series1,
                            label: l10n.appUpdateAvailable,
                          ),
                      ],
                    ),
                  ],
                ),
                trailing: selected != null
                    ? Checkbox(
                        value: selected.contains(app.name),
                        onChanged: (_) => _toggle(app.name),
                      )
                    : WorkloadMenu(
                        busy:
                            _busy.contains('app:${app.name}') ||
                            _waitingForRun(app),
                        actions: actionsFor(app.state, supported: _appActions),
                        onLogs:
                            app.state.isUp || app.state == WorkloadState.crashed
                            ? () =>
                                  openAppLogs(context, widget.session, app.name)
                            : null,
                        onShell: app.state == WorkloadState.running
                            ? () => openAppShell(
                                context,
                                widget.session,
                                app.name,
                              )
                            : null,
                        onSelected: (action) => _run(
                          'app:${app.name}',
                          app.name,
                          action,
                          () => _api.appAction(app.name, action),
                        ),
                      ),
                onTap: () =>
                    selected != null ? _toggle(app.name) : _openApp(app),
              ),
          ],
        ),
        if (w.vms case final vms?)
          ...groupedSection(l10n.vmsTitle, empty: l10n.vmsEmpty, [
            for (final vm in vms)
              ListTile(
                leading: const IconTile(
                  Icons.computer_rounded,
                  AppPalette.tilePurple,
                  size: 40,
                ),
                title: Text(vm.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      [
                        l10n.vmSummary(
                          vm.vcpus,
                          formatBytes(vm.memoryMib * 1024 * 1024),
                        ),
                        if (vm.description.isNotEmpty) vm.description,
                      ].join('\n'),
                    ),
                    const SizedBox(height: 4),
                    WorkloadStateLabel(state: vm.state),
                  ],
                ),
                trailing: WorkloadMenu(
                  busy: _busy.contains('vm:${vm.id}'),
                  actions: actionsFor(vm.state, supported: _vmActions),
                  onShell: vm.state == WorkloadState.running
                      ? () => openShell(
                          context,
                          widget.session,
                          WorkloadsApi.vmShell(vm.id),
                          vm.name,
                        )
                      : null,
                  onSelected: (action) => _run(
                    'vm:${vm.id}',
                    vm.name,
                    action,
                    () => _api.vmAction(vm.id, action),
                    isVm: true,
                  ),
                ),
              ),
          ]),
        if (w.containers case final containers?)
          ...groupedSection(l10n.containersTitle, empty: l10n.containersEmpty, [
            for (final container in containers)
              ListTile(
                leading: IconTile(
                  container.isVm
                      ? Icons.computer_rounded
                      : Icons.inventory_2_rounded,
                  container.isVm ? AppPalette.tilePurple : AppPalette.tileTeal,
                  size: 40,
                ),
                title: Text(container.name),
                subtitle: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (container.isVm || container.description != null)
                      Text(
                        [
                          if (container.isVm) l10n.containerIsVm,
                          ?container.description,
                        ].join(' · '),
                      ),
                    const SizedBox(height: 4),
                    WorkloadStateLabel(state: container.state),
                  ],
                ),
                trailing: WorkloadMenu(
                  busy: _busy.contains('ct:${container.id}'),
                  actions: actionsFor(
                    container.state,
                    supported: w.containerActions,
                  ),
                  onShell: container.state == WorkloadState.running
                      ? () async {
                          final options = await _api.containerShell(container);
                          if (!context.mounted) return;
                          await openShell(
                            context,
                            widget.session,
                            options,
                            container.name,
                            fallbackCommands: WorkloadsApi.shellFallbacks,
                          );
                        }
                      : null,
                  onSelected: (action) => _run(
                    'ct:${container.id}',
                    container.name,
                    action,
                    () => _api.containerAction(container, action),
                    isVm: container.isVm,
                  ),
                ),
              ),
          ]),
      ],
    );
  }
}

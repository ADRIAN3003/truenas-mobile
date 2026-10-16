import 'package:flutter/material.dart';

import '../../core/api/workloads_api.dart';
import '../../core/models/workloads.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/glass.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/formatting.dart';
import '../../shared/viz_colors.dart';
import '../../shared/widgets.dart';
import '../sharing/sharing_widgets.dart';
import '../storage/storage_helpers.dart';
import 'app_icon.dart';
import 'app_screen.dart';
import 'workload_widgets.dart';

class _Workloads {
  const _Workloads({
    required this.apps,
    required this.vms,
    required this.containers,
    required this.containerActions,
  });

  final List<TrueNasApp> apps;

  /// Null when the server can't list VMs (no permission or no support).
  final List<VirtualMachine>? vms;

  /// Null when the server has no container system.
  final List<LinuxContainer>? containers;
  final List<WorkloadAction> containerActions;
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
  const AppsTab({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<AppsTab> createState() => _AppsTabState();
}

class _AppsTabState extends State<AppsTab> with LoadState<AppsTab, _Workloads> {
  /// Keys (`app:x`, `vm:1`, `ct:x`) of workloads with an action in flight.
  final _busy = <String>{};

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
    final (apps, vms, containers, containerActions) = await (
      _api.apps(),
      optional(_api.vms),
      backend == ContainerBackend.none
          ? Future<List<LinuxContainer>?>.value()
          : optional(_api.containers),
      _api.containerActions(),
    ).wait;
    return _Workloads(
      apps: apps,
      vms: vms,
      containers: containers,
      containerActions: containerActions,
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
    final l10n = AppLocalizations.of(context);
    return AsyncBody<_Workloads>(
      value: data,
      error: error,
      onRefresh: load,
      builder: (w) => ListView(
        padding: ChromeInsets.pad(
          context,
          const EdgeInsets.fromLTRB(16, 0, 16, 24),
        ),
        children: [
          ...groupedSection(l10n.appsTitle, empty: l10n.appsEmpty, [
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
                trailing: WorkloadMenu(
                  busy: _busy.contains('app:${app.name}'),
                  actions: actionsFor(app.state, supported: _appActions),
                  onShell: app.state == WorkloadState.running
                      ? () => openAppShell(context, widget.session, app.name)
                      : null,
                  onSelected: (action) => _run(
                    'app:${app.name}',
                    app.name,
                    action,
                    () => _api.appAction(app.name, action),
                  ),
                ),
                onTap: () => _openApp(app),
              ),
          ]),
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
            ...groupedSection(
              l10n.containersTitle,
              empty: l10n.containersEmpty,
              [
                for (final container in containers)
                  ListTile(
                    leading: IconTile(
                      container.isVm
                          ? Icons.computer_rounded
                          : Icons.inventory_2_rounded,
                      container.isVm
                          ? AppPalette.tilePurple
                          : AppPalette.tileTeal,
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
                              final options = await _api.containerShell(
                                container,
                              );
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
              ],
            ),
        ],
      ),
    );
  }
}

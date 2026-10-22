import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../../core/instances/instances_provider.dart';
import '../../core/instances/server_instance.dart';
import '../../core/jobs/job_monitor.dart';
import '../../core/jobs/job_tracker.dart';
import '../../core/jobs/live_progress.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/session/truenas_session.dart';
import '../../core/widgets/home_widget_sync.dart';
import '../../core/widgets/home_widgets.dart';
import '../../core/notifications/background_alerts.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/connect_dialogs.dart';
import '../../shared/glass.dart';
import '../../shared/haptics.dart';
import '../../shared/widgets.dart';
import '../jobs/job_gauge_button.dart';
import '../jobs/job_progress_banner.dart';
import '../jobs/job_texts.dart';
import '../sharing/shares_tab.dart';
import '../storage/storage_tab.dart';
import '../workloads/apps_tab.dart';
import '../settings/settings_screen.dart';
import 'dashboard_tab.dart';
import 'more_tab.dart';

/// Window width from which the server screen uses a navigation rail.
const railBreakpoint = 600.0;

/// Connects to one saved server and shows its overview.
class ServerScreen extends ConsumerStatefulWidget {
  const ServerScreen(this.instanceId, {super.key});

  final String instanceId;

  @override
  ConsumerState<ServerScreen> createState() => _ServerScreenState();
}

class _ServerScreenState extends ConsumerState<ServerScreen>
    with WidgetsBindingObserver {
  TrueNasSession? _session;
  JobMonitor? _jobs;
  HomeWidgetSync? _widgets;
  Map<String, dynamic>? _info;
  Object? _error;
  var _tab = 0;

  /// Apps with an update, shown as a badge on the Apps tab. The tab reports it
  /// when it loads; this keeps it current while that tab is not open.
  var _appUpdates = 0;
  Timer? _appUpdateTimer;

  ServerInstance? get _instance => ref
      .read(instancesProvider)
      .value
      ?.where((e) => e.id == widget.instanceId)
      .firstOrNull;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    WidgetsBinding.instance.addPostFrameCallback((_) => _connect());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // The phone may have closed the socket while the app was away; reconnect
    // now rather than on the next tap, so live data resumes by itself.
    if (state == AppLifecycleState.resumed) {
      // A failed attempt is retried by the next call.
      _session?.ensureAlive().catchError((_) {}).whenComplete(() {
        _jobs?.refresh();
        _widgets?.refresh();
        _refreshAppUpdates();
      });
    } else if (state == AppLifecycleState.paused) {
      // The widgets show what the app saw last, so save it as it is left.
      _widgets?.refresh();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _appUpdateTimer?.cancel();
    _jobs?.dispose();
    _widgets?.dispose();
    _session?.close();
    super.dispose();
  }

  void _setAppUpdates(int count) {
    if (mounted && count != _appUpdates) setState(() => _appUpdates = count);
  }

  /// Counts the apps with an update. Not being able to ask (the server is out
  /// of reach, or has no apps) leaves the badge as it was.
  Future<void> _refreshAppUpdates() async {
    final session = _session;
    if (session == null) return;
    try {
      final apps = await session.workloads.apps();
      if (session == _session) {
        _setAppUpdates(apps.where((a) => a.upgradeAvailable).length);
      }
    } catch (_) {}
  }

  Future<void> _connect() async {
    final instance = _instance;
    if (instance == null) return;
    final previous = _session;
    _session = null;
    _appUpdateTimer?.cancel();
    _appUpdates = 0;
    final previousJobs = _jobs;
    _jobs = null;
    _widgets?.dispose();
    _widgets = null;
    await previousJobs?.dispose();
    await previous?.close();
    setState(() {
      _error = null;
      _info = null;
    });
    try {
      final (session, updated) = await connectToInstance(
        instance,
        confirmCertificate: (cert) => confirmCertificateDialog(context, cert),
        askOtp: () => askOtpDialog(context),
      );
      if (!mounted) {
        await session.close();
        return;
      }
      _session = session;
      _appUpdateTimer = Timer.periodic(
        const Duration(minutes: 5),
        (_) => _refreshAppUpdates(),
      );
      _jobs = JobMonitor(
        source: SessionJobSource(session),
        progress: ref.read(liveProgressProvider),
        instanceId: instance.id,
        serverName: () => _instance?.name ?? instance.name,
        texts: () => AppLocalizations.of(context).jobTexts,
        lockScreen: ref.read(settingsProvider).liveJobs,
      )..start();
      if (ref.read(settingsProvider).homeWidgets) {
        _widgets = HomeWidgetSync(
          publisher: ref.read(homeWidgetPublisherProvider),
          session: session,
          server: () => _instance ?? instance,
          servers: () => ref.read(instancesProvider).value ?? [instance],
          locale: () => Localizations.localeOf(context),
          chosenDefault: () => ref.read(settingsProvider).defaultServerId,
        )..start();
        // A widget added since the app started gets its background refresh
        // from now on.
        unawaited(
          ref
              .read(alertNotificationServiceProvider)
              .resume(ref.read(settingsProvider)),
        );
      }
      if (updated.pinnedFingerprint != instance.pinnedFingerprint ||
          updated.lastApiVersion != instance.lastApiVersion) {
        // Remembering the pin is a courtesy; failing to save it must not
        // fail a connection that worked.
        await ref
            .read(instancesProvider.notifier)
            .upsert(updated)
            .catchError((_) {});
      }
      final info = await session.systemInfo();
      if (mounted) setState(() => _info = info);
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  /// Asks before closing an open server, whose shells and live views end with
  /// it. Going back from the connecting or error screen needs no question.
  Future<void> _confirmLeave() async {
    final l10n = AppLocalizations.of(context);
    final leave = await confirmAction(
      context,
      title: l10n.leaveServerTitle(_instance?.name ?? ''),
      body: l10n.leaveServerBody,
      confirmLabel: l10n.leaveServerConfirm,
      cancelLabel: l10n.leaveServerStay,
    );
    if (leave && mounted) Navigator.pop(context);
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop:
        !ref.watch(settingsProvider).confirmLeave ||
        _session == null ||
        _info == null,
    onPopInvokedWithResult: (didPop, _) {
      if (!didPop) _confirmLeave();
    },
    child: _screen(context),
  );

  /// The app's settings, one tap away from any screen of the server.
  List<Widget> _actions() => [
    if (_jobs != null && _session != null)
      JobGaugeButton(
        tracker: _jobs!.tracker,
        onOpen: () => openJobs(context, _session!),
      ),
    IconButton(
      tooltip: AppLocalizations.of(context).settingsTitle,
      onPressed: () => Navigator.push(
        context,
        MaterialPageRoute<void>(builder: (_) => const SettingsScreen()),
      ),
      icon: const Icon(Icons.settings_outlined),
    ),
    const SizedBox(width: 4),
  ];

  /// [content] with the running jobs floating over its bottom edge.
  Widget _withJobs(Widget content, TrueNasSession session, double bottom) {
    final jobs = _jobs;
    if (jobs == null) return content;
    return Stack(
      children: [
        content,
        Positioned(
          left: 12,
          right: 12,
          bottom: bottom,
          child: JobProgressBanner(
            tracker: jobs.tracker,
            onOpen: () => openJobs(context, session),
          ),
        ),
      ],
    );
  }

  Widget _screen(BuildContext context) {
    ref.listen(
      settingsProvider.select((s) => s.liveJobs),
      (_, on) => _jobs?.setLockScreen(on),
    );
    final l10n = AppLocalizations.of(context);
    final instance = _instance;
    final session = _session;
    final info = _info;
    if (session != null && info != null) {
      final destinations = [
        (
          Icons.space_dashboard_outlined,
          Icons.space_dashboard_rounded,
          l10n.tabDashboard,
        ),
        (Icons.storage_outlined, Icons.storage_rounded, l10n.tabStorage),
        (
          Icons.folder_shared_outlined,
          Icons.folder_shared_rounded,
          l10n.tabSharesShort,
        ),
        (Icons.widgets_outlined, Icons.widgets_rounded, l10n.tabApps),
        (Icons.more_horiz_rounded, Icons.more_horiz_rounded, l10n.tabMore),
      ];
      final body = IndexedStack(
        index: _tab,
        children: [
          DashboardTab(
            session: session,
            info: info,
            onOpenAlerts: () => openAlerts(context, session),
          ),
          StorageTab(session: session),
          SharesTab(session: session),
          AppsTab(session: session, onUpdateCount: _setAppUpdates),
          MoreTab(session: session, serverName: instance?.name ?? ''),
        ],
      );
      const appsTab = 3;
      // The count of apps with an update, on the Apps tab's icon.
      Widget badged(int index, IconData icon) => index == appsTab
          ? Badge.count(
              count: _appUpdates,
              isLabelVisible: _appUpdates > 0,
              child: Icon(icon),
            )
          : Icon(icon);
      void select(int index) {
        if (index != _tab) Haptics.selection();
        setState(() => _tab = index);
      }

      final width = MediaQuery.sizeOf(context).width;
      // Tablets and landscape phones get a side rail instead of a bottom bar.
      if (width >= railBreakpoint) {
        return Scaffold(
          appBar: AppBar(
            title: Text(instance?.name ?? ''),
            actions: _actions(),
          ),
          body: SafeArea(
            top: false,
            child: Row(
              children: [
                NavigationRail(
                  selectedIndex: _tab,
                  onDestinationSelected: select,
                  extended: width >= 1200,
                  labelType: width >= 1200
                      ? NavigationRailLabelType.none
                      : NavigationRailLabelType.all,
                  destinations: [
                    for (final (i, (icon, selected, label))
                        in destinations.indexed)
                      NavigationRailDestination(
                        icon: badged(i, icon),
                        selectedIcon: badged(i, selected),
                        label: Text(label),
                      ),
                  ],
                ),
                VerticalDivider(
                  width: 1,
                  color: Theme.of(context).colorScheme.outlineVariant,
                ),
                Expanded(child: _withJobs(body, session, 12)),
              ],
            ),
          ),
        );
      }
      if (useGlassChrome(context)) {
        // iOS: content scrolls under a transparent top bar and a floating
        // liquid glass tab bar.
        final insets = glassChromeInsets(context);
        return Scaffold(
          extendBodyBehindAppBar: true,
          appBar: AppBar(
            title: Text(instance?.name ?? ''),
            actions: _actions(),
            backgroundColor: Colors.transparent,
          ),
          body: Stack(
            children: [
              ChromeInsets(insets: insets, child: body),
              Positioned(
                left: 12,
                right: 12,
                bottom: insets.bottom - 4,
                child: _jobs == null
                    ? const SizedBox.shrink()
                    : JobProgressBanner(
                        tracker: _jobs!.tracker,
                        onOpen: () => openJobs(context, session),
                      ),
              ),
              GlassTopEdge(height: insets.top - 8),
              GlassTabBar(
                destinations: destinations,
                badges: {appsTab: _appUpdates},
                selectedIndex: _tab,
                onSelected: select,
              ),
            ],
          ),
        );
      }
      return Scaffold(
        appBar: AppBar(title: Text(instance?.name ?? ''), actions: _actions()),
        body: _withJobs(body, session, 12),
        bottomNavigationBar: DecoratedBox(
          decoration: BoxDecoration(
            border: Border(
              top: BorderSide(
                color: Theme.of(context).colorScheme.outlineVariant,
              ),
            ),
          ),
          child: NavigationBar(
            selectedIndex: _tab,
            onDestinationSelected: select,
            destinations: [
              for (final (i, (icon, selected, label)) in destinations.indexed)
                NavigationDestination(
                  icon: badged(i, icon),
                  selectedIcon: badged(i, selected),
                  label: label,
                ),
            ],
          ),
        ),
      );
    }
    return Scaffold(
      appBar: AppBar(title: Text(instance?.name ?? ''), actions: _actions()),
      body: _error != null
          ? _ErrorState(
              message: describeConnectError(l10n, _error!),
              onRetry: _connect,
            )
          : Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const CircularProgressIndicator.adaptive(),
                  const SizedBox(height: 16),
                  Text(l10n.connecting),
                ],
              ),
            ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  const _ErrorState({required this.message, required this.onRetry});

  final String message;
  final VoidCallback onRetry;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(Icons.cloud_off, size: 64, color: theme.colorScheme.error),
            const SizedBox(height: 16),
            Text(message, textAlign: TextAlign.center),
            const SizedBox(height: 16),
            FilledButton.tonal(
              onPressed: onRetry,
              child: Text(AppLocalizations.of(context).retry),
            ),
          ],
        ),
      ),
    );
  }
}

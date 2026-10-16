import 'package:flutter/material.dart';

import '../../core/api/sharing_api.dart';
import '../../core/models/sharing.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../storage/storage_helpers.dart';
import 'sharing_widgets.dart';

/// Every system service with its state, controls and start-on-boot switch.
class ServicesScreen extends StatefulWidget {
  const ServicesScreen({super.key, required this.session});

  final TrueNasSession session;

  @override
  State<ServicesScreen> createState() => _ServicesScreenState();
}

class _ServicesScreenState extends State<ServicesScreen>
    with LoadState<ServicesScreen, List<ServiceEntry>> {
  /// Services with an action in flight.
  final _busy = <String>{};

  @override
  Future<List<ServiceEntry>> fetch() => widget.session.sharing.services();

  Future<void> _control(ServiceEntry service, ServiceAction action) async {
    final l10n = AppLocalizations.of(context);
    if (action == ServiceAction.stop &&
        !await confirmAction(
          context,
          title: l10n.serviceStopTitle(service.displayName),
          body: l10n.serviceStopBody,
          confirmLabel: l10n.serviceStop,
          cancelLabel: l10n.cancel,
        )) {
      return;
    }
    if (!mounted) return;
    setState(() => _busy.add(service.service));
    await runWithFeedback(
      context,
      () => widget.session.sharing.controlService(service.service, action),
      success: action == ServiceAction.stop
          ? l10n.serviceStoppedMessage(service.displayName)
          : l10n.serviceStartedMessage(service.displayName),
    );
    await load();
    if (mounted) setState(() => _busy.remove(service.service));
  }

  Future<void> _autostart(ServiceEntry service, bool enable) async {
    setState(() => _busy.add(service.service));
    await runWithFeedback(
      context,
      () => widget.session.sharing.setServiceAutostart(service.id, enable),
    );
    await load();
    if (mounted) setState(() => _busy.remove(service.service));
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    return Scaffold(
      appBar: AppBar(title: Text(l10n.servicesTitle)),
      body: AsyncBody<List<ServiceEntry>>(
        value: data,
        error: error,
        onRefresh: load,
        builder: (services) => services.isEmpty
            ? ListView(
                children: [
                  const SizedBox(height: 120),
                  Center(child: Text(l10n.servicesEmpty)),
                ],
              )
            : ListView(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 24),
                children: [
                  GroupedCard(
                    indent: 16,
                    children: [
                      for (final service in services)
                        _ServiceTile(
                          service: service,
                          busy: _busy.contains(service.service),
                          onAction: (action) => _control(service, action),
                          onAutostart: (v) => _autostart(service, v),
                        ),
                    ],
                  ),
                ],
              ),
      ),
    );
  }
}

class _ServiceTile extends StatelessWidget {
  const _ServiceTile({
    required this.service,
    required this.busy,
    required this.onAction,
    required this.onAutostart,
  });

  final ServiceEntry service;
  final bool busy;
  final ValueChanged<ServiceAction> onAction;
  final ValueChanged<bool> onAutostart;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.fromLTRB(16, 12, 8, 4),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  service.displayName,
                  style: theme.textTheme.titleSmall,
                ),
              ),
              if (busy)
                const Padding(
                  padding: EdgeInsets.all(12),
                  child: SizedBox.square(
                    dimension: 20,
                    child: CircularProgressIndicator.adaptive(strokeWidth: 2),
                  ),
                )
              else
                ServiceStateLabel(service: service),
              PopupMenuButton<ServiceAction>(
                enabled: !busy,
                onSelected: onAction,
                itemBuilder: (_) => [
                  if (!service.running)
                    PopupMenuItem(
                      value: ServiceAction.start,
                      child: Text(l10n.serviceStart),
                    ),
                  if (service.running) ...[
                    PopupMenuItem(
                      value: ServiceAction.restart,
                      child: Text(l10n.serviceRestart),
                    ),
                    PopupMenuItem(
                      value: ServiceAction.stop,
                      child: Text(l10n.serviceStop),
                    ),
                  ],
                ],
              ),
            ],
          ),
          Row(
            children: [
              Expanded(
                child: Text(
                  l10n.serviceStartOnBoot,
                  style: theme.textTheme.bodyMedium?.copyWith(
                    color: theme.colorScheme.onSurfaceVariant,
                  ),
                ),
              ),
              AppSwitch(
                value: service.enable,
                onChanged: busy ? null : onAutostart,
              ),
              const SizedBox(width: 8),
            ],
          ),
        ],
      ),
    );
  }
}

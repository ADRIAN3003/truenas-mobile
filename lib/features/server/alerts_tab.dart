import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:intl/intl.dart';

import '../../core/models/alert.dart';
import '../../core/notifications/background_alerts.dart';
import '../../core/settings/settings_provider.dart';
import '../../core/session/truenas_session.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/dialogs.dart';
import '../../shared/theme.dart';
import '../../shared/ui.dart';
import '../../shared/widgets.dart';
import '../../shared/connect_dialogs.dart';
import '../../shared/viz_colors.dart';

/// Active and dismissed alerts, updated live.
class AlertsTab extends ConsumerStatefulWidget {
  const AlertsTab({super.key, required this.session});

  final TrueNasSession session;

  @override
  ConsumerState<AlertsTab> createState() => _AlertsTabState();
}

class _AlertsTabState extends ConsumerState<AlertsTab> {
  List<TrueNasAlert>? _alerts;
  Object? _error;
  StreamSubscription<Object?>? _changes;

  @override
  void initState() {
    super.initState();
    _changes = widget.session.alertChanges().listen(
      (_) => _load(),
      onError: (_) {},
    );
    _load();
  }

  @override
  void dispose() {
    _changes?.cancel();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final alerts = await widget.session.alerts();
      alerts.sort((a, b) {
        final bySeverity = b.level.index.compareTo(a.level.index);
        if (bySeverity != 0) return bySeverity;
        return (b.time ?? DateTime(0)).compareTo(a.time ?? DateTime(0));
      });
      if (!mounted) return;
      setState(() {
        _alerts = alerts;
        _error = null;
      });
    } catch (error) {
      if (mounted) setState(() => _error = error);
    }
  }

  Future<void> _toggle(TrueNasAlert alert) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    try {
      if (alert.dismissed) {
        await widget.session.restoreAlert(alert.id);
      } else {
        await widget.session.dismissAlert(alert.id);
      }
      await _load();
    } catch (error) {
      messenger.showSnackBar(
        SnackBar(content: Text(describeConnectError(l10n, error))),
      );
    }
  }

  /// Stops (or brings back) notifications for the kind of [alert].
  Future<void> _toggleMute(TrueNasAlert alert) async {
    final messenger = ScaffoldMessenger.of(context);
    final l10n = AppLocalizations.of(context);
    final label = AlertKind(alert.klass).label;
    final mute = !ref
        .read(settingsProvider)
        .mutedAlertKinds
        .contains(alert.klass);
    await ref
        .read(settingsProvider.notifier)
        .update(
          (s) => s.copyWith(
            mutedAlertKinds: {
              for (final id in s.mutedAlertKinds)
                if (id != alert.klass) id,
              if (mute) alert.klass,
            },
          ),
        );
    messenger.showSnackBar(
      SnackBar(
        content: Text(
          mute ? l10n.alertKindMuted(label) : l10n.alertKindUnmuted(label),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final canMute = ref.watch(alertNotificationServiceProvider).isSupported;
    final muted = ref.watch(settingsProvider.select((s) => s.mutedAlertKinds));
    final alerts = _alerts;
    if (alerts == null) {
      return Center(
        child: _error == null
            ? const CircularProgressIndicator.adaptive()
            : Text(describeConnectError(l10n, _error!)),
      );
    }
    final active = alerts.where((a) => !a.dismissed).toList();
    final dismissed = alerts.where((a) => a.dismissed).toList();
    return AppRefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 24),
        children: [
          ...groupedSection(l10n.alertsActive, indent: 72, [
            if (active.isEmpty)
              ListTile(
                leading: SoftIcon(
                  Icons.check_circle_rounded,
                  AppPalette.of(context).good,
                ),
                title: Text(l10n.alertsNone),
              ),
            for (final alert in active)
              _AlertTile(
                alert,
                onToggle: _toggle,
                onToggleMute: canMute ? _toggleMute : null,
                muted: muted.contains(alert.klass),
              ),
          ]),
          ...groupedSection(l10n.alertsDismissed, indent: 72, [
            for (final alert in dismissed)
              _AlertTile(
                alert,
                onToggle: _toggle,
                onToggleMute: canMute ? _toggleMute : null,
                muted: muted.contains(alert.klass),
              ),
          ]),
        ],
      ),
    );
  }
}

class _AlertTile extends StatelessWidget {
  const _AlertTile(
    this.alert, {
    required this.onToggle,
    required this.onToggleMute,
    required this.muted,
  });

  final TrueNasAlert alert;
  final ValueChanged<TrueNasAlert> onToggle;

  /// Stops or brings back notifications for this kind of alert; null where
  /// the phone shows no alert notifications.
  final ValueChanged<TrueNasAlert>? onToggleMute;

  /// Whether notifications for this kind of alert are off.
  final bool muted;

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final locale = Localizations.localeOf(context).toLanguageTag();
    final (icon, color, label) = switch (alert.level.severity) {
      AlertSeverity.critical => (
        Icons.error,
        VizColors.critical,
        l10n.levelCritical,
      ),
      AlertSeverity.warning => (
        Icons.warning_amber,
        VizColors.warning,
        l10n.levelWarning,
      ),
      AlertSeverity.info => (
        Icons.info_outline,
        theme.colorScheme.onSurfaceVariant,
        l10n.levelInfo,
      ),
    };
    final time = alert.time;
    final meta = [
      label,
      if (time != null) DateFormat.yMMMd(locale).add_jm().format(time),
    ].join(' · ');
    return Opacity(
      opacity: alert.dismissed ? 0.6 : 1,
      child: ListTile(
        leading: SoftIcon(
          icon,
          statusColors(context, color).$1,
          semanticLabel: label,
        ),
        title: Text(alert.plainMessage),
        subtitle: Text(meta),
        isThreeLine: alert.plainMessage.length > 60,
        trailing: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextButton(
              onPressed: () => onToggle(alert),
              child: Text(
                alert.dismissed ? l10n.alertRestore : l10n.alertDismiss,
              ),
            ),
            if (onToggleMute != null && alert.klass.isNotEmpty)
              AppPopupMenu<bool>(
                entries: [
                  menuEntry(
                    true,
                    muted ? l10n.alertUnmuteKind : l10n.alertMuteKind,
                  ),
                ],
                onSelected: (_) => onToggleMute!(alert),
              ),
          ],
        ),
      ),
    );
  }
}

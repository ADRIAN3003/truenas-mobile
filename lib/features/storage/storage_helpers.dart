import 'package:flutter/material.dart';

import '../../l10n/generated/app_localizations.dart';
import '../../shared/connect_dialogs.dart';
import '../../shared/theme.dart';
import '../../shared/viz_colors.dart';

/// Runs [action], shows [success] or the error in a snackbar, and returns
/// whether it succeeded.
Future<bool> runWithFeedback(
  BuildContext context,
  Future<void> Function() action, {
  String? success,
}) async {
  final messenger = ScaffoldMessenger.of(context);
  final l10n = AppLocalizations.of(context);
  try {
    await action();
    if (success != null) {
      messenger.showSnackBar(SnackBar(content: Text(success)));
    }
    return true;
  } catch (error) {
    messenger.showSnackBar(
      SnackBar(content: Text(describeConnectError(l10n, error))),
    );
    return false;
  }
}

/// Icon and colour for a ZFS status such as `ONLINE` or `DEGRADED`.
(IconData, Color) zfsStatusStyle(String status) => switch (status) {
  'ONLINE' => (Icons.check_circle, VizColors.good),
  'DEGRADED' => (Icons.warning_amber, VizColors.warning),
  _ => (Icons.error, VizColors.critical),
};

/// Status pill tone for a ZFS status.
StatusTone zfsStatusTone(String status) => switch (status) {
  'ONLINE' => StatusTone.good,
  'DEGRADED' => StatusTone.warning,
  _ => StatusTone.critical,
};

/// A loading / error / content switch with pull to refresh.
class AsyncBody<T> extends StatelessWidget {
  const AsyncBody({
    super.key,
    required this.value,
    required this.error,
    required this.onRefresh,
    required this.builder,
  });

  final T? value;
  final Object? error;
  final Future<void> Function() onRefresh;
  final Widget Function(T value) builder;

  @override
  Widget build(BuildContext context) {
    final value = this.value;
    if (value != null) {
      return RefreshIndicator.adaptive(
        onRefresh: onRefresh,
        child: builder(value),
      );
    }
    if (error != null) {
      return Center(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                describeConnectError(AppLocalizations.of(context), error!),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 16),
              FilledButton.tonal(
                onPressed: onRefresh,
                child: Text(AppLocalizations.of(context).retry),
              ),
            ],
          ),
        ),
      );
    }
    return const Center(child: CircularProgressIndicator.adaptive());
  }
}

/// A label/value row used in detail cards.
class InfoRow extends StatelessWidget {
  const InfoRow(this.label, this.value, {super.key});

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Text(
              label,
              style: theme.textTheme.bodyMedium?.copyWith(
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ),
          const SizedBox(width: 16),
          Flexible(
            child: Text(
              value,
              textAlign: TextAlign.end,
              style: theme.textTheme.bodyMedium,
            ),
          ),
        ],
      ),
    );
  }
}

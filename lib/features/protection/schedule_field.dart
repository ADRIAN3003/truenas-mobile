import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../../core/models/cron_schedule.dart';
import '../../core/models/protection.dart';
import '../../l10n/generated/app_localizations.dart';
import '../../shared/dialogs.dart';

/// A weekday name; [day] 0 is Sunday.
String _weekdayName(String locale, int day, {bool short = false}) {
  // 1 January 2023 was a Sunday.
  final date = DateTime(2023, 1, 1 + day);
  return (short ? DateFormat.E(locale) : DateFormat.EEEE(locale)).format(date);
}

String _timeOfDay(String locale, int hour, int minute) =>
    DateFormat.jm(locale).format(DateTime(2023, 1, 1, hour, minute));

/// [schedule] in words when it is one of the shapes the custom editor
/// builds, otherwise its cron text.
String cronDescription(AppLocalizations l10n, CronSchedule schedule) {
  final draft = CronDraft.from(schedule);
  final locale = l10n.localeName;
  final time = _timeOfDay(locale, draft.hour, draft.minute);
  return switch (draft.mode) {
    CronMode.minutes => l10n.scheduleEveryMinutes(draft.interval),
    CronMode.hourly => l10n.scheduleEveryHours(draft.interval, draft.minute),
    CronMode.daily => l10n.scheduleDailyAt(time),
    CronMode.weekly => l10n.scheduleWeeklyAt(
      [
        for (final d in _mondayFirst)
          if (draft.weekdays.contains(d)) _weekdayName(locale, d),
      ].join(', '),
      time,
    ),
    CronMode.monthly => l10n.scheduleMonthlyAt(draft.day, time),
    CronMode.advanced => l10n.scheduleCustom(schedule.text),
  };
}

const _mondayFirst = [1, 2, 3, 4, 5, 6, 0];

/// What the "Custom…" entry of a [ScheduleField] stands for.
const _customChoice = Object();

/// A dropdown of the schedule presets, the schedule a task already has when
/// it is none of them, and "Custom…", which opens [showCronEditor].
///
/// [value] is a [SnapshotSchedule], a [CronSchedule] or null; null only
/// when [noneLabel] is given (a replication that follows its snapshots).
class ScheduleField extends StatefulWidget {
  const ScheduleField({
    super.key,
    required this.value,
    required this.onChanged,
    this.noneLabel,
  });

  final Object? value;
  final ValueChanged<Object?> onChanged;
  final String? noneLabel;

  @override
  State<ScheduleField> createState() => _ScheduleFieldState();
}

class _ScheduleFieldState extends State<ScheduleField> {
  /// Bumped when the editor is cancelled, to show the old choice again.
  int _revision = 0;

  Future<void> _change(Object? choice) async {
    if (!identical(choice, _customChoice)) return widget.onChanged(choice);
    final current = widget.value;
    final edited = await showCronEditor(context, switch (current) {
      final CronSchedule cron => cron,
      final SnapshotSchedule preset => preset.asCron,
      _ => null,
    });
    if (!mounted) return;
    if (edited == null) {
      setState(() => _revision++);
    } else {
      widget.onChanged(edited);
    }
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final value = widget.value;
    return DropdownButtonFormField<Object?>(
      key: ValueKey((value, widget.noneLabel != null, _revision)),
      initialValue: value,
      isExpanded: true,
      decoration: InputDecoration(labelText: l10n.snapshotTaskSchedule),
      items: [
        if (widget.noneLabel case final label?)
          DropdownMenuItem(value: null, child: Text(label)),
        for (final s in SnapshotSchedule.values)
          DropdownMenuItem(value: s, child: Text(scheduleLabel(l10n, s))),
        if (value is CronSchedule)
          DropdownMenuItem(
            value: value,
            child: Text(scheduleLabel(l10n, value)),
          ),
        DropdownMenuItem(
          value: _customChoice,
          child: Text(l10n.scheduleCustomChoice),
        ),
      ],
      onChanged: _change,
    );
  }
}

/// Words for a schedule: a preset's name, or [cronDescription].
String scheduleLabel(AppLocalizations l10n, Object? schedule) =>
    switch (schedule) {
      SnapshotSchedule.hourly => l10n.scheduleHourly,
      SnapshotSchedule.daily => l10n.scheduleDaily,
      SnapshotSchedule.weekly => l10n.scheduleWeekly,
      final CronSchedule cron => cronDescription(l10n, cron),
      _ => '',
    };

/// Asks for a schedule, starting from [initial] (null for a daily one).
/// Null when cancelled.
Future<CronSchedule?> showCronEditor(
  BuildContext context,
  CronSchedule? initial,
) => showAppDialog<CronSchedule>(
  context: context,
  builder: (_) => _CronEditor(initial: initial),
);

class _CronEditor extends StatefulWidget {
  const _CronEditor({required this.initial});

  final CronSchedule? initial;

  @override
  State<_CronEditor> createState() => _CronEditorState();
}

class _CronEditorState extends State<_CronEditor> {
  late final CronDraft _draft = CronDraft.from(widget.initial);
  late final List<TextEditingController> _fields = [
    for (final text in _draft.advanced) TextEditingController(text: text),
  ];

  @override
  void dispose() {
    for (final c in _fields) {
      c.dispose();
    }
    super.dispose();
  }

  void _setMode(CronMode mode) => setState(() {
    _draft.switchTo(mode);
    if (mode == CronMode.advanced) {
      for (final (i, text) in _draft.advanced.indexed) {
        _fields[i].text = text;
      }
    }
  });

  static String _two(int n) => n.toString().padLeft(2, '0');

  Widget _numbers({
    required String label,
    required int value,
    required Iterable<int> options,
    required ValueChanged<int> onChanged,
    String Function(int)? format,
  }) => DropdownButtonFormField<int>(
    key: ValueKey((label, value)),
    initialValue: value,
    isExpanded: true,
    decoration: InputDecoration(labelText: label),
    items: [
      for (final n in options)
        DropdownMenuItem(value: n, child: Text(format?.call(n) ?? '$n')),
    ],
    onChanged: (n) => setState(() => onChanged(n!)),
  );

  /// Hour and minute, side by side.
  Widget _timeOfDayRow(AppLocalizations l10n) => Row(
    children: [
      Expanded(
        child: _numbers(
          label: l10n.cronTimeHour,
          value: _draft.hour,
          options: List.generate(24, (i) => i),
          format: _two,
          onChanged: (n) => _draft.hour = n,
        ),
      ),
      const SizedBox(width: 12),
      Expanded(
        child: _numbers(
          label: l10n.cronTimeMinute,
          value: _draft.minute,
          options: List.generate(60, (i) => i),
          format: _two,
          onChanged: (n) => _draft.minute = n,
        ),
      ),
    ],
  );

  List<Widget> _modeFields(AppLocalizations l10n, ThemeData theme) {
    final locale = l10n.localeName;
    return switch (_draft.mode) {
      CronMode.minutes => [
        _numbers(
          label: l10n.cronMinutesBetween,
          value: _draft.interval,
          options: CronDraft.minuteIntervals,
          onChanged: (n) => _draft.interval = n,
        ),
      ],
      CronMode.hourly => [
        _numbers(
          label: l10n.cronHoursBetween,
          value: _draft.interval,
          options: CronDraft.hourIntervals,
          onChanged: (n) => _draft.interval = n,
        ),
        _numbers(
          label: l10n.cronAtMinute,
          value: _draft.minute,
          options: List.generate(60, (i) => i),
          format: _two,
          onChanged: (n) => _draft.minute = n,
        ),
      ],
      CronMode.daily => [_timeOfDayRow(l10n)],
      CronMode.weekly => [
        Text(l10n.cronWeekdays, style: theme.textTheme.bodySmall),
        Wrap(
          spacing: 6,
          children: [
            for (final d in _mondayFirst)
              FilterChip(
                label: Text(_weekdayName(locale, d, short: true)),
                selected: _draft.weekdays.contains(d),
                onSelected: (on) => setState(
                  () => on ? _draft.weekdays.add(d) : _draft.weekdays.remove(d),
                ),
              ),
          ],
        ),
        if (_draft.weekdays.isEmpty)
          Text(
            l10n.cronPickWeekday,
            style: theme.textTheme.bodySmall?.copyWith(
              color: theme.colorScheme.error,
            ),
          ),
        _timeOfDayRow(l10n),
      ],
      CronMode.monthly => [
        _numbers(
          label: l10n.cronDayOfMonth,
          value: _draft.day,
          options: List.generate(31, (i) => i + 1),
          onChanged: (n) => _draft.day = n,
        ),
        _timeOfDayRow(l10n),
      ],
      CronMode.advanced => [
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            for (final (i, label) in [
              l10n.cronFieldMinute,
              l10n.cronFieldHour,
              l10n.cronFieldDom,
              l10n.cronFieldMonth,
              l10n.cronFieldDow,
            ].indexed)
              SizedBox(
                width: 76,
                child: TextField(
                  controller: _fields[i],
                  decoration: InputDecoration(
                    labelText: label,
                    errorText: CronField.values[i].accepts(_draft.advanced[i])
                        ? null
                        : l10n.cronFieldInvalid,
                    errorMaxLines: 2,
                  ),
                  autocorrect: false,
                  enableSuggestions: false,
                  keyboardType: TextInputType.visiblePassword,
                  onChanged: (text) =>
                      setState(() => _draft.advanced[i] = text.trim()),
                ),
              ),
          ],
        ),
        Text(l10n.cronAdvancedHelp, style: theme.textTheme.bodySmall),
      ],
    };
  }

  @override
  Widget build(BuildContext context) {
    final l10n = AppLocalizations.of(context);
    final theme = Theme.of(context);
    final schedule = _draft.build();
    final modeNames = {
      CronMode.minutes: l10n.cronModeMinutes,
      CronMode.hourly: l10n.cronModeHourly,
      CronMode.daily: l10n.cronModeDaily,
      CronMode.weekly: l10n.cronModeWeekly,
      CronMode.monthly: l10n.cronModeMonthly,
      CronMode.advanced: l10n.cronModeAdvanced,
    };
    return AppDialog(
      title: Text(l10n.cronEditorTitle),
      scrollable: true,
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        spacing: 12,
        children: [
          DropdownButtonFormField<CronMode>(
            key: ValueKey(_draft.mode),
            initialValue: _draft.mode,
            isExpanded: true,
            decoration: InputDecoration(labelText: l10n.cronRepeat),
            items: [
              for (final m in CronMode.values)
                DropdownMenuItem(value: m, child: Text(modeNames[m]!)),
            ],
            onChanged: (m) => _setMode(m!),
          ),
          ..._modeFields(l10n, theme),
          if (_draft.isValid) ...[
            Text(
              cronDescription(l10n, schedule),
              style: theme.textTheme.bodyMedium,
            ),
            Text(
              schedule.text,
              style: theme.textTheme.bodySmall?.copyWith(
                fontFamily: 'monospace',
                color: theme.colorScheme.onSurfaceVariant,
              ),
            ),
          ],
        ],
      ),
      actions: [
        dialogAction(
          context,
          label: l10n.cancel,
          onPressed: () => Navigator.pop(context),
        ),
        dialogAction(
          context,
          label: l10n.done,
          primary: true,
          onPressed: _draft.isValid
              ? () => Navigator.pop(context, schedule)
              : null,
        ),
      ],
    );
  }
}

/// The five cron fields TrueNAS schedules use, and what each accepts.
enum CronField {
  minute(0, 59),
  hour(0, 23),
  dom(1, 31),
  month(1, 12),
  dow(0, 7);

  const CronField(this.min, this.max);

  final int min;
  final int max;

  static const _months = {
    'jan': 1,
    'feb': 2,
    'mar': 3,
    'apr': 4,
    'may': 5,
    'jun': 6,
    'jul': 7,
    'aug': 8,
    'sep': 9,
    'oct': 10,
    'nov': 11,
    'dec': 12,
  };

  static const _weekdays = {
    'sun': 0,
    'mon': 1,
    'tue': 2,
    'wed': 3,
    'thu': 4,
    'fri': 5,
    'sat': 6,
  };

  int? _value(String text) {
    if (RegExp(r'^\d+$').hasMatch(text)) return int.parse(text);
    return switch (this) {
      month => _months[text.toLowerCase()],
      dow => _weekdays[text.toLowerCase()],
      _ => null,
    };
  }

  bool _inRange(int? n) => n != null && n >= min && n <= max;

  /// Whether [text] is a cron expression for this field: a comma list of `*`,
  /// numbers, `a-b` ranges, each with an optional `/step`.
  bool accepts(String text) {
    if (text.isEmpty) return false;
    for (final part in text.split(',')) {
      final pieces = part.split('/');
      if (pieces.length > 2) return false;
      if (pieces.length == 2) {
        final step = int.tryParse(pieces[1]);
        if (step == null || step < 1 || !RegExp(r'^\d+$').hasMatch(pieces[1])) {
          return false;
        }
      }
      final range = pieces.first;
      if (range == '*') continue;
      final ends = range.split('-');
      if (ends.length > 2) return false;
      final values = ends.map(_value).toList();
      if (!values.every(_inRange)) return false;
      if (values.length == 2 && values[0]! > values[1]!) return false;
    }
    return true;
  }
}

/// A cron schedule as TrueNAS stores it: five text fields, and for snapshot
/// and replication tasks the time window (`begin`, `end`) it may run in.
class CronSchedule {
  const CronSchedule({
    this.minute = '0',
    this.hour = '*',
    this.dom = '*',
    this.month = '*',
    this.dow = '*',
    this.begin,
    this.end,
  });

  factory CronSchedule.fromJson(Map<String, dynamic> json) {
    String field(String key) {
      final text = (json[key] ?? '*').toString().trim();
      return text.isEmpty ? '*' : text;
    }

    String? window(String key) {
      final text = json[key];
      return text is String && text.isNotEmpty ? text : null;
    }

    return CronSchedule(
      minute: field('minute'),
      hour: field('hour'),
      dom: field('dom'),
      month: field('month'),
      dow: field('dow'),
      begin: window('begin'),
      end: window('end'),
    );
  }

  final String minute;
  final String hour;
  final String dom;
  final String month;
  final String dow;

  /// The time of day the task may start in; null leaves the server's.
  final String? begin;
  final String? end;

  /// The five fields in cron order.
  List<String> get fields => [minute, hour, dom, month, dow];

  /// `minute hour dom month dow`, as written in a crontab.
  String get text => fields.join(' ');

  /// Whether every field is something cron accepts.
  bool get isValid {
    for (final (i, field) in CronField.values.indexed) {
      if (!field.accepts(fields[i])) return false;
    }
    return true;
  }

  /// The request body for the server. [window] adds the whole-day window
  /// snapshot and replication tasks need when none was carried over.
  Map<String, String> toJson({bool window = false}) => {
    'minute': minute,
    'hour': hour,
    'dom': dom,
    'month': month,
    'dow': dow,
    if (begin != null || window) 'begin': begin ?? '00:00',
    if (end != null || window) 'end': end ?? '23:59',
  };

  @override
  bool operator ==(Object other) =>
      other is CronSchedule &&
      other.text == text &&
      other.begin == begin &&
      other.end == end;

  @override
  int get hashCode => Object.hash(text, begin, end);

  @override
  String toString() => text;
}

/// The kinds of schedule the custom editor builds without cron knowledge.
enum CronMode { minutes, hourly, daily, weekly, monthly, advanced }

/// What the custom schedule editor edits: one mode and its settings, which
/// [build] turns into a [CronSchedule] and [CronDraft.from] reads back.
class CronDraft {
  CronDraft({
    this.mode = CronMode.daily,
    this.interval = 1,
    this.minute = 0,
    this.hour = 0,
    Set<int>? weekdays,
    this.day = 1,
    List<String>? advanced,
    this.begin,
    this.end,
  }) : weekdays = weekdays ?? {1},
       advanced = advanced ?? ['0', '0', '*', '*', '*'];

  /// Reads [schedule] into the simplest mode that says the same thing, or
  /// [CronMode.advanced] when none does.
  factory CronDraft.from(CronSchedule? schedule) {
    if (schedule == null) return CronDraft();
    final draft = CronDraft(
      mode: CronMode.advanced,
      advanced: schedule.fields,
      begin: schedule.begin,
      end: schedule.end,
    );
    int? number(String text, int max) {
      if (!RegExp(r'^\d{1,2}$').hasMatch(text)) return null;
      final n = int.parse(text);
      return n <= max ? n : null;
    }

    int? step(String text, List<int> allowed) {
      final n = text == '*'
          ? 1
          : text.startsWith('*/')
          ? number(text.substring(2), 59)
          : null;
      return n != null && allowed.contains(n) ? n : null;
    }

    final s = schedule;
    final rest = s.month == '*' && s.dow == '*';
    final minute = number(s.minute, 59);
    final hour = number(s.hour, 23);
    final dayless = s.dom == '*' && rest;

    final everyMinutes = step(s.minute, minuteIntervals);
    if (everyMinutes != null && s.hour == '*' && dayless) {
      return draft
        ..mode = CronMode.minutes
        ..interval = everyMinutes;
    }
    final everyHours = step(s.hour, hourIntervals);
    if (minute != null && everyHours != null && dayless) {
      return draft
        ..mode = CronMode.hourly
        ..minute = minute
        ..interval = everyHours;
    }
    if (minute == null || hour == null) return draft;
    draft
      ..minute = minute
      ..hour = hour;
    if (dayless) return draft..mode = CronMode.daily;
    final dayOfMonth = number(s.dom, 31);
    if (dayOfMonth != null && dayOfMonth >= 1 && rest) {
      return draft
        ..mode = CronMode.monthly
        ..day = dayOfMonth;
    }
    if (s.dom == '*' && s.month == '*' && s.dow != '*') {
      final days = <int>{};
      for (final part in s.dow.split(',')) {
        final n = number(part, 7);
        if (n == null) return draft..mode = CronMode.advanced;
        days.add(n % 7);
      }
      return draft
        ..mode = CronMode.weekly
        ..weekdays = days;
    }
    return draft;
  }

  /// Run every this many minutes.
  static const minuteIntervals = [1, 2, 3, 4, 5, 6, 10, 12, 15, 20, 30];

  /// Run every this many hours.
  static const hourIntervals = [1, 2, 3, 4, 6, 8, 12];

  CronMode mode;

  /// Minutes between runs in [CronMode.minutes], hours in [CronMode.hourly].
  int interval;
  int minute;
  int hour;

  /// 0 is Sunday.
  Set<int> weekdays;
  int day;

  /// The five fields of [CronMode.advanced], as typed.
  List<String> advanced;

  /// Carried through from the schedule being edited.
  String? begin;
  String? end;

  /// Switches to [next], keeping what it can: the advanced fields start from
  /// what the old mode was saying.
  void switchTo(CronMode next) {
    if (next == CronMode.advanced && mode != CronMode.advanced) {
      advanced = build().fields;
    }
    mode = next;
    if (next == CronMode.minutes && !minuteIntervals.contains(interval)) {
      interval = 5;
    }
    if (next == CronMode.hourly && !hourIntervals.contains(interval)) {
      interval = 1;
    }
  }

  /// Whether [build] gives a schedule the server will take.
  bool get isValid => switch (mode) {
    CronMode.weekly => weekdays.isNotEmpty,
    CronMode.advanced => build().isValid,
    _ => true,
  };

  CronSchedule build() {
    String every(int n) => n == 1 ? '*' : '*/$n';
    final days = (weekdays.toList()..sort()).join(',');
    final (m, h, dom, dow) = switch (mode) {
      CronMode.minutes => (every(interval), '*', '*', '*'),
      CronMode.hourly => ('$minute', every(interval), '*', '*'),
      CronMode.daily => ('$minute', '$hour', '*', '*'),
      CronMode.weekly => ('$minute', '$hour', '*', days.isEmpty ? '*' : days),
      CronMode.monthly => ('$minute', '$hour', '$day', '*'),
      CronMode.advanced => (advanced[0], advanced[1], advanced[2], advanced[4]),
    };
    return CronSchedule(
      minute: m.trim(),
      hour: h.trim(),
      dom: dom.trim(),
      month: mode == CronMode.advanced ? advanced[3].trim() : '*',
      dow: dow.trim(),
      begin: begin,
      end: end,
    );
  }
}

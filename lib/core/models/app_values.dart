import 'app_catalog.dart';

/// Why a value does not fit its setting.
enum AppValueProblem {
  required,
  notNumber,
  tooSmall,
  tooLarge,
  tooShort,
  tooLong,
  invalidChars,
}

/// Building and tidying the values an app is installed or edited with: the
/// plain JSON map `app.create` and `app.update` take.
abstract final class AppValues {
  /// Deep copy of decoded JSON.
  static Object? copy(Object? value) => switch (value) {
    final Map<dynamic, dynamic> m => {
      for (final e in m.entries) e.key.toString(): copy(e.value),
    },
    final List<dynamic> l => [for (final e in l) copy(e)],
    _ => value,
  };

  /// The values a fresh form starts with: every setting at its default.
  static Map<String, dynamic> defaults(List<AppQuestion> questions) => {
    for (final q in questions) ..._defaultsOf(q),
  };

  static Map<String, dynamic> _defaultsOf(AppQuestion q) => {
    q.variable: defaultFor(q),
    for (final sub in q.schema.subquestions) ..._defaultsOf(sub),
  };

  /// What a new value of [q] is: its default, else an empty one of its kind.
  static Object? defaultFor(AppQuestion q) {
    final s = q.schema;
    final given = s.defaultValue;
    switch (s.type) {
      case 'dict':
        return {
          ...defaults(s.attrs),
          if (given is Map) ...copy(given)! as Map<String, dynamic>,
        };
      case 'list':
        return given is List ? copy(given) : <Object?>[];
      case 'boolean':
        return given is bool ? given : false;
      case 'int':
        return given is num ? given.toInt() : null;
      default:
        if (given != null) return copy(given);
        return s.nullable || (s.choices.isNotEmpty && !s.required) ? null : '';
    }
  }

  /// A new entry of the list setting [list].
  static Object? newItem(AppQuestion list) {
    final item = list.schema.items.firstOrNull;
    return item == null ? '' : defaultFor(item);
  }

  /// Adds the settings [values] lacks (a newer version brings new ones),
  /// inside dicts and list entries too. Returns a new map.
  static Map<String, dynamic> fill(
    List<AppQuestion> questions,
    Map<String, dynamic> values,
  ) {
    final out = <String, dynamic>{...values};
    void one(AppQuestion q) {
      if (!out.containsKey(q.variable)) {
        out[q.variable] = defaultFor(q);
      } else {
        out[q.variable] = _fillValue(q, out[q.variable]);
      }
      for (final sub in q.schema.subquestions) {
        one(sub);
      }
    }

    questions.forEach(one);
    return out;
  }

  static Object? _fillValue(AppQuestion q, Object? value) {
    final s = q.schema;
    if (s.type == 'dict' && value is Map<String, dynamic>) {
      return fill(s.attrs, value);
    }
    if (s.type == 'list' && value is List && s.items.isNotEmpty) {
      final item = s.items.first;
      return [for (final e in value) _fillValue(item, e)];
    }
    return value;
  }

  /// Whether [q] is shown, given the other settings at its level.
  static bool isVisible(AppQuestion q, Map<String, dynamic> siblings) {
    for (final rule in q.schema.showIf) {
      final actual = _lookup(siblings, rule[0].toString());
      final expected = rule[2];
      final holds = switch (rule[1]) {
        '=' => _same(actual, expected),
        '!=' => !_same(actual, expected),
        'in' => expected is List && expected.any((e) => _same(actual, e)),
        'nin' => expected is List && !expected.any((e) => _same(actual, e)),
        _ => true,
      };
      if (!holds) return false;
    }
    return true;
  }

  static Object? _lookup(Map<String, dynamic> values, String path) {
    Object? current = values;
    for (final part in path.split('.')) {
      if (current is! Map) return null;
      current = current[part];
    }
    return current;
  }

  static bool _same(Object? a, Object? b) =>
      a == b || (a is num && b is num && a == b);

  /// The settings of one level that apply now: the questions whose `show_if`
  /// holds, with the sub-questions of those whose answer unlocks them.
  static List<AppQuestion> applicable(
    List<AppQuestion> questions,
    Map<String, dynamic> values,
  ) {
    final out = <AppQuestion>[];
    void one(AppQuestion q) {
      if (!isVisible(q, values)) return;
      out.add(q);
      final unlock = q.schema.showSubquestionsIf;
      if (q.schema.subquestions.isNotEmpty &&
          _same(values[q.variable], unlock)) {
        q.schema.subquestions.forEach(one);
      }
    }

    questions.forEach(one);
    return out;
  }

  /// [values] without the settings that don't apply, which is what the web
  /// UI sends. Keys the schema doesn't know (like `ix_volumes`) stay.
  static Map<String, dynamic> prune(
    List<AppQuestion> questions,
    Map<String, dynamic> values,
  ) {
    final known = <String>{};
    void collect(AppQuestion q) {
      known.add(q.variable);
      q.schema.subquestions.forEach(collect);
    }

    questions.forEach(collect);
    final keep = applicable(questions, values);
    final out = <String, dynamic>{};
    for (final MapEntry(:key, :value) in values.entries) {
      final q = keep.where((q) => q.variable == key).firstOrNull;
      if (q != null) {
        out[key] = _pruneValue(q, value);
      } else if (!known.contains(key)) {
        out[key] = value;
      }
    }
    return out;
  }

  static Object? _pruneValue(AppQuestion q, Object? value) {
    final s = q.schema;
    if (s.type == 'dict' && value is Map<String, dynamic>) {
      return prune(s.attrs, value);
    }
    if (s.type == 'list' && value is List && s.items.isNotEmpty) {
      final item = s.items.first;
      return [for (final e in value) _pruneValue(item, e)];
    }
    return value;
  }

  /// What is wrong with [value] for [q], or null when it is fine. Container
  /// settings are checked through their fields.
  static AppValueProblem? check(AppQuestion q, Object? value) {
    final s = q.schema;
    if (s.isContainer) return null;
    final empty = value == null || (value is String && value.trim().isEmpty);
    if (empty) {
      return s.required && !s.nullable && s.type != 'boolean'
          ? AppValueProblem.required
          : null;
    }
    if (s.type == 'int') {
      if (value is! num) return AppValueProblem.notNumber;
      if (s.min != null && value < s.min!) return AppValueProblem.tooSmall;
      if (s.max != null && value > s.max!) return AppValueProblem.tooLarge;
      return null;
    }
    if (value is String) {
      if (s.minLength != null && value.length < s.minLength!) {
        return AppValueProblem.tooShort;
      }
      if (s.maxLength != null && value.length > s.maxLength!) {
        return AppValueProblem.tooLong;
      }
      final chars = s.validChars;
      if (chars != null) {
        try {
          if (!RegExp(chars).hasMatch(value)) {
            return AppValueProblem.invalidChars;
          }
        } on FormatException {
          // A pattern Dart can't read: leave it to the server.
        }
      }
    }
    return null;
  }

  /// The first problem in [values] against [questions], as
  /// (the setting, what is wrong), looking into dicts and lists.
  static (AppQuestion, AppValueProblem)? firstProblem(
    List<AppQuestion> questions,
    Map<String, dynamic> values,
  ) {
    for (final q in applicable(questions, values)) {
      if (q.isHidden) continue;
      final value = values[q.variable];
      final s = q.schema;
      if (s.type == 'dict' && value is Map<String, dynamic>) {
        final inner = firstProblem(s.attrs, value);
        if (inner != null) return inner;
      } else if (s.type == 'list' && value is List && s.items.isNotEmpty) {
        final item = s.items.first;
        for (final e in value) {
          if (item.schema.type == 'dict' && e is Map<String, dynamic>) {
            final inner = firstProblem(item.schema.attrs, e);
            if (inner != null) return inner;
          } else {
            final problem = check(item, e);
            if (problem != null) return (item, problem);
          }
        }
      } else {
        final problem = check(q, value);
        if (problem != null) return (q, problem);
      }
    }
    return null;
  }
}

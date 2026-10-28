import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

void main() {
  // A RemoteViews layout may only use these classes; anything else (a plain
  // View, a Space, a ScrollView...) makes the launcher say "Problem loading
  // widget".
  const allowed = {
    'FrameLayout',
    'LinearLayout',
    'RelativeLayout',
    'GridLayout',
    'AnalogClock',
    'Button',
    'Chronometer',
    'ImageButton',
    'ImageView',
    'ProgressBar',
    'TextClock',
    'TextView',
    'ViewFlipper',
    'ListView',
    'GridView',
    'StackView',
    'AdapterViewFlipper',
    'ViewStub',
  };

  test('Android widget layouts only use views a RemoteViews can inflate', () {
    final layouts = Directory('android/app/src/main/res/layout')
        .listSync()
        .whereType<File>()
        .where((f) => f.uri.pathSegments.last.startsWith('widget_'));
    expect(layouts, isNotEmpty);
    for (final file in layouts) {
      final tagPattern = RegExp(r'<([A-Za-z][\w.]*)');
      final text = file.readAsStringSync();
      final tags = tagPattern.allMatches(text).map((m) => m.group(1)!);
      for (final tag in tags) {
        expect(allowed, contains(tag), reason: '$tag in ${file.path}');
      }
    }
  });
}

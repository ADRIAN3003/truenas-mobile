import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/shared/theme.dart';
import 'package:truenas_mobile/shared/ui.dart';
import 'package:truenas_mobile/shared/widgets.dart';

const _blue = Color(0xFF2A78D6);
const _orange = Color(0xFFEB6834);

void main() {
  Widget host(Widget child, {bool reduceMotion = false}) => MaterialApp(
    theme: buildAppTheme(Brightness.light),
    home: MediaQuery(
      data: MediaQueryData(disableAnimations: reduceMotion),
      child: Scaffold(body: Center(child: child)),
    ),
  );

  /// The segment fractions the ring is painting right now.
  List<double> drawn(WidgetTester tester) {
    final paint = tester.widget<CustomPaint>(
      find.descendant(
        of: find.byType(RingGauge),
        matching: find.byType(CustomPaint),
      ),
    );
    final segments = (paint.painter! as dynamic).segments as List;
    return [for (final (fraction as double, _) in segments) fraction];
  }

  group('RingGauge', () {
    testWidgets('sweeps in, then glides to a new value', (tester) async {
      await tester.pumpWidget(
        host(const RingGauge(segments: [(0.2, _blue)], child: Text('20'))),
      );
      expect(drawn(tester).single, 0);
      await tester.pump(const Duration(milliseconds: 200));
      expect(drawn(tester).single, inExclusiveRange(0, 0.2));
      await tester.pumpAndSettle();
      expect(drawn(tester).single, closeTo(0.2, 1e-9));

      await tester.pumpWidget(
        host(const RingGauge(segments: [(0.8, _blue)], child: Text('80'))),
      );
      await tester.pump(const Duration(milliseconds: 200));
      expect(drawn(tester).single, inExclusiveRange(0.2, 0.8));
      await tester.pumpAndSettle();
      expect(drawn(tester).single, closeTo(0.8, 1e-9));
    });

    testWidgets('grows and shrinks segments when their number changes', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const RingGauge(segments: [(0.3, _blue)], child: Text('x'))),
      );
      await tester.pumpAndSettle();
      await tester.pumpWidget(
        host(
          const RingGauge(
            segments: [(0.3, _blue), (0.2, _orange)],
            child: Text('x'),
          ),
        ),
      );
      await tester.pump(const Duration(milliseconds: 200));
      final midway = drawn(tester);
      expect(midway, hasLength(2));
      expect(midway.last, inExclusiveRange(0, 0.2));
      await tester.pumpAndSettle();
      expect(drawn(tester), [closeTo(0.3, 1e-9), closeTo(0.2, 1e-9)]);
    });

    testWidgets('jumps straight to the value with reduce motion on', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(
          const RingGauge(segments: [(0.6, _blue)], child: Text('60')),
          reduceMotion: true,
        ),
      );
      expect(drawn(tester).single, 0.6);
    });
  });

  group('AnimatedPercent', () {
    testWidgets('counts up and between values', (tester) async {
      await tester.pumpWidget(host(const AnimatedPercent(40)));
      expect(find.text('0%'), findsOneWidget);
      await tester.pump(const Duration(milliseconds: 200));
      final midway = int.parse(
        (tester.widget<Text>(find.byType(Text)).data!).replaceAll('%', ''),
      );
      expect(midway, inExclusiveRange(0, 40));
      await tester.pumpAndSettle();
      expect(find.text('40%'), findsOneWidget);

      await tester.pumpWidget(host(const AnimatedPercent(70)));
      await tester.pumpAndSettle();
      expect(find.text('70%'), findsOneWidget);
    });

    testWidgets('shows the value at once with reduce motion on', (
      tester,
    ) async {
      await tester.pumpWidget(
        host(const AnimatedPercent(40), reduceMotion: true),
      );
      expect(find.text('40%'), findsOneWidget);
    });
  });

  group('haptics', () {
    final taps = <String>[];

    setUp(() {
      taps.clear();
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, (call) async {
            if (call.method == 'HapticFeedback.vibrate') {
              taps.add(
                (call.arguments as String).replaceFirst(
                  'HapticFeedbackType.',
                  '',
                ),
              );
            }
            return null;
          });
    });

    tearDown(() {
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
          .setMockMethodCallHandler(SystemChannels.platform, null);
    });

    testWidgets('pull to refresh taps once when it starts', (tester) async {
      var refreshed = 0;
      await tester.pumpWidget(
        host(
          SizedBox(
            height: 400,
            child: AppRefreshIndicator(
              onRefresh: () async => refreshed++,
              child: ListView(children: const [SizedBox(height: 800)]),
            ),
          ),
        ),
      );
      expect(taps, isEmpty);
      await tester.fling(find.byType(ListView), const Offset(0, 300), 1000);
      await tester.pumpAndSettle();
      expect(refreshed, 1);
      expect(taps, ['mediumImpact']);
    });

    testWidgets('a switch ticks', (tester) async {
      var on = false;
      await tester.pumpWidget(
        host(
          StatefulBuilder(
            builder: (context, setState) =>
                AppSwitch(value: on, onChanged: (v) => setState(() => on = v)),
          ),
        ),
      );
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(on, isTrue);
      expect(taps, ['selectionClick']);
    });

    testWidgets('a disabled switch stays disabled', (tester) async {
      await tester.pumpWidget(
        host(const AppSwitch(value: false, onChanged: null)),
      );
      expect(tester.widget<Switch>(find.byType(Switch)).onChanged, isNull);
    });

    Widget iosTile(void Function(bool) onChanged, bool value) => MaterialApp(
      theme: buildAppTheme(Brightness.light, platform: TargetPlatform.iOS),
      home: Scaffold(
        body: AppSwitchTile(
          value: value,
          title: const Text('Enabled'),
          onChanged: onChanged,
        ),
      ),
    );

    testWidgets('tapping a row ticks once', (tester) async {
      bool? changed;
      await tester.pumpWidget(iosTile((v) => changed = v, false));
      await tester.tap(find.text('Enabled'));
      await tester.pumpAndSettle();
      expect(changed, isTrue);
      expect(taps, ['selectionClick']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('an iOS switch ticks once', (tester) async {
      bool? changed;
      await tester.pumpWidget(iosTile((v) => changed = v, false));
      await tester.tap(find.byType(Switch));
      await tester.pumpAndSettle();
      expect(changed, isTrue);
      expect(taps, ['selectionClick']);
    }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

    testWidgets('a disabled tile ignores taps', (tester) async {
      await tester.pumpWidget(iosTile((_) {}, false));
      await tester.pumpWidget(
        host(
          const AppSwitchTile(
            value: false,
            onChanged: null,
            title: Text('Enabled'),
          ),
        ),
      );
      await tester.tap(find.text('Enabled'));
      await tester.pumpAndSettle();
      expect(taps, isEmpty);
    });

    Future<bool?> confirm(
      WidgetTester tester, {
      required bool destructive,
      required String press,
    }) async {
      bool? result;
      await tester.pumpWidget(
        host(
          Builder(
            builder: (context) => TextButton(
              onPressed: () async => result = await confirmAction(
                context,
                title: 'Sure?',
                body: 'Really.',
                confirmLabel: 'Do it',
                cancelLabel: 'Cancel',
                destructive: destructive,
              ),
              child: const Text('open'),
            ),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
      await tester.tap(find.text(press));
      await tester.pumpAndSettle();
      return result;
    }

    testWidgets('confirming taps lightly, a destructive one firmly', (
      tester,
    ) async {
      expect(await confirm(tester, destructive: false, press: 'Do it'), isTrue);
      expect(taps, ['lightImpact']);
      taps.clear();
      expect(await confirm(tester, destructive: true, press: 'Do it'), isTrue);
      expect(taps, ['heavyImpact']);
    });

    testWidgets('cancelling a confirmation is silent', (tester) async {
      expect(
        await confirm(tester, destructive: true, press: 'Cancel'),
        isFalse,
      );
      expect(taps, isEmpty);
    });
  });
}

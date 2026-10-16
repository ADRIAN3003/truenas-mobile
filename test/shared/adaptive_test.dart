import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;
import 'package:truenas_mobile/shared/theme.dart';
import 'package:truenas_mobile/shared/widgets.dart';

void main() {
  Future<void> openConfirm(WidgetTester tester, TargetPlatform platform) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: buildAppTheme(Brightness.light, platform: platform),
        home: Builder(
          builder: (context) => TextButton(
            onPressed: () => confirmAction(
              context,
              title: 'Delete?',
              body: 'Gone for good.',
              confirmLabel: 'Delete',
              cancelLabel: 'Cancel',
              destructive: true,
            ),
            child: const Text('open'),
          ),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
  }

  testWidgets('confirmations use the package\'s glass dialog on iOS', (
    tester,
  ) async {
    await openConfirm(tester, TargetPlatform.iOS);
    expect(find.byType(lg.GlassDialog), findsOneWidget);
    expect(find.byType(AlertDialog), findsNothing);
    expect(find.text('Gone for good.'), findsOneWidget);
    expect(find.widgetWithText(lg.GlassButton, 'Delete'), findsOneWidget);
    expect(find.widgetWithText(lg.GlassButton, 'Cancel'), findsOneWidget);
    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets('confirmations use a Material dialog on Android', (tester) async {
    await openConfirm(tester, TargetPlatform.android);
    expect(find.byType(lg.GlassDialog), findsNothing);
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.text('Gone for good.'), findsOneWidget);
    expect(find.widgetWithText(FilledButton, 'Delete'), findsOneWidget);
    expect(find.widgetWithText(TextButton, 'Cancel'), findsOneWidget);
  });

  test('both themes carry the app palette', () {
    for (final brightness in Brightness.values) {
      expect(buildAppTheme(brightness).extension<AppPalette>(), isNotNull);
    }
  });
}

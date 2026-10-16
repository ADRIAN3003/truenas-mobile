import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;
import 'package:truenas_mobile/shared/dialogs.dart';
import 'package:truenas_mobile/shared/glass.dart';
import 'package:truenas_mobile/shared/theme.dart';
import 'package:truenas_mobile/shared/ui.dart';

void main() {
  Widget host(TargetPlatform platform, Widget Function(BuildContext) body) =>
      MaterialApp(
        theme: buildAppTheme(Brightness.light, platform: platform),
        home: Scaffold(body: Builder(builder: body)),
      );

  final ios = TargetPlatformVariant.only(TargetPlatform.iOS);

  group('AppDialog on iOS', () {
    Future<void> open(
      WidgetTester tester,
      Widget Function(BuildContext) dialog,
    ) async {
      await tester.pumpWidget(
        host(
          TargetPlatform.iOS,
          (context) => TextButton(
            onPressed: () =>
                showAppDialog<String>(context: context, builder: dialog),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets(
      "is the package's glass dialog with icon, title, content and actions",
      (tester) async {
        String? result;
        await tester.pumpWidget(
          host(
            TargetPlatform.iOS,
            (context) => TextButton(
              onPressed: () async => result = await showAppDialog<String>(
                context: context,
                builder: (context) => AppDialog(
                  icon: const Icon(Icons.shield_outlined),
                  title: const Text('Trust it?'),
                  content: const Text('A new certificate.'),
                  actions: [
                    dialogAction(
                      context,
                      label: 'Cancel',
                      onPressed: () => Navigator.pop(context, 'no'),
                    ),
                    dialogAction(
                      context,
                      label: 'Trust',
                      primary: true,
                      onPressed: () => Navigator.pop(context, 'yes'),
                    ),
                  ],
                ),
              ),
              child: const Text('open'),
            ),
          ),
        );
        await tester.tap(find.text('open'));
        await tester.pumpAndSettle();
        expect(find.byType(GlassAlert), findsOneWidget);
        expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
        expect(find.text('Trust it?'), findsOneWidget);
        expect(find.text('A new certificate.'), findsOneWidget);
        // Two actions sit side by side.
        expect(
          tester.getCenter(find.text('Cancel')).dy,
          tester.getCenter(find.text('Trust')).dy,
        );
        await tester.tap(find.text('Trust'));
        await tester.pumpAndSettle();
        expect(result, 'yes');
        expect(find.byType(GlassAlert), findsNothing);
      },
      variant: ios,
    );

    testWidgets('three actions stack', (tester) async {
      await open(
        tester,
        (context) => AppDialog(
          title: const Text('Pick'),
          actions: [
            for (final label in ['One', 'Two', 'Three'])
              dialogAction(context, label: label, onPressed: () {}),
          ],
        ),
      );
      final ys = [
        for (final label in ['One', 'Two', 'Three'])
          tester.getCenter(find.text(label)).dy,
      ];
      expect(ys[0], lessThan(ys[1]));
      expect(ys[1], lessThan(ys[2]));
    }, variant: ios);

    testWidgets('tall content scrolls instead of overflowing', (tester) async {
      tester.view.physicalSize = const Size(800, 700);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(
        tester,
        (context) => AppDialog(
          title: const Text('Datasets'),
          scrollable: true,
          content: Column(
            children: [
              for (var i = 0; i < 60; i++)
                ListTile(dense: true, title: Text('tank/dataset$i')),
            ],
          ),
          actions: [dialogAction(context, label: 'Close', onPressed: () {})],
        ),
      );
      expect(tester.takeException(), isNull);
      // The panel fits the screen with its button in view, and the rest of
      // the list is below the fold until scrolled to.
      expect(tester.getBottomLeft(find.text('Close')).dy, lessThan(700));
      expect(
        tester.getTopLeft(find.text('tank/dataset59')).dy,
        greaterThan(700),
      );
      await tester.drag(find.text('tank/dataset3'), const Offset(0, -3000));
      await tester.pumpAndSettle();
      expect(tester.getTopLeft(find.text('tank/dataset59')).dy, lessThan(700));
    }, variant: ios);

    testWidgets('the buttons are solid capsules, not see-through glass', (
      tester,
    ) async {
      await open(
        tester,
        (context) => AppDialog(
          title: const Text('Restart?'),
          message: 'Services stop for a moment.',
          actions: [
            dialogAction(context, label: 'Cancel', onPressed: () {}),
            dialogAction(
              context,
              label: 'Save',
              primary: true,
              onPressed: () {},
            ),
          ],
        ),
      );
      expect(find.text('Restart?'), findsOneWidget);
      expect(find.text('Services stop for a moment.'), findsOneWidget);
      // No glass button, no Material text button.
      expect(find.byType(lg.GlassButton), findsNothing);
      expect(
        find.descendant(
          of: find.byType(GlassAlert),
          matching: find.byType(TextButton),
        ),
        findsNothing,
      );
      Material buttonOf(String label) => tester.widget<Material>(
        find
            .ancestor(of: find.text(label), matching: find.byType(Material))
            .first,
      );
      final scheme = Theme.of(tester.element(find.text('Save'))).colorScheme;
      for (final label in ['Cancel', 'Save']) {
        expect(buttonOf(label).shape, isA<StadiumBorder>(), reason: label);
      }
      // The main action is the accent colour, fully opaque; the other is a
      // neutral grey.
      expect(buttonOf('Save').color, scheme.primary);
      expect(buttonOf('Cancel').color!.a, greaterThan(0));
      expect(buttonOf('Cancel').color!.a, lessThan(0.5));
    }, variant: ios);

    testWidgets('the panel is mostly opaque and well rounded', (tester) async {
      await open(
        tester,
        (context) => AppDialog(
          title: const Text('Restart?'),
          actions: [dialogAction(context, label: 'OK', onPressed: () {})],
        ),
      );
      final card = tester.widget<lg.GlassCard>(find.byType(lg.GlassCard));
      expect(
        (card.shape as lg.LiquidRoundedSuperellipse).borderRadius,
        greaterThanOrEqualTo(30),
      );
      final fill =
          tester
                  .widget<DecoratedBox>(
                    find
                        .descendant(
                          of: find.byType(lg.GlassCard),
                          matching: find.byType(DecoratedBox),
                        )
                        .first,
                  )
                  .decoration
              as ShapeDecoration;
      expect(fill.color!.a, greaterThanOrEqualTo(0.8));
    }, variant: ios);

    testWidgets('a button without a handler is disabled', (tester) async {
      var taps = 0;
      await open(
        tester,
        (context) => AppDialog(
          title: const Text('New dataset'),
          actions: [
            dialogAction(context, label: 'Create', onPressed: null),
            dialogAction(context, label: 'Cancel', onPressed: () => taps++),
          ],
        ),
      );
      await tester.tap(find.text('Create'));
      await tester.pumpAndSettle();
      expect(taps, 0);
      expect(find.byType(GlassAlert), findsOneWidget);
    }, variant: ios);

    testWidgets('text fields work inside the dialog', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await open(
        tester,
        (context) => AppDialog(
          title: const Text('Name'),
          content: TextField(controller: controller),
          actions: [dialogAction(context, label: 'Save', onPressed: () {})],
        ),
      );
      await tester.enterText(find.byType(TextField), 'tank');
      expect(controller.text, 'tank');
    }, variant: ios);

    testWidgets('lifts above the keyboard', (tester) async {
      tester.view.physicalSize = const Size(800, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.reset);
      await open(
        tester,
        (context) => AppDialog(
          title: const Text('Name'),
          content: const TextField(),
          actions: [dialogAction(context, label: 'Save', onPressed: () {})],
        ),
      );
      final before = tester.getBottomLeft(find.text('Save')).dy;
      tester.view.viewInsets = const FakeViewPadding(bottom: 400);
      addTearDown(tester.view.resetViewInsets);
      await tester.pumpAndSettle();
      final after = tester.getBottomLeft(find.text('Save')).dy;
      expect(after, lessThan(before));
      expect(after, lessThanOrEqualTo(900 - 400));
    }, variant: ios);
  });

  testWidgets('AppDialog is a Material dialog on Android', (tester) async {
    await tester.pumpWidget(
      host(
        TargetPlatform.android,
        (context) => TextButton(
          onPressed: () => showAppDialog<void>(
            context: context,
            builder: (_) => const AppDialog(title: Text('Hi')),
          ),
          child: const Text('open'),
        ),
      ),
    );
    await tester.tap(find.text('open'));
    await tester.pumpAndSettle();
    expect(find.byType(AlertDialog), findsOneWidget);
    expect(find.byType(GlassAlert), findsNothing);
  });

  group('showAppChoice', () {
    Future<void> openChoice(
      WidgetTester tester,
      TargetPlatform platform,
      void Function((String?,)?) done, {
      bool dialogOnAndroid = false,
    }) async {
      await tester.pumpWidget(
        host(
          platform,
          (context) => TextButton(
            onPressed: () async => done(
              await showAppChoice<String?>(
                context: context,
                title: 'Theme',
                dialogOnAndroid: dialogOnAndroid,
                choices: [
                  appChoice<String?>(null, 'Same as device', selected: true),
                  appChoice<String?>('dark', 'Dark'),
                ],
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('is the glass action sheet on iOS and returns the choice', (
      tester,
    ) async {
      (String?,)? picked;
      await openChoice(tester, TargetPlatform.iOS, (v) => picked = v);
      expect(find.byType(BottomSheet), findsNothing);
      // The sheet is drawn on a Material, so its text has no yellow
      // underline (a route has none of its own).
      final text = tester.widget<Text>(find.text('Dark'));
      expect(
        DefaultTextStyle.of(tester.element(find.text('Dark'))).style.decoration,
        isNot(TextDecoration.underline),
      );
      expect(text.style?.decoration, isNull);
      expect(find.text('Theme'), findsOneWidget);
      expect(find.text('Same as device'), findsOneWidget);
      // The current choice carries a check.
      expect(find.byIcon(Icons.check_rounded), findsOneWidget);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(picked, ('dark',));
    }, variant: ios);

    testWidgets('choosing a null value is not dismissing', (tester) async {
      (String?,)? picked;
      await openChoice(tester, TargetPlatform.iOS, (v) => picked = v);
      await tester.tap(find.text('Same as device'));
      await tester.pumpAndSettle();
      expect(picked, (null,));
    }, variant: ios);

    testWidgets('Cancel dismisses with nothing chosen', (tester) async {
      var done = false;
      (String?,)? picked = ('x',);
      await openChoice(tester, TargetPlatform.iOS, (v) {
        picked = v;
        done = true;
      });
      await tester.tap(find.text('Cancel'));
      await tester.pumpAndSettle();
      expect(done, isTrue);
      expect(picked, isNull);
    }, variant: ios);

    testWidgets('is a Material bottom sheet on Android', (tester) async {
      (String?,)? picked;
      await openChoice(tester, TargetPlatform.android, (v) => picked = v);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(picked, ('dark',));
    });

    testWidgets('can be a dialog on Android, for a long list', (tester) async {
      (String?,)? picked;
      await openChoice(
        tester,
        TargetPlatform.android,
        (v) => picked = v,
        dialogOnAndroid: true,
      );
      expect(find.byType(AlertDialog), findsOneWidget);
      await tester.tap(find.text('Dark'));
      await tester.pumpAndSettle();
      expect(picked, ('dark',));
    });
  });

  group('AppSwitch, AppSlider and AppSegments', () {
    testWidgets('are the package\'s glass controls on iOS', (tester) async {
      var on = false;
      var size = 14.0;
      var segment = 0;
      await tester.pumpWidget(
        host(
          TargetPlatform.iOS,
          (context) => StatefulBuilder(
            builder: (context, setState) => Column(
              children: [
                AppSwitch(value: on, onChanged: (v) => setState(() => on = v)),
                AppSlider(
                  value: size,
                  min: 10,
                  max: 20,
                  divisions: 10,
                  onChanged: (v) => setState(() => size = v),
                ),
                AppSegments<int>(
                  values: const [0, 1],
                  labels: const ['One', 'Two'],
                  selected: segment,
                  onChanged: (v) => setState(() => segment = v),
                ),
              ],
            ),
          ),
        ),
      );
      expect(find.byType(lg.GlassSwitch), findsOneWidget);
      expect(find.byType(lg.GlassSlider), findsOneWidget);
      expect(find.byType(lg.GlassSegmentedControl), findsOneWidget);
      expect(find.byType(Switch), findsNothing);
      expect(find.byType(Slider), findsNothing);
      expect(find.byType(SegmentedButton<int>), findsNothing);

      await tester.tap(find.byType(lg.GlassSwitch));
      await tester.pumpAndSettle();
      expect(on, isTrue);
    }, variant: ios);

    testWidgets('a disabled glass switch ignores taps', (tester) async {
      await tester.pumpWidget(
        host(
          TargetPlatform.iOS,
          (context) => const AppSwitch(value: false, onChanged: null),
        ),
      );
      await tester.tap(find.byType(lg.GlassSwitch), warnIfMissed: false);
      await tester.pumpAndSettle();
      expect(
        tester.widget<lg.GlassSwitch>(find.byType(lg.GlassSwitch)).value,
        isFalse,
      );
    }, variant: ios);

    testWidgets('are Material on Android', (tester) async {
      await tester.pumpWidget(
        host(
          TargetPlatform.android,
          (context) => Column(
            children: [
              AppSwitch(value: false, onChanged: (_) {}),
              AppSlider(value: 1, min: 0, max: 2, onChanged: (_) {}),
              AppSegments<int>(
                values: const [0, 1],
                labels: const ['One', 'Two'],
                selected: 0,
                onChanged: (_) {},
              ),
            ],
          ),
        ),
      );
      expect(find.byType(Switch), findsOneWidget);
      expect(find.byType(Slider), findsOneWidget);
      expect(find.byType(SegmentedButton<int>), findsOneWidget);
      expect(find.byType(lg.GlassSwitch), findsNothing);
    });

    testWidgets('segments stay Material inside a glass dialog', (tester) async {
      await tester.pumpWidget(
        host(
          TargetPlatform.iOS,
          (context) => AppSegments<int>(
            inGlass: true,
            values: const [0, 1],
            labels: const ['One', 'Two'],
            selected: 0,
            onChanged: (_) {},
          ),
        ),
      );
      expect(find.byType(SegmentedButton<int>), findsOneWidget);
      expect(find.byType(lg.GlassSegmentedControl), findsNothing);
    }, variant: ios);
  });

  group('AppPopupMenu', () {
    Widget menu(TargetPlatform platform, void Function(String) onSelected) =>
        host(
          platform,
          (context) => Align(
            alignment: Alignment.topRight,
            child: AppPopupMenu<String>(
              onSelected: onSelected,
              entries: [
                menuEntry('edit', 'Edit'),
                menuEntry('delete', 'Delete', destructive: true),
              ],
            ),
          ),
        );

    testWidgets('opens a glass menu on iOS', (tester) async {
      String? picked;
      await tester.pumpWidget(menu(TargetPlatform.iOS, (v) => picked = v));
      expect(find.byType(PopupMenuButton<String>), findsNothing);
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsOneWidget);
      expect(find.text('Delete'), findsOneWidget);
      await tester.tap(find.text('Delete'));
      await tester.pumpAndSettle();
      expect(picked, 'delete');
    }, variant: ios);

    testWidgets('is a popup menu on Android', (tester) async {
      String? picked;
      await tester.pumpWidget(menu(TargetPlatform.android, (v) => picked = v));
      expect(find.byType(PopupMenuButton<String>), findsOneWidget);
      await tester.tap(find.byType(PopupMenuButton<String>));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Edit'));
      await tester.pumpAndSettle();
      expect(picked, 'edit');
    });

    testWidgets('a disabled menu does not open', (tester) async {
      await tester.pumpWidget(
        host(
          TargetPlatform.iOS,
          (context) => AppPopupMenu<String>(
            enabled: false,
            onSelected: (_) {},
            entries: [menuEntry('edit', 'Edit')],
          ),
        ),
      );
      await tester.tap(find.byType(IconButton));
      await tester.pumpAndSettle();
      expect(find.text('Edit'), findsNothing);
    }, variant: ios);
  });
}

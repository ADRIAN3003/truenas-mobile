import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:liquid_glass_widgets/liquid_glass_widgets.dart' as lg;
import 'package:truenas_mobile/shared/dialogs.dart';
import 'package:truenas_mobile/shared/glass.dart';
import 'package:truenas_mobile/shared/theme.dart';

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

    testWidgets('shows its icon, title, content and actions on glass', (
      tester,
    ) async {
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
      expect(find.byType(GlassDialogPanel), findsOneWidget);
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
      expect(find.byType(GlassDialogPanel), findsNothing);
    }, variant: ios);

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

    testWidgets('the glass is plain: no tint, no filled or coloured buttons', (
      tester,
    ) async {
      await open(
        tester,
        (context) => AppDialog(
          title: const Text('Restart?'),
          content: const Text('Services stop for a moment.'),
          actions: [
            dialogAction(context, label: 'Cancel', onPressed: () {}),
            dialogAction(
              context,
              label: 'Restart',
              primary: true,
              destructive: true,
              onPressed: () {},
            ),
          ],
        ),
      );
      final card = tester.widget<lg.GlassCard>(find.byType(lg.GlassCard));
      expect(card.settings, isNull);
      expect(
        find.descendant(
          of: find.byType(GlassDialogPanel),
          matching: find.byWidgetPredicate(
            (w) => w is FilledButton || w is TextButton || w is OutlinedButton,
          ),
        ),
        findsNothing,
      );
      TextStyle labelStyle(String label) =>
          DefaultTextStyle.of(tester.element(find.text(label))).style;
      // Only the destructive label is coloured, only the primary one is bold.
      expect(labelStyle('Restart').color, isNot(labelStyle('Cancel').color));
      expect(labelStyle('Restart').fontWeight, FontWeight.w700);
      expect(labelStyle('Cancel').fontWeight, isNot(FontWeight.w700));
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
      expect(find.byType(GlassDialogPanel), findsOneWidget);
    }, variant: ios);

    testWidgets('text fields work inside the panel', (tester) async {
      final controller = TextEditingController();
      addTearDown(controller.dispose);
      await open(
        tester,
        (context) => AppDialog(
          title: const Text('Name'),
          content: TextField(controller: controller),
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
        (context) => const AppDialog(
          title: Text('Name'),
          content: TextField(),
          actions: [SizedBox(height: 46, child: Text('Save'))],
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
    expect(find.byType(GlassDialogPanel), findsNothing);
  });

  group('showAppSheet', () {
    Future<void> openSheet(
      WidgetTester tester,
      TargetPlatform platform,
      void Function(String?) done,
    ) async {
      await tester.pumpWidget(
        host(
          platform,
          (context) => TextButton(
            onPressed: () async => done(
              await showAppSheet<String>(
                context: context,
                builder: (context) => ListTile(
                  title: const Text('Snapshot task'),
                  onTap: () => Navigator.pop(context, 'snapshot'),
                ),
              ),
            ),
            child: const Text('open'),
          ),
        ),
      );
      await tester.tap(find.text('open'));
      await tester.pumpAndSettle();
    }

    testWidgets('is opaque and rounded on iOS and returns the choice', (
      tester,
    ) async {
      String? picked;
      await openSheet(tester, TargetPlatform.iOS, (v) => picked = v);
      final sheet = tester.widget<BottomSheet>(find.byType(BottomSheet));
      expect(sheet.backgroundColor, isNotNull);
      expect(sheet.backgroundColor!.a, 1);
      expect(sheet.showDragHandle, isTrue);
      await tester.tap(find.text('Snapshot task'));
      await tester.pumpAndSettle();
      expect(picked, 'snapshot');
    }, variant: ios);

    testWidgets('is a Material bottom sheet on Android', (tester) async {
      String? picked;
      await openSheet(tester, TargetPlatform.android, (v) => picked = v);
      expect(find.byType(BottomSheet), findsOneWidget);
      await tester.tap(find.text('Snapshot task'));
      await tester.pumpAndSettle();
      expect(picked, 'snapshot');
    });
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

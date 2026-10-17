import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/jobs/job_tracker.dart';
import 'package:truenas_mobile/features/jobs/job_gauge_button.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/job_fakes.dart';

void main() {
  late FakeJobSource source;
  late JobTracker tracker;

  setUp(() => source = FakeJobSource());

  Future<void> pump(WidgetTester tester, {VoidCallback? onOpen}) async {
    await tester.runAsync(() async {
      tracker = JobTracker(source, pollInterval: const Duration(hours: 1))
        ..start();
      await Future<void>.delayed(const Duration(milliseconds: 20));
    });
    addTearDown(tracker.dispose);
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: Scaffold(
          appBar: AppBar(
            actions: [
              JobGaugeButton(tracker: tracker, onOpen: onOpen ?? () {}),
            ],
          ),
        ),
      ),
    );
  }

  testWidgets('is not there while no job runs', (tester) async {
    await pump(tester);
    expect(find.byType(CircularProgressIndicator), findsNothing);
  });

  testWidgets('shows the progress and opens the jobs on tap', (tester) async {
    source.active.add(jobJson(1, 'pool.scrub.run', percent: 40));
    var opened = 0;
    await pump(tester, onOpen: () => opened++);
    await tester.pumpAndSettle();
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, closeTo(0.4, 0.001));
    expect(find.byIcon(Icons.speed_rounded), findsOneWidget);
    await tester.tap(find.byType(IconButton));
    expect(opened, 1);
  });

  testWidgets('counts several jobs and averages their progress', (
    tester,
  ) async {
    source.active.addAll([
      jobJson(1, 'pool.scrub.run', percent: 20),
      jobJson(2, 'app.upgrade', percent: 60),
    ]);
    await pump(tester);
    await tester.pumpAndSettle();
    expect(find.text('2'), findsOneWidget);
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, closeTo(0.4, 0.001));
  });

  testWidgets('spins while no job knows its percent', (tester) async {
    source.active.add(jobJson(1, 'pool.scrub.run', arguments: ['tank']));
    await pump(tester);
    await tester.pump(const Duration(seconds: 1));
    final ring = tester.widget<CircularProgressIndicator>(
      find.byType(CircularProgressIndicator),
    );
    expect(ring.value, isNull);
    await tester.pumpWidget(const SizedBox());
  });
}

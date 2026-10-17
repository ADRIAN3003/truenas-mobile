import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/jobs/job_tracker.dart';
import 'package:truenas_mobile/features/jobs/job_progress_banner.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/job_fakes.dart';

void main() {
  late FakeJobSource source;
  late JobTracker tracker;

  setUp(() => source = FakeJobSource());

  Future<void> pump(WidgetTester tester, {VoidCallback? onOpen}) async {
    // Real timers and sockets-like async: outside the test's fake clock.
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
          body: JobProgressBanner(tracker: tracker, onOpen: onOpen ?? () {}),
        ),
      ),
    );
  }

  testWidgets('shows nothing while no job runs', (tester) async {
    await pump(tester);
    expect(find.byType(LinearProgressIndicator), findsNothing);
  });

  testWidgets('lists the running jobs with their percent', (tester) async {
    source.active.addAll([
      jobJson(
        1,
        'pool.scrub.run',
        percent: 42,
        text: 'Scanning',
        arguments: ['tank'],
      ),
      jobJson(2, 'app.upgrade', percent: 10, arguments: ['plex']),
    ]);
    await pump(tester);
    expect(find.text('Scrub · tank'), findsOneWidget);
    expect(find.text('Scanning'), findsOneWidget);
    expect(find.text('42%'), findsOneWidget);
    expect(find.text('App update · plex'), findsOneWidget);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(2));
  });

  testWidgets('folds jobs beyond the limit and opens the list on tap', (
    tester,
  ) async {
    source.active.addAll([
      for (var i = 1; i <= 5; i++)
        jobJson(i, 'replication.run', percent: i * 10),
    ]);
    var opened = 0;
    await pump(tester, onOpen: () => opened++);
    expect(find.byType(LinearProgressIndicator), findsNWidgets(bannerLimit));
    expect(find.text('+2 more'), findsOneWidget);
    await tester.tap(find.text('10%'));
    expect(opened, 1);
  });

  testWidgets('warns when the connection is lost', (tester) async {
    source.active.add(jobJson(1, 'pool.scrub.run', percent: 42));
    await pump(tester);
    source.offline = true;
    await tester.runAsync(() async {
      await tracker.refresh();
    });
    await tester.pump();
    expect(
      find.text('Connection lost, progress may be out of date'),
      findsOneWidget,
    );
  });

  testWidgets('can be dismissed, and comes back for a new job', (tester) async {
    source.active.add(jobJson(1, 'pool.scrub.run', percent: 42));
    await pump(tester);
    expect(find.byType(LinearProgressIndicator), findsOneWidget);
    await tester.tap(find.byIcon(Icons.close_rounded));
    await tester.pump();
    expect(find.byType(LinearProgressIndicator), findsNothing);

    await tester.runAsync(() async {
      source.active.add(jobJson(2, 'app.upgrade', percent: 5));
      await tracker.refresh();
    });
    await tester.pump();
    expect(find.text('App update'), findsOneWidget);
    expect(find.text('Scrub'), findsNothing);
  });
}

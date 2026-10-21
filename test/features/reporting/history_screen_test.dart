import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
import 'package:truenas_mobile/features/reporting/history_screen.dart';
import 'package:truenas_mobile/features/server/dashboard_tab.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_truenas_server.dart';

void main() {
  late FakeTrueNasServer server;
  late TrueNasSession session;

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: child,
  );

  /// Lets real socket traffic happen, then rebuilds.
  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  setUp(() => HttpOverrides.global = null);

  Future<void> openScreen(
    WidgetTester tester, {
    bool legacy = false,
    bool reporting = true,
    Set<String> failing = const {},
    Set<String> hidden = const {},
  }) async {
    tester.view
      ..physicalSize = const Size(800, 4000)
      ..devicePixelRatio = 1;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      server = await FakeTrueNasServer.start();
      server
        ..legacy = legacy
        ..reporting = reporting
        ..failingGraphs.addAll(failing)
        ..hiddenGraphs.addAll(hidden);
      final (s, _) = await connectToInstance(
        ServerInstance(
          id: '1',
          name: 'Home',
          url: 'http://127.0.0.1:${server.port}',
          authMethod: AuthMethod.password,
          username: 'truenas_admin',
          secret: 'secret',
        ),
        confirmCertificate: (_) async => false,
        askOtp: () async => null,
      );
      session = s;
    });
    await tester.pumpWidget(wrap(HistoryScreen(session: session)));
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await session.close();
      await server.close();
    });
  }

  testWidgets('draws every chart with its average and peak', (tester) async {
    await openScreen(tester);

    expect(find.text('History'), findsOneWidget);
    expect(find.text('CPU temperature'), findsOneWidget);
    expect(find.text('ZFS cache (ARC)'), findsOneWidget);
    expect(find.text('Disk temperature'), findsOneWidget);
    // user + system = 15 to 19; the idle column is left out.
    expect(find.text('Average 17% · peak 19%'), findsOneWidget);
    // Kilobits per second, shown the way the dashboard does.
    expect(find.text('Average 3.0 Mb/s · peak 5.0 Mb/s'), findsOneWidget);
    expect(find.text('Average 100.0 kb/s · peak 100.0 kb/s'), findsOneWidget);
    expect(find.text('Average 4.0 GiB · peak 4.0 GiB'), findsOneWidget);
    // The busy interface and the hotter disk come first.
    expect(find.text('Interface eno1'), findsOneWidget);
    expect(find.text('Disk sdb'), findsOneWidget);
    // The mean of the two cores (41 to 45) and the hotter disk (41 to 45).
    expect(find.text('Average 43 °C · peak 45 °C'), findsNWidgets(2));
    // A day unless asked otherwise.
    expect(
      server.calls
          .where((c) => c.$1 == 'reporting.get_data')
          .map((c) => (c.$2[1] as Map)['unit']),
      everyElement('DAY'),
    );
    await close(tester);
  });

  testWidgets('works with the 25.04 method names', (tester) async {
    await openScreen(tester, legacy: true);
    expect(find.text('Average 17% · peak 19%'), findsOneWidget);
    expect(
      server.calls.any((c) => c.$1 == 'reporting.netdata_get_data'),
      isTrue,
    );
    await close(tester);
  });

  testWidgets('another range asks the server again', (tester) async {
    await openScreen(tester);
    server.calls.clear();
    await tester.tap(find.text('Week'));
    await settle(tester);

    final units = server.calls
        .where((c) => c.$1 == 'reporting.get_data')
        .map((c) => (c.$2[1] as Map)['unit']);
    expect(units, isNotEmpty);
    expect(units, everyElement('WEEK'));
    expect(find.text('Average 17% · peak 19%'), findsOneWidget);
    await close(tester);
  });

  testWidgets('a disk and an interface can be picked', (tester) async {
    await openScreen(tester);
    server.calls.clear();

    await tester.tap(find.text('Disk sdb'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('sda').last);
    await tester.pumpAndSettle();
    expect(find.text('Disk sda'), findsOneWidget);
    expect(find.text('Average 37 °C · peak 39 °C'), findsOneWidget);

    await tester.tap(find.text('Interface eno1'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('eno2').last);
    await tester.pumpAndSettle();
    expect(find.text('Interface eno2'), findsOneWidget);
    expect(find.text('Average 0 b/s · peak 0 b/s'), findsNWidgets(2));
    // Both were fetched up front: choosing asks for nothing.
    expect(server.calls.where((c) => c.$1 == 'reporting.get_data'), isEmpty);
    await close(tester);
  });

  testWidgets('a failing chart does not take the others down', (tester) async {
    await openScreen(tester, failing: {'arcsize'});
    expect(find.text('Could not load this chart.'), findsOneWidget);
    expect(find.text('Average 17% · peak 19%'), findsOneWidget);
    await close(tester);
  });

  testWidgets('graphs the server lacks are left out', (tester) async {
    await openScreen(tester, hidden: {'cputemp', 'disktemp'});
    expect(find.text('CPU temperature'), findsNothing);
    expect(find.text('Disk temperature'), findsNothing);
    expect(find.text('Average 17% · peak 19%'), findsOneWidget);
    await close(tester);
  });

  testWidgets('says so when the server has no reporting', (tester) async {
    await openScreen(tester, reporting: false);
    expect(find.text('This server has no history data.'), findsOneWidget);
    await close(tester);
  });

  group('from the dashboard', () {
    Future<void> openDashboard(WidgetTester tester, bool reporting) async {
      await tester.runAsync(() async {
        server = await FakeTrueNasServer.start();
        server.reporting = reporting;
        final (s, _) = await connectToInstance(
          ServerInstance(
            id: '1',
            name: 'Home',
            url: 'http://127.0.0.1:${server.port}',
            authMethod: AuthMethod.password,
            username: 'truenas_admin',
            secret: 'secret',
          ),
          confirmCertificate: (_) async => false,
          askOtp: () async => null,
        );
        session = s;
      });
      await tester.pumpWidget(
        wrap(
          Scaffold(
            body: DashboardTab(
              session: session,
              info: const {'hostname': 'nas'},
              onOpenAlerts: () {},
            ),
          ),
        ),
      );
      await settle(tester);
    }

    testWidgets('the gauges link to the history', (tester) async {
      await openDashboard(tester, true);
      await tester.scrollUntilVisible(find.text('History'), 200);
      await tester.tap(find.text('History'));
      await settle(tester);
      await tester.pumpAndSettle();
      expect(find.byType(HistoryScreen), findsOneWidget);
      await close(tester);
    });

    testWidgets('no link when the server has no reporting', (tester) async {
      await openDashboard(tester, false);
      expect(find.text('History'), findsNothing);
      await close(tester);
    });
  });
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_riverpod/misc.dart' show Override;
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/notifications/background_alerts.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
import 'package:truenas_mobile/core/settings/app_settings.dart';
import 'package:truenas_mobile/core/settings/settings_provider.dart';
import 'package:truenas_mobile/features/server/alerts_tab.dart';
import 'package:truenas_mobile/features/server/dashboard_tab.dart';
import 'package:truenas_mobile/features/server/jobs_tab.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';
import 'package:truenas_mobile/shared/ui.dart';

import '../../support/alert_fakes.dart';
import '../../support/fake_truenas_server.dart';
import '../../support/memory_store.dart';

void main() {
  late FakeTrueNasServer server;
  late TrueNasSession session;

  Widget wrap(Widget child, {List<Override> overrides = const []}) =>
      ProviderScope(
        overrides: overrides,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: child),
        ),
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

  // Widget tests replace HttpClient with a fake that answers 400; these
  // tests talk to a real local fake server instead.
  setUp(() => HttpOverrides.global = null);

  Future<void> connect(WidgetTester tester) async {
    await tester.runAsync(() async {
      server = await FakeTrueNasServer.start();
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
  }

  Future<void> disconnect(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(() async {
      await session.close();
      await server.close();
    });
  }

  testWidgets('dashboard shows live stats, pools and alerts', (tester) async {
    await connect(tester);
    await tester.pumpWidget(
      wrap(
        DashboardTab(
          session: session,
          info: const {'hostname': 'nas', 'version': '25.10.7'},
          onOpenAlerts: () {},
        ),
      ),
    );
    await settle(tester);
    // The gauges count up to their value.
    await tester.pump(gaugeDuration);

    expect(find.text('nas'), findsOneWidget);
    expect(find.text('24%'), findsOneWidget);
    expect(find.text('41 °C'), findsOneWidget);
    expect(find.text('12.0 GiB of 32.0 GiB'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('1.0 Mb/s'), 200);
    expect(find.text('In'), findsOneWidget);
    await tester.scrollUntilVisible(find.text('tank'), 200);
    expect(find.text('tank'), findsOneWidget);
    expect(find.text('1 critical'), findsOneWidget);
    expect(
      server.subscriptions,
      containsAll(['reporting.realtime', 'alert.list']),
    );
    await disconnect(tester);
  });

  testWidgets('a failed pool query is not shown as "No pools"', (tester) async {
    await connect(tester);
    server.failingPools = true;
    await tester.pumpWidget(
      wrap(
        DashboardTab(
          session: session,
          info: const {'hostname': 'nas', 'version': '25.10.7'},
          onOpenAlerts: () {},
        ),
      ),
    );
    await settle(tester);
    await tester.scrollUntilVisible(find.text('Try again'), 200);

    expect(find.text('No pools'), findsNothing);
    expect(find.textContaining("Couldn't load the pools"), findsOneWidget);

    // Retrying once the server answers again shows the pools.
    server.failingPools = false;
    await tester.tap(find.text('Try again'));
    await settle(tester);
    await tester.scrollUntilVisible(find.text('tank'), 200);
    expect(find.text('tank'), findsOneWidget);
    expect(find.text('Try again'), findsNothing);
    await disconnect(tester);
  });

  testWidgets('alerts can be dismissed and restored', (tester) async {
    await connect(tester);
    await tester.pumpWidget(wrap(AlertsTab(session: session)));
    await settle(tester);

    expect(find.text('Pool tank state is DEGRADED'), findsOneWidget);
    expect(find.text('Dismiss'), findsOneWidget);
    expect(find.text('Restore'), findsOneWidget);

    await tester.tap(find.text('Dismiss'));
    await settle(tester);
    expect(server.alerts.first['dismissed'], isTrue);
    expect(find.text('No active alerts'), findsOneWidget);
    await disconnect(tester);
  });

  testWidgets('a kind of alert can be muted and unmuted', (tester) async {
    await connect(tester);
    final container = ProviderContainer(
      overrides: [
        settingsRepositoryProvider.overrideWithValue(
          SettingsRepository(MemoryStore()),
        ),
        alertNotificationServiceProvider.overrideWithValue(
          AlertNotificationService(
            scheduler: FakeBackgroundScheduler(),
            notifier: FakeAlertNotifier(),
            store: MemoryStore(),
          ),
        ),
      ],
    );
    addTearDown(container.dispose);
    await tester.pumpWidget(
      UncontrolledProviderScope(
        container: container,
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Scaffold(body: AlertsTab(session: session)),
        ),
      ),
    );
    await settle(tester);

    await tester.tap(find.byType(PopupMenuButton<bool>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text("Don't notify for this type"));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).mutedAlertKinds, {'PoolStatus'});
    expect(find.textContaining('No more notifications'), findsOneWidget);

    await tester.tap(find.byType(PopupMenuButton<bool>).first);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Notify for this type again'));
    await tester.pumpAndSettle();
    expect(container.read(settingsProvider).mutedAlertKinds, isEmpty);
    await disconnect(tester);
  });

  testWidgets('there is no mute menu where alerts do not notify', (
    tester,
  ) async {
    await connect(tester);
    await tester.pumpWidget(wrap(AlertsTab(session: session)));
    await settle(tester);
    expect(find.byType(PopupMenuButton<bool>), findsNothing);
    await disconnect(tester);
  });

  testWidgets('jobs show running progress with an abort button', (
    tester,
  ) async {
    await connect(tester);
    await tester.pumpWidget(wrap(JobsTab(session: session)));
    await settle(tester);

    expect(find.text('pool.scrub.run'), findsOneWidget);
    expect(find.text('Scrubbing'), findsOneWidget);
    expect(find.byTooltip('Abort'), findsOneWidget);
    await disconnect(tester);
  });
}

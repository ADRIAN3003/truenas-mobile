import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/logging/app_log.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/wol/wake_on_lan.dart';
import 'package:truenas_mobile/features/instances/instances_screen.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/memory_store.dart';
import '../../support/wol_fakes.dart';

const _home = ServerInstance(
  id: 'a',
  name: 'Home NAS',
  url: 'https://nas.local',
  authMethod: AuthMethod.apiKey,
  username: 'truenas_admin',
  secret: 'key',
);

void main() {
  Future<void> open(WidgetTester tester, FlakyStore store) => tester.pumpWidget(
    ProviderScope(
      overrides: [
        instanceRepositoryProvider.overrideWithValue(
          InstanceRepository(store, retryDelay: Duration.zero),
        ),
      ],
      child: const MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: InstancesScreen(),
      ),
    ),
  );

  testWidgets('unreadable servers can be retried and are not lost', (
    tester,
  ) async {
    final store = FlakyStore();
    await InstanceRepository(store).save([_home]);
    store.failReads = 99;
    await open(tester, store);
    await tester.pumpAndSettle();

    expect(find.text("Can't read your saved servers"), findsOneWidget);
    expect(find.text('Home NAS'), findsNothing);
    // Still in storage, untouched.
    store.failReads = 0;
    await tester.tap(find.text('Try again'));
    await tester.pumpAndSettle();
    expect(find.text('Home NAS'), findsOneWidget);
  });

  testWidgets('clearing unreadable servers needs a confirmation', (
    tester,
  ) async {
    final store = FlakyStore();
    await InstanceRepository(store).save([_home]);
    store.failReads = 99;
    await open(tester, store);
    await tester.pumpAndSettle();

    await tester.tap(find.text('Clear saved servers'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Clear'));
    await tester.pumpAndSettle();

    expect(
      find.text('Add a TrueNAS server (25.04 or newer) to start managing it.'),
      findsOneWidget,
    );
  });

  group('Wake-on-LAN', () {
    final waking = _home.copyWith(
      wol: () => const WakeOnLanSettings(mac: 'AA:BB:CC:DD:EE:FF'),
    );

    Future<FakeWakeOnLanSender> openWith(
      WidgetTester tester,
      ServerInstance server,
    ) async {
      final sender = FakeWakeOnLanSender();
      final store = MemoryStore();
      await InstanceRepository(store).save([server]);
      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            instanceRepositoryProvider.overrideWithValue(
              InstanceRepository(store),
            ),
            wakeOnLanSenderProvider.overrideWithValue(sender),
          ],
          child: const MaterialApp(
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            home: InstancesScreen(),
          ),
        ),
      );
      await tester.pumpAndSettle();
      return sender;
    }

    testWidgets('a server without settings has no wake button', (tester) async {
      await openWith(tester, _home);
      expect(find.byTooltip('Wake up'), findsNothing);
    });

    testWidgets('the wake button sends the packet and says so', (tester) async {
      final sender = await openWith(tester, waking);
      await tester.tap(find.byTooltip('Wake up'));
      await tester.pumpAndSettle();
      expect(sender.sent.single.mac, 'AA:BB:CC:DD:EE:FF');
      expect(find.textContaining('Wake-up sent to Home NAS'), findsOneWidget);
    });

    testWidgets('a packet that could not be sent is reported', (tester) async {
      AppLog.instance = AppLog();
      final sender = await openWith(tester, waking);
      sender.failWith = const SocketException('Network is unreachable');
      await tester.tap(find.byTooltip('Wake up'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Could not send the wake-up'), findsOneWidget);
      expect(find.textContaining('Network is unreachable'), findsOneWidget);
      // The failure is in the error log too, for a bug report.
      final logged = AppLog.instance.entries.single;
      expect(logged.source, 'wake-on-lan');
      expect(logged.message, contains('Home NAS'));
      expect(logged.message, contains('Network is unreachable'));
    });
  });
}

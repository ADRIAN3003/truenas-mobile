import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/features/instances/instances_screen.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/memory_store.dart';

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
}

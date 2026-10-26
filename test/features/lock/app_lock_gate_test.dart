import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/app.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/security/biometric_auth.dart';
import 'package:truenas_mobile/core/settings/app_settings.dart';
import 'package:truenas_mobile/core/settings/settings_provider.dart';
import 'package:truenas_mobile/features/lock/app_lock_gate.dart';

import '../../support/biometric_fakes.dart';
import '../../support/memory_store.dart';

void main() {
  late FakeBiometricAuth auth;

  setUp(() => auth = FakeBiometricAuth());

  Future<void> open(
    WidgetTester tester, {
    bool lockOn = true,
    Duration promptDelay = Duration.zero,
  }) async {
    final store = MemoryStore();
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          instanceRepositoryProvider.overrideWithValue(
            InstanceRepository(store),
          ),
          settingsRepositoryProvider.overrideWithValue(
            SettingsRepository(store),
          ),
          initialSettingsProvider.overrideWithValue(
            AppSettings(appLock: lockOn),
          ),
          biometricAuthProvider.overrideWithValue(auth),
          lockPromptDelayProvider.overrideWithValue(promptDelay),
        ],
        child: const TrueNasMobileApp(),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> background(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.paused);
    await tester.pump();
  }

  Future<void> foreground(WidgetTester tester) async {
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.hidden);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
  }

  testWidgets('nothing is in the way while the lock is off', (tester) async {
    await open(tester, lockOn: false);
    expect(find.text('TrueNAS Mobile is locked'), findsNothing);
    expect(auth.prompts, isEmpty);
    await background(tester);
    await foreground(tester);
    expect(find.text('TrueNAS Mobile is locked'), findsNothing);
    expect(auth.prompts, isEmpty);
  });

  testWidgets('asks at start and opens the app once it passes', (tester) async {
    await open(tester);
    expect(auth.prompts, ['Unlock TrueNAS Mobile']);
    expect(find.text('TrueNAS Mobile is locked'), findsNothing);
    expect(find.byTooltip('App settings'), findsOneWidget);
  });

  testWidgets('a cold start shows the lock screen before the prompt', (
    tester,
  ) async {
    await open(tester, promptDelay: const Duration(milliseconds: 400));
    // The app's own screen, with its icon, is up and the phone has not been
    // asked yet, so the user never sees the launch screen behind the prompt.
    expect(find.text('TrueNAS Mobile is locked'), findsOneWidget);
    expect(find.byType(Image), findsOneWidget);
    expect(auth.prompts, isEmpty);

    await tester.pump(const Duration(milliseconds: 400));
    await tester.pumpAndSettle();
    expect(auth.prompts, hasLength(1));
    expect(find.text('TrueNAS Mobile is locked'), findsNothing);
  });

  testWidgets('stays locked when the prompt fails, and Unlock tries again', (
    tester,
  ) async {
    auth.passes = false;
    await open(tester);
    expect(find.text('TrueNAS Mobile is locked'), findsOneWidget);
    expect(find.text('Not unlocked. Try again.'), findsOneWidget);
    expect(find.byTooltip('App settings').hitTestable(), findsNothing);

    auth.passes = true;
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(auth.prompts, hasLength(2));
    expect(find.text('TrueNAS Mobile is locked'), findsNothing);
  });

  testWidgets('locks again when the app comes back from the background', (
    tester,
  ) async {
    await open(tester);
    expect(auth.prompts, hasLength(1));

    await background(tester);
    // The cover hides the app in the phone's app switcher.
    expect(find.text('TrueNAS Mobile is locked'), findsOneWidget);

    auth.passes = false;
    await foreground(tester);
    expect(auth.prompts, hasLength(2));
    expect(find.text('TrueNAS Mobile is locked'), findsOneWidget);

    auth.passes = true;
    await tester.tap(find.text('Unlock'));
    await tester.pumpAndSettle();
    expect(find.text('TrueNAS Mobile is locked'), findsNothing);
  });

  testWidgets('a brief pause (a system sheet) does not ask again', (
    tester,
  ) async {
    await open(tester);
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.inactive);
    await tester.pump();
    tester.binding.handleAppLifecycleStateChanged(AppLifecycleState.resumed);
    await tester.pumpAndSettle();
    expect(auth.prompts, hasLength(1));
    expect(find.text('TrueNAS Mobile is locked'), findsNothing);
  });

  testWidgets('does not lock out a phone that lost its unlock method', (
    tester,
  ) async {
    auth.available = false;
    await open(tester);
    expect(find.text('TrueNAS Mobile is locked'), findsNothing);
    expect(auth.prompts, isEmpty);
  });

  testWidgets('turning the lock off lifts it', (tester) async {
    auth.passes = false;
    await open(tester);
    expect(find.text('TrueNAS Mobile is locked'), findsOneWidget);
    final container = ProviderScope.containerOf(
      tester.element(find.byType(TrueNasMobileApp)),
    );
    await container
        .read(settingsProvider.notifier)
        .update((s) => s.copyWith(appLock: false));
    await tester.pumpAndSettle();
    expect(find.text('TrueNAS Mobile is locked'), findsNothing);
  });
}

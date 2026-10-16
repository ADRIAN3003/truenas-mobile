import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
import 'package:truenas_mobile/core/settings/app_settings.dart';
import 'package:truenas_mobile/core/settings/settings_provider.dart';
import 'package:truenas_mobile/features/shell/shell_screen.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';
import 'package:xterm/xterm.dart';

import '../../support/fake_truenas_server.dart';

void main() {
  late FakeTrueNasServer server;
  late TrueNasSession session;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  setUp(() => HttpOverrides.global = null);

  /// Opens the shell on top of a "home" page, so there is somewhere to go
  /// back to.
  Future<void> open(
    WidgetTester tester, {
    AppSettings settings = const AppSettings(),
    bool refuse = false,
  }) async {
    await tester.runAsync(() async {
      server = await FakeTrueNasServer.start();
      server.shellDenied = refuse;
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
      ProviderScope(
        overrides: [initialSettingsProvider.overrideWithValue(settings)],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: Builder(
            builder: (context) => Scaffold(
              body: TextButton(
                onPressed: () => Navigator.push(
                  context,
                  MaterialPageRoute<void>(
                    builder: (_) => ShellScreen(session: session),
                  ),
                ),
                child: const Text('home'),
              ),
            ),
          ),
        ),
      ),
    );
    await tester.tap(find.text('home'));
    await tester.pump(const Duration(seconds: 1));
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.pumpWidget(const SizedBox());
    await tester.runAsync(
      () => Future<void>.delayed(const Duration(milliseconds: 200)),
    );
    await tester.pump();
    await tester.runAsync(() async {
      await session.close();
      await server.close();
    });
  }

  testWidgets('asks before closing a running shell', (tester) async {
    await open(tester);
    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    expect(find.text('Close the shell?'), findsOneWidget);

    // Staying keeps the shell.
    await tester.tap(find.text('Stay'));
    await tester.pumpAndSettle();
    expect(find.byType(ShellScreen), findsOneWidget);

    await tester.tap(find.byType(BackButton));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Close shell'));
    // The dialog closes first, then the page slides away.
    await tester.pump(const Duration(seconds: 1));
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(ShellScreen), findsNothing);
    expect(find.text('home'), findsOneWidget);
    await close(tester);
  });

  testWidgets('does not ask when the user turned that off', (tester) async {
    await open(tester, settings: const AppSettings(confirmLeave: false));
    await tester.tap(find.byType(BackButton));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Close the shell?'), findsNothing);
    expect(find.text('home'), findsOneWidget);
    await close(tester);
  });

  testWidgets('does not ask about a shell that never started', (tester) async {
    await open(tester, refuse: true);
    expect(find.textContaining('Invalid token'), findsOneWidget);
    await tester.tap(find.byType(BackButton));
    await tester.pump(const Duration(seconds: 1));
    expect(find.text('Close the shell?'), findsNothing);
    expect(find.text('home'), findsOneWidget);
    await close(tester);
  });

  testWidgets('extra keys can be hidden, copy and paste stay', (tester) async {
    await open(tester, settings: const AppSettings(shellExtraKeys: false));
    expect(find.text('Esc'), findsNothing);
    expect(find.text('Ctrl+C'), findsNothing);
    expect(find.byIcon(Icons.copy_rounded), findsOneWidget);
    expect(find.byIcon(Icons.content_paste_rounded), findsOneWidget);
    await close(tester);
  });

  testWidgets('the terminal uses the chosen font size', (tester) async {
    await open(tester, settings: const AppSettings(shellFontSize: 18));
    final view = tester.widget<TerminalView>(find.byType(TerminalView));
    expect(view.textStyle.fontSize, 18);
    await close(tester);
  });
}

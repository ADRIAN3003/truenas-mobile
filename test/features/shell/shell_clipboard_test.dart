import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
import 'package:truenas_mobile/features/shell/shell_screen.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';
import 'package:xterm/xterm.dart';

import '../../support/fake_truenas_server.dart';

void main() {
  late FakeTrueNasServer server;
  late TrueNasSession session;
  String? clipboard;

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  setUp(() {
    HttpOverrides.global = null;
    clipboard = null;
  });

  Future<void> open(WidgetTester tester) async {
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        switch (call.method) {
          case 'Clipboard.setData':
            clipboard = (call.arguments as Map)['text'] as String?;
            return null;
          case 'Clipboard.getData':
            return clipboard == null ? null : {'text': clipboard};
        }
        return null;
      },
    );
    addTearDown(
      () => tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
        SystemChannels.platform,
        null,
      ),
    );
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
    await tester.pumpWidget(
      MaterialApp(
        localizationsDelegates: AppLocalizations.localizationsDelegates,
        supportedLocales: AppLocalizations.supportedLocales,
        home: ShellScreen(session: session),
      ),
    );
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

  Finder button(IconData icon) => find.widgetWithIcon(IconButton, icon);

  testWidgets('paste types the clipboard into the shell', (tester) async {
    await open(tester);
    clipboard = 'ls -la\r\nwhoami';
    await tester.tap(button(Icons.content_paste_rounded));
    await settle(tester);
    // Line breaks become Enter, as in any terminal.
    expect(server.shellInput.toString(), 'ls -la\rwhoami');
    await close(tester);
  });

  testWidgets('paste does nothing for an empty clipboard', (tester) async {
    await open(tester);
    await tester.tap(button(Icons.content_paste_rounded));
    await settle(tester);
    expect(server.shellInput.toString(), isEmpty);
    await close(tester);
  });

  testWidgets('copy needs a selection, then puts it on the clipboard', (
    tester,
  ) async {
    await open(tester);
    IconButton copy() => tester.widget<IconButton>(button(Icons.copy_rounded));
    expect(copy().onPressed, isNull);

    // The prompt "truenas# " is on the first line; a long press selects the
    // word under the finger.
    final terminal = find.byType(TerminalView);
    await tester.longPressAt(
      tester.getTopLeft(terminal) + const Offset(20, 12),
    );
    await tester.pump();
    expect(copy().onPressed, isNotNull);

    await tester.tap(button(Icons.copy_rounded));
    await tester.pump();
    expect(clipboard, contains('truenas'));
    expect(find.text('Copied to clipboard'), findsOneWidget);
    // The selection is cleared, so there is nothing more to copy.
    expect(copy().onPressed, isNull);
    await close(tester);
  });
}

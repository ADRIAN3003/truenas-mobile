import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/features/instances/server_form_screen.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/memory_store.dart';

const _saved = ServerInstance(
  id: 'a',
  name: 'Home NAS',
  url: 'https://nas.local',
  authMethod: AuthMethod.password,
  username: 'truenas_admin',
  secret: 'hunter2',
);

void main() {
  late MemoryStore store;

  Future<void> openForm(WidgetTester tester, {ServerInstance? edit}) async {
    store = MemoryStore();
    if (edit != null) await InstanceRepository(store).save([edit]);
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          instanceRepositoryProvider.overrideWithValue(
            InstanceRepository(store),
          ),
        ],
        child: MaterialApp(
          localizationsDelegates: AppLocalizations.localizationsDelegates,
          supportedLocales: AppLocalizations.supportedLocales,
          home: ServerFormScreen(instance: edit),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  TextField secretField(WidgetTester tester) => tester.widget<TextField>(
    find.descendant(
      of: find.byKey(const Key('secret')),
      matching: find.byType(TextField),
    ),
  );

  Future<ServerInstance> savedServer() async =>
      (await InstanceRepository(store).load()).single;

  testWidgets('editing never shows the saved password', (tester) async {
    await openForm(tester, edit: _saved);
    expect(secretField(tester).controller!.text, isEmpty);
    expect(find.text('hunter2'), findsNothing);
    expect(
      find.textContaining('Leave empty to keep the saved password'),
      findsOneWidget,
    );
  });

  testWidgets('an empty password field keeps the saved one', (tester) async {
    await openForm(tester, edit: _saved);
    await tester.enterText(find.byType(TextFormField).first, 'Office NAS');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    final server = await savedServer();
    expect(server.name, 'Office NAS');
    expect(server.secret, 'hunter2');
  });

  testWidgets('typing a password replaces the saved one', (tester) async {
    await openForm(tester, edit: _saved);
    await tester.enterText(find.byKey(const Key('secret')), 'correct horse');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect((await savedServer()).secret, 'correct horse');
  });

  testWidgets('another sign-in method needs its own secret', (tester) async {
    await openForm(tester, edit: _saved);
    await tester.tap(find.text('API key'));
    await tester.pumpAndSettle();
    expect(find.textContaining('Leave empty'), findsNothing);
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);
    expect((await savedServer()).secret, 'hunter2');
  });

  testWidgets('a new server still needs a password', (tester) async {
    await openForm(tester);
    await tester.enterText(find.byKey(const Key('address')), 'nas.local');
    await tester.tap(find.text('Save'));
    await tester.pumpAndSettle();
    expect(find.text('Required'), findsOneWidget);
    expect(await InstanceRepository(store).load(), isEmpty);
  });
}

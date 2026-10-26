import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/api/workloads_api.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/core/session/truenas_session.dart';
import 'package:truenas_mobile/features/workloads/app_screen.dart';
import 'package:truenas_mobile/features/workloads/apps_tab.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';

import '../../support/fake_truenas_server.dart';

void main() {
  late FakeTrueNasServer server;
  late TrueNasSession session;

  Widget wrap(Widget child) => MaterialApp(
    localizationsDelegates: AppLocalizations.localizationsDelegates,
    supportedLocales: AppLocalizations.supportedLocales,
    home: Scaffold(body: child),
  );

  Future<void> settle(WidgetTester tester) async {
    for (var i = 0; i < 10; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
    await tester.pumpAndSettle();
  }

  /// Waits for the server's answer to the install or update request,
  /// including the short wait for it to refuse the job.
  Future<void> submitted(WidgetTester tester) async {
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 100)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
    await tester.pumpAndSettle();
  }

  /// A tall window, so a long form needs no scrolling.
  void tall(WidgetTester tester) {
    tester.view.physicalSize = const Size(800, 2400);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);
  }

  setUp(() {
    HttpOverrides.global = null;
    WorkloadsApi.settleWindow = const Duration(milliseconds: 300);
  });
  tearDown(() => WorkloadsApi.settleWindow = const Duration(seconds: 10));

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

  Future<void> openCatalog(WidgetTester tester) async {
    await tester.pumpWidget(wrap(AppsTab(session: session)));
    await settle(tester);
    await tester.tap(find.byTooltip('Install app'));
    await settle(tester);
  }

  Future<void> openPlex(WidgetTester tester) async {
    tall(tester);
    await openCatalog(tester);
    await tester.tap(find.text('Plex'));
    await settle(tester);
  }

  Finder field(String label) => find.widgetWithText(TextField, label);

  group('catalog', () {
    testWidgets('lists what the catalog offers and marks installed apps', (
      tester,
    ) async {
      await connect(tester);
      await openCatalog(tester);

      expect(find.text('App catalog'), findsOneWidget);
      expect(find.text('Jellyfin'), findsOneWidget);
      expect(find.text('Plex'), findsOneWidget);
      // Community apps say which train they come from.
      expect(find.textContaining('community · Files'), findsOneWidget);
      expect(find.byTooltip('Installed'), findsOneWidget);
      await disconnect(tester);
    });

    testWidgets('searches by name and filters by category', (tester) async {
      await connect(tester);
      await openCatalog(tester);

      await tester.enterText(find.byType(TextField).first, 'next');
      await tester.pumpAndSettle();
      expect(find.text('Nextcloud'), findsOneWidget);
      expect(find.text('Plex'), findsNothing);

      await tester.enterText(find.byType(TextField).first, '');
      await tester.pumpAndSettle();
      await tester.tap(find.widgetWithText(ChoiceChip, 'streaming'));
      await tester.pumpAndSettle();
      expect(find.text('Plex'), findsOneWidget);
      expect(find.text('Jellyfin'), findsNothing);
      await disconnect(tester);
    });

    testWidgets('says why nothing can be installed before a pool is set', (
      tester,
    ) async {
      await connect(tester);
      server.dockerStatus = 'UNCONFIGURED';
      await openCatalog(tester);

      expect(find.textContaining('Apps need a pool first'), findsOneWidget);
      await tester.tap(find.text('Plex'));
      await settle(tester);
      // Still on the catalog.
      expect(find.text('App catalog'), findsOneWidget);
      expect(find.text('Install'), findsNothing);
      await disconnect(tester);
    });

    testWidgets('refreshing asks the server to sync the catalog', (
      tester,
    ) async {
      await connect(tester);
      await openCatalog(tester);

      await tester.tap(find.byTooltip('Refresh catalog'));
      await settle(tester);
      expect(server.catalogSyncs, 1);
      expect(find.text('Catalog refreshed'), findsOneWidget);
      await disconnect(tester);
    });

    testWidgets('a server without a catalog offers no install button', (
      tester,
    ) async {
      await connect(tester);
      server.catalog = false;
      await tester.pumpWidget(wrap(AppsTab(session: session)));
      await settle(tester);

      expect(find.byTooltip('Install app'), findsNothing);
      await disconnect(tester);
    });
  });

  group('install', () {
    testWidgets('builds the form from the catalog and sends what was typed', (
      tester,
    ) async {
      await connect(tester);
      await openPlex(tester);

      // Sections and settings from the schema.
      expect(find.text('Application Configuration'), findsOneWidget);
      expect(find.text('Storage Configuration'), findsOneWidget);
      expect(find.text('Verbose logs'), findsOneWidget);
      // The sub-question and the path wait for their switch and choice.
      expect(find.text('Log level'), findsNothing);
      expect(find.text('Host path'), findsNothing);

      await tester.enterText(field('Application name'), 'plex-home');
      await tester.enterText(field('Claim token'), 'claim-123');
      await tester.enterText(field('Web port *'), '32401');
      await tester.tap(find.text('Verbose logs'));
      await tester.pumpAndSettle();
      expect(find.text('Log level'), findsOneWidget);

      // Add an environment variable.
      await tester.ensureVisible(find.byTooltip('Add entry'));
      await tester.tap(find.byTooltip('Add entry'));
      await tester.pumpAndSettle();
      await tester.enterText(field('Name *'), 'TZ');
      await tester.enterText(field('Value'), 'UTC');

      await tester.tap(find.text('Install'));
      await submitted(tester);

      expect(server.appCreates, hasLength(1));
      final request = server.appCreates.single;
      expect(request['app_name'], 'plex-home');
      expect(request['catalog_app'], 'plex');
      expect(request['train'], 'stable');
      expect(request['version'], '2.0.1');
      expect(request['values'], {
        'claim_token': 'claim-123',
        'timezone': 'UTC',
        'enable_logs': true,
        'log_level': 'info',
        'network': {'web_port': 32401},
        'extra_env': [
          {'name': 'TZ', 'value': 'UTC'},
        ],
        'storage': {'type': 'ix_volume'},
      });

      // Back on the Apps tab, with the new app in the list.
      expect(find.text('plex-home'), findsOneWidget);
      expect(find.text('plex-home installed'), findsOneWidget);
      await disconnect(tester);
    });

    testWidgets('settings that do not apply are not sent', (tester) async {
      await connect(tester);
      await openPlex(tester);

      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<Object?>, 'ixVolume'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Host path').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Host path *'), findsOneWidget);
      await tester.enterText(field('Host path *'), '/mnt/tank/plex');
      // Switch back: the typed path must not travel with ixVolume.
      await tester.tap(
        find.widgetWithText(DropdownButtonFormField<Object?>, 'Host path'),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('ixVolume').last);
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Host path *'), findsNothing);

      await tester.tap(find.text('Install'));
      await submitted(tester);

      final values = server.appCreates.single['values'] as Map;
      expect(values['storage'], {'type': 'ix_volume'});
      await disconnect(tester);
    });

    testWidgets('a wrong name or value is flagged and nothing is sent', (
      tester,
    ) async {
      await connect(tester);
      await openPlex(tester);

      await tester.enterText(field('Application name'), 'Plex Home');
      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Use lowercase letters'), findsOneWidget);

      await tester.enterText(field('Application name'), 'plex-home');
      await tester.enterText(field('Web port *'), '80');
      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();
      expect(find.text('Web port: Too small'), findsOneWidget);
      expect(server.appCreates, isEmpty);
      await disconnect(tester);
    });

    testWidgets('a refusal from the server stays on the form', (tester) async {
      await connect(tester);
      server.appJobState = 'FAILED';
      await openPlex(tester);

      await tester.tap(find.text('Install'));
      await submitted(tester);

      expect(server.appCreates, hasLength(1));
      expect(find.textContaining('Invalid'), findsOneWidget);
      // Still the install form, ready to try again.
      expect(find.text('Install'), findsOneWidget);
      expect(find.text('Application name'), findsOneWidget);
      await disconnect(tester);
    });

    testWidgets('a long install carries on and says so', (tester) async {
      await connect(tester);
      server.appJobState = 'RUNNING';
      await openPlex(tester);

      await tester.tap(find.text('Install'));
      await submitted(tester);

      expect(find.textContaining('Installing plex.'), findsOneWidget);
      // Back on the Apps tab; the app shows while it deploys.
      expect(find.text('plex'), findsOneWidget);
      await disconnect(tester);
    });

    testWidgets('JSON mode edits the same values', (tester) async {
      await connect(tester);
      await openPlex(tester);

      await tester.tap(find.byTooltip('Edit as JSON'));
      await tester.pumpAndSettle();
      expect(find.widgetWithText(TextField, 'Configuration (JSON)'), findsOne);
      await tester.enterText(
        find.widgetWithText(TextField, 'Configuration (JSON)'),
        '{"claim_token": "from-json", "network": {"web_port": 40000}}',
      );
      // Back to the form: what was typed is there, the rest at defaults.
      await tester.tap(find.byTooltip('Back to the form'));
      await tester.pumpAndSettle();
      expect(find.text('from-json'), findsOneWidget);

      await tester.tap(find.text('Install'));
      await submitted(tester);
      final values = server.appCreates.single['values'] as Map;
      expect(values['claim_token'], 'from-json');
      expect((values['network'] as Map)['web_port'], 40000);
      expect(values['timezone'], 'UTC');
      await disconnect(tester);
    });

    testWidgets('JSON that is not an object is refused', (tester) async {
      await connect(tester);
      await openPlex(tester);

      await tester.tap(find.byTooltip('Edit as JSON'));
      await tester.pumpAndSettle();
      await tester.enterText(
        find.widgetWithText(TextField, 'Configuration (JSON)'),
        '{not json',
      );
      await tester.tap(find.text('Install'));
      await tester.pumpAndSettle();
      expect(find.text('That is not valid JSON.'), findsOneWidget);
      expect(server.appCreates, isEmpty);
      await disconnect(tester);
    });

    testWidgets('picks an older version when asked', (tester) async {
      await connect(tester);
      await openPlex(tester);

      await tester.tap(
        find.widgetWithText(
          DropdownButtonFormField<String>,
          '1.41.0_2.0.1 (2.0.1)',
        ),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('1.40.0_1.9.0 (1.9.0)').last);
      await tester.pumpAndSettle();
      await tester.tap(find.text('Install'));
      await submitted(tester);

      expect(server.appCreates.single['version'], '1.9.0');
      await disconnect(tester);
    });

    testWidgets('a custom app is installed from a Compose file', (
      tester,
    ) async {
      await connect(tester);
      await openCatalog(tester);

      await tester.tap(find.text('Custom app'));
      await settle(tester);
      await tester.enterText(field('Application name'), 'whoami');
      await tester.enterText(
        field('Docker Compose file'),
        'services:\n  web:\n    image: traefik/whoami\n',
      );
      await tester.tap(find.text('Install'));
      await submitted(tester);

      final request = server.appCreates.single;
      expect(request['app_name'], 'whoami');
      expect(request['custom_app'], isTrue);
      expect(
        request['custom_compose_config_string'],
        contains('traefik/whoami'),
      );
      expect(find.text('whoami'), findsOneWidget);
      await disconnect(tester);
    });
  });

  group('edit', () {
    Future<void> openEdit(WidgetTester tester) async {
      final app = (await tester.runAsync(session.workloads.apps))!.single;
      await tester.pumpWidget(wrap(AppScreen(session: session, app: app)));
      await settle(tester);
      await tester.tap(find.text('Edit configuration'));
      await settle(tester);
    }

    testWidgets('loads the current values and sends them back changed', (
      tester,
    ) async {
      await connect(tester);
      await openEdit(tester);

      expect(find.text('Edit jellyfin'), findsOneWidget);
      expect(find.widgetWithText(TextField, '30013'), findsOneWidget);
      expect(find.text('LANG'), findsOneWidget);

      await tester.enterText(field('Web port *'), '30014');
      await tester.tap(find.text('Save'));
      await submitted(tester);

      expect(server.appUpdates, hasLength(1));
      final (name, data) = server.appUpdates.single;
      expect(name, 'jellyfin');
      final values = data['values'] as Map;
      expect(values['network'], {'web_port': 30014});
      expect(values['extra_env'], [
        {'name': 'LANG', 'value': 'C'},
      ]);
      // Back on the app's screen.
      expect(find.text('Edit configuration'), findsOneWidget);
      expect(find.text('jellyfin updated'), findsOneWidget);
      await disconnect(tester);
    });

    testWidgets('a refusal stays on the form', (tester) async {
      await connect(tester);
      server.appJobState = 'FAILED';
      await openEdit(tester);

      await tester.tap(find.text('Save'));
      await submitted(tester);

      expect(find.textContaining('Invalid'), findsOneWidget);
      expect(find.text('Edit jellyfin'), findsOneWidget);
      await disconnect(tester);
    });

    testWidgets('a custom app is edited as its Compose config in JSON', (
      tester,
    ) async {
      await connect(tester);
      server.apps.single
        ..['custom_app'] = true
        ..['metadata'] = {'title': 'jellyfin'};
      server.appConfigs['jellyfin'] = {
        'services': {
          'web': {'image': 'traefik/whoami'},
        },
      };
      await openEdit(tester);

      expect(
        find.widgetWithText(TextField, 'Docker Compose config (JSON)'),
        findsOneWidget,
      );
      expect(find.byTooltip('Back to the form'), findsNothing);
      await tester.enterText(
        find.widgetWithText(TextField, 'Docker Compose config (JSON)'),
        '{"services": {"web": {"image": "traefik/whoami:v1"}}}',
      );
      await tester.tap(find.text('Save'));
      await submitted(tester);

      final (_, data) = server.appUpdates.single;
      expect(data.containsKey('values'), isFalse);
      expect(data['custom_compose_config'], {
        'services': {
          'web': {'image': 'traefik/whoami:v1'},
        },
      });
      await disconnect(tester);
    });
  });
}

// Renders the README screenshots against the fake server. Skipped in normal
// runs; regenerate with:
//   SCREENSHOTS=1 flutter test test/screenshots --update-goldens
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/core/instances/instance_repository.dart';
import 'package:truenas_mobile/core/instances/instances_provider.dart';
import 'package:truenas_mobile/core/instances/server_instance.dart';
import 'package:truenas_mobile/features/instances/instances_screen.dart';
import 'package:truenas_mobile/l10n/generated/app_localizations.dart';
import 'package:truenas_mobile/shared/theme.dart';

import '../support/fake_truenas_server.dart';
import '../support/memory_store.dart';

final _skip = !Platform.environment.containsKey('SCREENSHOTS');

final _materialFonts =
    '${Platform.environment['FLUTTER_ROOT'] ?? ''}'
    '/bin/cache/artifacts/material_fonts';

/// Roboto lacks arrows like →, which phones draw from a system font.
const _fallbackFont = '/usr/share/fonts/truetype/dejavu/DejaVuSans.ttf';

Future<void> _loadFont(String family, List<String> files) async {
  final loader = FontLoader(family);
  for (final file in files) {
    final bytes = File(file).readAsBytesSync();
    loader.addFont(Future.value(ByteData.sublistView(bytes)));
  }
  await loader.load();
}

void main() {
  late FakeTrueNasServer server;
  late ProviderContainer container;

  setUpAll(() async {
    if (_skip) return;
    await _loadFont('Roboto', [
      for (final weight in ['Regular', 'Medium', 'Bold'])
        '$_materialFonts/Roboto-$weight.ttf',
    ]);
    await _loadFont('MaterialIcons', [
      '$_materialFonts/MaterialIcons-Regular.otf',
    ]);
    if (File(_fallbackFont).existsSync()) {
      await _loadFont('Fallback', [_fallbackFont]);
    }
  });

  setUp(() => HttpOverrides.global = _NasLan());

  Future<void> settle(WidgetTester tester, [int rounds = 10]) async {
    for (var i = 0; i < rounds; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump(const Duration(milliseconds: 100));
    }
  }

  Future<void> open(WidgetTester tester, Brightness brightness) async {
    debugDisableShadows = false;
    tester.view.physicalSize = const Size(1080, 2340);
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.runAsync(() async {
      server = await FakeTrueNasServer.start();
      _NasLan.port = server.port;
      _realisticSizes(server);
      final store = MemoryStore();
      await InstanceRepository(store).save([
        ServerInstance(
          id: '1',
          name: 'Home NAS',
          url: 'http://truenas.lan',
          authMethod: AuthMethod.password,
          username: 'truenas_admin',
          secret: 'secret',
          lastApiVersion: 'v25.10.5',
        ),
        const ServerInstance(
          id: '2',
          name: 'Backup box',
          url: 'https://backup.lan',
          authMethod: AuthMethod.apiKey,
          username: 'truenas_admin',
          secret: 'key',
          lastApiVersion: 'v25.04.2',
        ),
      ]);
      container = ProviderContainer(
        overrides: [
          instanceRepositoryProvider.overrideWithValue(
            InstanceRepository(store),
          ),
        ],
      );
      await container.read(instancesProvider.future);
    });
    await tester.runAsync(
      () => tester.pumpWidget(
        UncontrolledProviderScope(
          container: container,
          child: MaterialApp(
            debugShowCheckedModeBanner: false,
            localizationsDelegates: AppLocalizations.localizationsDelegates,
            supportedLocales: AppLocalizations.supportedLocales,
            theme: buildAppTheme(
              brightness,
              fontFamilyFallback: const ['Fallback'],
            ),
            home: const InstancesScreen(),
          ),
        ),
      ),
    );
    await settle(tester);
  }

  Future<void> close(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.pumpWidget(const SizedBox());
      await Future<void>.delayed(const Duration(milliseconds: 200));
      container.dispose();
      await server.close();
    });
    await tester.pump(const Duration(seconds: 16));
    debugDisableShadows = true;
  }

  Future<void> shot(WidgetTester tester, String name) async {
    await settle(tester);
    await expectLater(
      find.byType(MaterialApp),
      matchesGoldenFile('../../docs/screenshots/$name.png'),
    );
  }

  Future<void> tap(WidgetTester tester, String text) async {
    await tester.tap(find.text(text).last);
    await settle(tester);
  }

  // The server screen connects as it is built; build it with real timers so
  // the socket's ping timer isn't left in the fake test zone.
  Future<void> openServer(WidgetTester tester) async {
    await tester.runAsync(() async {
      await tester.tap(find.text('Home NAS'));
      await tester.pump();
    });
    await settle(tester);
  }

  testWidgets('light', skip: _skip, (tester) async {
    await open(tester, Brightness.light);
    await shot(tester, 'servers');
    await openServer(tester);
    await shot(tester, 'dashboard');
    await tap(tester, 'Storage');
    await shot(tester, 'storage');
    await tap(tester, 'Apps');
    await shot(tester, 'apps');
    await close(tester);
  });

  testWidgets('dark', skip: _skip, (tester) async {
    await open(tester, Brightness.dark);
    await openServer(tester);
    await tap(tester, 'More');
    await shot(tester, 'more');
    await tap(tester, 'Storage');
    await tap(tester, 'Data protection');
    await shot(tester, 'protection');
    await close(tester);
  });
}

const _tib = 1 << 40;

/// Swaps the fixtures' byte-sized pool and datasets for terabytes.
void _realisticSizes(FakeTrueNasServer server) {
  server.pools = [
    {...samplePool, 'size': 16 * _tib, 'allocated': 9 * _tib, 'free': 7 * _tib},
  ];
  const used = {'tank': 9 * _tib, 'tank/media': 8 * _tib, 'tank/vm': _tib};
  for (final dataset in server.datasets) {
    final bytes = used[dataset['id']] ?? 0;
    dataset['used'] = {'parsed': bytes, 'value': '$bytes'};
    dataset['available'] = {'parsed': 7 * _tib, 'value': '${7 * _tib}'};
  }
}

/// Sends requests for truenas.lan to the fake server, so the screenshots
/// show a believable address.
class _NasLan extends HttpOverrides {
  static int port = 0;

  @override
  HttpClient createHttpClient(SecurityContext? context) =>
      super.createHttpClient(context)
        ..connectionFactory = (uri, proxyHost, proxyPort) =>
            Socket.startConnect(InternetAddress.loopbackIPv4, port);
}

import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/features/workloads/app_icon.dart';
import 'package:truenas_mobile/shared/ui.dart';

void main() {
  late HttpServer server;

  setUp(() async {
    HttpOverrides.global = null;
    server = await HttpServer.bind(InternetAddress.loopbackIPv4, 0);
    server.listen((request) {
      request.response.headers.contentType = ContentType('image', 'svg+xml');
      request.response.write(switch (request.uri.path) {
        '/none.svg' =>
          '<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 10 10">'
              '<rect transform="none" width="10" height="10" '
              'style="fill:#08f;transform: none"/></svg>',
        _ => 'not an svg',
      });
      request.response.close();
    });
  });
  tearDown(() => server.close(force: true));

  Future<void> show(WidgetTester tester, String path) async {
    await tester.pumpWidget(
      MaterialApp(home: AppIcon(url: 'http://127.0.0.1:${server.port}$path')),
    );
    for (var i = 0; i < 20; i++) {
      await tester.runAsync(
        () => Future<void>.delayed(const Duration(milliseconds: 50)),
      );
      await tester.pump();
    }
  }

  test('transform none is taken out, other transforms stay', () {
    expect(cleanSvg('<g transform="none"><g transform=\'none\'>'), '<g><g>');
    expect(
      cleanSvg('<g style="transform: none; fill: red">'),
      '<g style="fill: red">',
    );
    expect(
      cleanSvg('<g transform="rotate(45)">'),
      '<g transform="rotate(45)">',
    );
  });

  testWidgets('an icon with transform none is drawn', (tester) async {
    await show(tester, '/none.svg');
    expect(find.byType(SvgPicture), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  testWidgets('an SVG that cannot be read shows the generic icon, quietly', (
    tester,
  ) async {
    await show(tester, '/broken.svg');
    expect(find.byType(SvgPicture), findsNothing);
    expect(find.byType(IconTile), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}

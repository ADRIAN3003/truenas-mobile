import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:truenas_mobile/shared/glass.dart';

void main() {
  setUp(resetNativeGlassPauses);

  test('pauses stack and each can be released only once', () {
    expect(nativeGlassPauses, 0);
    final a = pauseNativeGlass();
    final b = pauseNativeGlass();
    expect(nativeGlassPauses, 2);
    a();
    a();
    expect(nativeGlassPauses, 1);
    b();
    expect(nativeGlassPauses, 0);
  });

  testWidgets('dragging a page back pauses native glass until it lets go', (
    tester,
  ) async {
    final observer = glassNavigatorObserver();
    await tester.pumpWidget(
      MaterialApp(navigatorObservers: [observer], home: const SizedBox()),
    );
    final route = MaterialPageRoute<void>(builder: (_) => const SizedBox());
    observer.didStartUserGesture(route, null);
    expect(nativeGlassPauses, 1);
    observer.didStartUserGesture(route, null);
    expect(nativeGlassPauses, 1);
    observer.didStopUserGesture();
    expect(nativeGlassPauses, 0);
    observer.didStopUserGesture();
    expect(nativeGlassPauses, 0);
  });

  testWidgets('native glass is paused for the whole of a page transition', (
    tester,
  ) async {
    final navigator = GlobalKey<NavigatorState>();
    await tester.pumpWidget(
      MaterialApp(
        navigatorKey: navigator,
        navigatorObservers: [glassNavigatorObserver()],
        home: const SizedBox(),
      ),
    );
    expect(nativeGlassPauses, 0);

    unawaited(
      navigator.currentState!.push<void>(
        MaterialPageRoute(builder: (_) => const Text('second')),
      ),
    );
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(nativeGlassPauses, 1);
    await tester.pumpAndSettle();
    expect(nativeGlassPauses, 0);

    navigator.currentState!.pop();
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));
    expect(nativeGlassPauses, 1);
    await tester.pumpAndSettle();
    expect(nativeGlassPauses, 0);
  });
}

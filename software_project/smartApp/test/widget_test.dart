// Basic smoke test: the app builds and shows the admin login screen.
//
// Before the login screen ever renders, _AuthGate (lib/main.dart) awaits
// authService.restoreSession(), which reads a stored token via
// flutter_secure_storage — a plugin backed by a platform MethodChannel.
// `flutter test` has no real platform on the other end of that channel, and
// with no mock registered, the resulting Future never completes within a
// `tester.pump()` loop: Flutter's test binding does eventually resolve an
// unmocked channel call with a MissingPluginException, but only on a real
// event-loop turn (e.g. `Future.delayed`), not on the fake clock
// `tester.pump()` advances. So FutureBuilder stays on ConnectionState.waiting
// forever, the CircularProgressIndicator never goes away, AdminLoginScreen
// never builds, and no amount of pumping makes 'Smart Classroom IoT' or
// 'Sign In' appear — this was the actual cause of the failure, not a timing
// issue. Mocking the channel lets the read resolve immediately as "no stored
// token", which is exactly the state a fresh install is in.
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';

import 'package:smartApp/main.dart';

void main() {
  const secureStorageChannel =
      MethodChannel('plugins.it_nomads.com/flutter_secure_storage');

  setUp(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, (call) async => null);
  });

  tearDown(() {
    TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger
        .setMockMethodCallHandler(secureStorageChannel, null);
  });

  testWidgets('App boots to the admin login screen', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());

    // A bounded pump loop, not pumpAndSettle(): something on the login
    // screen keeps a transient animation alive (e.g. a text field's blinking
    // cursor), so the tree never fully "settles".
    for (var i = 0; i < 15; i++) {
      await tester.pump(const Duration(milliseconds: 200));
    }

    expect(find.text('Smart Classroom IoT'), findsOneWidget);
    expect(find.text('Sign In'), findsOneWidget);
  });
}

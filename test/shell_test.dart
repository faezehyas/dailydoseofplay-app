import 'package:dailydoseofplay/bridge.dart';
import 'package:dailydoseofplay/shell.dart';
import 'package:dailydoseofplay/splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:webview_flutter_platform_interface/webview_flutter_platform_interface.dart';

import 'fake_webview.dart';

void main() {
  late FakeWebViewPlatform platform;
  late List<Uri> opened;
  late List<String> shared;

  setUp(() {
    WebViewPlatform.instance = platform = FakeWebViewPlatform();
    opened = [];
    shared = [];
  });

  Future<void> pumpShell(WidgetTester tester) => tester.pumpWidget(
    MaterialApp(
      home: Shell(
        bridge: Bridge(
          share: (text) async => shared.add(text),
          haptic: (_) async {},
        ),
        openOutside: (uri) async => opened.add(uri),
      ),
    ),
  );

  Matrix4 dot(WidgetTester tester, int i) =>
      tester.widget<Transform>(find.byKey(ValueKey('dot$i'))).transform;

  testWidgets('opens the site under the splash, with the bridge', (
    tester,
  ) async {
    await pumpShell(tester);
    expect(platform.controller.loads, [siteHome]);
    expect(find.byType(Splash), findsOneWidget);
    expect(find.text('Opening the games'), findsNothing);

    platform.controller.post(
      Bridge.channel,
      '{"type":"share","text":"Play with me!","url":"https://www.dailydoseofplay.com/"}',
    );
    expect(shared, ['Play with me! https://www.dailydoseofplay.com/']);
  });

  testWidgets(
    'words from 2 s, a way out from 10 s, and Try again loads the site again',
    (tester) async {
      await pumpShell(tester);
      await tester.pump(wordsFrom - const Duration(milliseconds: 1));
      expect(find.text('Opening the games'), findsNothing);
      await tester.pump(const Duration(milliseconds: 1));
      expect(find.text('Opening the games'), findsOneWidget);
      expect(find.text('Try again'), findsNothing);

      await tester.pump(helpFrom - wordsFrom);
      expect(
        find.text('Taking a while? Check your connection or try again.'),
        findsOneWidget,
      );
      await tester.tap(find.text('Try again'));
      await tester.pump();
      expect(platform.controller.loads, [siteHome, siteHome]);
      expect(find.text('Try again'), findsNothing);
      await tester.pump(helpFrom);
      expect(find.text('Try again'), findsOneWidget);
    },
  );

  testWidgets('the dots hop in turn from 300 ms', (tester) async {
    await pumpShell(tester);
    await tester.pump(hopFrom - const Duration(milliseconds: 1));
    expect(dot(tester, 0), Matrix4.identity());
    await tester.pump(const Duration(milliseconds: 1));
    await tester.pump(const Duration(milliseconds: 100));
    expect(dot(tester, 0), isNot(Matrix4.identity()));
    expect(dot(tester, 1), Matrix4.identity());
  });

  testWidgets(
    'with reduce motion the dots stay still and the splash just goes',
    (tester) async {
      tester.platformDispatcher.accessibilityFeaturesTestValue =
          FakeAccessibilityFeatures(disableAnimations: true);
      addTearDown(
        tester.platformDispatcher.clearAccessibilityFeaturesTestValue,
      );
      await pumpShell(tester);
      for (var t = 0; t < 20; t++) {
        await tester.pump(const Duration(milliseconds: 100));
        for (var i = 0; i < 4; i++) {
          expect(dot(tester, i), Matrix4.identity());
        }
      }
      expect(find.text('Opening the games'), findsOneWidget);

      platform.navigation.onPageFinished(siteHome.toString());
      await tester.pump();
      expect(find.byType(Splash), findsNothing);
    },
  );

  testWidgets('fades into the first page once it loads', (tester) async {
    await pumpShell(tester);
    platform.navigation.onPageStarted(siteHome.toString());
    platform.navigation.onPageFinished(siteHome.toString());
    await tester.pump();
    expect(find.byType(Splash), findsOneWidget);
    await tester.pump(const Duration(milliseconds: 500));
    await tester.pump();
    expect(find.byType(Splash), findsNothing);
    expect(platform.controller.scripts.single, contains('DDPBackground'));
  });

  testWidgets('a page that fails to load keeps the splash', (tester) async {
    await pumpShell(tester);
    platform.navigation.onPageStarted(siteHome.toString());
    platform.navigation.onWebResourceError(
      const WebResourceError(
        errorCode: -1009,
        description: 'offline',
        isForMainFrame: true,
      ),
    );
    platform.navigation.onPageFinished(siteHome.toString());
    await tester.pump(const Duration(seconds: 1));
    expect(find.byType(Splash), findsOneWidget);
  });

  testWidgets('keeps the site inside and opens other sites outside', (
    tester,
  ) async {
    await pumpShell(tester);
    Future<NavigationDecision> go(
      String url, {
      bool isMainFrame = true,
    }) async => platform.navigation.onNavigationRequest(
      NavigationRequest(url: url, isMainFrame: isMainFrame),
    );

    expect(
      await go('https://www.dailydoseofplay.com/ludo/?room=ABCD'),
      NavigationDecision.navigate,
    );
    expect(
      await go('https://dailydoseofplay.com/'),
      NavigationDecision.navigate,
    );
    expect(
      await go('https://www.youtube.com/embed/x', isMainFrame: false),
      NavigationDecision.navigate,
    );
    expect(
      await go('https://github.com/Faezehyas/dailydoseofplay'),
      NavigationDecision.prevent,
    );
    expect(
      await go('http://www.dailydoseofplay.com/'),
      NavigationDecision.prevent,
    );
    expect(await go('mailto:hello@example.com'), NavigationDecision.prevent);
    expect(opened, [
      Uri.parse('https://github.com/Faezehyas/dailydoseofplay'),
      Uri.parse('http://www.dailydoseofplay.com/'),
      Uri.parse('mailto:hello@example.com'),
    ]);
  });

  testWidgets('back goes back in the page, then leaves the app', (
    tester,
  ) async {
    final calls = <String>[];
    tester.binding.defaultBinaryMessenger.setMockMethodCallHandler(
      SystemChannels.platform,
      (call) async {
        calls.add(call.method);
        return null;
      },
    );
    await pumpShell(tester);

    platform.controller.canGoBackValue = true;
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(platform.controller.backs, 1);
    expect(calls, isNot(contains('SystemNavigator.pop')));

    platform.controller.canGoBackValue = false;
    await tester.binding.handlePopRoute();
    await tester.pump();
    expect(platform.controller.backs, 1);
    expect(calls, contains('SystemNavigator.pop'));
  });

  testWidgets("the strips around the page take the page's background", (
    tester,
  ) async {
    await pumpShell(tester);
    platform.controller.post('DDPBackground', 'rgb(18, 21, 28)');
    await tester.pump();
    final frame = tester.widget<ColoredBox>(
      find
          .descendant(of: find.byType(Shell), matching: find.byType(ColoredBox))
          .first,
    );
    expect(frame.color, const Color(0xFF12151C));
  });
}

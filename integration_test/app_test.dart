import 'package:dailydoseofplay/bridge.dart';
import 'package:dailydoseofplay/shell.dart';
import 'package:dailydoseofplay/splash.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';

// Against the live site: needs the network.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  Future<void> waitFor(WidgetTester tester, bool Function() done) async {
    for (var i = 0; i < 300 && !done(); i++) {
      await tester.pump(const Duration(milliseconds: 100));
    }
    expect(done(), isTrue);
  }

  testWidgets('the WebView loads the site and the bridge answers', (
    tester,
  ) async {
    final shared = <String>[];
    final haptics = <String>[];
    await tester.pumpWidget(
      MaterialApp(
        home: Shell(
          bridge: Bridge(
            share: (text) async => shared.add(text),
            haptic: (kind) async => haptics.add(kind),
          ),
        ),
      ),
    );

    await waitFor(tester, () => find.byType(Splash).evaluate().isEmpty);
    final controller = tester.state<ShellState>(find.byType(Shell)).controller;
    expect(await controller.currentUrl(), siteHome.toString());
    expect(await controller.getTitle(), contains('Daily Dose of Play'));

    // The site's own bridge module, as a game page uses it.
    await controller.runJavaScript(
      'import("/engine/native.js").then((app) => { if (app.isApp) { app.share("Play with me!", location.href); app.haptic("medium"); } });',
    );
    await waitFor(tester, () => haptics.isNotEmpty);
    expect(shared, ['Play with me! ${siteHome.toString()}']);
    expect(haptics, ['medium']);
  });
}

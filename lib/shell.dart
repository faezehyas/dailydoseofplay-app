import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:url_launcher/url_launcher.dart';
import 'package:webview_flutter/webview_flutter.dart';

import 'bridge.dart';
import 'splash.dart';

final siteHome = Uri.parse('https://www.dailydoseofplay.com/');

// The site's pages stay in the app; every other link opens outside it.
bool _isSite(Uri uri) =>
    uri.scheme == 'https' &&
    (uri.host == 'www.dailydoseofplay.com' ||
        uri.host == 'dailydoseofplay.com');

// The site's --bg, for the strips around the WebView (status bar, home
// indicator) until the page reports its own.
const _lightBackground = Color(0xFFF6F3EE);
const _darkBackground = Color(0xFF12151C);

// The page's background follows the site's theme setting as well as the
// system's, so each page reports it, and again whenever either changes.
const _backgroundChannel = 'DDPBackground';
const _watchBackground =
    '''
(() => {
  const send = () => $_backgroundChannel.postMessage(getComputedStyle(document.body).backgroundColor);
  new MutationObserver(send).observe(document.documentElement, { attributeFilter: ["data-theme"] });
  matchMedia("(prefers-color-scheme: dark)").addEventListener("change", send);
  send();
})();
''';

// The splash's exit: a fade with a slight zoom, like the review's.
const _fade = Duration(milliseconds: 450);
const _fadeEase = Cubic(0.22, 1, 0.36, 1);

Future<void> _openOutside(Uri uri) =>
    launchUrl(uri, mode: LaunchMode.externalApplication);

class Shell extends StatefulWidget {
  const Shell({
    super.key,
    this.bridge = const Bridge(),
    this.openOutside = _openOutside,
  });

  final Bridge bridge;
  final Future<void> Function(Uri uri) openOutside;

  @override
  State<Shell> createState() => ShellState();
}

class ShellState extends State<Shell> {
  @visibleForTesting
  late final WebViewController controller;
  // The splash covers the WebView until its first page loads without an error.
  bool _loaded = false;
  bool _failed = false;
  bool _splashGone = false;
  Color? _background;

  @override
  void initState() {
    super.initState();
    controller = WebViewController()
      ..setJavaScriptMode(JavaScriptMode.unrestricted)
      ..addJavaScriptChannel(
        Bridge.channel,
        onMessageReceived: (m) => widget.bridge.receive(m.message),
      )
      ..addJavaScriptChannel(
        _backgroundChannel,
        onMessageReceived: (m) => _setBackground(m.message),
      )
      ..setNavigationDelegate(
        NavigationDelegate(
          onNavigationRequest: _navigate,
          onPageStarted: (_) => _failed = false,
          onWebResourceError: (error) {
            if (error.isForMainFrame ?? true) _failed = true;
          },
          onPageFinished: _pageFinished,
        ),
      )
      ..loadRequest(siteHome);
  }

  NavigationDecision _navigate(NavigationRequest request) {
    final uri = Uri.tryParse(request.url);
    if (!request.isMainFrame || (uri != null && _isSite(uri))) {
      return NavigationDecision.navigate;
    }
    if (uri != null) widget.openOutside(uri);
    return NavigationDecision.prevent;
  }

  void _pageFinished(String url) {
    if (_failed) return;
    controller.runJavaScript(_watchBackground);
    if (_loaded) return;
    setState(() {
      _loaded = true;
      _splashGone = MediaQuery.disableAnimationsOf(context);
    });
  }

  void _retry() {
    _failed = false;
    controller.loadRequest(siteHome);
  }

  // A CSS colour as getComputedStyle gives it: "rgb(r, g, b)" or "rgba(r, g, b, a)".
  void _setBackground(String css) {
    final c = RegExp(r'[\d.]+')
        .allMatches(css)
        .map((m) => double.parse(m[0]!))
        .toList();
    if (c.length < 3 || (c.length > 3 && c[3] == 0)) return;
    setState(
      () => _background = Color.fromARGB(
        255,
        c[0].round(),
        c[1].round(),
        c[2].round(),
      ),
    );
  }

  // Android's back button: back in the WebView, then out of the app.
  Future<void> _back(bool didPop, Object? result) async {
    if (didPop) return;
    if (await controller.canGoBack()) {
      await controller.goBack();
    } else {
      await SystemNavigator.pop();
    }
  }

  @override
  Widget build(BuildContext context) {
    final background =
        _background ??
        (MediaQuery.platformBrightnessOf(context) == Brightness.dark
            ? _darkBackground
            : _lightBackground);
    // Dark status bar icons on the coral splash and on a light page.
    final darkIcons = !_splashGone || background.computeLuminance() > 0.5;
    return PopScope(
      canPop: false,
      onPopInvokedWithResult: _back,
      child: AnnotatedRegion<SystemUiOverlayStyle>(
        value: darkIcons
            ? SystemUiOverlayStyle.dark
            : SystemUiOverlayStyle.light,
        child: ColoredBox(
          color: background,
          child: Stack(
            children: [
              SafeArea(
                child: ExcludeSemantics(
                  excluding: !_loaded,
                  child: WebViewWidget(controller: controller),
                ),
              ),
              if (!_splashGone)
                Positioned.fill(
                  child: IgnorePointer(
                    ignoring: _loaded,
                    child: ExcludeSemantics(
                      excluding: _loaded,
                      child: AnimatedOpacity(
                        opacity: _loaded ? 0 : 1,
                        duration: _fade,
                        curve: _fadeEase,
                        onEnd: () => setState(() => _splashGone = true),
                        child: AnimatedScale(
                          scale: _loaded ? 1.06 : 1,
                          duration: _fade,
                          curve: _fadeEase,
                          child: Splash(onRetry: _retry),
                        ),
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

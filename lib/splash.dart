import 'dart:async';
import 'dart:ui' show lerpDouble;

import 'package:flutter/material.dart';

// "The screen is the logo" (ddp-landing public/loading/, "Opening the app"):
// the whole screen is the website's --accent, and the logo's four dots are in
// --accent-ink, top right and bottom left at 55%. The native launch screen is
// the same picture standing still.
const _coral = Color(0xFFFF6B4A);
const _coralDark = Color(0xFFFF7A5C);
const _ink = Color(0xFF1A0E0A);

Color _splashColor(Brightness brightness) =>
    brightness == Brightness.dark ? _coralDark : _coral;

// The loading review's timing: the launch image's still dots until 300 ms,
// words from 2 s, a way out from 10 s.
const hopFrom = Duration(milliseconds: 300);
const wordsFrom = Duration(seconds: 2);
const helpFrom = Duration(seconds: 10);

const _dot = 36.0;
const _step = 62.0; // a dot and the 26 pt gap
// Top left, top right, bottom right, bottom left: the order they hop in.
const _dots = [
  (0.0, 0.0, 1.0),
  (_step, 0.0, 0.55),
  (_step, _step, 1.0),
  (0.0, _step, 0.55),
];

// The site's @keyframes hop, as (time, rise in dots, x scale, y scale): up and
// stretched at 16%, landed and squashed at 30%, still from 40%. Each dot runs
// it every 1.6 s, 0.2 s after the one before.
const _hop = [
  (0.0, 0.0, 1.0, 1.0),
  (0.16, -0.38, 0.94, 1.06),
  (0.30, 0.0, 1.12, 0.88),
  (0.40, 0.0, 1.0, 1.0),
];
const _hopEase = Cubic(0.22, 1, 0.36, 1); // --ease-out

Matrix4 _hopAt(double t) {
  for (var k = 1; k < _hop.length; k++) {
    final (t1, y1, sx1, sy1) = _hop[k];
    if (t >= t1) continue;
    final (t0, y0, sx0, sy0) = _hop[k - 1];
    final s = _hopEase.transform((t - t0) / (t1 - t0));
    return Matrix4.diagonal3Values(
      lerpDouble(sx0, sx1, s)!,
      lerpDouble(sy0, sy1, s)!,
      1,
    )..setTranslationRaw(0, lerpDouble(y0, y1, s)! * _dot, 0);
  }
  return Matrix4.identity();
}

class Splash extends StatefulWidget {
  const Splash({super.key, required this.onRetry});

  final VoidCallback onRetry;

  @override
  State<Splash> createState() => _SplashState();
}

class _SplashState extends State<Splash> with SingleTickerProviderStateMixin {
  late final _clock = AnimationController(
    vsync: this,
    duration: const Duration(milliseconds: 1600),
  );
  late final Timer _hopTimer;
  late final Timer _wordsTimer;
  late Timer _helpTimer;
  bool _hopping = false;
  bool _words = false;
  bool _help = false;

  @override
  void initState() {
    super.initState();
    _hopTimer = Timer(hopFrom, () {
      _hopping = true;
      _syncHop();
    });
    _wordsTimer = Timer(wordsFrom, () => setState(() => _words = true));
    _startHelp();
  }

  // With the system's reduce-motion setting the dots stay still.
  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    _syncHop();
  }

  void _syncHop() {
    if (!_hopping || MediaQuery.disableAnimationsOf(context)) {
      _clock.reset();
    } else if (!_clock.isAnimating) {
      _clock.repeat();
    }
  }

  void _startHelp() =>
      _helpTimer = Timer(helpFrom, () => setState(() => _help = true));

  void _retry() {
    _helpTimer.cancel();
    setState(() => _help = false);
    _startHelp();
    widget.onRetry();
  }

  @override
  void dispose() {
    _hopTimer.cancel();
    _wordsTimer.cancel();
    _helpTimer.cancel();
    _clock.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const words = TextStyle(
      color: _ink,
      fontSize: 18,
      fontWeight: FontWeight.w600,
    );
    const help = TextStyle(color: _ink, fontSize: 15);
    return Material(
      color: _splashColor(MediaQuery.platformBrightnessOf(context)),
      // Equal room above and below keeps the dots where the launch image has them.
      child: Column(
        children: [
          const Spacer(),
          Semantics(
            image: true,
            label: 'Daily Dose of Play',
            child: SizedBox.square(
              dimension: _step + _dot,
              child: Stack(
                children: [
                  for (final (i, (x, y, opacity)) in _dots.indexed)
                    Positioned(
                      left: x,
                      top: y,
                      child: AnimatedBuilder(
                        animation: _clock,
                        builder: (context, child) => Transform(
                          key: ValueKey('dot$i'),
                          alignment: Alignment.center,
                          transform: _hopAt((_clock.value - i / 8) % 1),
                          child: child,
                        ),
                        child: Opacity(
                          opacity: opacity,
                          child: const DecoratedBox(
                            decoration: BoxDecoration(
                              color: _ink,
                              shape: BoxShape.circle,
                            ),
                            child: SizedBox.square(dimension: _dot),
                          ),
                        ),
                      ),
                    ),
                ],
              ),
            ),
          ),
          Expanded(
            child: SafeArea(
              top: false,
              child: SingleChildScrollView(
                padding: const EdgeInsets.fromLTRB(32, 40, 32, 16),
                child: Column(
                  children: [
                    if (_words)
                      Semantics(
                        liveRegion: true,
                        child: const Text(
                          'Opening the games',
                          style: words,
                          textAlign: TextAlign.center,
                        ),
                      ),
                    if (_help) ...[
                      const SizedBox(height: 10),
                      Semantics(
                        liveRegion: true,
                        child: const Text(
                          'Taking a while? Check your connection or try again.',
                          style: help,
                          textAlign: TextAlign.center,
                        ),
                      ),
                      const SizedBox(height: 8),
                      OutlinedButton(
                        onPressed: _retry,
                        style: OutlinedButton.styleFrom(
                          foregroundColor: _ink,
                          side: const BorderSide(color: _ink),
                        ),
                        child: const Text('Try again'),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

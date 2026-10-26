import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:share_plus/share_plus.dart';

// The app's side of the website's engine/native.js. The page posts one JSON
// message per call on the DDPApp channel:
//
//   { type: "share", text, url }   the phone's share sheet
//   { type: "haptic", kind }       "light", "medium" or "heavy"
//
// Anything else is ignored, so a newer site never breaks an older app.
class Bridge {
  const Bridge({this.share = _share, this.haptic = _haptic});

  static const channel = 'DDPApp';

  final Future<void> Function(String text) share;
  final Future<void> Function(String kind) haptic;

  void receive(String message) {
    final Object? data;
    try {
      data = jsonDecode(message);
    } on FormatException {
      return;
    }
    if (data is! Map) return;
    switch (data['type']) {
      case 'share':
        final text = [data['text'], data['url']].whereType<String>().join(' ');
        if (text.isNotEmpty) share(text);
      case 'haptic':
        final kind = data['kind'];
        haptic(kind is String ? kind : 'light');
    }
  }
}

Future<void> _share(String text) =>
    SharePlus.instance.share(ShareParams(text: text));

Future<void> _haptic(String kind) => switch (kind) {
  'heavy' => HapticFeedback.heavyImpact(),
  'medium' => HapticFeedback.mediumImpact(),
  _ => HapticFeedback.lightImpact(),
};

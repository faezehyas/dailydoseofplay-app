import 'package:dailydoseofplay/bridge.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late List<String> shared;
  late List<String> haptics;
  late Bridge bridge;

  setUp(() {
    shared = [];
    haptics = [];
    bridge = Bridge(
      share: (text) async => shared.add(text),
      haptic: (kind) async => haptics.add(kind),
    );
  });

  test('share sends the text and the link to the share sheet', () {
    bridge.receive(
      '{"type":"share","text":"Play Ludo with me!","url":"https://www.dailydoseofplay.com/ludo/?room=ABCD"}',
    );
    expect(shared, [
      'Play Ludo with me! https://www.dailydoseofplay.com/ludo/?room=ABCD',
    ]);
  });

  test('haptic passes its kind on, light by default', () {
    bridge.receive('{"type":"haptic","kind":"heavy"}');
    bridge.receive('{"type":"haptic"}');
    expect(haptics, ['heavy', 'light']);
  });

  test('anything else is ignored', () {
    for (final message in [
      'not json',
      '[1]',
      '{"type":"wave"}',
      '{"type":"share"}',
    ]) {
      bridge.receive(message);
    }
    expect(shared, isEmpty);
    expect(haptics, isEmpty);
  });
}

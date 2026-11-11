import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:auri/features/read_aloud/data/incoming_text.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  const channel = MethodChannel('auri/incoming_text');
  final messenger =
      TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;

  tearDown(() => messenger.setMockMethodCallHandler(channel, null));

  test('delivers text waiting from launch', () async {
    messenger.setMockMethodCallHandler(channel, (call) async {
      expect(call.method, 'takeText');
      return 'Hello from Chrome';
    });
    final got = <String>[];
    await IncomingText().listen((text, _) => got.add(text));
    expect(got, ['Hello from Chrome']);
  });

  test('preserves the sender’s subject when provided', () async {
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => {'text': 'A shared article', 'subject': ' Article title '},
    );
    final got = <(String, String?)>[];
    await IncomingText().listen((text, title) => got.add((text, title)));
    expect(got, [('A shared article', 'Article title')]);
  });

  test('ignores empty or missing text', () async {
    final replies = [null, '   '];
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => replies.removeAt(0),
    );
    final got = <String>[];
    final incoming = IncomingText();
    await incoming.listen((text, _) => got.add(text));
    await incoming.listen((text, _) => got.add(text));
    expect(got, isEmpty);
  });

  test('pulls again when the app is told new text arrived', () async {
    final replies = <String?>[null, 'Second selection'];
    messenger.setMockMethodCallHandler(
      channel,
      (_) async => replies.removeAt(0),
    );
    final got = <String>[];
    await IncomingText().listen((text, _) => got.add(text));
    await messenger.handlePlatformMessage(
      channel.name,
      channel.codec.encodeMethodCall(const MethodCall('textAvailable')),
      (_) {},
    );
    await Future<void>.delayed(Duration.zero);
    expect(got, ['Second selection']);
  });
}

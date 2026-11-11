import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Text another Android app shared to Auri. See `MainActivity.kt`.
/// ("Read aloud" in the selection menu doesn't come here: it reads natively,
/// see `ReadAloudActivity.kt`.)
class IncomingText {
  IncomingText({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('auri/incoming_text');

  final MethodChannel _channel;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Calls [onText] with any text waiting from launch, and again for each
  /// selection sent while the app is running.
  Future<void> listen(
    void Function(String text, String? subject) onText,
  ) async {
    if (!supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'textAvailable') await _take(onText);
    });
    await _take(onText);
  }

  void dispose() {
    if (supported) _channel.setMethodCallHandler(null);
  }

  Future<void> _take(void Function(String text, String? subject) onText) async {
    try {
      final payload = await _channel.invokeMethod<Object?>('takeText');
      final text = payload is Map ? payload['text'] : payload;
      final subject = payload is Map ? payload['subject'] : null;
      if (text is String && text.trim().isNotEmpty) {
        onText(
          text,
          subject is String && subject.trim().isNotEmpty
              ? subject.trim()
              : null,
        );
      }
    } on PlatformException {
      // Nothing to read; the reader just opens as usual.
    } on MissingPluginException {
      // Not wired up on this platform.
    }
  }
}

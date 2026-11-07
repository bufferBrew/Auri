import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';

/// Text another Android app sent to Voxen, from its text-selection menu
/// ("Read with Voxen") or the Share sheet. See `MainActivity.kt`.
class IncomingText {
  IncomingText({MethodChannel? channel})
    : _channel = channel ?? const MethodChannel('voxen/incoming_text');

  final MethodChannel _channel;

  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  /// Calls [onText] with any text waiting from launch, and again for each
  /// selection sent while the app is running.
  Future<void> listen(void Function(String text) onText) async {
    if (!supported) return;
    _channel.setMethodCallHandler((call) async {
      if (call.method == 'textAvailable') await _take(onText);
    });
    await _take(onText);
  }

  void dispose() {
    if (supported) _channel.setMethodCallHandler(null);
  }

  Future<void> _take(void Function(String text) onText) async {
    try {
      final text = await _channel.invokeMethod<String>('takeText');
      if (text != null && text.trim().isNotEmpty) onText(text);
    } on PlatformException {
      // Nothing to read; the reader just opens as usual.
    } on MissingPluginException {
      // Not wired up on this platform.
    }
  }
}

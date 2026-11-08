import 'dart:convert';
import 'dart:typed_data';
import 'package:http/http.dart' as http;
import 'features/read_aloud/domain/text_chunk.dart';
import 'mp3.dart';

class SpeechException implements Exception {
  const SpeechException(this.message);
  final String message;
  @override
  String toString() => message;
}

/// A user-supplied key is sent only to the explicitly configured HTTPS endpoint.
/// No keys, input text, response bodies or headers are logged or persisted.
class SpeechApi {
  SpeechApi(this.client);
  final http.Client client;

  Future<Uint8List> generate({
    required String text,
    required String endpoint,
    required String apiKey,
    required String model,
    required String voice,
    double speed = 1,
    void Function(int, int)? onProgress,
  }) async {
    final uri = _checkEndpoint(endpoint);
    if (apiKey.trim().isEmpty || model.trim().isEmpty || voice.trim().isEmpty) {
      throw const SpeechException('Enter your API key, model, and voice.');
    }
    if (text.trim().isEmpty) {
      throw const SpeechException('Add some text first.');
    }
    final chunks = chunkText(text);
    final parts = <Uint8List>[];
    for (var i = 0; i < chunks.length; i++) {
      onProgress?.call(i, chunks.length);
      final request = http.Request('POST', uri)
        ..followRedirects = false
        ..headers.addAll({
          'Authorization': 'Bearer ${apiKey.trim()}',
          'Content-Type': 'application/json',
        })
        ..body = jsonEncode({
          'model': model.trim(),
          'voice': voice.trim(),
          'input': chunks[i].text,
          'response_format': 'mp3',
          'speed': speed,
        });
      final response = await (() async {
        final streamed = await client.send(request);
        return http.Response.fromStream(streamed);
      })().timeout(const Duration(seconds: 90));
      if (response.statusCode != 200) {
        final message = switch (response.statusCode) {
          401 ||
          403 => 'The provider rejected this API key or its permissions.',
          429 => 'The provider rate limit or account quota was reached.',
          >= 300 && < 400 =>
            'The endpoint redirected the request. Enter its final HTTPS address.',
          _ =>
            'Speech generation failed (HTTP ${response.statusCode}). Check your endpoint, model, and voice.',
        };
        throw SpeechException(message);
      }
      if (!_isMp3(response.bodyBytes)) {
        throw const SpeechException(
          'The provider did not return MP3 audio. Check its speech settings.',
        );
      }
      parts.add(response.bodyBytes);
    }
    onProgress?.call(chunks.length, chunks.length);
    return concatMp3(parts);
  }

  /// Voice ids from an OpenAI-compatible server's `/audio/voices`, next to the
  /// speech endpoint. Kokoro-FastAPI has it; OpenAI itself does not.
  Future<List<String>> voices({
    required String endpoint,
    required String apiKey,
  }) async {
    final speech = _checkEndpoint(endpoint);
    if (apiKey.trim().isEmpty) {
      throw const SpeechException('Enter your key first.');
    }
    if (!speech.path.endsWith('/audio/speech')) {
      throw const SpeechException(
        'This endpoint has no voice list. Type a voice instead.',
      );
    }
    final uri = speech.replace(
      path: speech.path.replaceFirst(
        RegExp(r'/audio/speech$'),
        '/audio/voices',
      ),
    );
    final request = http.Request('GET', uri)
      ..followRedirects = false
      ..headers['Authorization'] = 'Bearer ${apiKey.trim()}';
    final response = await (() async {
      final streamed = await client.send(request);
      return http.Response.fromStream(streamed);
    })().timeout(const Duration(seconds: 20));
    if (response.statusCode == 401 || response.statusCode == 403) {
      throw const SpeechException('The server rejected this key.');
    }
    if (response.statusCode != 200) {
      throw SpeechException(
        'Could not load voices (HTTP ${response.statusCode}). Type a voice instead.',
      );
    }
    try {
      final body = jsonDecode(response.body);
      final list = body is Map ? body['voices'] : null;
      // Older Kokoro releases list bare ids; newer ones list `{ id, … }`.
      final ids = <String>[
        for (final v in list is List ? list : const [])
          if (v is String)
            v
          else if (v is Map && v['id'] is String)
            v['id'] as String,
      ]..sort();
      if (ids.isEmpty) throw const FormatException();
      return ids;
    } on FormatException {
      throw const SpeechException(
        'The server sent no voice list. Type a voice instead.',
      );
    }
  }

  Uri _checkEndpoint(String endpoint) {
    final uri = Uri.tryParse(endpoint.trim());
    if (uri == null ||
        uri.scheme != 'https' ||
        uri.host.isEmpty ||
        uri.userInfo.isNotEmpty ||
        uri.hasQuery ||
        uri.hasFragment) {
      throw const SpeechException(
        'Enter an HTTPS speech endpoint without credentials or query parameters.',
      );
    }
    return uri;
  }

  bool _isMp3(Uint8List b) =>
      b.length >= 3 &&
      ((b[0] == 0x49 && b[1] == 0x44 && b[2] == 0x33) ||
          (b[0] == 0xff && (b[1] & 0xe0) == 0xe0));
}

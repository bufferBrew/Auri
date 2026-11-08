/// Ready-made settings for the API voice.
///
/// Kokoro is a self-hosted Kokoro-FastAPI server (the one Synapse reads aloud
/// with), which speaks the same OpenAI speech contract. Its address is a
/// build-time define so this public repo names no one's server:
///
///     flutter build apk --dart-define=KOKORO_URL=https://<host>
///
/// The token is never a define: it is entered at runtime like any API key.
enum SpeechPreset { openai, kokoro, custom }

const kokoroUrl = String.fromEnvironment('KOKORO_URL');

class PresetSettings {
  const PresetSettings({
    required this.label,
    required this.endpoint,
    required this.model,
    required this.voice,
    required this.keyLabel,
  });
  final String label;
  final String endpoint;
  final String model;
  final String voice;
  final String keyLabel;
}

PresetSettings presetSettings(SpeechPreset preset) => switch (preset) {
  SpeechPreset.openai => const PresetSettings(
    label: 'OpenAI',
    endpoint: 'https://api.openai.com/v1/audio/speech',
    model: 'tts-1',
    voice: 'alloy',
    keyLabel: 'API key',
  ),
  SpeechPreset.kokoro => PresetSettings(
    label: 'Kokoro',
    endpoint: kokoroUrl.isEmpty ? '' : kokoroSpeechEndpoint(kokoroUrl),
    model: 'kokoro',
    voice: 'af_heart',
    keyLabel: 'Kokoro token',
  ),
  SpeechPreset.custom => const PresetSettings(
    label: 'Custom',
    endpoint: '',
    model: '',
    voice: '',
    keyLabel: 'API key',
  ),
};

/// `https://host` or `https://host/` → `https://host/v1/audio/speech`; a full
/// speech endpoint is kept as it is.
String kokoroSpeechEndpoint(String base) {
  final trimmed = base.trim().replaceAll(RegExp(r'/+$'), '');
  return trimmed.endsWith('/v1/audio/speech')
      ? trimmed
      : '$trimmed/v1/audio/speech';
}

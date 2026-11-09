/// Ready-made settings for the "Other API" mode, and Kokoro's address.
///
/// Kokoro is a self-hosted Kokoro-FastAPI server (the one Synapse reads aloud
/// with), which speaks the same OpenAI speech contract. Its default address is
/// a build-time define so this public repo names no one's server:
///
///     flutter build apk --dart-define=KOKORO_URL=https://<host>
///
/// It can also be typed in Settings. The token is never a define: it is
/// entered at runtime, and kept on the device only if the user asks.
enum SpeechPreset { openai, custom }

const kokoroDefaultUrl = String.fromEnvironment('KOKORO_URL');
const kokoroModel = 'kokoro';
const kokoroDefaultVoice = 'af_heart';

class PresetSettings {
  const PresetSettings({
    required this.label,
    required this.endpoint,
    required this.model,
    required this.voice,
  });
  final String label;
  final String endpoint;
  final String model;
  final String voice;
}

PresetSettings presetSettings(SpeechPreset preset) => switch (preset) {
  SpeechPreset.openai => const PresetSettings(
    label: 'OpenAI',
    endpoint: 'https://api.openai.com/v1/audio/speech',
    model: 'tts-1',
    voice: 'alloy',
  ),
  SpeechPreset.custom => const PresetSettings(
    label: 'Custom',
    endpoint: '',
    model: '',
    voice: '',
  ),
};

/// `https://host` or `https://host/` → `https://host/v1/audio/speech`; a full
/// speech endpoint is kept as it is. Empty stays empty.
String kokoroSpeechEndpoint(String base) {
  final trimmed = base.trim().replaceAll(RegExp(r'/+$'), '');
  if (trimmed.isEmpty) return '';
  return trimmed.endsWith('/v1/audio/speech')
      ? trimmed
      : '$trimmed/v1/audio/speech';
}

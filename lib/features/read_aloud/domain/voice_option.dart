class VoiceOption {
  const VoiceOption(this.id);

  final String id;

  static const Map<String, String> _accents = <String, String>{
    'a': 'American',
    'b': 'British',
    'e': 'Spanish',
    'f': 'French',
    'h': 'Hindi',
    'i': 'Italian',
    'j': 'Japanese',
    'p': 'Portuguese',
    'z': 'Mandarin',
  };

  /// Kokoro's English voices; the others need text in their own language.
  bool get isEnglish => id.startsWith('a') || id.startsWith('b');

  String get accent => _accents[id.isEmpty ? '' : id[0]] ?? 'Other';

  String get gender => id.length > 1 && id[1] == 'm' ? 'male' : 'female';

  String get name {
    final int underscore = id.indexOf('_');
    final String raw = underscore < 0 ? id : id.substring(underscore + 1);
    return raw.isEmpty ? id : '${raw[0].toUpperCase()}${raw.substring(1)}';
  }

  String get label => '$name · $accent $gender';
}

import 'dart:typed_data';

/// Joins MP3 chunks into one file.
///
/// MP3 is a stream of self-contained frames, so files can be concatenated
/// byte for byte. Only a leading ID3v2 tag on the later parts is cut — a tag
/// mid-stream is harmless to most players but trips a few, and tells the
/// listener nothing.
Uint8List concatMp3(List<Uint8List> parts) {
  final BytesBuilder out = BytesBuilder(copy: false);
  for (int i = 0; i < parts.length; i++) {
    final Uint8List p = parts[i];
    out.add(i == 0 ? p : Uint8List.sublistView(p, _id3Length(p)));
  }
  return out.takeBytes();
}

/// Length of a leading ID3v2 tag (header + syncsafe size), or 0.
int _id3Length(Uint8List b) {
  if (b.length < 10 || b[0] != 0x49 || b[1] != 0x44 || b[2] != 0x33) return 0;
  final int size =
      (b[6] & 0x7f) << 21 |
      (b[7] & 0x7f) << 14 |
      (b[8] & 0x7f) << 7 |
      (b[9] & 0x7f);
  final bool footer = (b[5] & 0x10) != 0;
  final int total = 10 + size + (footer ? 10 : 0);
  return total <= b.length ? total : 0;
}

/// A file name from a title: "Why HTTPS works?" → "Why HTTPS works.mp3".
String mp3FileName(String title) {
  final String safe = title
      .replaceAll(RegExp(r'[\\/:*?"<>|\n\r\t]+'), ' ')
      .replaceAll(RegExp(r'\s+'), ' ')
      .trim();
  final String stem = safe.isEmpty
      ? 'Reading'
      : safe.length > 60
      ? safe.substring(0, 60).trim()
      : safe;
  return '$stem.mp3';
}

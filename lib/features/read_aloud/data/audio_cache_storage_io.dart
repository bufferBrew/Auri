import 'dart:io';

import 'package:path_provider/path_provider.dart';

class AudioCacheStorage {
  AudioCacheStorage({this.cachePath});

  final Future<String> Function()? cachePath;

  // Includes the base64 encoding and timing metadata.
  static const _limit = 48 * 1024 * 1024;

  Future<Directory> _directory() async {
    final root =
        await (cachePath?.call() ??
            getApplicationCacheDirectory().then((dir) => dir.path));
    return Directory('$root/read-aloud-v1');
  }

  Future<String?> read(String key) async {
    final dir = await _directory();
    final file = File('${dir.path}/$key');
    if (!await file.exists()) return null;
    final data = await file.readAsString();
    await file.setLastModified(DateTime.now());
    return data;
  }

  Future<void> write(String key, String data) async {
    if (data.length > _limit) return;
    final dir = await _directory();
    await dir.create(recursive: true);
    final file = File('${dir.path}/$key');
    final temp = File('${dir.path}/$key.tmp');
    await temp.writeAsString(data);
    await temp.rename(file.path);

    final entries = <({File file, FileStat stat})>[];
    var size = data.length;
    await for (final entry in dir.list(followLinks: false)) {
      if (entry is File && entry.path != file.path) {
        final stat = await entry.stat();
        size += stat.size;
        entries.add((file: entry, stat: stat));
      }
    }
    entries.sort((a, b) => a.stat.modified.compareTo(b.stat.modified));
    for (final entry in entries) {
      if (size <= _limit) break;
      await entry.file.delete();
      size -= entry.stat.size;
    }
  }

  Future<void> deleteReading(String id) async {
    final dir = await _directory();
    if (!await dir.exists()) return;
    await for (final file in dir.list(followLinks: false)) {
      if (file is File && file.uri.pathSegments.last.startsWith('$id-')) {
        await file.delete();
      }
    }
  }
}

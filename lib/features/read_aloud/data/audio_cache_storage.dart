import 'package:shared_preferences/shared_preferences.dart';

const _prefix = 'auri.audio-cache.';

class AudioCacheStorage {
  AudioCacheStorage({Future<String> Function()? cachePath});

  static const _limit = 1500000;

  Future<String?> read(String key) async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('$_prefix$key');
  }

  Future<void> write(String key, String data) async {
    if (data.length > _limit) return;
    final prefs = await SharedPreferences.getInstance();
    final storageKey = '$_prefix$key';
    final keys =
        prefs
            .getKeys()
            .where((k) => k.startsWith(_prefix) && k != storageKey)
            .toList()
          ..sort(
            (a, b) =>
                (prefs.getString(a) ?? '').compareTo(prefs.getString(b) ?? ''),
          );
    var size =
        data.length +
        keys.fold(0, (sum, k) => sum + (prefs.getString(k)?.length ?? 0));
    for (final old in keys) {
      if (size <= _limit) break;
      size -= prefs.getString(old)?.length ?? 0;
      await prefs.remove(old);
    }
    await prefs.setString(storageKey, data);
  }

  Future<void> deleteReading(String id) async {
    final prefs = await SharedPreferences.getInstance();
    final keys = prefs.getKeys().where((key) => key.startsWith('$_prefix$id-'));
    for (final key in keys) {
      await prefs.remove(key);
    }
  }
}

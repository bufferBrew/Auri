import 'dart:async';
import 'dart:io';
import 'dart:isolate';

import 'package:archive/archive_io.dart';
import 'package:flutter/foundation.dart';
import 'package:http/http.dart' as http;
import 'package:path_provider/path_provider.dart';

import 'local_kokoro.dart';

enum LocalModelPhase { absent, downloading, unpacking, ready, failed }

@immutable
class LocalModelState {
  const LocalModelState(
    this.phase, {
    this.received = 0,
    this.total = 0,
    this.error,
  });
  final LocalModelPhase phase;
  final int received;
  final int total;
  final String? error;

  /// 0–1 while downloading with a known size, else null.
  double? get progress => phase == LocalModelPhase.downloading && total > 0
      ? received / total
      : null;
}

/// Downloads, unpacks, checks and deletes the on-device voice models.
///
/// Nothing is fetched on its own: a download only ever starts from
/// [download], which the UI calls after the user agrees to its size. A model
/// counts as installed only when every file it needs is on disk, so a
/// cancelled or failed download never leaves a half-model in use.
class LocalModels extends ChangeNotifier {
  LocalModels({
    Future<Directory> Function()? baseDir,
    http.Client Function()? client,
  }) : _baseDir = baseDir ?? _defaultBase,
       _client = client ?? http.Client.new;

  final Future<Directory> Function() _baseDir;
  final http.Client Function() _client;

  /// On-device synthesis ships for Android only.
  static bool get supported =>
      !kIsWeb && defaultTargetPlatform == TargetPlatform.android;

  static Future<Directory> _defaultBase() async =>
      Directory('${(await getApplicationSupportDirectory()).path}/models');

  final _states = {
    for (final m in LocalModel.values)
      m: const LocalModelState(LocalModelPhase.absent),
  };
  http.Client? _active;
  LocalModel? _activeModel;

  LocalModelState stateOf(LocalModel model) => _states[model]!;
  bool isReady(LocalModel model) =>
      _states[model]!.phase == LocalModelPhase.ready;

  /// The model to speak with: the full one if both are installed.
  LocalModel? get installed {
    for (final m in LocalModel.values) {
      if (isReady(m)) return m;
    }
    return null;
  }

  bool get busy => _activeModel != null;

  Future<String> dirOf(LocalModel model) async =>
      '${(await _baseDir()).path}/${model.folder}';

  void _set(LocalModel model, LocalModelState state) {
    _states[model] = state;
    notifyListeners();
  }

  /// Finds models already on disk.
  Future<void> refresh() async {
    for (final m in LocalModel.values) {
      if (_activeModel == m) continue;
      _states[m] = LocalModelState(
        await _complete(m) ? LocalModelPhase.ready : LocalModelPhase.absent,
      );
    }
    notifyListeners();
  }

  Future<bool> _complete(LocalModel model) async {
    try {
      final dir = await dirOf(model);
      for (final f in model.requiredFiles) {
        if (!await File('$dir/$f').exists()) return false;
      }
      return true;
    } catch (_) {
      return false;
    }
  }

  /// Downloads and unpacks [model]. One download at a time.
  Future<void> download(LocalModel model) async {
    if (busy || isReady(model)) return;
    _activeModel = model;
    final client = _client();
    _active = client;
    final base = await _baseDir();
    final archive = File('${base.path}/${model.folder}.tar.bz2.part');
    final dir = Directory('${base.path}/${model.folder}');
    _set(model, const LocalModelState(LocalModelPhase.downloading));
    try {
      await base.create(recursive: true);
      final response = await client.send(http.Request('GET', model.url));
      if (response.statusCode != 200) {
        throw HttpException(
          'The download failed (HTTP ${response.statusCode}).',
        );
      }
      final total = response.contentLength ?? model.downloadMb * 1024 * 1024;
      final sink = archive.openWrite();
      var received = 0, lastShown = 0;
      try {
        await for (final bytes in response.stream) {
          sink.add(bytes);
          received += bytes.length;
          // About every 1%, not every packet.
          if (received - lastShown > total ~/ 100) {
            lastShown = received;
            _set(
              model,
              LocalModelState(
                LocalModelPhase.downloading,
                received: received,
                total: total,
              ),
            );
          }
        }
      } finally {
        await sink.close();
      }
      if (_active != client) throw StateError('cancelled');
      _set(model, const LocalModelState(LocalModelPhase.unpacking));
      if (await dir.exists()) await dir.delete(recursive: true);
      final from = archive.path, to = base.path;
      // Unpacking a few hundred MB of bzip2 takes a while; keep it off the UI.
      await Isolate.run(() => extractFileToDisk(from, to, verify: true));
      if (!await _complete(model)) {
        throw const FileSystemException('The download is missing files.');
      }
      _set(model, const LocalModelState(LocalModelPhase.ready));
    } catch (e) {
      final cancelled = _active != client;
      await _cleanUp(dir);
      _set(
        model,
        cancelled
            ? const LocalModelState(LocalModelPhase.absent)
            : LocalModelState(LocalModelPhase.failed, error: _describe(e)),
      );
    } finally {
      client.close();
      if (await archive.exists()) await archive.delete();
      if (_active == client) _active = null;
      _activeModel = null;
      notifyListeners();
    }
  }

  /// Stops the download in progress and removes what it wrote.
  void cancel() {
    final client = _active;
    _active = null;
    client?.close();
  }

  /// Removes [model] from the phone.
  Future<void> delete(LocalModel model) async {
    if (_activeModel == model) return;
    await _cleanUp(Directory(await dirOf(model)));
    _set(model, const LocalModelState(LocalModelPhase.absent));
  }

  Future<void> _cleanUp(Directory dir) async {
    try {
      if (await dir.exists()) await dir.delete(recursive: true);
    } catch (_) {
      // Best effort; a later download replaces whatever is left.
    }
  }

  static String _describe(Object e) => switch (e) {
    HttpException(:final message) => message,
    SocketException() || http.ClientException() =>
      'No connection. Check you’re online and try again.',
    FileSystemException(:final osError?) when osError.errorCode == 28 =>
      'Not enough free space on the phone.',
    FileSystemException(:final message) => message,
    _ => 'The download couldn’t be unpacked. Try again.',
  };
}

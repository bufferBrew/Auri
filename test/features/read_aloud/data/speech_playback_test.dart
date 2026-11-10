import 'package:auri/features/read_aloud/data/speech_playback.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:just_audio/just_audio.dart';

class _SpeechPlayer implements AudioPlayer {
  @override
  bool playing = false;

  @override
  ProcessingState processingState = ProcessingState.ready;

  bool interrupt = false;
  int completedChunks = 0;

  @override
  Future<void> play() async {
    if (playing) return;
    if (interrupt) return;
    playing = true;
    processingState = ProcessingState.completed;
    completedChunks++;
  }

  @override
  Future<void> pause() async => playing = false;

  @override
  dynamic noSuchMethod(Invocation invocation) => super.noSuchMethod(invocation);
}

void main() {
  test('each new chunk gets its own completed play', () async {
    final player = _SpeechPlayer();

    expect(await playSpeechChunk(player), isTrue);
    player.processingState = ProcessingState.ready;
    expect(await playSpeechChunk(player), isTrue);
    expect(player.completedChunks, 2);
  });

  test('an interrupted chunk is never reported as complete', () async {
    final player = _SpeechPlayer()..interrupt = true;

    expect(await playSpeechChunk(player), isFalse);
    expect(player.completedChunks, 0);
  });
}

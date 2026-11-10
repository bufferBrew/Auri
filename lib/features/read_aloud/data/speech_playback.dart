import 'package:just_audio/just_audio.dart';

/// Waits for a loaded speech chunk to finish and resets the playing flag.
/// just_audio keeps that flag set at the end, so the next play call would
/// return immediately and allow the caller to replace audio still playing.
Future<bool> playSpeechChunk(AudioPlayer player) async {
  await player.play();
  if (player.processingState != ProcessingState.completed) return false;
  await player.pause();
  return true;
}

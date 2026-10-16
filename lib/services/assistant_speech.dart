import 'package:flutter/services.dart';
import 'package:flutter_tts/flutter_tts.dart';

abstract interface class AssistantSpeech {
  Future<void> say(String text);
  Future<void> stop();
}

class DeviceAssistantSpeech implements AssistantSpeech {
  FlutterTts? _tts;
  Future<bool>? _ready;
  int _generation = 0;

  Future<bool> _initialize() async {
    final tts = _tts ??= FlutterTts();
    if (await tts.isLanguageAvailable('zh-CN') != true) return false;
    await tts.setLanguage('zh-CN');
    await tts.setSpeechRate(0.48);
    await tts.setPitch(1.08);
    await tts.awaitSpeakCompletion(true);
    return true;
  }

  @override
  Future<void> say(String text) async {
    final generation = ++_generation;
    try {
      final ready = await (_ready ??= _initialize()).timeout(
        const Duration(seconds: 4),
      );
      if (generation != _generation) return;
      if (ready) {
        // The music is paused and wake-word capture is stopped by the caller.
        final result = await _tts!
            .speak(text)
            .timeout(const Duration(seconds: 6));
        if (result != 1 && generation == _generation) {
          await SystemSound.play(SystemSoundType.click);
        }
      } else {
        await SystemSound.play(SystemSoundType.click);
      }
    } catch (_) {
      _ready = null;
      try {
        await _tts?.stop().timeout(const Duration(seconds: 2));
      } catch (_) {
        /* Text feedback remains available. */
      }
      if (generation == _generation) {
        await SystemSound.play(SystemSoundType.click);
      }
    }
  }

  @override
  Future<void> stop() async {
    _generation++;
    await _tts?.stop().timeout(const Duration(seconds: 2));
  }
}

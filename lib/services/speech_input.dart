import 'package:speech_to_text/speech_to_text.dart';

abstract interface class SpeechInput {
  Future<bool> initialize({
    required void Function(String) onStatus,
    required void Function(String) onError,
  });
  Future<List<String>> locales();
  Future<void> listen({
    required String locale,
    required void Function(String, bool) onResult,
  });
  Future<void> stop();
  Future<void> cancel();
}

class DeviceSpeechInput implements SpeechInput {
  final SpeechToText _speech = SpeechToText();
  @override
  Future<bool> initialize({
    required void Function(String) onStatus,
    required void Function(String) onError,
  }) => _speech.initialize(
    onStatus: onStatus,
    onError: (error) => onError(error.errorMsg),
  );
  @override
  Future<List<String>> locales() async =>
      (await _speech.locales()).map((locale) => locale.localeId).toList();
  @override
  Future<void> listen({
    required String locale,
    required void Function(String, bool) onResult,
  }) async {
    await _speech.listen(
      onResult: (result) =>
          onResult(result.recognizedWords, result.finalResult),
      listenOptions: SpeechListenOptions(
        localeId: locale,
        listenMode: ListenMode.confirmation,
        partialResults: true,
        cancelOnError: true,
        listenFor: const Duration(seconds: 15),
        pauseFor: const Duration(seconds: 3),
      ),
    );
  }

  @override
  Future<void> stop() => _speech.stop();
  @override
  Future<void> cancel() => _speech.cancel();
}

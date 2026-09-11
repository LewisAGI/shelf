import 'package:speech_to_text/speech_to_text.dart';

class SpeechCapture {
  SpeechCapture({SpeechToText? speech}) : _speech = speech ?? SpeechToText();

  final SpeechToText _speech;

  bool available = false;
  bool initialised = false;
  String? unavailableReason;

  bool get isListening => _speech.isListening;

  Future<bool> ensureReady() async {
    if (initialised) {
      return available;
    }
    try {
      available = await _speech.initialize(
        onError: (error) {
          unavailableReason = error.errorMsg;
        },
        onStatus: (_) {},
      );
      initialised = true;
      if (!available) {
        unavailableReason ??=
            'Speech recognition is not available on this device.';
      }
    } on Object catch (error) {
      initialised = true;
      available = false;
      unavailableReason = error.toString();
    }
    return available;
  }

  Future<void> start({
    required void Function(String words, bool finalResult) onText,
  }) async {
    final ready = await ensureReady();
    if (!ready) {
      throw StateError(
        unavailableReason ?? 'Voice dictation is not available.',
      );
    }
    await _speech.listen(
      onResult: (result) {
        onText(result.recognizedWords, result.finalResult);
      },
      listenOptions: SpeechListenOptions(
        localeId: 'en_GB',
        partialResults: true,
        cancelOnError: true,
      ),
    );
  }

  Future<void> stop() => _speech.stop();

  Future<void> cancel() => _speech.cancel();
}

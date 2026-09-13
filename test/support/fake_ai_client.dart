import 'package:shelf/models/ai_provider.dart';
import 'package:shelf/services/ai_client.dart';

class FakeAiClient implements AiClient {
  FakeAiClient({
    this.verifyResult = const AiVerifyResult(
      ok: true,
      message: 'Connected. Models list looks good.',
    ),
    this.askReply = 'The passage is about method.',
    this.verifyError,
    this.askError,
  });

  AiVerifyResult verifyResult;
  String askReply;
  Object? verifyError;
  Object? askError;
  AiConnection? lastVerify;
  AiConnection? lastAskConnection;
  AiAskRequest? lastAsk;

  @override
  Future<AiVerifyResult> verify(AiConnection connection) async {
    lastVerify = connection;
    final error = verifyError;
    if (error != null) {
      if (error is AiClientException) {
        return AiVerifyResult(ok: false, message: error.message);
      }
      return AiVerifyResult(ok: false, message: error.toString());
    }
    return verifyResult;
  }

  @override
  Future<String> askAbout(
    AiConnection connection,
    AiAskRequest request,
  ) async {
    lastAskConnection = connection;
    lastAsk = request;
    final error = askError;
    if (error != null) {
      throw error;
    }
    return askReply;
  }
}

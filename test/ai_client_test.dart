import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';
import 'package:shelf/models/ai_provider.dart';
import 'package:shelf/services/ai_client.dart';
import 'package:shelf/services/ai_secure_storage.dart';
import 'package:shelf/services/ai_settings_controller.dart';

import 'support/fake_ai_client.dart';

const _fakeKey = 'sk-test-not-a-real-key';

AiConnection _openai() {
  return const AiConnection(
    provider: AiProvider.openai,
    baseUrl: 'https://api.openai.com/v1',
    model: 'gpt-4o-mini',
    apiKey: _fakeKey,
  );
}

void main() {
  group('HttpAiClient verify', () {
    test('OpenAI-compatible models.list success', () async {
      final client = HttpAiClient(
        httpClient: MockClient((request) async {
          expect(request.method, 'GET');
          expect(request.url.toString(), 'https://api.openai.com/v1/models');
          expect(request.headers['Authorization'], 'Bearer $_fakeKey');
          return http.Response(
            '{"data":[{"id":"gpt-4o-mini"},{"id":"gpt-4o"}]}',
            200,
          );
        }),
      );

      final result = await client.verify(_openai());
      expect(result.ok, isTrue);
      expect(result.message, contains('2 models'));
    });

    test('OpenAI-compatible 401 failure', () async {
      final client = HttpAiClient(
        httpClient: MockClient((request) async {
          return http.Response(
            '{"error":{"message":"Incorrect API key provided"}}',
            401,
          );
        }),
      );

      final result = await client.verify(_openai());
      expect(result.ok, isFalse);
      expect(result.message, contains('401'));
      expect(result.message, contains('Incorrect API key'));
    });

    test('falls back to a tiny chat completion when /models is 404', () async {
      final client = HttpAiClient(
        httpClient: MockClient((request) async {
          if (request.url.path.endsWith('/models')) {
            return http.Response('not found', 404);
          }
          expect(request.method, 'POST');
          expect(
            request.url.toString(),
            'https://api.openai.com/v1/chat/completions',
          );
          return http.Response(
            '{"choices":[{"message":{"content":"pong"}}]}',
            200,
          );
        }),
      );

      final result = await client.verify(_openai());
      expect(result.ok, isTrue);
      expect(result.message, contains('Chat completions'));
    });

    test('Anthropic models.list success and 403 failure', () async {
      var calls = 0;
      final client = HttpAiClient(
        httpClient: MockClient((request) async {
          calls += 1;
          expect(request.url.toString(), 'https://api.anthropic.com/v1/models');
          expect(request.headers['x-api-key'], _fakeKey);
          expect(request.headers['anthropic-version'], isNotEmpty);
          if (calls == 1) {
            return http.Response('{"data":[{"id":"claude-sonnet-4-5"}]}', 200);
          }
          return http.Response('{"error":{"message":"forbidden"}}', 403);
        }),
      );
      final anthropic = const AiConnection(
        provider: AiProvider.anthropic,
        baseUrl: 'https://api.anthropic.com',
        model: 'claude-sonnet-4-5',
        apiKey: _fakeKey,
      );

      final ok = await client.verify(anthropic);
      expect(ok.ok, isTrue);
      expect(ok.message, contains('1 models'));

      final fail = await client.verify(anthropic);
      expect(fail.ok, isFalse);
      expect(fail.message, contains('403'));
    });

    test('missing key fails without hitting the network', () async {
      var hits = 0;
      final client = HttpAiClient(
        httpClient: MockClient((request) async {
          hits += 1;
          return http.Response('nope', 500);
        }),
      );
      final result = await client.verify(
        const AiConnection(
          provider: AiProvider.openai,
          baseUrl: 'https://api.openai.com/v1',
          model: 'gpt-4o-mini',
          apiKey: '',
        ),
      );
      expect(result.ok, isFalse);
      expect(result.message, contains('API key'));
      expect(hits, 0);
    });
  });

  group('HttpAiClient askAbout', () {
    test('sends note text and selected_text to OpenAI chat', () async {
      late String body;
      final client = HttpAiClient(
        httpClient: MockClient((request) async {
          body = request.body;
          expect(
            request.url.toString(),
            'https://api.openai.com/v1/chat/completions',
          );
          return http.Response(
            '{"choices":[{"message":{"content":"Here is a reading of the note."}}]}',
            200,
          );
        }),
      );

      final reply = await client.askAbout(
        _openai(),
        const AiAskRequest(
          noteText: 'Come back to the method section.',
          selectedText: 'method',
          documentTitle: 'Notes on method',
          page: 2,
        ),
      );

      expect(reply.reply, 'Here is a reading of the note.');
      expect(body, contains('Come back to the method section.'));
      expect(body, contains('method'));
      expect(body, contains('Notes on method'));
      expect(body, contains('Page: 2'));
      expect(body, isNot(contains(_fakeKey)));
    });

    test('Grok uses the OpenAI-compatible xAI host', () async {
      late String body;
      final client = HttpAiClient(
        httpClient: MockClient((request) async {
          body = request.body;
          expect(request.url.toString(), 'https://api.x.ai/v1/chat/completions');
          expect(request.headers['Authorization'], 'Bearer $_fakeKey');
          return http.Response(
            '{"choices":[{"message":{"content":"Grok reply"}}]}',
            200,
          );
        }),
      );
      final grok = const AiConnection(
        provider: AiProvider.grok,
        baseUrl: 'https://api.x.ai/v1',
        model: 'grok-4.6',
        apiKey: _fakeKey,
      );

      final outcome = await client.askAbout(
        grok,
        const AiAskRequest(noteText: 'What is this saying?'),
      );
      expect(outcome.reply, 'Grok reply');
      expect(body, contains('What is this saying?'));
      expect(body, isNot(contains(_fakeKey)));
    });

    test('skips a Grok PDF attachment and still sends the notes', () async {
      late String body;
      final client = HttpAiClient(
        httpClient: MockClient((request) async {
          body = request.body;
          return http.Response(
            '{"choices":[{"message":{"content":"Notes only reply"}}]}',
            200,
          );
        }),
      );
      final grok = const AiConnection(
        provider: AiProvider.grok,
        baseUrl: 'https://api.x.ai/v1',
        model: 'grok-4.6',
        apiKey: _fakeKey,
      );
      final outcome = await client.askAbout(
        grok,
        AiAskRequest(
          noteText: 'Whole book',
          documentTitle: 'Notes on method',
          notes: const [
            AiNoteSnippet(text: 'First', page: 1),
            AiNoteSnippet(text: 'Second', page: 2),
          ],
          pdfBytes: [1, 2, 3, 4],
          pdfFileName: 'notes.pdf',
        ),
      );
      expect(outcome.reply, 'Notes only reply');
      expect(outcome.pdfNotice, contains('xAI'));
      expect(body, isNot(contains('file_data')));
      expect(body, contains('The PDF could not be attached'));
    });

    test('Anthropic attaches a PDF document block', () async {
      late String body;
      final client = HttpAiClient(
        httpClient: MockClient((request) async {
          body = request.body;
          return http.Response(
            '{"content":[{"type":"text","text":"With PDF"}]}',
            200,
          );
        }),
      );
      final outcome = await client.askAbout(
        const AiConnection(
          provider: AiProvider.anthropic,
          baseUrl: 'https://api.anthropic.com',
          model: 'claude-sonnet-4-5',
          apiKey: _fakeKey,
        ),
        AiAskRequest(
          noteText: 'Look at the figure.',
          pdfBytes: [37, 80, 68, 70],
          pdfFileName: 'book.pdf',
        ),
      );
      expect(outcome.reply, 'With PDF');
      expect(outcome.pdfNotice, isNull);
      expect(body, contains('"type":"document"'));
      expect(body, contains('application/pdf'));
    });

    test('Anthropic messages success and HTTP failure', () async {
      var calls = 0;
      final client = HttpAiClient(
        httpClient: MockClient((request) async {
          calls += 1;
          expect(request.url.toString(), 'https://api.anthropic.com/v1/messages');
          if (calls == 1) {
            return http.Response(
              '{"content":[{"type":"text","text":"Anthropic reply"}]}',
              200,
            );
          }
          return http.Response('{"error":{"message":"overloaded"}}', 529);
        }),
      );
      final anthropic = const AiConnection(
        provider: AiProvider.anthropic,
        baseUrl: 'https://api.anthropic.com',
        model: 'claude-sonnet-4-5',
        apiKey: _fakeKey,
      );
      final request = const AiAskRequest(noteText: 'What is this saying?');

      expect((await client.askAbout(anthropic, request)).reply, 'Anthropic reply');
      expect(
        () => client.askAbout(anthropic, request),
        throwsA(isA<AiClientException>()),
      );
    });
  });

  group('AiSettingsController verify wiring', () {
    test('success and failure paths update status', () async {
      final fake = FakeAiClient();
      final controller = AiSettingsController(
        storage: MemoryAiSecureStorage(),
        client: fake,
      );
      await controller.load();
      await controller.saveApiKey(_fakeKey);

      fake.verifyResult = const AiVerifyResult(
        ok: true,
        message: 'Connected. Provider listed 3 models.',
      );
      final ok = await controller.verify();
      expect(ok.ok, isTrue);
      expect(controller.lastVerifyOk, isTrue);
      expect(controller.status, contains('3 models'));
      expect(fake.lastVerify?.apiKey, _fakeKey);

      fake.verifyResult = const AiVerifyResult(
        ok: false,
        message: 'HTTP 401: Incorrect API key provided',
      );
      final fail = await controller.verify();
      expect(fail.ok, isFalse);
      expect(controller.lastVerifyOk, isFalse);
      expect(controller.status, contains('401'));
    });
  });
}

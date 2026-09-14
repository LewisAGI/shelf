import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/models/ai_provider.dart';
import 'package:shelf/services/ai_secure_storage.dart';
import 'package:shelf/services/ai_settings_controller.dart';

import 'support/fake_ai_client.dart';

void main() {
  test('persists provider, endpoint, model, and key in secure storage', () async {
    final storage = MemoryAiSecureStorage();
    final controller = AiSettingsController(
      storage: storage,
      client: FakeAiClient(),
    );

    await controller.load();
    expect(controller.provider, AiProvider.openai);
    expect(controller.hasApiKey, isFalse);
    expect(
      storage.snapshot.containsKey(
        AiSettingsController.apiKeyStorageKey(AiProvider.openai),
      ),
      isFalse,
    );

    await controller.setProvider(AiProvider.openaiCompatible);
    await controller.setBaseUrl('https://example.com/v1');
    await controller.setModel('local-llama');
    await controller.saveApiKey('sk-test-not-a-real-key');

    expect(storage.snapshot[AiSettingsController.providerKey], 'openaiCompatible');
    expect(
      storage.snapshot[AiSettingsController.baseUrlStorageKey(
        AiProvider.openaiCompatible,
      )],
      'https://example.com/v1',
    );
    expect(
      storage.snapshot[AiSettingsController.modelStorageKey(
        AiProvider.openaiCompatible,
      )],
      'local-llama',
    );
    expect(
      storage.snapshot[AiSettingsController.apiKeyStorageKey(
        AiProvider.openaiCompatible,
      )],
      'sk-test-not-a-real-key',
    );
    expect(controller.hasApiKey, isTrue);
    expect(controller.connection.apiKey, 'sk-test-not-a-real-key');

    final reloaded = AiSettingsController(
      storage: storage,
      client: FakeAiClient(),
    );
    await reloaded.load();
    expect(reloaded.provider, AiProvider.openaiCompatible);
    expect(reloaded.baseUrl, 'https://example.com/v1');
    expect(reloaded.model, 'local-llama');
    expect(reloaded.hasApiKey, isTrue);
    expect(reloaded.connection.apiKey, 'sk-test-not-a-real-key');
  });

  test('clearing the key deletes it from secure storage', () async {
    final storage = MemoryAiSecureStorage({
      AiSettingsController.apiKeyStorageKey(AiProvider.openai):
          'sk-test-not-a-real-key',
    });
    final controller = AiSettingsController(
      storage: storage,
      client: FakeAiClient(),
    );
    await controller.load();
    expect(controller.hasApiKey, isTrue);

    await controller.clearApiKey();
    expect(controller.hasApiKey, isFalse);
    expect(
      storage.snapshot.containsKey(
        AiSettingsController.apiKeyStorageKey(AiProvider.openai),
      ),
      isFalse,
    );
  });

  test('OpenAI, Anthropic, and Grok presets fill endpoint and model', () async {
    final controller = AiSettingsController(
      storage: MemoryAiSecureStorage(),
      client: FakeAiClient(),
    );
    await controller.load();
    expect(controller.baseUrl, 'https://api.openai.com/v1');
    expect(controller.model, 'gpt-4o-mini');

    await controller.setProvider(AiProvider.anthropic);
    expect(controller.baseUrl, 'https://api.anthropic.com');
    expect(controller.model, 'claude-sonnet-4-5');

    await controller.setProvider(AiProvider.grok);
    expect(controller.baseUrl, 'https://api.x.ai/v1');
    expect(controller.model, 'grok-4.6');
    expect(controller.provider.usesOpenAiCompatibleApi, isTrue);
  });

  test('switching provider keeps each key and model', () async {
    final storage = MemoryAiSecureStorage();
    final controller = AiSettingsController(
      storage: storage,
      client: FakeAiClient(),
    );
    await controller.load();

    await controller.saveApiKey('sk-ant-test-not-real');
    await controller.setModel('claude-sonnet-4-5');
    await controller.setProvider(AiProvider.anthropic);
    await controller.saveApiKey('sk-ant-test-not-real');
    await controller.setModel('claude-opus-4-5');

    await controller.setProvider(AiProvider.openai);
    await controller.saveApiKey('sk-openai-test-not-real');
    await controller.setModel('gpt-4o');

    await controller.setProvider(AiProvider.anthropic);
    expect(controller.hasApiKey, isTrue);
    expect(controller.connection.apiKey, 'sk-ant-test-not-real');
    expect(controller.model, 'claude-opus-4-5');

    await controller.setProvider(AiProvider.openai);
    expect(controller.connection.apiKey, 'sk-openai-test-not-real');
    expect(controller.model, 'gpt-4o');

    expect(
      storage.snapshot[AiSettingsController.apiKeyStorageKey(AiProvider.anthropic)],
      'sk-ant-test-not-real',
    );
    expect(
      storage.snapshot[AiSettingsController.apiKeyStorageKey(AiProvider.openai)],
      'sk-openai-test-not-real',
    );
  });

  test('migrates the PR #7 single-slot key into the active provider', () async {
    final storage = MemoryAiSecureStorage({
      AiSettingsController.providerKey: 'anthropic',
      AiSettingsController.apiKeyKey: 'sk-legacy-test-not-real',
      AiSettingsController.modelKey: 'claude-haiku-4-5',
    });
    final controller = AiSettingsController(
      storage: storage,
      client: FakeAiClient(),
    );
    await controller.load();
    expect(controller.provider, AiProvider.anthropic);
    expect(controller.connection.apiKey, 'sk-legacy-test-not-real');
    expect(controller.model, 'claude-haiku-4-5');
    expect(
      storage.snapshot[AiSettingsController.apiKeyStorageKey(AiProvider.anthropic)],
      'sk-legacy-test-not-real',
    );
  });
}

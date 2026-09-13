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
    expect(storage.snapshot.containsKey(AiSettingsController.apiKeyKey), isFalse);

    await controller.setProvider(AiProvider.openaiCompatible);
    await controller.setBaseUrl('https://example.com/v1');
    await controller.setModel('local-llama');
    await controller.saveApiKey('sk-test-not-a-real-key');

    expect(storage.snapshot[AiSettingsController.providerKey], 'openaiCompatible');
    expect(
      storage.snapshot[AiSettingsController.baseUrlKey],
      'https://example.com/v1',
    );
    expect(storage.snapshot[AiSettingsController.modelKey], 'local-llama');
    expect(
      storage.snapshot[AiSettingsController.apiKeyKey],
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
      AiSettingsController.apiKeyKey: 'sk-test-not-a-real-key',
    });
    final controller = AiSettingsController(
      storage: storage,
      client: FakeAiClient(),
    );
    await controller.load();
    expect(controller.hasApiKey, isTrue);

    await controller.clearApiKey();
    expect(controller.hasApiKey, isFalse);
    expect(storage.snapshot.containsKey(AiSettingsController.apiKeyKey), isFalse);
  });

  test('OpenAI and Anthropic presets fill endpoint and model', () async {
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
  });
}

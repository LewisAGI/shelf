import 'package:flutter/foundation.dart';

import '../models/ai_provider.dart';
import 'ai_client.dart';
import 'ai_secure_storage.dart';

/// Loads and saves BYO AI settings. The API key is Keychain-backed.
class AiSettingsController extends ChangeNotifier {
  AiSettingsController({
    required this._storage,
    AiClient? client,
  }) : _client = client ?? HttpAiClient();

  static const providerKey = 'shelf.ai.provider';
  static const baseUrlKey = 'shelf.ai.base_url';
  static const modelKey = 'shelf.ai.model';
  static const apiKeyKey = 'shelf.ai.api_key';

  final AiSecureStorage _storage;
  final AiClient _client;

  AiProvider _provider = AiProvider.openai;
  String _baseUrl = AiProvider.openai.presetBaseUrl;
  String _model = AiProvider.openai.presetModel;
  String _apiKey = '';
  bool _ready = false;
  bool _busy = false;
  String? _status;
  bool _lastVerifyOk = false;

  AiProvider get provider => _provider;
  String get baseUrl => _baseUrl;
  String get model => _model;
  bool get hasApiKey => _apiKey.trim().isNotEmpty;
  bool get ready => _ready;
  bool get busy => _busy;
  String? get status => _status;
  bool get lastVerifyOk => _lastVerifyOk;

  AiConnection get connection => AiConnection(
    provider: _provider,
    baseUrl: _baseUrl,
    model: _model,
    apiKey: _apiKey,
  );

  String get endpointLabel {
    final url = connection.resolvedBaseUrl;
    return url.isEmpty ? 'Not configured' : url;
  }

  String get connectionStatusLabel {
    if (!hasApiKey) {
      return 'On this iPhone — add your own API key';
    }
    if (_lastVerifyOk) {
      return 'Key saved — last test succeeded';
    }
    return 'Key saved in Keychain — not tested yet';
  }

  Future<void> load() async {
    final providerId = await _storage.read(providerKey);
    final baseUrl = await _storage.read(baseUrlKey);
    final model = await _storage.read(modelKey);
    final apiKey = await _storage.read(apiKeyKey);
    _provider = AiProviderX.fromId(providerId);
    _baseUrl = (baseUrl == null || baseUrl.isEmpty)
        ? _provider.presetBaseUrl
        : baseUrl;
    _model = (model == null || model.isEmpty) ? _provider.presetModel : model;
    _apiKey = apiKey ?? '';
    _ready = true;
    notifyListeners();
  }

  Future<void> setProvider(AiProvider provider) async {
    _provider = provider;
    if (!provider.allowsCustomBaseUrl || _baseUrl.trim().isEmpty) {
      _baseUrl = provider.presetBaseUrl;
      await _storage.write(baseUrlKey, _baseUrl);
    }
    if (_model.trim().isEmpty ||
        AiProvider.values.any((item) => item.presetModel == _model)) {
      _model = provider.presetModel;
      await _storage.write(modelKey, _model);
    }
    await _storage.write(providerKey, provider.id);
    _lastVerifyOk = false;
    notifyListeners();
  }

  Future<void> setBaseUrl(String value) async {
    _baseUrl = value.trim();
    await _storage.write(baseUrlKey, _baseUrl);
    _lastVerifyOk = false;
    notifyListeners();
  }

  Future<void> setModel(String value) async {
    _model = value.trim();
    await _storage.write(modelKey, _model);
    notifyListeners();
  }

  Future<void> saveApiKey(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await clearApiKey();
      return;
    }
    _apiKey = trimmed;
    await _storage.write(apiKeyKey, trimmed);
    _status = 'API key saved in the iPhone Keychain.';
    _lastVerifyOk = false;
    notifyListeners();
  }

  Future<void> clearApiKey() async {
    _apiKey = '';
    await _storage.delete(apiKeyKey);
    _status = 'API key removed from this iPhone.';
    _lastVerifyOk = false;
    notifyListeners();
  }

  Future<AiVerifyResult> verify() async {
    _busy = true;
    _status = 'Testing connection…';
    notifyListeners();
    final result = await _client.verify(connection);
    _busy = false;
    _lastVerifyOk = result.ok;
    _status = result.message;
    notifyListeners();
    return result;
  }

  Future<String> askAbout(AiAskRequest request) {
    return _client.askAbout(connection, request);
  }
}

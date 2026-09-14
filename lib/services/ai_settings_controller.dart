import 'package:flutter/foundation.dart';

import '../models/ai_provider.dart';
import 'ai_client.dart';
import 'ai_secure_storage.dart';

/// Loads and saves BYO AI settings. Keys are Keychain-backed **per provider**.
class AiSettingsController extends ChangeNotifier {
  AiSettingsController({
    required this._storage,
    AiClient? client,
  }) : _client = client ?? HttpAiClient();

  static const providerKey = 'shelf.ai.provider';

  /// Legacy single-slot keys from PR #7. Migrated into the active provider.
  static const baseUrlKey = 'shelf.ai.base_url';
  static const modelKey = 'shelf.ai.model';
  static const apiKeyKey = 'shelf.ai.api_key';

  static String apiKeyStorageKey(AiProvider provider) =>
      'shelf.ai.${provider.id}.api_key';

  static String modelStorageKey(AiProvider provider) =>
      'shelf.ai.${provider.id}.model';

  static String baseUrlStorageKey(AiProvider provider) =>
      'shelf.ai.${provider.id}.base_url';

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

  bool get isCustomModel => !_provider.knownModels.contains(_model);

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
    _provider = AiProviderX.fromId(providerId);
    await _migrateLegacyInto(_provider);
    await _readProviderSlot(_provider);
    _ready = true;
    notifyListeners();
  }

  Future<void> setProvider(AiProvider provider) async {
    if (provider == _provider) {
      return;
    }
    _provider = provider;
    await _storage.write(providerKey, provider.id);
    await _readProviderSlot(provider);
    _lastVerifyOk = false;
    _status = null;
    notifyListeners();
  }

  Future<void> setBaseUrl(String value) async {
    _baseUrl = value.trim();
    await _storage.write(baseUrlStorageKey(_provider), _baseUrl);
    _lastVerifyOk = false;
    notifyListeners();
  }

  Future<void> setModel(String value) async {
    _model = value.trim();
    if (_model.isEmpty) {
      _model = _provider.presetModel;
    }
    await _storage.write(modelStorageKey(_provider), _model);
    notifyListeners();
  }

  Future<void> saveApiKey(String value) async {
    final trimmed = value.trim();
    if (trimmed.isEmpty) {
      await clearApiKey();
      return;
    }
    _apiKey = trimmed;
    await _storage.write(apiKeyStorageKey(_provider), trimmed);
    _status = 'API key saved in the iPhone Keychain.';
    _lastVerifyOk = false;
    notifyListeners();
  }

  Future<void> clearApiKey() async {
    _apiKey = '';
    await _storage.delete(apiKeyStorageKey(_provider));
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

  Future<AiAskOutcome> askAbout(AiAskRequest request) {
    return _client.askAbout(connection, request);
  }

  Future<void> _readProviderSlot(AiProvider provider) async {
    final apiKey = await _storage.read(apiKeyStorageKey(provider));
    final model = await _storage.read(modelStorageKey(provider));
    final baseUrl = await _storage.read(baseUrlStorageKey(provider));
    _apiKey = apiKey ?? '';
    _model = (model == null || model.isEmpty) ? provider.presetModel : model;
    if (provider.allowsCustomBaseUrl) {
      _baseUrl = baseUrl ?? '';
    } else {
      _baseUrl = (baseUrl == null || baseUrl.isEmpty)
          ? provider.presetBaseUrl
          : baseUrl;
    }
  }

  Future<void> _migrateLegacyInto(AiProvider provider) async {
    final slottedKey = await _storage.read(apiKeyStorageKey(provider));
    if (slottedKey == null || slottedKey.isEmpty) {
      final legacyKey = await _storage.read(apiKeyKey);
      if (legacyKey != null && legacyKey.isNotEmpty) {
        await _storage.write(apiKeyStorageKey(provider), legacyKey);
      }
    }
    final slottedModel = await _storage.read(modelStorageKey(provider));
    if (slottedModel == null || slottedModel.isEmpty) {
      final legacyModel = await _storage.read(modelKey);
      if (legacyModel != null && legacyModel.isNotEmpty) {
        await _storage.write(modelStorageKey(provider), legacyModel);
      }
    }
    final slottedUrl = await _storage.read(baseUrlStorageKey(provider));
    if (slottedUrl == null || slottedUrl.isEmpty) {
      final legacyUrl = await _storage.read(baseUrlKey);
      if (legacyUrl != null && legacyUrl.isNotEmpty) {
        await _storage.write(baseUrlStorageKey(provider), legacyUrl);
      }
    }
  }
}

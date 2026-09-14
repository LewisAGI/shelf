import 'package:flutter_secure_storage/flutter_secure_storage.dart';

/// Key-value store for BYO AI settings. The API key must live here, not in
/// SharedPreferences / SQLite.
abstract class AiSecureStorage {
  Future<String?> read(String key);

  Future<void> write(String key, String value);

  Future<void> delete(String key);
}

/// In-memory store for widget/unit tests. Never used for a real key on device.
class MemoryAiSecureStorage implements AiSecureStorage {
  MemoryAiSecureStorage([Map<String, String>? seed]) : _values = {...?seed};

  final Map<String, String> _values;

  Map<String, String> get snapshot => Map.unmodifiable(_values);

  @override
  Future<String?> read(String key) async => _values[key];

  @override
  Future<void> write(String key, String value) async {
    _values[key] = value;
  }

  @override
  Future<void> delete(String key) async {
    _values.remove(key);
  }
}

/// iOS Keychain / Android Keystore via flutter_secure_storage.
class KeychainAiSecureStorage implements AiSecureStorage {
  /// iOS: first-unlock-this-device Keychain item.
  static const IOSOptions iosOptions = IOSOptions(
    accessibility: KeychainAccessibility.first_unlock_this_device,
  );

  /// Android: RSA-OAEP key wrap + AES-GCM, keys in the Android Keystore.
  /// `encryptedSharedPreferences` is deprecated in v10 — omit it.
  static const AndroidOptions androidOptions = AndroidOptions(
    resetOnError: true,
  );

  KeychainAiSecureStorage({FlutterSecureStorage? storage})
    : _storage =
          storage ??
          const FlutterSecureStorage(
            iOptions: iosOptions,
            aOptions: androidOptions,
          );

  final FlutterSecureStorage _storage;

  @override
  Future<String?> read(String key) => _storage.read(key: key);

  @override
  Future<void> write(String key, String value) {
    return _storage.write(key: key, value: value);
  }

  @override
  Future<void> delete(String key) => _storage.delete(key: key);
}

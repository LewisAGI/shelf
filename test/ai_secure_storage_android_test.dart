import 'dart:io';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shelf/services/ai_secure_storage.dart';

void main() {
  test('AndroidManifest declares mic, internet, speech query, and no backup', () {
    final manifest = File(
      'android/app/src/main/AndroidManifest.xml',
    ).readAsStringSync();
    expect(manifest, contains('android.permission.INTERNET'));
    expect(manifest, contains('android.permission.RECORD_AUDIO'));
    expect(manifest, contains('android.speech.RecognitionService'));
    expect(manifest, contains('android:allowBackup="false"'));
  });

  test('KeychainAiSecureStorage configures iOS Keychain and Android Keystore', () {
    expect(
      KeychainAiSecureStorage.iosOptions.accessibility,
      KeychainAccessibility.first_unlock_this_device,
    );
    final android = KeychainAiSecureStorage.androidOptions.toMap();
    expect(android['resetOnError'], 'true');
    expect(
      android['keyCipherAlgorithm'],
      'RSA_ECB_OAEPwithSHA_256andMGF1Padding',
    );
    expect(android['storageCipherAlgorithm'], 'AES_GCM_NoPadding');

    final storage = KeychainAiSecureStorage(
      storage: const FlutterSecureStorage(
        iOptions: KeychainAiSecureStorage.iosOptions,
        aOptions: KeychainAiSecureStorage.androidOptions,
      ),
    );
    expect(storage, isA<AiSecureStorage>());
  });
}

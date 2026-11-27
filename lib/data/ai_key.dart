import 'package:flutter_secure_storage/flutter_secure_storage.dart';

// API key disimpan di Android Keystore, tidak di database atau APK.
const _storage = FlutterSecureStorage();
const _keyName = 'deepseek_api_key';

Future<String?> readAiKey() => _storage.read(key: _keyName);

Future<void> writeAiKey(String value) =>
    _storage.write(key: _keyName, value: value);

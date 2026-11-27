import 'dart:convert';
import 'dart:math';

import 'package:crypto/crypto.dart';

String newSalt() {
  final r = Random.secure();
  return base64UrlEncode(List<int>.generate(16, (_) => r.nextInt(256)));
}

String hashPin(String pin, String salt) =>
    sha256.convert(utf8.encode('$salt:$pin')).toString();

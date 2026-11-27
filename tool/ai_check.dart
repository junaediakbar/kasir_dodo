// Uji manual Scan AI: kirim satu foto ke DeepSeek dengan katalog contoh.
// Pakai: DEEPSEEK_API_KEY=... dart run tool/ai_check.dart <path-foto.jpg>
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;
import 'package:kasir_dodo/data/ai_scan.dart';

Future<void> main(List<String> args) async {
  final key = Platform.environment['DEEPSEEK_API_KEY'];
  if (key == null || key.isEmpty) {
    stderr.writeln('DEEPSEEK_API_KEY belum di-set di shell ini.');
    exit(2);
  }
  if (args.isEmpty) {
    stderr.writeln('Pakai: dart run tool/ai_check.dart <path-foto.jpg>');
    exit(2);
  }
  final bytes = await File(args.first).readAsBytes();
  final catalog = [
    (id: 1, name: 'Teh Botol Sosro 350ml', unit: 'btl'),
    (id: 2, name: 'Kopi Kapal Api Mix', unit: 'renceng'),
    (id: 3, name: 'Indomie Goreng', unit: 'bks'),
    (id: 4, name: 'Minyak Goreng Bimoli 1L', unit: 'btl'),
  ];
  final client = http.Client();
  try {
    final matches = await scanProducts(
      client: client,
      apiKey: key,
      model: 'deepseek-v4-flash-vision-exp',
      imageJpegBase64: base64Encode(bytes),
      catalog: catalog,
    );
    stdout.writeln('matches: ${matches.map((m) => '${m.productId}:${m.confidence}').join(', ')}');
    stdout.writeln('aksi (ambang 0,85): ${actionFor(matches, 0.85)}');
  } on AiException catch (e) {
    stdout.writeln('AiException: $e');
  } finally {
    client.close();
  }
}

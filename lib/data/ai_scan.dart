import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:http/http.dart' as http;

/// Pesan yang aman ditampilkan ke kasir (bahasa Indonesia, tanpa detail internal).
class AiException implements Exception {
  AiException(this.message);
  final String message;
  @override
  String toString() => message;
}

class AiMatch {
  AiMatch(this.productId, this.confidence);
  final int productId;
  final double confidence;
}

enum ScanAction { autoAdd, suggest, unknown }

const _endpoint = 'https://api.deepseek.com/chat/completions';
const _timeout = Duration(seconds: 20);

/// Ambil daftar tebakan dari jawaban model. Id di luar katalog dibuang.
/// Mengembalikan paling banyak 3, urut dari keyakinan tertinggi.
List<AiMatch> parseMatches(String? content, Set<int> validIds) {
  if (content == null || content.trim().isEmpty) return const [];
  Object? data;
  try {
    data = jsonDecode(content);
  } catch (_) {
    // Model kadang membungkus JSON dengan teks lain.
    final s = content.indexOf('{');
    final e = content.lastIndexOf('}');
    if (s < 0 || e <= s) return const [];
    try {
      data = jsonDecode(content.substring(s, e + 1));
    } catch (_) {
      return const [];
    }
  }
  if (data is! Map || data['matches'] is! List) return const [];
  final out = <AiMatch>[];
  for (final m in data['matches'] as List) {
    if (m is! Map) continue;
    final id = m['product_id'];
    final c = m['confidence'];
    if (id is! num || c is! num) continue;
    final pid = id.toInt();
    if (!validIds.contains(pid)) continue;
    out.add(AiMatch(pid, c.toDouble().clamp(0.0, 1.0)));
  }
  out.sort((a, b) => b.confidence.compareTo(a.confidence));
  return out.take(3).toList();
}

/// Aturan PRD: ≥ ambang → masuk keranjang, 0,50 s/d ambang → saran, di bawahnya → tidak dikenali.
ScanAction actionFor(List<AiMatch> matches, double threshold) {
  if (matches.isEmpty) return ScanAction.unknown;
  final top = matches.first.confidence;
  if (top >= threshold) return ScanAction.autoAdd;
  if (top >= 0.5) return ScanAction.suggest;
  return ScanAction.unknown;
}

/// Kirim satu foto + katalog ke DeepSeek. [catalog] berisi (id, nama, satuan).
Future<List<AiMatch>> scanProducts({
  required http.Client client,
  required String apiKey,
  required String model,
  required String imageJpegBase64,
  required List<({int id, String name, String unit})> catalog,
}) async {
  final catalogText = catalog
      .map((p) => '${p.id} | ${p.name} | ${p.unit}')
      .join('\n');
  final prompt = 'Kenali produk di foto kemasan. Pilih maksimal 3 produk dari daftar '
      'berikut (format: id | nama | satuan). Jawab dalam JSON dengan format '
      '{"matches": [{"product_id": <id>, "confidence": <0 sampai 1>}]}. '
      'Jika tidak ada yang cocok, kembalikan {"matches": []}.\n\nDaftar produk:\n$catalogText';
  final body = jsonEncode({
    'model': model,
    'temperature': 0,
    'max_tokens': 200,
    'response_format': {'type': 'json_object'},
    'messages': [
      {
        'role': 'user',
        'content': [
          {'type': 'text', 'text': prompt},
          {
            'type': 'image_url',
            'image_url': {'url': 'data:image/jpeg;base64,$imageJpegBase64'},
          },
        ],
      },
    ],
  });

  http.Response res;
  try {
    res = await client
        .post(
          Uri.parse(_endpoint),
          headers: {
            'Authorization': 'Bearer $apiKey',
            'Content-Type': 'application/json',
          },
          body: body,
        )
        .timeout(_timeout);
  } on TimeoutException {
    throw AiException('Koneksi lambat. Coba lagi atau cari manual.');
  } on SocketException {
    throw AiException('Tidak ada internet. Cari produk manual.');
  } on http.ClientException {
    throw AiException('Tidak ada internet. Cari produk manual.');
  }

  if (res.statusCode != 200) throw AiException(_messageFor(res.statusCode));

  String? content;
  try {
    final json = jsonDecode(utf8.decode(res.bodyBytes)) as Map<String, dynamic>;
    final choices = json['choices'] as List?;
    final msg = (choices?.first as Map?)?['message'] as Map?;
    content = msg?['content'] as String?;
  } catch (_) {
    throw AiException('Jawaban AI tidak bisa dibaca. Cari produk manual.');
  }
  return parseMatches(content, catalog.map((p) => p.id).toSet());
}

String _messageFor(int status) {
  switch (status) {
    case 401:
    case 403:
      return 'API key tidak valid. Periksa di Pengaturan.';
    case 402:
      return 'Saldo DeepSeek habis. Isi saldo atau cari manual.';
    case 429:
      return 'Terlalu banyak permintaan. Coba beberapa saat lagi.';
    default:
      if (status >= 500) return 'Server AI sedang sibuk. Coba lagi nanti.';
      return 'Scan AI gagal (kode $status). Cari produk manual.';
  }
}

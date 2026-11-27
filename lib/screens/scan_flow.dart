import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../core/cart.dart';
import '../data/ai_key.dart';
import '../data/ai_scan.dart';
import '../data/repo.dart';
import '../theme.dart';

/// Alur Scan AI (F-08): foto → DeepSeek → masuk keranjang / pilih saran / tidak dikenali.
Future<void> runAiScan(
  BuildContext context,
  Repo repo,
  Cart cart,
  VoidCallback onChanged,
) async {
  final messenger = ScaffoldMessenger.of(context);
  void msg(String t) => messenger.showSnackBar(SnackBar(content: Text(t)));

  final store = await repo.store();
  if (store == null || store['ai_enabled'] != 1) {
    msg('Aktifkan Scan AI di Pengaturan dulu');
    return;
  }
  final apiKey = await readAiKey();
  if (apiKey == null || apiKey.isEmpty) {
    msg('Isi API key DeepSeek di Pengaturan');
    return;
  }
  if (!context.mounted) return;

  final source = await showModalBottomSheet<ImageSource>(
    context: context,
    builder: (ctx) => SafeArea(
      child: Wrap(children: [
        ListTile(
          leading: const Icon(Icons.photo_camera),
          title: const Text('Ambil foto'),
          onTap: () => Navigator.pop(ctx, ImageSource.camera),
        ),
        ListTile(
          leading: const Icon(Icons.photo_library),
          title: const Text('Pilih dari galeri'),
          onTap: () => Navigator.pop(ctx, ImageSource.gallery),
        ),
      ]),
    ),
  );
  if (source == null) return;

  // Ukuran dikecilkan di sini agar sesuai PRD (±1024 px, JPEG 80).
  final file = await ImagePicker().pickImage(
    source: source,
    maxWidth: 1024,
    imageQuality: 80,
  );
  if (file == null) return;
  final b64 = base64Encode(await file.readAsBytes());
  if (!context.mounted) return;

  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (_) => const AlertDialog(
      content: Row(children: [
        CircularProgressIndicator(),
        SizedBox(width: 16),
        Expanded(child: Text('Mengenali produk...')),
      ]),
    ),
  );

  List<AiMatch> matches;
  final products = await repo.products();
  final byId = {for (final p in products) p['id'] as int: p};
  final client = http.Client();
  try {
    matches = await scanProducts(
      client: client,
      apiKey: apiKey,
      model: store['ai_model'] as String,
      imageJpegBase64: b64,
      catalog: [
        for (final p in products)
          (id: p['id'] as int, name: p['name'] as String, unit: p['unit'] as String)
      ],
    );
  } on AiException catch (e) {
    if (context.mounted) Navigator.of(context, rootNavigator: true).pop();
    msg(e.message);
    return;
  } finally {
    client.close();
  }
  if (!context.mounted) return;
  Navigator.of(context, rootNavigator: true).pop();

  final threshold = (store['ai_threshold'] as num).toDouble();
  void addMatch(AiMatch m) {
    final p = byId[m.productId]!;
    try {
      cart.add(
        productId: p['id'] as int,
        name: p['name'] as String,
        price: p['sell_price'] as int,
        cost: p['cost_price'] as int,
        stock: p['stock'] as int,
      );
      onChanged();
      msg('Ditambahkan: ${p['name']}');
    } on StateError catch (e) {
      msg(e.message);
    }
  }

  switch (actionFor(matches, threshold)) {
    case ScanAction.autoAdd:
      addMatch(matches.first);
    case ScanAction.suggest:
      await showModalBottomSheet<void>(
        context: context,
        builder: (ctx) => SafeArea(
          child: Column(mainAxisSize: MainAxisSize.min, children: [
            const ListTile(title: Text('Produk mirip, pilih salah satu')),
            for (final m in matches)
              ListTile(
                title: Text(byId[m.productId]!['name'] as String),
                trailing: Text('${(m.confidence * 100).round()}%'),
                onTap: () {
                  Navigator.pop(ctx);
                  addMatch(m);
                },
              ),
          ]),
        ),
      );
    case ScanAction.unknown:
      msg('Produk tidak dikenali. Cari manual.');
  }
}

/// Tombol kecil untuk membuka Scan AI dari layar kasir.
class ScanAiButton extends StatelessWidget {
  const ScanAiButton({super.key, required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => OutlinedButton.icon(
        style: OutlinedButton.styleFrom(
          foregroundColor: kPrimary,
          minimumSize: const Size.fromHeight(48),
        ),
        onPressed: onPressed,
        icon: const Icon(Icons.auto_awesome),
        label: const Text('Scan AI'),
      );
}

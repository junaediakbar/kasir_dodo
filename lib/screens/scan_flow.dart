import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';

import '../core/cart.dart';
import '../data/ai_key.dart';
import '../data/ai_scan.dart';
import '../data/repo.dart';
import '../theme.dart';
import 'ui.dart';

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
    showDragHandle: true,
    builder: (ctx) => SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(mainAxisSize: MainAxisSize.min, children: [
          const SectionLabel('Scan AI · ambil gambar produk'),
          Row(children: [
            for (final (src, icon, label) in [
              (ImageSource.camera, Icons.photo_camera_outlined, 'Ambil foto'),
              (ImageSource.gallery, Icons.photo_library_outlined, 'Pilih dari galeri'),
            ]) ...[
              Expanded(
                child: Panel(
                  color: kSurfaceLow,
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  onTap: () => Navigator.pop(ctx, src),
                  child: Column(children: [
                    Icon(icon, color: kPrimaryDark, size: 28),
                    const SizedBox(height: 6),
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                  ]),
                ),
              ),
              if (src == ImageSource.camera) const SizedBox(width: 12),
            ],
          ]),
        ]),
      ),
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
        showDragHandle: true,
        builder: (ctx) => SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(children: [
                  iconTile(Icons.auto_fix_high, size: 28),
                  const SizedBox(width: 8),
                  Text('KOREKSI SCAN AI',
                      style: mono(11, weight: FontWeight.w700, color: kPrimaryDark)),
                ]),
                const SizedBox(height: 8),
                Text('Pilih produk yang benar',
                    style: Theme.of(ctx).textTheme.headlineSmall),
                Text('AI belum yakin. Ketuk salah satu untuk masuk keranjang.',
                    style: Theme.of(ctx).textTheme.bodySmall),
                const SizedBox(height: 12),
                for (final m in matches) ...[
                  Panel(
                    padding: const EdgeInsets.all(8),
                    onTap: () {
                      Navigator.pop(ctx);
                      addMatch(m);
                    },
                    child: Row(children: [
                      productThumb(byId[m.productId]!),
                      const SizedBox(width: 10),
                      Expanded(
                        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                          Text(byId[m.productId]!['name'] as String,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(fontWeight: FontWeight.w600)),
                          Money(byId[m.productId]!['sell_price'] as int,
                              size: 12, color: kPrimaryDark),
                        ]),
                      ),
                      pill('${(m.confidence * 100).round()}%',
                          fg: m.confidence >= .6 ? kOnMintSoft : kAmberDark,
                          bg: m.confidence >= .6 ? kMintSoft : kAmberSoft),
                      const SizedBox(width: 8),
                      const Icon(Icons.add_circle_outline, color: kPrimary),
                    ]),
                  ),
                  const SizedBox(height: 8),
                ],
                OutlinedButton(
                  style: OutlinedButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                  onPressed: () => Navigator.pop(ctx),
                  child: const Text('Batal, cari manual'),
                ),
              ],
            ),
          ),
        ),
      );
    case ScanAction.unknown:
      msg('Produk tidak dikenali. Cari manual.');
  }
}

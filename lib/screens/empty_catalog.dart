import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../data/seed_demo.dart';

/// Tampilan katalog kosong dengan tombol isi data contoh.
class EmptyCatalog extends StatefulWidget {
  const EmptyCatalog({super.key, required this.repo, required this.onSeeded});
  final Repo repo;
  final VoidCallback onSeeded;

  @override
  State<EmptyCatalog> createState() => _EmptyCatalogState();
}

class _EmptyCatalogState extends State<EmptyCatalog> {
  bool _busy = false;

  Future<void> _seed() async {
    setState(() => _busy = true);
    final messenger = ScaffoldMessenger.of(context);
    try {
      final added = await seedDemo(widget.repo);
      messenger.showSnackBar(
          SnackBar(content: Text('Data contoh ditambahkan: $added produk')));
      widget.onSeeded();
    } catch (e) {
      debugPrint('seedDemo gagal: $e');
      messenger.showSnackBar(
          const SnackBar(content: Text('Gagal mengisi data contoh')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.inventory_2_outlined, size: 48, color: Colors.black38),
            const SizedBox(height: 12),
            Text('Belum ada produk', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            const Text(
              'Tambah produk di tab Produk, atau isi data contoh untuk mencoba aplikasi.',
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: 16),
            OutlinedButton.icon(
              onPressed: _busy ? null : _seed,
              icon: const Icon(Icons.auto_awesome),
              label: const Text('Isi data contoh'),
            ),
          ],
        ),
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/repo.dart';

class BerandaScreen extends StatelessWidget {
  const BerandaScreen({super.key, required this.repo});
  final Repo repo;

  Future<_Home> _load() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final report = await repo.report(start, start.add(const Duration(days: 1)));
    final low = await repo.lowStock();
    final store = await repo.store();
    return _Home(report, low.length, store?['name'] as String? ?? 'Toko');
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Home>(
      future: _load(),
      builder: (context, snap) {
        if (!snap.hasData) {
          return const Center(child: CircularProgressIndicator());
        }
        final h = snap.data!;
        final r = h.report;
        return ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(h.storeName, style: Theme.of(context).textTheme.titleLarge),
            const Text('Ringkasan hari ini'),
            const SizedBox(height: 12),
            _stat('Omzet', rp(r.omzet), big: true),
            Row(children: [
              Expanded(child: _stat('Transaksi', '${r.count}')),
              const SizedBox(width: 12),
              Expanded(child: _stat('Laba kotor', rp(r.profit))),
            ]),
            const SizedBox(height: 12),
            _stat('Produk menipis / habis', '${h.lowCount}'),
            const SizedBox(height: 20),
            Text('Terlaris hari ini', style: Theme.of(context).textTheme.titleMedium),
            if (r.topProducts.isEmpty)
              const Padding(
                padding: EdgeInsets.symmetric(vertical: 12),
                child: Text('Belum ada penjualan hari ini'),
              ),
            for (final t in r.topProducts)
              ListTile(
                contentPadding: EdgeInsets.zero,
                title: Text(t['name'] as String),
                trailing: Text('${t['qty']} terjual'),
              ),
          ],
        );
      },
    );
  }

  Widget _stat(String label, String value, {bool big = false}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(
                      fontSize: big ? 28 : 18, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
}

class _Home {
  _Home(this.report, this.lowCount, this.storeName);
  final Report report;
  final int lowCount;
  final String storeName;
}

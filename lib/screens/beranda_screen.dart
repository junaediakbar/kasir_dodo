import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/repo.dart';
import 'pengaturan_screen.dart';
import 'riwayat_screen.dart';

class BerandaScreen extends StatefulWidget {
  const BerandaScreen({super.key, required this.repo});
  final Repo repo;

  @override
  State<BerandaScreen> createState() => _BerandaScreenState();
}

class _BerandaScreenState extends State<BerandaScreen> {
  late Future<_Home> _future = _load();

  Future<_Home> _load() async {
    final now = DateTime.now();
    final start = DateTime(now.year, now.month, now.day);
    final report = await widget.repo.report(start, start.add(const Duration(days: 1)));
    final low = await widget.repo.lowStock();
    final store = await widget.repo.store();
    return _Home(report, low.length, store?['name'] as String? ?? 'Toko');
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _reload();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<_Home>(
      future: _future,
      builder: (context, snap) {
        final h = snap.data;
        return Scaffold(
          backgroundColor: Colors.transparent,
          appBar: AppBar(
            title: Text(h?.storeName ?? 'Beranda'),
            actions: [
              IconButton(
                tooltip: 'Riwayat',
                icon: const Icon(Icons.receipt_long),
                onPressed: () => _open(RiwayatScreen(repo: widget.repo)),
              ),
              IconButton(
                tooltip: 'Pengaturan',
                icon: const Icon(Icons.settings),
                onPressed: () => _open(PengaturanScreen(repo: widget.repo)),
              ),
            ],
          ),
          body: h == null
              ? const Center(child: CircularProgressIndicator())
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    const Text('Ringkasan hari ini'),
                    const SizedBox(height: 12),
                    _stat('Omzet', rp(h.report.omzet), big: true),
                    Row(children: [
                      Expanded(child: _stat('Transaksi', '${h.report.count}')),
                      const SizedBox(width: 12),
                      Expanded(child: _stat('Laba kotor', rp(h.report.profit))),
                    ]),
                    const SizedBox(height: 12),
                    _stat('Produk menipis / habis', '${h.lowCount}'),
                    const SizedBox(height: 20),
                    Text('Terlaris hari ini', style: Theme.of(context).textTheme.titleMedium),
                    if (h.report.topProducts.isEmpty)
                      const Padding(
                        padding: EdgeInsets.symmetric(vertical: 12),
                        child: Text('Belum ada penjualan hari ini'),
                      ),
                    for (final t in h.report.topProducts)
                      ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(t['name'] as String),
                        trailing: Text('${t['qty']} terjual'),
                      ),
                  ],
                ),
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
                  style: TextStyle(fontSize: big ? 28 : 18, fontWeight: FontWeight.w800)),
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

import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/repo.dart';
import '../theme.dart';

/// Laporan penjualan: Hari ini / 7 hari / 30 hari (RPT-01, RPT-02, RPT-07).
class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key, required this.repo});
  final Repo repo;

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  int _days = 1;

  Future<Report> _load() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final start = end.subtract(Duration(days: _days));
    return widget.repo.report(start, end);
  }

  @override
  Widget build(BuildContext context) {
    return ListView(
      padding: const EdgeInsets.all(16),
      children: [
        Text('Laporan penjualan', style: Theme.of(context).textTheme.titleLarge),
        const SizedBox(height: 12),
        SegmentedButton<int>(
          segments: const [
            ButtonSegment(value: 1, label: Text('Hari ini')),
            ButtonSegment(value: 7, label: Text('7 hari')),
            ButtonSegment(value: 30, label: Text('30 hari')),
          ],
          selected: {_days},
          onSelectionChanged: (s) => setState(() => _days = s.first),
        ),
        const SizedBox(height: 16),
        FutureBuilder<Report>(
          future: _load(),
          builder: (context, snap) {
            if (!snap.hasData) {
              return const Padding(
                padding: EdgeInsets.all(24),
                child: Center(child: CircularProgressIndicator()),
              );
            }
            final r = snap.data!;
            return Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _tile('Omzet', rp(r.omzet), big: true),
                Row(children: [
                  Expanded(child: _tile('Transaksi', '${r.count}')),
                  const SizedBox(width: 12),
                  Expanded(child: _tile('Laba kotor', rp(r.profit))),
                ]),
                const SizedBox(height: 16),
                Text('Per metode bayar', style: Theme.of(context).textTheme.titleMedium),
                if (r.byMethod.isEmpty) const Text('Belum ada transaksi'),
                for (final e in r.byMethod.entries)
                  Row(children: [
                    Expanded(child: Text(e.key)),
                    Text(rp(e.value)),
                  ]),
                const SizedBox(height: 16),
                Text('Produk terlaris', style: Theme.of(context).textTheme.titleMedium),
                for (final t in r.topProducts)
                  Row(children: [
                    Expanded(child: Text(t['name'] as String)),
                    Text('${t['qty']} terjual · ${rp(t['revenue'] as int)}'),
                  ]),
                if (r.topProducts.isEmpty) const Text('Belum ada penjualan'),
              ],
            );
          },
        ),
        const SizedBox(height: 12),
        const Text('Transaksi VOID tidak dihitung.', style: TextStyle(color: kDark, fontSize: 12)),
      ],
    );
  }

  Widget _tile(String label, String value, {bool big = false}) => Card(
        child: Padding(
          padding: const EdgeInsets.all(12),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(label, style: const TextStyle(fontSize: 12)),
              const SizedBox(height: 4),
              Text(value,
                  style: TextStyle(fontSize: big ? 26 : 17, fontWeight: FontWeight.w800)),
            ],
          ),
        ),
      );
}

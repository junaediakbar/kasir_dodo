import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/repo.dart';
import '../theme.dart';
import 'ui.dart';

/// Laporan penjualan & laba: Hari ini / 7 hari / 30 hari
/// (acuan Stitch: laporan_penjualan_laba_rugi_rpt_01_rpt_02, rekap_produk_terlaris_rpt_07).
class LaporanScreen extends StatefulWidget {
  const LaporanScreen({super.key, required this.repo});
  final Repo repo;

  @override
  State<LaporanScreen> createState() => _LaporanScreenState();
}

class _LaporanScreenState extends State<LaporanScreen> {
  int _days = 1;

  static const _periods = {1: 'Hari ini', 7: '7 hari terakhir', 30: '30 hari terakhir'};
  static const _methods = [
    ('CASH', 'Tunai', Icons.payments_outlined, kPrimaryDark),
    ('QRIS', 'QRIS', Icons.qr_code_2, kMint),
    ('TRANSFER', 'Transfer', Icons.account_balance_outlined, kAmber),
  ];

  Future<Report> _load() {
    final now = DateTime.now();
    final end = DateTime(now.year, now.month, now.day).add(const Duration(days: 1));
    final start = end.subtract(Duration(days: _days));
    return widget.repo.report(start, end);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: shopAppBar(widget.repo, 'Laporan'),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
        children: [
          Text('Laporan Penjualan & Laba', style: Theme.of(context).textTheme.headlineSmall),
          const Text('Transaksi void tidak dihitung.',
              style: TextStyle(fontSize: 12, color: kInkSoft)),
          const SizedBox(height: 12),
          Row(children: [
            for (final e in _periods.entries)
              Padding(
                padding: const EdgeInsets.only(right: 8),
                child: ChoiceChip(
                  label: Text(e.key == 1 ? 'Hari ini' : '${e.key} hari'),
                  selected: _days == e.key,
                  onSelected: (_) => setState(() => _days = e.key),
                ),
              ),
          ]),
          const SizedBox(height: 12),
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
              return Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                _hero(r),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
                    Expanded(child: _hpp(r)),
                    const SizedBox(width: 12),
                    Expanded(child: _profit(r)),
                  ]),
                ),
                const SizedBox(height: 12),
                _methodsCard(r),
                const SizedBox(height: 12),
                _topCard(r),
              ]);
            },
          ),
        ],
      ),
    );
  }

  Widget _hero(Report r) {
    final avg = r.count == 0 ? 0 : r.omzet ~/ r.count;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: kPrimaryDark, borderRadius: BorderRadius.circular(8)),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Text('OMZET PENJUALAN · ${_periods[_days]!.toUpperCase()}',
            style: mono(11, weight: FontWeight.w700, color: kMintFixed)),
        const SizedBox(height: 8),
        Money(r.omzet, size: 32, color: Colors.white),
        const SizedBox(height: 6),
        Row(children: [
          Expanded(
            child: Text('Rata-rata keranjang ${rp(avg)}',
                style: mono(11, color: Colors.white70)),
          ),
          Text('${r.count} nota lunas',
              style: mono(11, weight: FontWeight.w700, color: Colors.white)),
        ]),
      ]),
    );
  }

  Widget _hpp(Report r) => Panel(
        child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          Text('TOTAL HPP (MODAL)', style: mono(10, weight: FontWeight.w700, color: kInkSoft)),
          const SizedBox(height: 8),
          Money(r.omzet - r.profit, size: 17),
          const SizedBox(height: 4),
          Text(
              r.omzet == 0
                  ? '-'
                  : '${((r.omzet - r.profit) * 100 / r.omzet).toStringAsFixed(1)}% dari omzet',
              style: const TextStyle(fontSize: 11, color: kInkSoft)),
        ]),
      );

  Widget _profit(Report r) {
    final margin = r.omzet == 0 ? 0.0 : r.profit * 100 / r.omzet;
    return Panel(
      color: const Color(0xFFE6F7EF),
      borderColor: const Color(0xFFC4EBD8),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          Expanded(
            child: Text('LABA KOTOR',
                style: mono(10, weight: FontWeight.w700, color: kPrimaryDark)),
          ),
          const Icon(Icons.trending_up, size: 16, color: kPrimaryDark),
        ]),
        const SizedBox(height: 8),
        Money(r.profit, size: 17, color: kPrimaryDark),
        const SizedBox(height: 4),
        pill('Margin ${margin.toStringAsFixed(1)}%', fg: kOnMintSoft, bg: kMintSoft),
      ]),
    );
  }

  Widget _methodsCard(Report r) => Panel(
        padding: const EdgeInsets.all(16),
        child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
          Text('Metode Pembayaran', style: Theme.of(context).textTheme.titleMedium),
          const Text('Uang fisik di laci vs pembayaran non-tunai',
              style: TextStyle(fontSize: 12, color: kInkSoft)),
          const SizedBox(height: 12),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: SizedBox(
              height: 8,
              child: r.omzet == 0
                  ? const ColoredBox(color: kSurfaceHigh)
                  : Row(children: [
                      for (final (key, _, _, color) in _methods)
                        if ((r.byMethod[key] ?? 0) > 0)
                          Expanded(
                            flex: r.byMethod[key]!,
                            child: ColoredBox(color: color),
                          ),
                    ]),
            ),
          ),
          const SizedBox(height: 12),
          for (final (key, label, icon, color) in _methods) ...[
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                  color: kSurfaceLow, borderRadius: BorderRadius.circular(4)),
              child: Row(children: [
                iconTile(icon, fg: color, bg: Colors.white, size: 36),
                const SizedBox(width: 10),
                Expanded(
                  child: Row(children: [
                    Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                    const SizedBox(width: 6),
                    pill(
                        r.omzet == 0
                            ? '0%'
                            : '${((r.byMethod[key] ?? 0) * 100 / r.omzet).round()}%',
                        fg: Colors.white,
                        bg: color),
                  ]),
                ),
                Money(r.byMethod[key] ?? 0, size: 13),
              ]),
            ),
            const SizedBox(height: 6),
          ],
        ]),
      );

  Widget _topCard(Report r) {
    final maxQty = r.topProducts.isEmpty
        ? 1
        : r.topProducts.map((t) => t['qty'] as int).reduce((a, b) => a > b ? a : b);
    return Panel(
      padding: const EdgeInsets.all(16),
      child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
        Text('Rekap Produk Terlaris', style: Theme.of(context).textTheme.titleMedium),
        Text('5 teratas · ${_periods[_days]!.toLowerCase()}',
            style: const TextStyle(fontSize: 12, color: kInkSoft)),
        const SizedBox(height: 12),
        if (r.topProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 12),
            child: Center(child: Text('Belum ada penjualan')),
          ),
        for (final (i, t) in r.topProducts.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 12),
            child: Column(crossAxisAlignment: CrossAxisAlignment.stretch, children: [
              Row(children: [
                Text('#${i + 1}', style: mono(12, weight: FontWeight.w700, color: kPrimaryDark)),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(t['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                Money(t['revenue'] as int, size: 13),
              ]),
              const SizedBox(height: 4),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: (t['qty'] as int) / maxQty,
                      minHeight: 6,
                      color: i == 0 ? kPrimaryDark : kMint,
                      backgroundColor: kSurfaceHigh,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('${t['qty']} terjual', style: mono(11, color: kInkSoft)),
              ]),
            ]),
          ),
      ]),
    );
  }
}

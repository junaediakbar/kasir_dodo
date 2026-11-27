import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/repo.dart';
import '../theme.dart';
import 'pengaturan_screen.dart';
import 'riwayat_screen.dart';
import 'ui.dart';

/// Beranda owner (acuan Stitch: beranda_owner_toko_berkah_jaya).
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
    final report = await widget.repo.report(
      start,
      start.add(const Duration(days: 1)),
    );
    final low = await widget.repo.lowStock();
    final store = await widget.repo.store();
    return _Home(report, low.length, store?['owner_name'] as String? ?? '');
  }

  void _reload() => setState(() => _future = _load());

  Future<void> _open(Widget page) async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => page));
    _reload();
  }

  // Tanpa DateFormat locale agar tidak perlu initializeDateFormatting.
  static String _tanggal(DateTime d) {
    const hari = [
      'Senin',
      'Selasa',
      'Rabu',
      'Kamis',
      'Jumat',
      'Sabtu',
      'Minggu',
    ];
    const bulan = [
      'Januari',
      'Februari',
      'Maret',
      'April',
      'Mei',
      'Juni',
      'Juli',
      'Agustus',
      'September',
      'Oktober',
      'November',
      'Desember',
    ];
    return '${hari[d.weekday - 1]}, ${d.day} ${bulan[d.month - 1]} ${d.year}';
  }

  static String _greeting(int hour) => switch (hour) {
    < 11 => 'Selamat pagi',
    < 15 => 'Selamat siang',
    < 18 => 'Selamat sore',
    _ => 'Selamat malam',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: shopAppBar(
        widget.repo,
        'Beranda',
        actions: [
          IconButton(
            tooltip: 'Riwayat',
            icon: const Icon(Icons.receipt_long_outlined),
            onPressed: () => _open(RiwayatScreen(repo: widget.repo)),
          ),
          IconButton(
            tooltip: 'Pengaturan',
            icon: const Icon(Icons.settings_outlined),
            onPressed: () => _open(PengaturanScreen(repo: widget.repo)),
          ),
        ],
      ),
      body: FutureBuilder<_Home>(
        future: _future,
        builder: (context, snap) {
          final h = snap.data;
          if (h == null)
            return const Center(child: CircularProgressIndicator());
          final r = h.report;
          final now = DateTime.now();
          return RefreshIndicator(
            onRefresh: () async => _reload(),
            child: ListView(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 24),
              children: [
                Text(
                  '${_greeting(now.hour)}${h.owner.isEmpty ? '' : ', ${h.owner}'}',
                  style: Theme.of(context).textTheme.headlineSmall,
                ),
                Text(_tanggal(now), style: mono(11, color: kInkSoft)),
                const SizedBox(height: 12),
                _hero(r),
                const SizedBox(height: 12),
                IntrinsicHeight(
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      Expanded(child: _profit(r)),
                      const SizedBox(width: 12),
                      Expanded(child: _methods(r)),
                    ],
                  ),
                ),
                const SizedBox(height: 12),
                if (h.lowCount > 0) ...[
                  _stockAlert(h.lowCount),
                  const SizedBox(height: 12),
                ],
                _top(r),
                const SizedBox(height: 16),
                const SectionLabel('Pintasan'),
                Row(
                  children: [
                    Expanded(
                      child: _shortcut(
                        Icons.receipt_long_outlined,
                        'Riwayat',
                        'Struk & void',
                        () => _open(RiwayatScreen(repo: widget.repo)),
                      ),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: _shortcut(
                        Icons.storefront_outlined,
                        'Pengaturan',
                        'Toko, AI, PIN',
                        () => _open(PengaturanScreen(repo: widget.repo)),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  Widget _hero(Report r) {
    final avg = r.count == 0 ? 0 : r.omzet ~/ r.count;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: kPrimaryDark,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.payments_outlined, size: 16, color: kMintFixed),
              const SizedBox(width: 6),
              Text(
                'OMZET PENJUALAN HARI INI',
                style: mono(11, weight: FontWeight.w700, color: kMintFixed),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Money(r.omzet, size: 32, color: Colors.white),
          const SizedBox(height: 4),
          Text.rich(
            TextSpan(
              children: [
                TextSpan(
                  text: '${r.count}',
                  style: const TextStyle(fontWeight: FontWeight.w700),
                ),
                const TextSpan(text: ' transaksi selesai  •  rata-rata '),
                TextSpan(
                  text: rp(avg),
                  style: mono(12, weight: FontWeight.w700),
                ),
              ],
            ),
            style: const TextStyle(color: Colors.white70, fontSize: 12),
          ),
        ],
      ),
    );
  }

  Widget _profit(Report r) {
    final margin = r.omzet == 0 ? 0 : (r.profit * 100 / r.omzet).round();
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.trending_up, size: 16, color: kPrimaryDark),
              const SizedBox(width: 4),
              Text(
                'LABA KOTOR',
                style: mono(10, weight: FontWeight.w700, color: kInkSoft),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Money(r.profit, size: 18, color: kPrimaryDark),
          const SizedBox(height: 6),
          pill('Margin $margin%', fg: kOnMintSoft, bg: kMintSoft),
        ],
      ),
    );
  }

  Widget _methods(Report r) {
    final cash = r.byMethod['CASH'] ?? 0;
    final other = r.omzet - cash;
    return Panel(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(
                Icons.account_balance_wallet_outlined,
                size: 16,
                color: kAmberDark,
              ),
              const SizedBox(width: 4),
              Text(
                'METODE BAYAR',
                style: mono(10, weight: FontWeight.w700, color: kInkSoft),
              ),
            ],
          ),
          const SizedBox(height: 8),
          _methodRow('Tunai', cash),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: r.omzet == 0 ? 0 : cash / r.omzet,
              minHeight: 6,
              color: kPrimaryDark,
              backgroundColor: kAmber,
            ),
          ),
          const SizedBox(height: 4),
          _methodRow('QRIS/Transfer', other),
        ],
      ),
    );
  }

  Widget _methodRow(String label, int amount) => Row(
    children: [
      Expanded(
        child: Text(
          label,
          style: const TextStyle(fontSize: 11, color: kInkSoft),
        ),
      ),
      Money(amount, size: 11),
    ],
  );

  Widget _stockAlert(int n) => Panel(
    color: const Color(0xFFFFF4E5),
    borderColor: kAmberSoft,
    child: Row(
      children: [
        iconTile(Icons.inventory_2_outlined, fg: Colors.white, bg: kAmberDark),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '$n produk perlu restok',
                style: const TextStyle(
                  fontWeight: FontWeight.w700,
                  color: kAmberDark,
                ),
              ),
              const Text(
                'Stok habis atau di bawah batas minimum. Cek tab Stok.',
                style: TextStyle(fontSize: 12, color: kInkSoft),
              ),
            ],
          ),
        ),
      ],
    ),
  );

  Widget _top(Report r) => Panel(
    padding: const EdgeInsets.fromLTRB(12, 12, 12, 4),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '5 Produk Terlaris Hari Ini',
          style: Theme.of(context).textTheme.titleMedium,
        ),
        const Text(
          'Dihitung dari transaksi selesai hari ini',
          style: TextStyle(fontSize: 12, color: kInkSoft),
        ),
        const SizedBox(height: 8),
        if (r.topProducts.isEmpty)
          const Padding(
            padding: EdgeInsets.symmetric(vertical: 16),
            child: Center(child: Text('Belum ada penjualan hari ini')),
          ),
        for (final (i, t) in r.topProducts.indexed)
          Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Row(
              children: [
                Container(
                  width: 32,
                  height: 32,
                  alignment: Alignment.center,
                  decoration: BoxDecoration(
                    color: i == 0 ? kPrimaryDark : kSurfaceMid,
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    '#${i + 1}',
                    style: mono(
                      11,
                      weight: FontWeight.w700,
                      color: i == 0 ? Colors.white : kInkSoft,
                    ),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        t['name'] as String,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: const TextStyle(fontWeight: FontWeight.w600),
                      ),
                      Text(
                        '${t['qty']} terjual',
                        style: mono(11, color: kInkSoft),
                      ),
                    ],
                  ),
                ),
                Money(t['revenue'] as int, size: 13),
              ],
            ),
          ),
      ],
    ),
  );

  Widget _shortcut(
    IconData icon,
    String title,
    String hint,
    VoidCallback onTap,
  ) => Panel(
    onTap: onTap,
    child: Row(
      children: [
        iconTile(icon, bg: kMintSoft),
        const SizedBox(width: 10),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(title, style: const TextStyle(fontWeight: FontWeight.w700)),
              Text(hint, style: const TextStyle(fontSize: 11, color: kInkSoft)),
            ],
          ),
        ),
      ],
    ),
  );
}

class _Home {
  _Home(this.report, this.lowCount, this.owner);
  final Report report;
  final int lowCount;
  final String owner;
}

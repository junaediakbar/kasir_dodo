import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repo.dart';
import '../theme.dart';
import 'empty_catalog.dart';
import 'ui.dart';

/// Pengingat stok (acuan Stitch: pengingat_stok_ritel_umkm). Produk habis/menipis
/// di atas. Ketuk "Ubah stok" untuk barang masuk atau koreksi.
class StokScreen extends StatefulWidget {
  const StokScreen({super.key, required this.repo, this.onChanged});
  final Repo repo;
  final VoidCallback? onChanged;

  @override
  State<StokScreen> createState() => _StokScreenState();
}

enum _Filter { semua, habis, menipis, aman }

_Filter _levelOf(Map<String, Object?> p) {
  final stock = p['stock'] as int, min = p['min_stock'] as int;
  if (stock <= 0) return _Filter.habis;
  if (min > 0 && stock <= min) return _Filter.menipis;
  return _Filter.aman;
}

class _StokScreenState extends State<StokScreen> {
  _Filter _filter = _Filter.semua;
  String _query = '';

  Future<List<Map<String, Object?>>> _load() async {
    final all = await widget.repo.products(query: _query);
    all.sort((a, b) {
      final la = _levelOf(a).index, lb = _levelOf(b).index;
      if (la != lb) return la.compareTo(lb);
      return (a['stock'] as int).compareTo(b['stock'] as int);
    });
    return all;
  }

  Future<void> _adjust(Map<String, Object?> p) async {
    final ctrl = TextEditingController();
    var reason = 'IN';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: Text('Ubah stok ${p['name']}'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('Stok sekarang: ${p['stock']} ${p['unit']}'),
              const SizedBox(height: 12),
              SegmentedButton<String>(
                segments: const [
                  ButtonSegment(value: 'IN', label: Text('Barang masuk')),
                  ButtonSegment(value: 'CORRECTION', label: Text('Koreksi')),
                ],
                selected: {reason},
                onSelectionChanged: (s) => setD(() => reason = s.first),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: ctrl,
                keyboardType: const TextInputType.numberWithOptions(signed: true),
                decoration: InputDecoration(
                  labelText: reason == 'IN'
                      ? 'Jumlah masuk'
                      : 'Selisih (+ tambah, - kurangi)',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Batal')),
            FilledButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Simpan')),
          ],
        ),
      ),
    );
    final raw = int.tryParse(ctrl.text.trim());
    ctrl.dispose();
    if (ok != true || raw == null || raw == 0) return;
    if (reason == 'IN' && raw < 0) return;
    try {
      await widget.repo.adjustStock(p['id'] as int, raw, reason: reason);
      if (mounted) setState(() {});
      widget.onChanged?.call();
    } on InsufficientStock catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  void _openCard(Map<String, Object?> p) => Navigator.push(
        context,
        MaterialPageRoute(builder: (_) => StockCardScreen(repo: widget.repo, product: p)),
      );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: shopAppBar(widget.repo, 'Stok'),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: _load(),
        builder: (context, snap) {
          final all = snap.data ?? const [];
          if (all.isEmpty && _query.isEmpty && snap.connectionState == ConnectionState.done) {
            return EmptyCatalog(repo: widget.repo, onSeeded: () => setState(() {}));
          }
          final count = {for (final f in _Filter.values) f: 0};
          for (final p in all) {
            count[_levelOf(p)] = count[_levelOf(p)]! + 1;
          }
          final items = _filter == _Filter.semua
              ? all
              : all.where((p) => _levelOf(p) == _filter).toList();
          return ListView(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 16),
            children: [
              Panel(
                color: kSurfaceLow,
                child: Row(children: [
                  iconTile(Icons.notifications_active_outlined,
                      fg: Colors.white, bg: kPrimaryDark),
                  const SizedBox(width: 12),
                  const Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text('Pengingat Stok', style: TextStyle(fontWeight: FontWeight.w700)),
                      Text('Produk dengan stok di bawah batas minimum tampil paling atas.',
                          style: TextStyle(fontSize: 12, color: kInkSoft)),
                    ]),
                  ),
                ]),
              ),
              const SizedBox(height: 12),
              Row(children: [
                _summary('Habis', count[_Filter.habis]!, 'Kritis', kRed, kRedSoft,
                    Icons.cancel_outlined),
                const SizedBox(width: 8),
                _summary('Menipis', count[_Filter.menipis]!, 'Perlu restok', kAmberDark,
                    kAmberSoft, Icons.warning_amber),
                const SizedBox(width: 8),
                _summary('Aman', count[_Filter.aman]!, 'Siap jual', kPrimaryDark,
                    Colors.white, Icons.check_circle_outline),
              ]),
              const SizedBox(height: 12),
              TextField(
                decoration: const InputDecoration(
                  hintText: 'Cari produk',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
              const SizedBox(height: 8),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(children: [
                  for (final f in _Filter.values)
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: Text(
                            '${f.name[0].toUpperCase()}${f.name.substring(1)} (${f == _Filter.semua ? all.length : count[f]})'),
                        selected: _filter == f,
                        onSelected: (_) => setState(() => _filter = f),
                      ),
                    ),
                ]),
              ),
              const SizedBox(height: 8),
              if (items.isEmpty)
                const Padding(
                  padding: EdgeInsets.all(24),
                  child: Center(child: Text('Tidak ada produk di kelompok ini')),
                ),
              for (final p in items) ...[_card(p), const SizedBox(height: 8)],
            ],
          );
        },
      ),
    );
  }

  Widget _summary(String label, int n, String hint, Color fg, Color bg, IconData icon) =>
      Expanded(
        child: Container(
          padding: const EdgeInsets.all(10),
          decoration: BoxDecoration(
            color: bg,
            borderRadius: BorderRadius.circular(8),
            border: Border.all(color: bg == Colors.white ? kBorder : bg),
          ),
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Row(children: [
              Expanded(
                child: Text(label.toUpperCase(),
                    style: mono(10, weight: FontWeight.w700, color: fg)),
              ),
              Icon(icon, size: 16, color: fg),
            ]),
            const SizedBox(height: 6),
            Text.rich(TextSpan(children: [
              TextSpan(text: '$n', style: mono(22, weight: FontWeight.w700, color: fg)),
              TextSpan(text: ' SKU', style: mono(10, color: fg)),
            ])),
            Text(hint, style: TextStyle(fontSize: 11, color: fg)),
          ]),
        ),
      );

  Widget _card(Map<String, Object?> p) {
    final stock = p['stock'] as int;
    final min = p['min_stock'] as int;
    final level = _levelOf(p);
    final color = switch (level) {
      _Filter.habis => kRed,
      _Filter.menipis => kAmberDark,
      _ => kPrimary,
    };
    final ratio = min <= 0 ? 1.0 : (stock / (min * 2)).clamp(0.0, 1.0);
    return Panel(
      child: Column(children: [
        Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
          productThumb(p),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Row(children: [
                Expanded(
                  child: Text(p['name'] as String,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                ?stockBadge(stock, min),
              ]),
              const SizedBox(height: 6),
              Row(children: [
                Expanded(
                  child: ClipRRect(
                    borderRadius: BorderRadius.circular(4),
                    child: LinearProgressIndicator(
                      value: ratio,
                      minHeight: 6,
                      color: color,
                      backgroundColor: kSurfaceHigh,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Text('$stock ${p['unit']}',
                    style: mono(12, weight: FontWeight.w700, color: color)),
                Text(' (min $min)', style: mono(10, color: kInkSoft)),
              ]),
            ]),
          ),
        ]),
        const SizedBox(height: 10),
        Row(children: [
          Expanded(
            child: OutlinedButton.icon(
              onPressed: () => _openCard(p),
              icon: const Icon(Icons.history, size: 18),
              label: const Text('Kartu stok'),
              style: OutlinedButton.styleFrom(
                  backgroundColor: kSurfaceLow, side: BorderSide.none),
            ),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: FilledButton.icon(
              onPressed: () => _adjust(p),
              icon: const Icon(Icons.edit_note, size: 18),
              label: const Text('Ubah stok'),
              style: FilledButton.styleFrom(
                minimumSize: const Size(48, 48),
                textStyle: const TextStyle(
                    fontFamily: kSans, fontSize: 14, fontWeight: FontWeight.w700),
              ),
            ),
          ),
        ]),
      ]),
    );
  }
}

/// Kartu stok satu produk: semua perubahan stok, terbaru di atas (F-18).
class StockCardScreen extends StatelessWidget {
  const StockCardScreen({super.key, required this.repo, required this.product});
  final Repo repo;
  final Map<String, Object?> product;

  static const _reasons = {
    'SALE': ('Terjual', Icons.shopping_cart_outlined),
    'VOID': ('Void transaksi', Icons.undo),
    'IN': ('Barang masuk', Icons.move_to_inbox_outlined),
    'CORRECTION': ('Koreksi', Icons.tune),
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
          const Text('Kartu Stok'),
          Text(product['name'] as String, style: mono(11, color: kInkSoft)),
        ]),
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: repo.stockLog(product['id'] as int),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final rows = snap.data!;
          if (rows.isEmpty) {
            return const Center(child: Text('Belum ada perubahan stok'));
          }
          final fmt = DateFormat('dd/MM/yy HH:mm');
          return ListView.separated(
            padding: const EdgeInsets.all(16),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) {
              final r = rows[i];
              final delta = r['delta'] as int;
              final t = DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int);
              final (label, icon) = _reasons[r['reason']] ?? ('${r['reason']}', Icons.circle);
              final up = delta > 0;
              return Panel(
                child: Row(children: [
                  iconTile(icon,
                      fg: up ? kPrimaryDark : kRed, bg: up ? kMintSoft : kRedSoft),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                      Text(label, style: const TextStyle(fontWeight: FontWeight.w700)),
                      Text(fmt.format(t), style: mono(11, color: kInkSoft)),
                    ]),
                  ),
                  Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                    Text(up ? '+$delta' : '$delta',
                        style: mono(16,
                            weight: FontWeight.w700, color: up ? kPrimaryDark : kRed)),
                    Text('${r['before']} → ${r['after']}', style: mono(11, color: kInkSoft)),
                  ]),
                ]),
              );
            },
          );
        },
      ),
    );
  }
}

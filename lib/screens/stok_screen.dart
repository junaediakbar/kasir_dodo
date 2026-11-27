import 'package:flutter/material.dart';
import 'package:intl/intl.dart';

import '../data/repo.dart';
import '../theme.dart';
import 'empty_catalog.dart';

/// Stok: produk menipis/habis di atas. Ketuk untuk barang masuk atau koreksi.
class StokScreen extends StatefulWidget {
  const StokScreen({super.key, required this.repo});
  final Repo repo;

  @override
  State<StokScreen> createState() => _StokScreenState();
}

class _StokScreenState extends State<StokScreen> {
  Future<List<Map<String, Object?>>> _load() async {
    final all = await widget.repo.products();
    all.sort((a, b) {
      bool low(Map<String, Object?> p) =>
          (p['min_stock'] as int) > 0 && (p['stock'] as int) <= (p['min_stock'] as int);
      final la = low(a) ? 0 : 1;
      final lb = low(b) ? 0 : 1;
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
    } on InsufficientStock catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString())));
    }
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<List<Map<String, Object?>>>(
      future: _load(),
      builder: (context, snap) {
        final items = snap.data ?? const [];
        if (items.isEmpty && snap.connectionState == ConnectionState.done) {
          return EmptyCatalog(repo: widget.repo, onSeeded: () => setState(() {}));
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: items.length,
          itemBuilder: (_, i) {
            final p = items[i];
            final stock = p['stock'] as int;
            final minStock = p['min_stock'] as int;
            return Card(
              margin: const EdgeInsets.only(bottom: 8),
              child: ListTile(
                leading: IconButton(
                  tooltip: 'Kartu stok',
                  icon: const Icon(Icons.history),
                  onPressed: () => Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => StockCardScreen(repo: widget.repo, product: p),
                    ),
                  ),
                ),
                title: Text(p['name'] as String),
                subtitle: Text('Stok $stock ${p['unit']} · batas min $minStock'),
                trailing: stockBadge(stock, minStock) ??
                    const Icon(Icons.edit_outlined, color: kPrimary),
                onTap: () => _adjust(p),
              ),
            );
          },
        );
      },
    );
  }
}

/// Kartu stok satu produk: semua perubahan stok, terbaru di atas (F-18).
class StockCardScreen extends StatelessWidget {
  const StockCardScreen({super.key, required this.repo, required this.product});
  final Repo repo;
  final Map<String, Object?> product;

  static const _reasons = {
    'SALE': 'Terjual',
    'VOID': 'Void transaksi',
    'IN': 'Barang masuk',
    'CORRECTION': 'Koreksi',
  };

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Kartu stok · ${product['name']}')),
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
            padding: const EdgeInsets.all(12),
            itemCount: rows.length,
            separatorBuilder: (_, _) => const Divider(height: 1),
            itemBuilder: (_, i) {
              final r = rows[i];
              final delta = r['delta'] as int;
              final t = DateTime.fromMillisecondsSinceEpoch(r['created_at'] as int);
              return ListTile(
                title: Text(_reasons[r['reason']] ?? '${r['reason']}'),
                subtitle: Text('${fmt.format(t)} · ${r['before']} → ${r['after']}'),
                trailing: Text(
                  delta > 0 ? '+$delta' : '$delta',
                  style: TextStyle(
                    fontWeight: FontWeight.w700,
                    color: delta > 0 ? kPrimary : kRed,
                  ),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

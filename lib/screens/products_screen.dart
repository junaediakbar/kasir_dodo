import 'package:flutter/material.dart';

import '../data/repo.dart';
import '../theme.dart';
import 'empty_catalog.dart';
import 'product_form_screen.dart';
import 'ui.dart';

/// Katalog produk (acuan Stitch: katalog_daftar_produk_prd_01).
class ProductsScreen extends StatefulWidget {
  const ProductsScreen({super.key, required this.repo});
  final Repo repo;

  @override
  State<ProductsScreen> createState() => _ProductsScreenState();
}

class _ProductsScreenState extends State<ProductsScreen> {
  String _query = '';
  int? _categoryId;

  Future<void> _open([int? productId]) async {
    final changed = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormScreen(repo: widget.repo, productId: productId),
      ),
    );
    if (changed == true) setState(() {});
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: shopAppBar(widget.repo, 'Produk'),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah produk'),
      ),
      body: FutureBuilder<List<Map<String, Object?>>>(
        future: widget.repo.products(),
        builder: (context, allSnap) {
          final all = allSnap.data ?? const [];
          if (all.isEmpty && allSnap.connectionState == ConnectionState.done) {
            return EmptyCatalog(repo: widget.repo, onSeeded: () => setState(() {}));
          }
          final low = all.where((p) {
            final s = p['stock'] as int, m = p['min_stock'] as int;
            return s > 0 && m > 0 && s <= m;
          }).length;
          final out = all.where((p) => (p['stock'] as int) <= 0).length;
          return Column(children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
              child: Row(children: [
                _stat('${all.length}', 'SKU aktif', kInk),
                const SizedBox(width: 8),
                _stat('$low', 'Menipis', kAmberDark),
                const SizedBox(width: 8),
                _stat('$out', 'Habis', kRed),
              ]),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16),
              child: TextField(
                decoration: const InputDecoration(
                  hintText: 'Cari nama produk atau SKU',
                  prefixIcon: Icon(Icons.search),
                ),
                onChanged: (v) => setState(() => _query = v),
              ),
            ),
            _categories(),
            Expanded(child: _list()),
          ]);
        },
      ),
    );
  }

  Widget _stat(String value, String label, Color color) => Expanded(
        child: Panel(
          padding: const EdgeInsets.symmetric(vertical: 8),
          child: Column(children: [
            Text(value, style: mono(20, weight: FontWeight.w700, color: color)),
            Text(label, style: const TextStyle(fontSize: 11, color: kInkSoft)),
          ]),
        ),
      );

  Widget _categories() => FutureBuilder<List<Map<String, Object?>>>(
        future: widget.repo.categories(),
        builder: (context, snap) {
          final cats = snap.data ?? const [];
          return SizedBox(
            height: 52,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              children: [
                for (final (id, name) in [
                  (null, 'Semua'),
                  for (final c in cats) (c['id'] as int?, c['name'] as String),
                ])
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(name),
                      selected: _categoryId == id,
                      onSelected: (_) => setState(() => _categoryId = id),
                    ),
                  ),
              ],
            ),
          );
        },
      );

  Widget _list() => FutureBuilder<List<Map<String, Object?>>>(
        future: widget.repo.products(query: _query, categoryId: _categoryId),
        builder: (context, snap) {
          final items = snap.data ?? const [];
          if (items.isEmpty && snap.connectionState == ConnectionState.done) {
            return const Center(child: Text('Produk tidak ditemukan'));
          }
          return ListView.separated(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 88),
            itemCount: items.length,
            separatorBuilder: (_, _) => const SizedBox(height: 8),
            itemBuilder: (_, i) => _card(items[i]),
          );
        },
      );

  Widget _card(Map<String, Object?> p) {
    final stock = p['stock'] as int;
    final sell = p['sell_price'] as int, cost = p['cost_price'] as int;
    final margin = sell == 0 ? 0 : ((sell - cost) * 100 / sell).round();
    return Panel(
      onTap: () => _open(p['id'] as int),
      child: Row(crossAxisAlignment: CrossAxisAlignment.start, children: [
        productThumb(p, size: 56),
        const SizedBox(width: 12),
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text('SKU ${p['sku']} · ${p['category_name'] ?? 'Tanpa kategori'}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: mono(10, color: kInkSoft)),
            const SizedBox(height: 2),
            Text(p['name'] as String,
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 15)),
            const SizedBox(height: 4),
            Wrap(spacing: 6, runSpacing: 4, children: [
              ?stockBadge(stock, p['min_stock'] as int),
              pill('Stok $stock ${p['unit']}', fg: kInkSoft, bg: kSurfaceMid),
            ]),
            const SizedBox(height: 8),
            Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
              Text('Jual ', style: mono(10, color: kInkSoft)),
              Money(sell, size: 17),
              const Spacer(),
              Column(crossAxisAlignment: CrossAxisAlignment.end, children: [
                Row(children: [
                  Text('Modal ', style: mono(10, color: kInkSoft)),
                  Money(cost, size: 11, weight: FontWeight.w600, color: kInkSoft),
                ]),
                Text('Margin $margin%',
                    style: mono(10,
                        weight: FontWeight.w700, color: margin > 0 ? kPrimaryDark : kRed)),
              ]),
            ]),
          ]),
        ),
        const SizedBox(width: 4),
        const Icon(Icons.chevron_right, color: kOutline),
      ]),
    );
  }
}

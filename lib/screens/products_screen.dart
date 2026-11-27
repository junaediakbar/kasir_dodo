import 'package:flutter/material.dart';

import '../core/money.dart';
import '../data/repo.dart';
import '../theme.dart';
import 'empty_catalog.dart';
import 'product_form_screen.dart';

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
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: kPrimary,
        foregroundColor: Colors.white,
        onPressed: () => _open(),
        icon: const Icon(Icons.add),
        label: const Text('Tambah produk'),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              decoration: const InputDecoration(
                hintText: 'Cari nama atau SKU',
                prefixIcon: Icon(Icons.search),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          FutureBuilder<List<Map<String, Object?>>>(
            future: widget.repo.categories(),
            builder: (context, snap) {
              final cats = snap.data ?? const [];
              return SizedBox(
                height: 48,
                child: ListView(
                  scrollDirection: Axis.horizontal,
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  children: [
                    Padding(
                      padding: const EdgeInsets.only(right: 8),
                      child: ChoiceChip(
                        label: const Text('Semua'),
                        selected: _categoryId == null,
                        onSelected: (_) => setState(() => _categoryId = null),
                      ),
                    ),
                    for (final c in cats)
                      Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: ChoiceChip(
                          label: Text(c['name'] as String),
                          selected: _categoryId == c['id'],
                          onSelected: (_) =>
                              setState(() => _categoryId = c['id'] as int),
                        ),
                      ),
                  ],
                ),
              );
            },
          ),
          Expanded(
            child: FutureBuilder<List<Map<String, Object?>>>(
              future: widget.repo.products(query: _query, categoryId: _categoryId),
              builder: (context, snap) {
                final items = snap.data ?? const [];
                if (items.isEmpty && snap.connectionState == ConnectionState.done) {
                  if (_query.isEmpty && _categoryId == null) {
                    return EmptyCatalog(
                        repo: widget.repo, onSeeded: () => setState(() {}));
                  }
                  return const Center(child: Text('Produk tidak ditemukan'));
                }
                return ListView.builder(
                  padding: const EdgeInsets.fromLTRB(12, 0, 12, 88),
                  itemCount: items.length,
                  itemBuilder: (_, i) {
                    final p = items[i];
                    final stock = p['stock'] as int;
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        title: Text(p['name'] as String),
                        subtitle: Text(
                            '${p['category_name'] ?? 'Tanpa kategori'} · ${rp(p['sell_price'] as int)} · stok $stock ${p['unit']}'),
                        trailing: stockBadge(stock, p['min_stock'] as int),
                        onTap: () => _open(p['id'] as int),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';

import '../core/cart.dart';
import '../core/money.dart';
import '../data/repo.dart';
import '../theme.dart';
import 'empty_catalog.dart';
import 'payment_screen.dart';
import 'scan_flow.dart';

class KasirScreen extends StatefulWidget {
  const KasirScreen({
    super.key,
    required this.repo,
    required this.cart,
    required this.onChanged,
  });
  final Repo repo;
  final Cart cart;
  final VoidCallback onChanged;

  @override
  State<KasirScreen> createState() => _KasirScreenState();
}

class _KasirScreenState extends State<KasirScreen> {
  final _search = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _search.dispose();
    super.dispose();
  }

  void _changed() {
    setState(() {});
    widget.onChanged();
  }

  void _add(Map<String, Object?> p) {
    try {
      widget.cart.add(
        productId: p['id'] as int,
        name: p['name'] as String,
        price: p['sell_price'] as int,
        cost: p['cost_price'] as int,
        stock: p['stock'] as int,
      );
      _changed();
    } on StateError catch (e) {
      _snack(e.message);
    }
  }

  void _snack(String msg) =>
      ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));

  Future<void> _pay() async {
    final ok = await Navigator.push<bool>(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          repo: widget.repo,
          lines: widget.cart.lines,
        ),
      ),
    );
    if (ok == true) {
      widget.cart.clear();
      _changed();
    }
  }

  @override
  Widget build(BuildContext context) {
    final cart = widget.cart;
    return Column(
      children: [
        Padding(
          padding: const EdgeInsets.all(12),
          child: TextField(
            controller: _search,
            decoration: const InputDecoration(
              hintText: 'Cari nama atau SKU',
              prefixIcon: Icon(Icons.search),
            ),
            onChanged: (v) => setState(() => _query = v),
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12),
          child: ScanAiButton(
            onPressed: () => runAiScan(context, widget.repo, widget.cart, _changed),
          ),
        ),

        Expanded(
          child: FutureBuilder<List<Map<String, Object?>>>(
            future: widget.repo.products(query: _query),
            builder: (context, snap) {
              final items = snap.data ?? const [];
              if (items.isEmpty && snap.connectionState == ConnectionState.done) {
                if (_query.isEmpty) {
                  return EmptyCatalog(repo: widget.repo, onSeeded: _changed);
                }
                return const Center(child: Text('Produk tidak ditemukan'));
              }
              return ListView.builder(
                padding: const EdgeInsets.symmetric(horizontal: 12),
                itemCount: items.length,
                itemBuilder: (_, i) {
                  final p = items[i];
                  final stock = p['stock'] as int;
                  return Card(
                    margin: const EdgeInsets.only(bottom: 8),
                    child: ListTile(
                      minTileHeight: 56,
                      title: Text(p['name'] as String),
                      subtitle: Text('${rp(p['sell_price'] as int)} · stok $stock'),
                      trailing: stockBadge(stock, p['min_stock'] as int) ??
                          const Icon(Icons.add_circle, color: kPrimary),
                      enabled: stock > 0,
                      onTap: () => _add(p),
                    ),
                  );
                },
              );
            },
          ),
        ),
        if (!cart.isEmpty) _cartPanel(cart),
      ],
    );
  }

  Widget _cartPanel(Cart cart) {
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(top: BorderSide(color: kBorder)),
      ),
      constraints: const BoxConstraints(maxHeight: 280),
      padding: const EdgeInsets.all(12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Flexible(
            child: ListView(
              shrinkWrap: true,
              children: [
                for (final l in cart.lines)
                  Row(children: [
                    Expanded(child: Text(l.name, maxLines: 1, overflow: TextOverflow.ellipsis)),
                    IconButton(
                      icon: const Icon(Icons.remove_circle_outline),
                      onPressed: () {
                        cart.setQty(l.productId, l.qty - 1);
                        _changed();
                      },
                    ),
                    Text('${l.qty}'),
                    IconButton(
                      icon: const Icon(Icons.add_circle_outline),
                      onPressed: () {
                        try {
                          cart.setQty(l.productId, l.qty + 1);
                          _changed();
                        } on StateError catch (e) {
                          _snack(e.message);
                        }
                      },
                    ),
                    SizedBox(width: 90, child: Text(rp(l.subtotal), textAlign: TextAlign.end)),
                  ]),
              ],
            ),
          ),
          const SizedBox(height: 8),
          FilledButton(
            onPressed: _pay,
            child: Text('Bayar ${rp(cart.total)}'),
          ),
        ],
      ),
    );
  }
}

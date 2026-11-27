import 'package:flutter/material.dart';

import '../core/cart.dart';
import '../data/repo.dart';
import '../theme.dart';
import 'empty_catalog.dart';
import 'payment_screen.dart';
import 'scan_flow.dart';
import 'ui.dart';

/// Layar Kasir (acuan Stitch: kasir_pos_scan_kamera_offline).
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

  void _setQty(CartLine l, int qty) {
    try {
      widget.cart.setQty(l.productId, qty);
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
        builder: (_) => PaymentScreen(repo: widget.repo, lines: widget.cart.lines),
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
    return Scaffold(
      appBar: shopAppBar(widget.repo, 'Kasir'),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 4, 16, 8),
            child: _ScanBanner(
              onPressed: () => runAiScan(context, widget.repo, widget.cart, _changed),
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              controller: _search,
              decoration: InputDecoration(
                hintText: 'Cari nama atau SKU',
                prefixIcon: const Icon(Icons.search),
                suffixIcon: _query.isEmpty
                    ? null
                    : IconButton(
                        tooltip: 'Hapus pencarian',
                        icon: const Icon(Icons.close),
                        onPressed: () => setState(() {
                          _search.clear();
                          _query = '';
                        }),
                      ),
              ),
              onChanged: (v) => setState(() => _query = v),
            ),
          ),
          const SizedBox(height: 8),
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
                return ListView.separated(
                  padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
                  itemCount: items.length,
                  separatorBuilder: (_, _) => const SizedBox(height: 8),
                  itemBuilder: (_, i) => _productRow(items[i]),
                );
              },
            ),
          ),
          if (!cart.isEmpty) _cartPanel(cart),
        ],
      ),
    );
  }

  Widget _productRow(Map<String, Object?> p) {
    final stock = p['stock'] as int;
    final badge = stockBadge(stock, p['min_stock'] as int);
    return Opacity(
      opacity: stock > 0 ? 1 : .55,
      child: Panel(
        padding: const EdgeInsets.all(8),
        onTap: stock > 0 ? () => _add(p) : null,
        child: Row(children: [
          productThumb(p),
          const SizedBox(width: 10),
          Expanded(
            child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
              Text(p['name'] as String,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(fontWeight: FontWeight.w600)),
              const SizedBox(height: 2),
              Row(children: [
                Money(p['sell_price'] as int, size: 13),
                const SizedBox(width: 8),
                Text('stok $stock', style: mono(11, color: kInkSoft)),
                if (badge != null) ...[const SizedBox(width: 6), badge],
              ]),
            ]),
          ),
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: stock > 0 ? kPrimary : kSurfaceHigh,
              borderRadius: BorderRadius.circular(4),
            ),
            child: Icon(Icons.add, color: stock > 0 ? Colors.white : kOutline),
          ),
        ]),
      ),
    );
  }

  Widget _cartPanel(Cart cart) {
    final count = cart.lines.fold(0, (s, l) => s + l.qty);
    return Container(
      decoration: const BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.vertical(top: Radius.circular(12)),
        boxShadow: [BoxShadow(color: Color(0x14000000), blurRadius: 12, offset: Offset(0, -4))],
      ),
      constraints: BoxConstraints(maxHeight: MediaQuery.sizeOf(context).height * .5),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(children: [
            const Icon(Icons.shopping_bag_outlined, color: kPrimaryDark, size: 20),
            const SizedBox(width: 6),
            Text('Keranjang', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(width: 8),
            pill('$count item'),
            const Spacer(),
            TextButton.icon(
              onPressed: () {
                cart.clear();
                _changed();
              },
              icon: const Icon(Icons.delete_outline, size: 18),
              label: const Text('Kosongkan'),
              style: TextButton.styleFrom(foregroundColor: kInkSoft),
            ),
          ]),
          Flexible(
            child: ListView.separated(
              shrinkWrap: true,
              padding: const EdgeInsets.symmetric(vertical: 6),
              itemCount: cart.lines.length,
              separatorBuilder: (_, _) => const Divider(height: 12),
              itemBuilder: (_, i) => _cartLine(cart.lines[i]),
            ),
          ),
          const SizedBox(height: 6),
          Row(crossAxisAlignment: CrossAxisAlignment.end, children: [
            Text('TOTAL TAGIHAN',
                style: mono(11, weight: FontWeight.w700, color: kInkSoft)
                    .copyWith(letterSpacing: .6)),
            const Spacer(),
            Money(cart.total, size: 28, color: kPrimaryDark),
          ]),
          const SizedBox(height: 10),
          FilledButton(
            onPressed: _pay,
            style: FilledButton.styleFrom(padding: const EdgeInsets.symmetric(horizontal: 16)),
            child: Row(children: [
              const Icon(Icons.payments_outlined),
              const SizedBox(width: 10),
              const Text('BAYAR SEKARANG'),
              const Spacer(),
              Money(cart.total, size: 15, color: Colors.white),
              const Icon(Icons.chevron_right),
            ]),
          ),
        ],
      ),
    );
  }

  Widget _cartLine(CartLine l) => Row(children: [
        Expanded(
          child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
            Text(l.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            Money(l.price, size: 12, color: kInkSoft, weight: FontWeight.w500),
          ]),
        ),
        Container(
          padding: const EdgeInsets.all(2),
          decoration: BoxDecoration(
              color: kSurfaceLow, borderRadius: BorderRadius.circular(4)),
          child: Row(children: [
            _stepBtn(Icons.remove, 'Kurangi ${l.name}', kInk, () => _setQty(l, l.qty - 1)),
            SizedBox(
              width: 32,
              child: Text('${l.qty}',
                  textAlign: TextAlign.center, style: mono(14, weight: FontWeight.w700)),
            ),
            _stepBtn(Icons.add, 'Tambah ${l.name}', kPrimary, () => _setQty(l, l.qty + 1)),
          ]),
        ),
        SizedBox(
          width: 84,
          child: Align(
            alignment: Alignment.centerRight,
            child: Money(l.subtotal, size: 14),
          ),
        ),
        IconButton(
          tooltip: 'Hapus ${l.name}',
          visualDensity: VisualDensity.compact,
          icon: const Icon(Icons.delete_outline, size: 20, color: kInkSoft),
          onPressed: () => _setQty(l, 0),
        ),
      ]);

  Widget _stepBtn(IconData icon, String tip, Color fg, VoidCallback onTap) => Tooltip(
        message: tip,
        child: Material(
          color: Colors.white,
          borderRadius: BorderRadius.circular(4),
          child: InkWell(
            borderRadius: BorderRadius.circular(4),
            onTap: onTap,
            child: SizedBox.square(dimension: 36, child: Icon(icon, size: 18, color: fg)),
          ),
        ),
      );
}

/// Banner gelap dengan bingkai pemindai mint (gaya viewfinder Stitch).
class _ScanBanner extends StatelessWidget {
  const _ScanBanner({required this.onPressed});
  final VoidCallback onPressed;

  @override
  Widget build(BuildContext context) => Material(
        color: kDark,
        borderRadius: BorderRadius.circular(8),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onPressed,
          child: Padding(
            padding: const EdgeInsets.all(12),
            child: Row(children: [
              const SizedBox.square(
                dimension: 64,
                child: CustomPaint(
                  painter: _BracketPainter(),
                  child: Icon(Icons.photo_camera_outlined, color: kMintFixed, size: 28),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                  Row(children: [
                    const Icon(Icons.auto_awesome, color: kMintFixed, size: 16),
                    const SizedBox(width: 6),
                    Text('Scan AI',
                        style: Theme.of(context)
                            .textTheme
                            .titleMedium
                            ?.copyWith(color: Colors.white)),
                  ]),
                  const SizedBox(height: 2),
                  Text('Foto produk, AI mencocokkan ke katalog',
                      style: mono(11, color: Colors.white70)),
                ]),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
                decoration: BoxDecoration(
                    color: kPrimary, borderRadius: BorderRadius.circular(4)),
                child: Text('Mulai', style: mono(12, weight: FontWeight.w700, color: Colors.white)),
              ),
            ]),
          ),
        ),
      );
}

class _BracketPainter extends CustomPainter {
  const _BracketPainter();

  @override
  void paint(Canvas canvas, Size s) {
    final p = Paint()
      ..color = kMintFixed
      ..strokeWidth = 3
      ..style = PaintingStyle.stroke;
    const l = 14.0;
    final w = s.width, h = s.height;
    final path = Path()
      ..moveTo(0, l)..lineTo(0, 0)..lineTo(l, 0)
      ..moveTo(w - l, 0)..lineTo(w, 0)..lineTo(w, l)
      ..moveTo(w, h - l)..lineTo(w, h)..lineTo(w - l, h)
      ..moveTo(l, h)..lineTo(0, h)..lineTo(0, h - l);
    canvas.drawPath(path, p);
  }

  @override
  bool shouldRepaint(_BracketPainter old) => false;
}

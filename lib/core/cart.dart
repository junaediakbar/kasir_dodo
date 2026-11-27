class CartLine {
  CartLine({
    required this.productId,
    required this.name,
    required this.price,
    required this.cost,
    required this.stock,
    this.qty = 1,
  });

  final int productId;
  final String name;
  final int price; // rupiah
  final int cost; // rupiah, harga modal
  final int stock; // stok tersedia saat ini
  int qty;

  int get subtotal => price * qty;
}

/// Keranjang belanja. Tidak menyentuh database.
class Cart {
  final Map<int, CartLine> _lines = {};

  List<CartLine> get lines => _lines.values.toList();
  bool get isEmpty => _lines.isEmpty;
  int get total => _lines.values.fold(0, (s, l) => s + l.subtotal);
  int get profit =>
      _lines.values.fold(0, (s, l) => s + (l.price - l.cost) * l.qty);

  /// Tambah 1 unit. Melempar jika melebihi stok.
  void add({
    required int productId,
    required String name,
    required int price,
    required int cost,
    required int stock,
  }) {
    final existing = _lines[productId];
    final nextQty = (existing?.qty ?? 0) + 1;
    if (nextQty > stock) {
      throw StateError('Stok $name tidak cukup (sisa $stock)');
    }
    if (existing != null) {
      existing.qty = nextQty;
    } else {
      _lines[productId] = CartLine(
        productId: productId,
        name: name,
        price: price,
        cost: cost,
        stock: stock,
        qty: 1,
      );
    }
  }

  void setQty(int productId, int qty) {
    final line = _lines[productId];
    if (line == null) return;
    if (qty <= 0) {
      _lines.remove(productId);
      return;
    }
    if (qty > line.stock) {
      throw StateError('Stok ${line.name} tidak cukup (sisa ${line.stock})');
    }
    line.qty = qty;
  }

  void remove(int productId) => _lines.remove(productId);
  void clear() => _lines.clear();
}

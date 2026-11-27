import 'repo.dart';

/// Data contoh dari layar Stitch (katalog dan kasir).
/// Harga jual dan modal diambil dari layar bila tercantum; sisanya perkiraan.
/// Idempotent: produk yang sudah ada diperbarui ke nilai ini, tidak digandakan.
Future<int> seedDemo(Repo repo) async {
  const categories = ['Sembako', 'Mie & Instan', 'Bumbu', 'Minuman & Kopi'];
  for (final c in categories) {
    try {
      await repo.addCategory(c);
    } catch (_) {
      // Sudah ada (kolom name unik).
    }
  }
  final cats = {
    for (final c in await repo.categories()) c['name'] as String: c['id'] as int,
  };
  final existing = {
    for (final p in await repo.products(includeArchived: true))
      p['name'] as String: p,
  };

  // name, kategori, jual, modal, satuan, stok, batas min
  const items = <(String, String, int, int, String, int, int)>[
    ('Minyak Goreng Bimoli 1L Pouch', 'Sembako', 19500, 16500, 'pcs', 18, 5),
    ('Minyak Goreng Tropical 2L', 'Sembako', 37500, 33000, 'pcs', 0, 5),
    ('Gula Pasir Gulaku 1kg', 'Sembako', 17500, 14500, 'kg', 4, 10),
    ('Indomie Goreng Spesial', 'Mie & Instan', 3500, 2800, 'bks', 85, 10),
    ('Kecap Manis Bango 550ml', 'Bumbu', 24000, 20200, 'btl', 3, 5),
    ('Kopi Kapal Api Mix', 'Minuman & Kopi', 14000, 12000, 'renceng', 15, 5),
    ('Teh Botol Sosro 350ml', 'Minuman & Kopi', 5000, 3700, 'btl', 24, 6),
  ];

  var added = 0;
  for (final (name, cat, sell, cost, unit, stock, min) in items) {
    final cur = existing[name];
    if (cur == null) {
      await repo.addProduct(
        name: name,
        categoryId: cats[cat],
        sellPrice: sell,
        costPrice: cost,
        unit: unit,
        stock: stock,
        minStock: min,
      );
      added++;
      continue;
    }
    final id = cur['id'] as int;
    await repo.updateProduct(id, {
      'category_id': cats[cat],
      'sell_price': sell,
      'cost_price': cost,
      'unit': unit,
      'min_stock': min,
    });
    final delta = stock - (cur['stock'] as int);
    if (delta != 0) {
      await repo.adjustStock(id, delta, reason: 'CORRECTION');
    }
  }
  return added;
}

import 'repo.dart';

/// Data contoh dari layar Stitch (harga jual). Harga modal adalah perkiraan.
/// Idempotent: produk yang namanya sudah ada dilewati.
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
    for (final p in await repo.products(includeArchived: true)) p['name'] as String,
  };

  // name, kategori, jual, modal, satuan, stok awal, batas min
  const items = <(String, String, int, int, String, int, int)>[
    ('Minyak Goreng Bimoli 1L Pouch', 'Sembako', 19500, 17000, 'pcs', 12, 5),
    ('Minyak Goreng Tropical 2L', 'Sembako', 37500, 33000, 'pcs', 4, 5),
    ('Gula Pasir Gulaku 1kg', 'Sembako', 17500, 15000, 'kg', 0, 5),
    ('Indomie Goreng Spesial', 'Mie & Instan', 3500, 2800, 'bks', 40, 10),
    ('Kecap Manis Bango 550ml', 'Bumbu', 24000, 20200, 'btl', 6, 3),
    ('Kopi Kapal Api Mix', 'Minuman & Kopi', 14000, 12000, 'renceng', 15, 5),
    ('Teh Botol Sosro 350ml', 'Minuman & Kopi', 5000, 3700, 'btl', 24, 6),
  ];

  var added = 0;
  for (final (name, cat, sell, cost, unit, stock, min) in items) {
    if (existing.contains(name)) continue;
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
  }
  return added;
}

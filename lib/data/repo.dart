import 'package:sqflite/sqflite.dart';

import '../core/cart.dart';

class InsufficientStock implements Exception {
  InsufficientStock(this.name, this.available);
  final String name;
  final int available;
  @override
  String toString() => 'Stok $name tidak cukup (sisa $available)';
}

class Repo {
  Repo(this.db);
  final Database db;

  int _now() => DateTime.now().millisecondsSinceEpoch;

  // ---------- Toko ----------
  Future<Map<String, Object?>?> store() async {
    final rows = await db.query('store', where: 'id = 1');
    return rows.isEmpty ? null : rows.first;
  }

  Future<void> createStore({
    required String name,
    required String owner,
    required String pinHash,
    required String pinSalt,
  }) async {
    await db.insert('store', {
      'id': 1,
      'name': name,
      'owner_name': owner,
      'pin_hash': pinHash,
      'pin_salt': pinSalt,
    });
  }

  Future<void> updateStore(Map<String, Object?> values) =>
      db.update('store', values, where: 'id = 1');

  // ---------- Kategori ----------
  Future<List<Map<String, Object?>>> categories() =>
      db.query('category', orderBy: 'name');

  Future<int> addCategory(String name) =>
      db.insert('category', {'name': name.trim()});

  // ---------- Produk ----------
  Future<List<Map<String, Object?>>> products({
    String query = '',
    int? categoryId,
    bool includeArchived = false,
  }) {
    final where = <String>[];
    final args = <Object?>[];
    if (!includeArchived) where.add('p.active = 1');
    if (query.trim().isNotEmpty) {
      where.add('(p.name LIKE ? OR p.sku LIKE ?)');
      args.addAll(['%${query.trim()}%', '%${query.trim()}%']);
    }
    if (categoryId != null) {
      where.add('p.category_id = ?');
      args.add(categoryId);
    }
    return db.rawQuery('''
      SELECT p.*, c.name AS category_name FROM product p
      LEFT JOIN category c ON c.id = p.category_id
      ${where.isEmpty ? '' : 'WHERE ${where.join(' AND ')}'}
      ORDER BY p.name
    ''', args);
  }

  Future<Map<String, Object?>?> product(int id) async {
    final rows = await db.query('product', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<int> addProduct({
    required String name,
    required int? categoryId,
    required int sellPrice,
    required int costPrice,
    required String unit,
    required int stock,
    required int minStock,
    String? barcode,
  }) async {
    return db.transaction((txn) async {
      final id = await txn.insert('product', {
        'sku': 'TMP',
        'name': name.trim(),
        'category_id': categoryId,
        'sell_price': sellPrice,
        'cost_price': costPrice,
        'unit': unit,
        'stock': 0,
        'min_stock': minStock,
        'barcode': barcode,
      });
      final sku = 'SKU-${id.toString().padLeft(5, '0')}';
      await txn.update('product', {'sku': sku}, where: 'id = ?', whereArgs: [id]);
      if (stock > 0) {
        await _changeStock(txn, id, stock, 'IN', null);
      }
      return id;
    });
  }

  /// Ubah data produk, tidak termasuk stok (stok lewat [adjustStock]).
  Future<void> updateProduct(int id, Map<String, Object?> values) =>
      db.update('product', values, where: 'id = ?', whereArgs: [id]);

  Future<void> archiveProduct(int id) =>
      db.update('product', {'active': 0}, where: 'id = ?', whereArgs: [id]);

  Future<void> adjustStock(int productId, int delta, {required String reason}) {
    return db.transaction((txn) async {
      final before = await _stockOf(txn, productId);
      if (before + delta < 0) {
        throw InsufficientStock('produk', before);
      }
      await _changeStock(txn, productId, delta, reason, null);
    });
  }

  Future<List<Map<String, Object?>>> lowStock() => db.rawQuery('''
      SELECT * FROM product
      WHERE active = 1 AND min_stock > 0 AND stock <= min_stock
      ORDER BY (stock = 0) DESC, CAST(stock AS REAL) / min_stock ASC, name
    ''');

  Future<int> _stockOf(DatabaseExecutor e, int productId) async {
    final rows = await e.query('product',
        columns: ['stock'], where: 'id = ?', whereArgs: [productId]);
    return rows.first['stock'] as int;
  }

  Future<void> _changeStock(
      DatabaseExecutor e, int productId, int delta, String reason, int? ref) async {
    final before = await _stockOf(e, productId);
    final after = before + delta;
    await e.update('product', {'stock': after},
        where: 'id = ?', whereArgs: [productId]);
    await e.insert('stock_log', {
      'product_id': productId,
      'delta': delta,
      'before': before,
      'after': after,
      'reason': reason,
      'ref_id': ref,
      'created_at': _now(),
    });
  }

  // ---------- Penjualan ----------
  /// Simpan transaksi dan kurangi stok dalam satu transaksi DB.
  /// Mengembalikan id penjualan. Nomor berformat TRX-YYYYMMDD-0001.
  Future<int> checkout({
    required List<CartLine> lines,
    required String method,
    required int paid,
  }) {
    return db.transaction((txn) async {
      final total = lines.fold<int>(0, (s, l) => s + l.subtotal);
      if (lines.isEmpty) throw StateError('Keranjang kosong');
      if (paid < total && method == 'CASH') {
        throw ArgumentError('Uang diterima kurang dari total');
      }
      // Validasi ulang stok di dalam transaksi.
      for (final l in lines) {
        final stock = await _stockOf(txn, l.productId);
        if (stock < l.qty) throw InsufficientStock(l.name, stock);
      }
      final now = DateTime.now();
      final day = _dayKey(now);
      final count = Sqflite.firstIntValue(await txn.rawQuery(
              'SELECT COUNT(*) FROM sale WHERE number LIKE ?', ['TRX-$day-%'])) ??
          0;
      final number = 'TRX-$day-${(count + 1).toString().padLeft(4, '0')}';
      final saleId = await txn.insert('sale', {
        'number': number,
        'created_at': now.millisecondsSinceEpoch,
        'subtotal': total,
        'total': total,
        'method': method,
        'paid': paid,
        'change': paid >= total ? paid - total : 0,
        'status': 'DONE',
      });
      for (final l in lines) {
        await txn.insert('sale_item', {
          'sale_id': saleId,
          'product_id': l.productId,
          'name_snapshot': l.name,
          'qty': l.qty,
          'price': l.price,
          'cost': l.cost,
        });
        await _changeStock(txn, l.productId, -l.qty, 'SALE', saleId);
      }
      return saleId;
    });
  }

  /// Batalkan transaksi DONE: status VOID dan stok dikembalikan.
  Future<void> voidSale(int saleId) {
    return db.transaction((txn) async {
      final rows = await txn.query('sale', where: 'id = ?', whereArgs: [saleId]);
      if (rows.isEmpty) throw StateError('Transaksi tidak ditemukan');
      if (rows.first['status'] != 'DONE') {
        throw StateError('Transaksi sudah dibatalkan');
      }
      await txn.update('sale', {'status': 'VOID'},
          where: 'id = ?', whereArgs: [saleId]);
      final items = await txn.query('sale_item',
          where: 'sale_id = ?', whereArgs: [saleId]);
      for (final it in items) {
        await _changeStock(
            txn, it['product_id'] as int, it['qty'] as int, 'VOID', saleId);
      }
    });
  }

  Future<Map<String, Object?>?> saleById(int id) async {
    final rows = await db.query('sale', where: 'id = ?', whereArgs: [id]);
    return rows.isEmpty ? null : rows.first;
  }

  Future<List<Map<String, Object?>>> sales({int limit = 100}) =>
      db.query('sale', orderBy: 'created_at DESC', limit: limit);

  Future<List<Map<String, Object?>>> saleItems(int saleId) => db.query(
      'sale_item', where: 'sale_id = ?', whereArgs: [saleId], orderBy: 'id');

  /// Ringkasan rentang waktu [from, to) untuk transaksi DONE.
  Future<Report> report(DateTime from, DateTime to) async {
    final args = [from.millisecondsSinceEpoch, to.millisecondsSinceEpoch];
    final sum = await db.rawQuery('''
      SELECT COUNT(*) AS n, COALESCE(SUM(total),0) AS omzet FROM sale
      WHERE status = 'DONE' AND created_at >= ? AND created_at < ?''', args);
    final profit = await db.rawQuery('''
      SELECT COALESCE(SUM((si.price - si.cost) * si.qty),0) AS laba
      FROM sale_item si JOIN sale s ON s.id = si.sale_id
      WHERE s.status = 'DONE' AND s.created_at >= ? AND s.created_at < ?''', args);
    final methods = await db.rawQuery('''
      SELECT method, COALESCE(SUM(total),0) AS amount FROM sale
      WHERE status = 'DONE' AND created_at >= ? AND created_at < ?
      GROUP BY method''', args);
    final top = await db.rawQuery('''
      SELECT si.product_id, si.name_snapshot AS name, SUM(si.qty) AS qty,
             SUM(si.price * si.qty) AS revenue
      FROM sale_item si JOIN sale s ON s.id = si.sale_id
      WHERE s.status = 'DONE' AND s.created_at >= ? AND s.created_at < ?
      GROUP BY si.product_id ORDER BY qty DESC LIMIT 5''', args);
    return Report(
      count: sum.first['n'] as int,
      omzet: sum.first['omzet'] as int,
      profit: profit.first['laba'] as int,
      byMethod: {
        for (final m in methods) m['method'] as String: m['amount'] as int
      },
      topProducts: top,
    );
  }

  static String _dayKey(DateTime d) =>
      '${d.year}${d.month.toString().padLeft(2, '0')}${d.day.toString().padLeft(2, '0')}';
}

class Report {
  Report({
    required this.count,
    required this.omzet,
    required this.profit,
    required this.byMethod,
    required this.topProducts,
  });
  final int count;
  final int omzet;
  final int profit;
  final Map<String, int> byMethod;
  final List<Map<String, Object?>> topProducts;
}

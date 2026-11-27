import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dodo/core/cart.dart';
import 'package:kasir_dodo/data/app_db.dart';
import 'package:kasir_dodo/data/repo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  late Repo repo;

  setUpAll(sqfliteFfiInit);

  tearDown(() => repo.db.close());

  setUp(() async {
    final db = await openAppDb(databaseFactoryFfi, inMemoryDatabasePath);
    repo = Repo(db);
    await repo.createStore(name: 'Toko', owner: 'Bu Sari', pinHash: 'x', pinSalt: 'y');
  });

  Future<int> teh({int stock = 10}) => repo.addProduct(
      name: 'Teh Botol', categoryId: null, sellPrice: 5000, costPrice: 3500,
      unit: 'pcs', stock: stock, minStock: 5);

  CartLine line(int id, int qty, {String name = 'Teh Botol'}) {
    final c = Cart()
      ..add(productId: id, name: name, price: 5000, cost: 3500, stock: 999);
    c.setQty(id, qty);
    return c.lines.single;
  }

  test('checkout mengurangi stok dan mencatat nomor transaksi', () async {
    final id = await teh();
    final saleId = await repo.checkout(
        lines: [line(id, 3)], method: 'CASH', paid: 20000);
    expect((await repo.product(id))!['stock'], 7);
    final sale = (await repo.sales()).single;
    expect(sale['id'], saleId);
    expect(sale['change'], 5000);
    expect(sale['number'], startsWith('TRX-'));
    expect(sale['number'], endsWith('-0001'));
  });

  test('stok tidak cukup membatalkan seluruh transaksi', () async {
    final a = await teh(stock: 10);
    final b = await repo.addProduct(name: 'Roti', categoryId: null,
        sellPrice: 3000, costPrice: 2000, unit: 'pcs', stock: 1, minStock: 1);
    await expectLater(
      repo.checkout(
        lines: [line(a, 2), line(b, 5, name: 'Roti')],
        method: 'CASH', paid: 100000),
      throwsA(isA<InsufficientStock>()),
    );
    expect((await repo.product(a))!['stock'], 10);
    expect((await repo.product(b))!['stock'], 1);
    expect(await repo.sales(), isEmpty);
  });

  test('void mengembalikan stok dan tidak bisa dua kali', () async {
    final id = await teh();
    final saleId = await repo.checkout(
        lines: [line(id, 4)], method: 'TRANSFER', paid: 20000);
    await repo.voidSale(saleId);
    expect((await repo.product(id))!['stock'], 10);
    expect((await repo.sales()).single['status'], 'VOID');
    await expectLater(repo.voidSale(saleId), throwsStateError);
  });

  test('laporan hanya menghitung transaksi DONE', () async {
    final id = await teh();
    final s1 = await repo.checkout(
        lines: [line(id, 2)], method: 'CASH', paid: 10000);
    await repo.checkout(lines: [line(id, 1)], method: 'QRIS', paid: 5000);
    await repo.voidSale(s1);
    final now = DateTime.now();
    final r = await repo.report(
        DateTime(now.year, now.month, now.day), now.add(const Duration(days: 1)));
    expect(r.count, 1);
    expect(r.omzet, 5000);
    expect(r.profit, 1500);
    expect(r.byMethod, {'QRIS': 5000});
  });

  test('kartu stok mencatat masuk, jual, dan void (terbaru di atas)', () async {
    final id = await teh(stock: 10);
    await repo.adjustStock(id, 20, reason: 'IN');
    final saleId = await repo.checkout(
        lines: [line(id, 3)], method: 'CASH', paid: 15000);
    await repo.voidSale(saleId);
    final log = await repo.stockLog(id);
    expect(log.map((e) => e['reason']), ['VOID', 'SALE', 'IN', 'IN']);
    expect(log.map((e) => e['delta']), [3, -3, 20, 10]);
    expect(log.first['after'], 30);
    expect(await repo.stockLog(id + 99), isEmpty);
  });

  test('stok menipis diurutkan dari yang habis', () async {
    await teh(stock: 5); // stok <= min 5
    await repo.addProduct(name: 'Gula', categoryId: null, sellPrice: 1,
        costPrice: 1, unit: 'kg', stock: 0, minStock: 3);
    await repo.addProduct(name: 'Aman', categoryId: null, sellPrice: 1,
        costPrice: 1, unit: 'pcs', stock: 50, minStock: 3);
    final low = await repo.lowStock();
    expect(low.map((e) => e['name']), ['Gula', 'Teh Botol']);
  });
}

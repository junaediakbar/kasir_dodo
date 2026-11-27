import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dodo/core/cart.dart';
import 'package:kasir_dodo/core/money.dart';
import 'package:kasir_dodo/screens/payment_screen.dart';

void main() {
  test('rp memformat ribuan dengan titik', () {
    expect(rp(15000), 'Rp 15.000');
    expect(rp(0), 'Rp 0');
    expect(rp(1250000), 'Rp 1.250.000');
  });

  test('kembalian benar dan menolak uang kurang', () {
    expect(changeFor(total: 18000, paid: 20000), 2000);
    expect(changeFor(total: 18000, paid: 18000), 0);
    expect(() => changeFor(total: 18000, paid: 17000), throwsArgumentError);
  });

  test('total dan laba dari keranjang', () {
    final c = Cart();
    c.add(productId: 1, name: 'Teh', price: 5000, cost: 3500, stock: 10);
    c.add(productId: 1, name: 'Teh', price: 5000, cost: 3500, stock: 10);
    c.add(productId: 2, name: 'Roti', price: 3000, cost: 2000, stock: 5);
    expect(c.total, 13000);
    expect(c.profit, 3000 + 1000);
  });

  test('tidak bisa melebihi stok', () {
    final c = Cart();
    c.add(productId: 1, name: 'Teh', price: 5000, cost: 3500, stock: 1);
    expect(
      () => c.add(productId: 1, name: 'Teh', price: 5000, cost: 3500, stock: 1),
      throwsStateError,
    );
    expect(() => c.setQty(1, 2), throwsStateError);
  });

  test('setQty 0 menghapus baris', () {
    final c = Cart();
    c.add(productId: 1, name: 'Teh', price: 5000, cost: 3500, stock: 5);
    c.setQty(1, 0);
    expect(c.isEmpty, isTrue);
  });

  test('saran uang tunai: pembulatan ke atas, di atas total, maks 3', () {
    expect(quickCash(65000), [70000, 80000, 100000]);
    expect(quickCash(5000), [10000, 20000, 50000]);
    expect(quickCash(100000), isEmpty); // sudah bulat: cukup Uang pas
    expect(quickCash(123400), [125000, 130000, 140000]);
    expect(quickCash(0), isEmpty);
  });
}

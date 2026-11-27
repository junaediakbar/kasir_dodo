import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dodo/data/app_db.dart';
import 'package:kasir_dodo/data/repo.dart';
import 'package:kasir_dodo/screens/products_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('katalog kosong menampilkan tombol data contoh yang mengisi produk',
      (tester) async {
    final repo = Repo((await tester.runAsync(
        () => openAppDb(databaseFactoryFfi, inMemoryDatabasePath)))!);

    Future<void> settle() async {
      for (var i = 0; i < 5; i++) {
        await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
        await tester.pump();
      }
    }

    await tester.pumpWidget(MaterialApp(home: Scaffold(body: ProductsScreen(repo: repo))));
    await settle();
    expect(find.text('Isi data contoh'), findsOneWidget);

    await tester.tap(find.text('Isi data contoh'));
    await settle();
    expect(find.text('Isi data contoh'), findsNothing);
    expect(find.text('Indomie Goreng Spesial'), findsOneWidget);

    await tester.runAsync(() => repo.db.close());
  });
}

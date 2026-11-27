import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dodo/data/app_db.dart';
import 'package:kasir_dodo/data/repo.dart';
import 'package:kasir_dodo/data/seed_demo.dart';
import 'package:kasir_dodo/screens/stok_screen.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  testWidgets('stok menampilkan produk, yang habis/menipis di atas', (tester) async {
    final repo = Repo((await tester.runAsync(
        () => openAppDb(databaseFactoryFfi, inMemoryDatabasePath)))!);
    await tester.runAsync(() => seedDemo(repo));
    await tester.binding.setSurfaceSize(const Size(400, 2400));

    await tester.pumpWidget(MaterialApp(home: StokScreen(repo: repo)));
    for (var i = 0; i < 5; i++) {
      await tester.runAsync(() => Future.delayed(const Duration(milliseconds: 50)));
      await tester.pump();
    }

    expect(find.text('Isi data contoh'), findsNothing);
    final habis = tester.getTopLeft(find.text('Kecap Manis Bango 550ml')).dy;
    final aman = tester.getTopLeft(find.text('Indomie Goreng Spesial')).dy;
    expect(habis, lessThan(aman));

    await tester.runAsync(() => repo.db.close());
  });
}

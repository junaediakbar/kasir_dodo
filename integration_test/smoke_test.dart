import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:kasir_dodo/data/app_db.dart';
import 'package:kasir_dodo/data/repo.dart';
import 'package:kasir_dodo/main.dart' show KasirApp;

void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('alur Hari 1: setup, produk, jual tunai', (tester) async {
    final dir = await getDatabasesPath();
    final path = p.join(dir, 'smoke_test.db');
    await File(path).parent.create(recursive: true);
    await deleteDatabase(path);
    final db = await openAppDb(databaseFactory, path);
    final repo = Repo(db);

    await tester.pumpWidget(KasirApp(repo: repo));
    await tester.pumpAndSettle();

    // Setup toko & PIN
    expect(find.text('Selamat datang di Kasir Dodo'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Toko Uji');
    await tester.enterText(fields.at(1), 'Bu Sari');
    await tester.enterText(fields.at(2), '123456');
    await tester.enterText(fields.at(3), '123456');
    await tester.tap(find.text('Mulai'));
    await tester.pumpAndSettle();

    // Kunci PIN -> buka
    await tester.enterText(find.byType(TextField).first, '123456');
    await tester.tap(find.text('Buka'));
    await tester.pumpAndSettle();
    expect(find.text('Kasir'), findsWidgets);

    // Tambah produk di tab Produk
    await tester.tap(find.text('Produk'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Tambah produk'));
    await tester.pumpAndSettle();
    final pf = find.byType(TextFormField);
    await tester.enterText(pf.at(0), 'Teh Botol');
    await tester.enterText(pf.at(1), '5000');
    await tester.enterText(pf.at(2), '3500');
    await tester.enterText(pf.at(5), '10');
    await tester.tap(find.text('Simpan'));
    await tester.pumpAndSettle();
    expect(find.text('Teh Botol'), findsOneWidget);

    // Jual di tab Kasir
    await tester.tap(find.text('Kasir').last);
    await tester.pumpAndSettle();
    await tester.tap(find.text('Teh Botol'));
    await tester.pumpAndSettle();
    await tester.tap(find.textContaining('Bayar Rp 5.000'));
    await tester.pumpAndSettle();

    await tester.enterText(find.byType(TextField).first, '10000');
    await tester.pump();
    expect(find.text('Kembalian Rp 5.000'), findsOneWidget);
    await tester.tap(find.text('Selesaikan'));
    await tester.pumpAndSettle();
    expect(find.text('Transaksi selesai'), findsOneWidget);
    await tester.tap(find.text('Oke'));
    await tester.pumpAndSettle();

    // Stok harus berkurang dari 10 menjadi 9
    final sale = (await repo.sales()).single;
    expect(sale['status'], 'DONE');
    final prod = (await repo.products()).single;
    expect(prod['stock'], 9);

    await db.close();
  });
}

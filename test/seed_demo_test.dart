import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dodo/data/app_db.dart';
import 'package:kasir_dodo/data/repo.dart';
import 'package:kasir_dodo/data/seed_demo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('seed mengisi produk contoh dan tidak menggandakan saat dijalankan ulang', () async {
    final db = await openAppDb(databaseFactoryFfi, inMemoryDatabasePath);
    final repo = Repo(db);
    addTearDown(db.close);

    expect(await seedDemo(repo), 7);
    expect(await seedDemo(repo), 0);
    expect((await repo.products()).length, 7);
    expect((await repo.categories()).length, 4);
    expect((await repo.lowStock()).map((e) => e['name']),
        contains('Gula Pasir Gulaku 1kg'));
  });
}

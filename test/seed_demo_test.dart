import 'package:flutter_test/flutter_test.dart';
import 'package:kasir_dodo/data/app_db.dart';
import 'package:kasir_dodo/data/repo.dart';
import 'package:kasir_dodo/data/seed_demo.dart';
import 'package:sqflite_common_ffi/sqflite_ffi.dart';

void main() {
  setUpAll(sqfliteFfiInit);

  test('seed mengisi katalog, memperbarui nilai lama, dan tidak menggandakan', () async {
    final db = await openAppDb(databaseFactoryFfi, inMemoryDatabasePath);
    final repo = Repo(db);
    addTearDown(db.close);

    expect(await seedDemo(repo), 7);
    expect(await seedDemo(repo), 0);
    final all = await repo.products();
    expect(all.length, 7);
    expect((await repo.categories()).length, 4);

    final bimoli = all.firstWhere((p) => p['name'] == 'Minyak Goreng Bimoli 1L Pouch');
    expect(bimoli['stock'], 18);
    expect(bimoli['cost_price'], 16500);
    expect((await repo.lowStock()).map((e) => e['name']),
        contains('Gula Pasir Gulaku 1kg'));
  });
}

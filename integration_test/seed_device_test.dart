import 'package:flutter_test/flutter_test.dart';
import 'package:integration_test/integration_test.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'package:kasir_dodo/data/app_db.dart';
import 'package:kasir_dodo/data/repo.dart';
import 'package:kasir_dodo/data/seed_demo.dart';

/// Mengisi database aplikasi di emulator dengan data contoh. Tidak membuat toko/PIN.
void main() {
  IntegrationTestWidgetsFlutterBinding.ensureInitialized();

  testWidgets('isi data contoh ke database aplikasi', (tester) async {
    final dir = await getDatabasesPath();
    final db = await openAppDb(databaseFactory, p.join(dir, 'kasir_dodo.db'));
    final added = await seedDemo(Repo(db));
    await db.close();
    // ignore: avoid_print
    print('SEED_ADDED=$added');
    expect(added, greaterThanOrEqualTo(0));
  });
}

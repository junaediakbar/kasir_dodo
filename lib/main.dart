import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'data/app_db.dart';
import 'data/repo.dart';
import 'data/seed_demo.dart';
import 'screens/gate.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getDatabasesPath();
  final db = await openAppDb(databaseFactory, p.join(dir, 'kasir_dodo.db'));
  final repo = Repo(db);
  // `flutter run --dart-define=SEED_DEMO=true` mengisi data contoh tanpa menghapus data app.
  if (const bool.fromEnvironment('SEED_DEMO')) {
    debugPrint('SEED_ADDED=${await seedDemo(repo)}');
  }
  runApp(KasirApp(repo: repo));
}

class KasirApp extends StatelessWidget {
  const KasirApp({super.key, required this.repo});
  final Repo repo;

  @override
  Widget build(BuildContext context) => MaterialApp(
        title: 'Kasir Dodo',
        debugShowCheckedModeBanner: false,
        theme: buildTheme(),
        home: Gate(repo: repo),
      );
}

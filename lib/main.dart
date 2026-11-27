import 'package:flutter/material.dart';
import 'package:path/path.dart' as p;
import 'package:sqflite/sqflite.dart';

import 'data/app_db.dart';
import 'data/repo.dart';
import 'screens/gate.dart';
import 'theme.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  final dir = await getDatabasesPath();
  final db = await openAppDb(databaseFactory, p.join(dir, 'kasir_dodo.db'));
  runApp(KasirApp(repo: Repo(db)));
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

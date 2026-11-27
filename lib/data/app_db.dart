import 'package:sqflite/sqflite.dart';

const _schemaV1 = [
  '''CREATE TABLE store (
      id INTEGER PRIMARY KEY CHECK (id = 1),
      name TEXT NOT NULL,
      owner_name TEXT NOT NULL,
      address TEXT NOT NULL DEFAULT '',
      phone TEXT NOT NULL DEFAULT '',
      receipt_footer TEXT NOT NULL DEFAULT 'Terima kasih sudah belanja',
      pin_hash TEXT NOT NULL,
      pin_salt TEXT NOT NULL,
      ai_model TEXT NOT NULL DEFAULT 'deepseek-v4-flash-vision-exp',
      ai_threshold REAL NOT NULL DEFAULT 0.85,
      ai_enabled INTEGER NOT NULL DEFAULT 0
    )''',
  '''CREATE TABLE category (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      name TEXT NOT NULL UNIQUE
    )''',
  '''CREATE TABLE product (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sku TEXT NOT NULL UNIQUE,
      name TEXT NOT NULL,
      category_id INTEGER REFERENCES category(id),
      sell_price INTEGER NOT NULL CHECK (sell_price >= 0),
      cost_price INTEGER NOT NULL DEFAULT 0 CHECK (cost_price >= 0),
      unit TEXT NOT NULL DEFAULT 'pcs',
      stock INTEGER NOT NULL DEFAULT 0 CHECK (stock >= 0),
      min_stock INTEGER NOT NULL DEFAULT 5,
      barcode TEXT,
      photo_path TEXT,
      active INTEGER NOT NULL DEFAULT 1
    )''',
  '''CREATE TABLE sale (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      number TEXT NOT NULL UNIQUE,
      created_at INTEGER NOT NULL,
      subtotal INTEGER NOT NULL,
      total INTEGER NOT NULL,
      method TEXT NOT NULL CHECK (method IN ('CASH','TRANSFER','QRIS')),
      paid INTEGER NOT NULL,
      change INTEGER NOT NULL,
      status TEXT NOT NULL CHECK (status IN ('DONE','VOID'))
    )''',
  '''CREATE TABLE sale_item (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      sale_id INTEGER NOT NULL REFERENCES sale(id),
      product_id INTEGER NOT NULL REFERENCES product(id),
      name_snapshot TEXT NOT NULL,
      qty INTEGER NOT NULL CHECK (qty > 0),
      price INTEGER NOT NULL,
      cost INTEGER NOT NULL
    )''',
  '''CREATE TABLE stock_log (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      product_id INTEGER NOT NULL REFERENCES product(id),
      delta INTEGER NOT NULL,
      before INTEGER NOT NULL,
      after INTEGER NOT NULL,
      reason TEXT NOT NULL CHECK (reason IN ('SALE','VOID','IN','CORRECTION')),
      ref_id INTEGER,
      created_at INTEGER NOT NULL
    )''',
];

/// Membuka database dan menerapkan skema. [path] `inMemoryDatabasePath` untuk test.
Future<Database> openAppDb(DatabaseFactory factory, String path) {
  return factory.openDatabase(
    path,
    options: OpenDatabaseOptions(
      version: 1,
      onConfigure: (db) => db.execute('PRAGMA foreign_keys = ON'),
      onCreate: (db, _) async {
        for (final sql in _schemaV1) {
          await db.execute(sql);
        }
      },
    ),
  );
}

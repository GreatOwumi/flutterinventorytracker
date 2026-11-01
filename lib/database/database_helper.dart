import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/product.dart';
import 'product_repository.dart';

class DatabaseHelper implements ProductRepository {
  // One shared database for the whole app
  DatabaseHelper._internal();
  static final DatabaseHelper instance = DatabaseHelper._internal();

  Future<Database>? _opening;

  // Opens the database the first time, then reuses it
  Future<Database> get database async {
    try {
      return await (_opening ??= _initDatabase());
    } catch (_) {
      _opening = null;
      rethrow;
    }
  }

  Future<Database> _initDatabase() async {
    final dbPath = await getDatabasesPath();
    final path = join(dbPath, 'inventory.db');

    return openDatabase(
      path,
      version: 1,
      onCreate: (db, version) async {
        await db.execute('''
          CREATE TABLE products (
            id INTEGER PRIMARY KEY AUTOINCREMENT,
            name TEXT NOT NULL,
            category TEXT NOT NULL,
            price REAL NOT NULL,
            stock INTEGER NOT NULL,
            minStock INTEGER NOT NULL
          )
        ''');
      },
    );
  }

  // CREATE: add a new product
  @override
  Future<int> insertProduct(Product product) async {
    final db = await database;
    final values = product.toMap()..remove('id');
    return db.insert('products', values);
  }

  // READ: get all products
  @override
  Future<List<Product>> getProducts() async {
    final db = await database;
    final rows = await db.query(
      'products',
      orderBy: 'name COLLATE NOCASE ASC, id ASC',
    );
    return rows.map((row) => Product.fromMap(row)).toList();
  }

  // UPDATE: change an existing product
  @override
  Future<int> updateProduct(Product product) async {
    final db = await database;
    return db.update(
      'products',
      product.toMap(),
      where: 'id = ?',
      whereArgs: [product.id],
    );
  }

  // DELETE: remove a product
  @override
  Future<int> deleteProduct(int id) async {
    final db = await database;
    return db.delete('products', where: 'id = ?', whereArgs: [id]);
  }

  // Read the current quantity inside SQLite so stale UI snapshots cannot
  // overwrite another stock adjustment. The guard also prevents underflow.
  @override
  Future<void> adjustStock(int id, int delta) async {
    final db = await database;
    final changed = await db.rawUpdate(
      'UPDATE products SET stock = stock + ? '
      'WHERE id = ? AND stock + ? >= 0 AND stock + ? <= 2147483647',
      [delta, id, delta, delta],
    );
    if (changed != 1) {
      throw Exception('Stock change failed. Check the quantity and refresh.');
    }
  }
}

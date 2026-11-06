import 'package:sqflite/sqflite.dart';
import 'package:path/path.dart';

import '../models/product.dart';
import '../models/sale.dart';
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
      version: 2,
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
        await _createSales(db);
      },
      onUpgrade: (db, oldVersion, newVersion) async {
        if (oldVersion < 2) await _createSales(db);
      },
    );
  }

  Future<void> _createSales(Database db) => db.execute('''
    CREATE TABLE sales (
      id INTEGER PRIMARY KEY AUTOINCREMENT,
      request_id TEXT NOT NULL UNIQUE,
      product_id INTEGER NOT NULL,
      product_name TEXT NOT NULL,
      quantity INTEGER NOT NULL CHECK (quantity > 0),
      unit_price REAL NOT NULL CHECK (unit_price >= 1),
      payment_method TEXT NOT NULL CHECK (payment_method IN ('cash', 'transfer')),
      sold_at TEXT NOT NULL
    )
  ''');

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
  Future<int> updateProduct(Product product, {int? expectedStock}) async {
    final db = await database;
    return db.update(
      'products',
      product.toMap(),
      where: expectedStock == null ? 'id = ?' : 'id = ? AND stock = ?',
      whereArgs: [product.id, ?expectedStock],
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

  @override
  Future<List<Sale>> getSales() async {
    final db = await database;
    final rows = await db.query('sales', orderBy: 'sold_at DESC, id DESC');
    return rows.map(Sale.fromMap).toList();
  }

  @override
  Future<Sale> sellProduct({
    required int productId,
    required int quantity,
    required double expectedPrice,
    required String paymentMethod,
    required String requestId,
  }) async {
    final db = await database;
    // The receipt and stock change succeed together, or neither is saved.
    return db.transaction((txn) async {
      final previous = await txn.query(
        'sales',
        where: 'request_id = ?',
        whereArgs: [requestId],
      );
      if (previous.isNotEmpty) {
        final sale = Sale.fromMap(previous.single);
        if (sale.productId != productId ||
            sale.quantity != quantity ||
            sale.paymentMethod != paymentMethod ||
            sale.unitPrice != expectedPrice) {
          throw Exception('Sale reference already used for a different sale.');
        }
        return sale;
      }
      final rows = await txn.query(
        'products',
        where: 'id = ?',
        whereArgs: [productId],
      );
      if (rows.isEmpty) throw Exception('Product no longer exists.');
      final product = Product.fromMap(rows.single);
      if (quantity < 1 || quantity > product.stock) {
        throw Exception('Not enough stock.');
      }
      if (product.price != expectedPrice) {
        throw Exception('Price changed. Refresh and try again.');
      }
      final values = <String, Object?>{
        'request_id': requestId,
        'product_id': productId,
        'product_name': product.name,
        'quantity': quantity,
        'unit_price': product.price,
        'payment_method': paymentMethod,
        'sold_at': DateTime.now().toUtc().toIso8601String(),
      };
      final id = await txn.insert('sales', values);
      await txn.rawUpdate(
        'UPDATE products SET stock = stock - ? WHERE id = ?',
        [quantity, productId],
      );
      return Sale.fromMap({...values, 'id': id});
    });
  }
}

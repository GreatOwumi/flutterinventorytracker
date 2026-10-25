import '../database/database_helper.dart';
import '../models/product.dart';

class ProductService {
  final DatabaseHelper _db = DatabaseHelper.instance;

  // Get all products
  Future<List<Product>> getAllProducts() {
    return _db.getProducts();
  }

  // Add a product (after checking it is valid)
  Future<void> addProduct(Product product) async {
    _validate(product);
    await _db.insertProduct(product);
  }

  // Edit a product (after checking it is valid)
  Future<void> updateProduct(Product product) async {
    _validate(product);
    await _db.updateProduct(product);
  }

  // Delete a product
  Future<void> deleteProduct(int id) async {
    await _db.deleteProduct(id);
  }

  // Stock arrives: increase stock
  Future<void> increaseStock(Product product, [int amount = 1]) async {
    final updated = product.copyWith(stock: product.stock + amount);
    await _db.updateProduct(updated);
  }

  // Stock leaves: decrease stock, but never below zero
  Future<void> decreaseStock(Product product, [int amount = 1]) async {
    if (product.stock - amount < 0) {
      throw Exception('Stock cannot go below zero');
    }
    final updated = product.copyWith(stock: product.stock - amount);
    await _db.updateProduct(updated);
  }

  // The rules every product must follow
  void _validate(Product product) {
    if (product.name.trim().isEmpty) {
      throw Exception('Product name is required');
    }
    if (product.category.trim().isEmpty) {
      throw Exception('Category is required');
    }
    if (product.price < 0) {
      throw Exception('Price cannot be negative');
    }
    if (product.stock < 0) {
      throw Exception('Stock cannot be negative');
    }
    if (product.minStock < 0) {
      throw Exception('Minimum stock cannot be negative');
    }
  }
}
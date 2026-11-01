import '../database/database_helper.dart';
import '../database/product_repository.dart';
import '../models/product.dart';

class ProductService {
  ProductService({ProductRepository? repository})
    : _db = repository ?? DatabaseHelper.instance;

  final ProductRepository _db;
  static const maxQuantity = 2147483647;

  // Get all products
  Future<List<Product>> getAllProducts() {
    return _db.getProducts();
  }

  // Add a product (after checking it is valid)
  Future<void> addProduct(Product product) async {
    _validate(product);
    await _db.insertProduct(_normalized(product));
  }

  // Edit a product (after checking it is valid)
  Future<void> updateProduct(Product product) async {
    _validate(product);
    _requireId(product.id);
    if (await _db.updateProduct(_normalized(product)) != 1) {
      throw Exception('Product no longer exists. Refresh and try again.');
    }
  }

  // Delete a product
  Future<void> deleteProduct(int id) async {
    _requireId(id);
    if (await _db.deleteProduct(id) != 1) {
      throw Exception('Product no longer exists. Refresh and try again.');
    }
  }

  // Stock arrives: increase stock
  Future<void> increaseStock(Product product, [int amount = 1]) async {
    _validateAmount(amount);
    await _db.adjustStock(_requireId(product.id), amount);
  }

  // Stock leaves: decrease stock, but never below zero
  Future<void> decreaseStock(Product product, [int amount = 1]) async {
    _validateAmount(amount);
    await _db.adjustStock(_requireId(product.id), -amount);
  }

  Product _normalized(Product product) => product.copyWith(
    name: product.name.trim(),
    category: product.category.trim(),
  );

  int _requireId(int? id) {
    if (id == null || id <= 0) throw Exception('A saved product is required');
    return id;
  }

  void _validateAmount(int amount) {
    if (amount <= 0 || amount > maxQuantity) {
      throw Exception('Stock amount must be between 1 and $maxQuantity');
    }
  }

  // The rules every product must follow
  void _validate(Product product) {
    if (product.name.trim().isEmpty) {
      throw Exception('Product name is required');
    }
    if (product.category.trim().isEmpty) {
      throw Exception('Category is required');
    }
    if (!product.price.isFinite || product.price < 0) {
      throw Exception('Price must be a finite, non-negative number');
    }
    if (product.stock < 0 || product.stock > maxQuantity) {
      throw Exception('Stock must be between 0 and $maxQuantity');
    }
    if (product.minStock < 0 || product.minStock > maxQuantity) {
      throw Exception('Minimum stock must be between 0 and $maxQuantity');
    }
  }
}

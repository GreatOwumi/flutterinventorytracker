import '../models/product.dart';

abstract interface class ProductRepository {
  Future<List<Product>> getProducts();
  Future<int> insertProduct(Product product);
  Future<int> updateProduct(Product product);
  Future<int> deleteProduct(int id);
  Future<void> adjustStock(int id, int delta);
}

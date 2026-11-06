import '../models/product.dart';
import '../models/sale.dart';

abstract interface class ProductRepository {
  Future<List<Product>> getProducts();
  Future<int> insertProduct(Product product);
  Future<int> updateProduct(Product product, {int? expectedStock});
  Future<int> deleteProduct(int id);
  Future<void> adjustStock(int id, int delta);
  Future<Sale> sellProduct({
    required int productId,
    required int quantity,
    required double expectedPrice,
    required String paymentMethod,
    required String requestId,
  });
  Future<List<Sale>> getSales();
}

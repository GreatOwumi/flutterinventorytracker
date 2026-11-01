import 'package:inventory_tracker/database/product_repository.dart';
import 'package:inventory_tracker/models/product.dart';

class FakeProductRepository implements ProductRepository {
  final products = <int, Product>{};
  int _nextId = 1;
  bool failRead = false;
  bool failWrite = false;

  void _checkWrite() {
    if (failWrite) throw Exception('Storage unavailable');
  }

  @override
  Future<List<Product>> getProducts() async {
    if (failRead) throw Exception('Storage unavailable');
    return products.values.toList()..sort((a, b) => a.name.compareTo(b.name));
  }

  @override
  Future<int> insertProduct(Product product) async {
    _checkWrite();
    final id = _nextId++;
    products[id] = Product.fromMap({...product.toMap(), 'id': id});
    return id;
  }

  @override
  Future<int> updateProduct(Product product) async {
    _checkWrite();
    if (!products.containsKey(product.id)) return 0;
    products[product.id!] = product;
    return 1;
  }

  @override
  Future<int> deleteProduct(int id) async {
    _checkWrite();
    return products.remove(id) == null ? 0 : 1;
  }

  @override
  Future<void> adjustStock(int id, int delta) async {
    _checkWrite();
    final product = products[id];
    if (product == null ||
        product.stock + delta < 0 ||
        product.stock + delta > 2147483647) {
      throw Exception('Invalid stock adjustment');
    }
    products[id] = product.copyWith(stock: product.stock + delta);
  }
}

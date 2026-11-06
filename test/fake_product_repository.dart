import 'package:inventory_tracker/database/product_repository.dart';
import 'package:inventory_tracker/models/product.dart';
import 'package:inventory_tracker/models/sale.dart';

class FakeProductRepository implements ProductRepository {
  final products = <int, Product>{};
  final sales = <Sale>[];
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
  Future<int> updateProduct(Product product, {int? expectedStock}) async {
    _checkWrite();
    if (!products.containsKey(product.id)) return 0;
    if (expectedStock != null && products[product.id]!.stock != expectedStock) {
      return 0;
    }
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

  @override
  Future<List<Sale>> getSales() async {
    if (failRead) throw Exception('Storage unavailable');
    return sales.reversed.toList();
  }

  @override
  Future<Sale> sellProduct({
    required int productId,
    required int quantity,
    required double expectedPrice,
    required String paymentMethod,
    required String requestId,
  }) async {
    _checkWrite();
    final previous = sales.where((s) => s.requestId == requestId);
    if (previous.isNotEmpty) {
      final sale = previous.single;
      if (sale.productId != productId ||
          sale.quantity != quantity ||
          sale.unitPrice != expectedPrice ||
          sale.paymentMethod != paymentMethod) {
        throw Exception('Conflicting sale');
      }
      return sale;
    }
    final product = products[productId];
    if (product == null ||
        quantity < 1 ||
        quantity > product.stock ||
        product.price != expectedPrice) {
      throw Exception('Invalid sale');
    }
    final sale = Sale(
      id: sales.length + 1,
      requestId: requestId,
      productId: productId,
      productName: product.name,
      quantity: quantity,
      unitPrice: product.price,
      paymentMethod: paymentMethod,
      soldAt: DateTime.now(),
    );
    sales.add(sale);
    products[productId] = product.copyWith(stock: product.stock - quantity);
    return sale;
  }
}

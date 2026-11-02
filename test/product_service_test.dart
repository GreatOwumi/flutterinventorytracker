import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_tracker/models/product.dart';
import 'package:inventory_tracker/services/product_service.dart';

import 'fake_product_repository.dart';

Product sample() => Product(
  name: ' Rice ',
  category: ' Food ',
  price: 1500,
  stock: 3,
  minStock: 2,
);

void main() {
  late FakeProductRepository repository;
  late ProductService service;
  setUp(() {
    repository = FakeProductRepository();
    service = ProductService(repository: repository);
  });

  test('create, edit, reload and delete a product', () async {
    await service.addProduct(sample());
    final product = (await service.getAllProducts()).single;
    expect(product.name, 'Rice');
    expect(product.category, 'Food');
    await service.updateProduct(product.copyWith(name: 'Beans', price: 2000));
    expect((await service.getAllProducts()).single.name, 'Beans');
    await service.deleteProduct(product.id!);
    expect(await service.getAllProducts(), isEmpty);
  });

  test('rejects invalid fields before storage is touched', () async {
    for (final product in [
      sample().copyWith(name: ' '),
      sample().copyWith(category: ' '),
      sample().copyWith(price: -1),
      sample().copyWith(price: 0),
      sample().copyWith(price: 0.99),
      sample().copyWith(price: double.nan),
      sample().copyWith(price: double.infinity),
      sample().copyWith(stock: -1),
      sample().copyWith(minStock: -1),
      sample().copyWith(stock: 2147483648),
    ]) {
      await expectLater(service.addProduct(product), throwsException);
    }
    expect(repository.products, isEmpty);
  });

  test('price minimum applies when creating and editing products', () async {
    await service.addProduct(sample().copyWith(price: 1));
    final product = (await service.getAllProducts()).single;
    expect(product.price, 1);
    for (final price in [-1.0, 0.0, 0.99]) {
      await expectLater(
        service.updateProduct(product.copyWith(price: price)),
        throwsException,
      );
    }
    expect((await service.getAllProducts()).single.price, 1);
    await service.updateProduct(product.copyWith(price: 1.50));
    expect((await service.getAllProducts()).single.price, 1.50);
  });

  test(
    'adjustments use saved quantities even with stale product snapshots',
    () async {
      await service.addProduct(sample());
      final stale = (await service.getAllProducts()).single;
      await Future.wait([
        service.increaseStock(stale),
        service.increaseStock(stale),
      ]);
      expect(repository.products[stale.id]!.stock, 5);
      await service.decreaseStock(stale, 5);
      expect(repository.products[stale.id]!.stock, 0);
      await expectLater(service.decreaseStock(stale), throwsException);
      expect(repository.products[stale.id]!.stock, 0);
    },
  );

  test('rejects invalid adjustments and unsaved or deleted products', () async {
    await service.addProduct(sample());
    final product = (await service.getAllProducts()).single;
    for (final amount in [0, -1, 2147483648]) {
      await expectLater(
        service.increaseStock(product, amount),
        throwsException,
      );
      await expectLater(
        service.decreaseStock(product, amount),
        throwsException,
      );
    }
    await expectLater(service.increaseStock(sample()), throwsException);
    await expectLater(service.updateProduct(sample()), throwsException);
    await service.deleteProduct(product.id!);
    await expectLater(service.updateProduct(product), throwsException);
    await expectLater(service.deleteProduct(product.id!), throwsException);
  });

  test('low stock includes the minimum boundary and zero', () {
    expect(sample().isLowStock, isFalse);
    expect(sample().copyWith(stock: 2).isLowStock, isTrue);
    expect(sample().copyWith(stock: 0, minStock: 0).isLowStock, isTrue);
  });
}

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_tracker/models/product.dart';
import 'package:inventory_tracker/screens/product_list_screen.dart';
import 'package:inventory_tracker/services/product_service.dart';

import 'fake_product_repository.dart';

void main() {
  late FakeProductRepository repository;
  late ProductService service;
  late Product product;

  setUp(() async {
    repository = FakeProductRepository();
    service = ProductService(repository: repository);
    await service.addProduct(
      Product(
        name: 'Rice',
        category: 'Food',
        price: 1500,
        stock: 3,
        minStock: 1,
      ),
    );
    product = (await service.getAllProducts()).single;
  });

  test(
    'sale saves receipt and decreases stock; retry returns same receipt',
    () async {
      final sale = await service.sellProduct(
        product,
        quantity: 2,
        paymentMethod: 'cash',
        requestId: 'checkout-1',
      );
      expect(sale.total, 3000);
      expect(repository.products[product.id]!.stock, 1);
      final retry = await service.sellProduct(
        product,
        quantity: 2,
        paymentMethod: 'cash',
        requestId: 'checkout-1',
      );
      expect(retry.id, sale.id);
      expect(await service.getSales(), hasLength(1));
      expect(repository.products[product.id]!.stock, 1);
      await service.deleteProduct(product.id!);
      expect((await service.getSales()).single.productName, 'Rice');
    },
  );

  test(
    'invalid, oversold and changed-price sales leave inventory unchanged',
    () async {
      for (final quantity in [0, -1, 4, 2147483648]) {
        await expectLater(
          () => service.sellProduct(
            product,
            quantity: quantity,
            paymentMethod: 'cash',
            requestId: 'quantity-$quantity',
          ),
          throwsException,
        );
      }
      await expectLater(
        () => service.sellProduct(
          product,
          quantity: 1,
          paymentMethod: 'card',
          requestId: 'invalid-method',
        ),
        throwsException,
      );
      repository.products[product.id!] = product.copyWith(price: 2000);
      await expectLater(
        () => service.sellProduct(
          product,
          quantity: 1,
          paymentMethod: 'cash',
          requestId: 'stale-price',
        ),
        throwsException,
      );
      expect(repository.sales, isEmpty);
      expect(repository.products[product.id]!.stock, 3);
    },
  );

  test('editing an old product snapshot cannot undo a stock sale', () async {
    await service.sellProduct(
      product,
      quantity: 1,
      paymentMethod: 'transfer',
      requestId: 'checkout-2',
    );
    await expectLater(
      service.updateProduct(
        product.copyWith(name: 'Renamed'),
        expectedStock: product.stock,
      ),
      throwsException,
    );
    expect(repository.products[product.id]!.stock, 2);
  });

  testWidgets(
    'sell validates quantity, records sale and displays sales history',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ProductListScreen(service: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sell'));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField), '4');
      await tester.tap(find.text('Confirm sale'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a whole number from 1 to 3'), findsOneWidget);
      await tester.enterText(find.byType(TextFormField), '2');
      await tester.tap(find.text('Confirm sale'));
      await tester.pumpAndSettle();
      expect(repository.products[product.id]!.stock, 1);
      await tester.tap(find.byTooltip('Sales history'));
      await tester.pumpAndSettle();
      expect(find.text('Rice'), findsOneWidget);
      expect(find.text('2 × \u20a61500.00 = \u20a63000.00'), findsOneWidget);
      expect(find.text('Receipt #1'), findsOneWidget);
    },
  );

  testWidgets(
    'failed sale retains reference and retries without losing stock',
    (tester) async {
      await tester.pumpWidget(
        MaterialApp(home: ProductListScreen(service: service)),
      );
      await tester.pumpAndSettle();
      await tester.tap(find.text('Sell'));
      await tester.pumpAndSettle();
      repository.failWrite = true;
      await tester.tap(find.text('Confirm sale'));
      await tester.pumpAndSettle();
      expect(repository.sales, isEmpty);
      expect(repository.products[product.id]!.stock, 3);
      expect(find.text('Retry same sale'), findsOneWidget);
      repository.failWrite = false;
      await tester.tap(find.text('Retry same sale'));
      await tester.pumpAndSettle();
      expect(repository.sales, hasLength(1));
      expect(repository.products[product.id]!.stock, 2);
    },
  );

  testWidgets('zero-stock products cannot be sold', (tester) async {
    repository.products[product.id!] = product.copyWith(stock: 0);
    await tester.pumpWidget(
      MaterialApp(home: ProductListScreen(service: service)),
    );
    await tester.pumpAndSettle();
    expect(
      tester
          .widget<FilledButton>(find.widgetWithText(FilledButton, 'Sell'))
          .onPressed,
      isNull,
    );
  });
}

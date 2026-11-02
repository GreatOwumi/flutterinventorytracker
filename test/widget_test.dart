import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:inventory_tracker/models/product.dart';
import 'package:inventory_tracker/screens/product_list_screen.dart';
import 'package:inventory_tracker/services/product_service.dart';

import 'fake_product_repository.dart';

void main() {
  late FakeProductRepository repository;
  setUp(() => repository = FakeProductRepository());

  Future<void> open(WidgetTester tester) async {
    await tester.pumpWidget(
      MaterialApp(
        home: ProductListScreen(
          service: ProductService(repository: repository),
        ),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> seed() => repository.insertProduct(
    Product(name: 'Rice', category: 'Food', price: 1500, stock: 1, minStock: 2),
  );

  testWidgets('create validates required fields then saves real product', (
    tester,
  ) async {
    await open(tester);
    expect(find.text('No products yet. Tap + to add one.'), findsOneWidget);
    await tester.tap(find.byTooltip('Add product'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(find.text('Enter a product name'), findsOneWidget);
    final fields = find.byType(TextFormField);
    await tester.enterText(fields.at(0), 'Rice');
    await tester.enterText(fields.at(1), 'Food');
    for (final price in ['-1', '0', '0.99']) {
      await tester.enterText(fields.at(2), price);
      await tester.ensureVisible(find.text('Save product'));
      await tester.tap(find.text('Save product'));
      await tester.pumpAndSettle();
      expect(find.text('Enter a price of 1 or more'), findsOneWidget);
      expect(repository.products, isEmpty);
    }
    await tester.enterText(fields.at(2), '1');
    await tester.enterText(fields.at(3), '3');
    await tester.enterText(fields.at(4), '5');
    await tester.ensureVisible(find.text('Save product'));
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('LOW STOCK'), findsOneWidget);
    expect(repository.products.values.single.stock, 3);
    expect(repository.products.values.single.price, 1);
  });

  testWidgets('edit, stock controls and confirmed deletion work', (
    tester,
  ) async {
    await seed();
    await open(tester);
    expect(find.text('Total products'), findsOneWidget);
    expect(find.text('Low-stock items'), findsOneWidget);
    await tester.tap(find.byTooltip('Decrease stock for Rice'));
    await tester.pumpAndSettle();
    expect(find.text('OUT OF STOCK'), findsOneWidget);
    expect(
      tester
          .widget<IconButton>(
            find.widgetWithIcon(IconButton, Icons.remove_circle_outline),
          )
          .onPressed,
      isNull,
    );
    await tester.tap(find.byTooltip('Increase stock for Rice'));
    await tester.pumpAndSettle();
    expect(repository.products.values.single.stock, 1);
    await tester.tap(find.byTooltip('Edit Rice'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Beans');
    await tester.ensureVisible(find.text('Save product'));
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(find.text('Beans'), findsOneWidget);
    await tester.tap(find.byTooltip('Delete Beans'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Cancel'));
    await tester.pumpAndSettle();
    expect(repository.products, hasLength(1));
    await tester.tap(find.byTooltip('Delete Beans'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Delete'));
    await tester.pumpAndSettle();
    expect(repository.products, isEmpty);
  });

  testWidgets(
    'failed loads can retry and search and low-stock filter combine',
    (tester) async {
      await seed();
      await repository.insertProduct(
        Product(
          name: 'Soap',
          category: 'Cleaning',
          price: 100,
          stock: 10,
          minStock: 2,
        ),
      );
      repository.failRead = true;
      await open(tester);
      expect(
        find.text('Could not load inventory. Please try again.'),
        findsOneWidget,
      );
      repository.failRead = false;
      await tester.tap(find.text('Retry'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Low stock only'));
      await tester.pumpAndSettle();
      expect(find.text('Rice'), findsOneWidget);
      expect(find.text('Soap'), findsNothing);
      await tester.enterText(find.byType(TextField), 'CLEANING');
      await tester.pumpAndSettle();
      expect(find.text('No matching products.'), findsOneWidget);
      await tester.tap(find.text('Low stock only'));
      await tester.pumpAndSettle();
      expect(find.text('Soap'), findsOneWidget);
    },
  );

  testWidgets('failed saves retain entered values and allow retry', (
    tester,
  ) async {
    await seed();
    await open(tester);
    await tester.tap(find.byTooltip('Edit Rice'));
    await tester.pumpAndSettle();
    await tester.enterText(find.byType(TextFormField).first, 'Beans');
    repository.failWrite = true;
    await tester.ensureVisible(find.text('Save product'));
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(
      find.text('Could not save product. Please try again.'),
      findsOneWidget,
    );
    expect(find.text('Beans'), findsOneWidget);
    repository.failWrite = false;
    await tester.ensureVisible(find.text('Save product'));
    await tester.tap(find.text('Save product'));
    await tester.pumpAndSettle();
    expect(repository.products.values.single.name, 'Beans');
  });

  testWidgets('filter icon combines stock choices with search', (tester) async {
    await seed();
    await repository.insertProduct(
      Product(
        name: 'Soap',
        category: 'Cleaning',
        price: 100,
        stock: 0,
        minStock: 2,
      ),
    );
    await open(tester);
    await tester.tap(find.byTooltip('Filter products'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('Out of stock'),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuEntry),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Soap'), findsOneWidget);
    expect(find.text('Rice'), findsNothing);
    await tester.enterText(find.byType(TextField), 'Food');
    await tester.pumpAndSettle();
    expect(find.text('No matching products.'), findsOneWidget);
    await tester.tap(find.byTooltip('Filter products'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('In stock'),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuEntry),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Soap'), findsNothing);
    await tester.enterText(find.byType(TextField), '');
    await tester.tap(find.byTooltip('Filter products'));
    await tester.pumpAndSettle();
    await tester.tap(
      find.ancestor(
        of: find.text('All products'),
        matching: find.byWidgetPredicate((widget) => widget is PopupMenuEntry),
      ),
    );
    await tester.pumpAndSettle();
    expect(find.text('Rice'), findsOneWidget);
    expect(find.text('Soap'), findsOneWidget);
  });
}

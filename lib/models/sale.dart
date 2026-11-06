class Sale {
  const Sale({
    required this.id,
    required this.requestId,
    required this.productId,
    required this.productName,
    required this.quantity,
    required this.unitPrice,
    required this.paymentMethod,
    required this.soldAt,
  });

  final int id;
  final String requestId;
  final int productId;
  final String productName;
  final int quantity;
  final double unitPrice;
  final String paymentMethod;
  final DateTime soldAt;

  double get total => quantity * unitPrice;

  factory Sale.fromMap(Map<String, dynamic> row) => Sale(
    id: row['id'] as int,
    requestId: row['request_id'] as String,
    productId: row['product_id'] as int,
    productName: row['product_name'] as String,
    quantity: row['quantity'] as int,
    unitPrice: (row['unit_price'] as num).toDouble(),
    paymentMethod: row['payment_method'] as String,
    soldAt: DateTime.parse(row['sold_at'] as String).toLocal(),
  );
}

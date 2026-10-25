class Product {
  final int? id;
  final String name;
  final String category;
  final double price;
  final int stock;
  final int minStock;

  Product({
    this.id,
    required this.name,
    required this.category,
    required this.price,
    required this.stock,
    required this.minStock,
  });

  // True when stock is at or below the minimum level
  bool get isLowStock => stock <= minStock;

  // Product -> Map (to save in the database)
  Map<String, dynamic> toMap() {
    return {
      'id': id,
      'name': name,
      'category': category,
      'price': price,
      'stock': stock,
      'minStock': minStock,
    };
  }

  // Map -> Product (when reading from the database)
  factory Product.fromMap(Map<String, dynamic> map) {
    return Product(
      id: map['id'],
      name: map['name'],
      category: map['category'],
      price: (map['price'] as num).toDouble(),
      stock: map['stock'],
      minStock: map['minStock'],
    );
  }

  // Makes a copy with a different stock number (used for +/- buttons)
  Product copyWith({int? stock}) {
    return Product(
      id: id,
      name: name,
      category: category,
      price: price,
      stock: stock ?? this.stock,
      minStock: minStock,
    );
  }
}
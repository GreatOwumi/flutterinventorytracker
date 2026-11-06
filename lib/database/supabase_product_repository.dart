import 'package:supabase_flutter/supabase_flutter.dart';

import '../models/product.dart';
import '../models/sale.dart';
import 'product_repository.dart';

class SupabaseProductRepository implements ProductRepository {
  SupabaseProductRepository(this.client);
  final SupabaseClient client;

  String get _ownerId {
    final id = client.auth.currentUser?.id;
    if (id == null) throw Exception('Please sign in again.');
    return id;
  }

  @override
  Future<List<Product>> getProducts() async {
    final rows = await client
        .from('products')
        .select()
        .eq('owner_id', _ownerId)
        .order('name')
        .order('id');
    return rows.map(Product.fromMap).toList();
  }

  @override
  Future<int> insertProduct(Product product) async {
    final values = product.toMap()..remove('id');
    final row = await client
        .from('products')
        .insert({...values, 'owner_id': _ownerId})
        .select('id')
        .single();
    return row['id'] as int;
  }

  @override
  Future<int> updateProduct(Product product, {int? expectedStock}) async {
    final values = product.toMap()..remove('id');
    var query = client
        .from('products')
        .update(values)
        .eq('id', product.id!)
        .eq('owner_id', _ownerId);
    if (expectedStock != null) query = query.eq('stock', expectedStock);
    return (await query.select('id')).length;
  }

  @override
  Future<int> deleteProduct(int id) async =>
      (await client
              .from('products')
              .delete()
              .eq('id', id)
              .eq('owner_id', _ownerId)
              .select('id'))
          .length;

  @override
  Future<void> adjustStock(int id, int delta) async {
    await client.rpc(
      'adjust_stock',
      params: {'p_product_id': id, 'p_delta': delta},
    );
  }

  @override
  Future<List<Sale>> getSales() async {
    final rows = await client
        .from('sales')
        .select()
        .eq('owner_id', _ownerId)
        .order('sold_at', ascending: false)
        .order('id', ascending: false);
    return rows.map(Sale.fromMap).toList();
  }

  @override
  Future<Sale> sellProduct({
    required int productId,
    required int quantity,
    required double expectedPrice,
    required String paymentMethod,
    required String requestId,
  }) async {
    final row = await client.rpc(
      'record_sale',
      params: {
        'p_product_id': productId,
        'p_quantity': quantity,
        'p_expected_price': expectedPrice,
        'p_payment_method': paymentMethod,
        'p_request_id': requestId,
      },
    );
    return Sale.fromMap(Map<String, dynamic>.from(row as Map));
  }
}

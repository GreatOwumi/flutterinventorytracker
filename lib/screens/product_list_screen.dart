import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_service.dart';
import 'product_form_screen.dart';

class ProductListScreen extends StatefulWidget {
  const ProductListScreen({super.key, this.service});
  final ProductService? service;
  @override
  State<ProductListScreen> createState() => _ProductListScreenState();
}

class _ProductListScreenState extends State<ProductListScreen> {
  late final _service = widget.service ?? ProductService();
  List<Product> _products = [];
  bool _loading = true;
  bool _busy = false;
  bool _lowOnly = false;
  String _query = '';
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProducts();
  }

  Future<void> _loadProducts() async {
    if (!mounted) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final products = await _service.getAllProducts();
      if (mounted) setState(() => _products = products);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not load inventory. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  void _message(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _changeStock(Product product, bool increase) async {
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      if (increase) {
        await _service.increaseStock(product);
      } else {
        await _service.decreaseStock(product);
      }
      await _loadProducts();
    } catch (_) {
      _message('Could not change stock. Refresh and try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _deleteProduct(Product product) async {
    if (_busy || _loading) return;
    setState(() => _busy = true);
    try {
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('Delete product?'),
          content: Text(
            'Delete "${product.name}" from your inventory? This cannot be undone.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Delete'),
            ),
          ],
        ),
      );
      if (confirmed != true || !mounted) return;
      await _service.deleteProduct(product.id!);
      await _loadProducts();
      _message('${product.name} deleted');
    } catch (_) {
      _message('Could not delete product. Please try again.');
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _openForm([Product? product]) async {
    if (_busy || _loading || _error != null) return;
    setState(() => _busy = true);
    try {
      final saved = await Navigator.of(context).push<bool>(
        MaterialPageRoute(
          builder: (_) =>
              ProductFormScreen(service: _service, product: product),
        ),
      );
      if (saved == true && mounted) {
        await _loadProducts();
        _message('Product saved');
      }
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final filtered = _products
        .where(
          (p) =>
              (!_lowOnly || p.isLowStock) &&
              '${p.name} ${p.category}'.toLowerCase().contains(_query),
        )
        .toList();
    final enabled = !_busy && !_loading && _error == null;
    return Scaffold(
      appBar: AppBar(
        title: const Text('Inventory Tracker'),
        actions: [
          IconButton(
            tooltip: 'Refresh inventory',
            onPressed: _busy || _loading ? null : _loadProducts,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: Row(
              children: [
                _summary(
                  'Total products',
                  _products.length,
                  Icons.inventory_2_outlined,
                ),
                _summary(
                  'Low-stock items',
                  _products.where((p) => p.isLowStock).length,
                  Icons.warning_amber_outlined,
                ),
              ],
            ),
          ),
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 16),
            child: TextField(
              decoration: const InputDecoration(
                labelText: 'Search products or categories',
                prefixIcon: Icon(Icons.search),
                border: OutlineInputBorder(),
              ),
              onChanged: (value) =>
                  setState(() => _query = value.trim().toLowerCase()),
            ),
          ),
          Align(
            alignment: Alignment.centerLeft,
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
              child: FilterChip(
                label: const Text('Low stock only'),
                selected: _lowOnly,
                onSelected: (value) => setState(() => _lowOnly = value),
              ),
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _error != null
                ? Center(
                    child: Padding(
                      padding: const EdgeInsets.all(24),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(_error!, textAlign: TextAlign.center),
                          TextButton(
                            onPressed: _loadProducts,
                            child: const Text('Retry'),
                          ),
                        ],
                      ),
                    ),
                  )
                : filtered.isEmpty
                ? Center(
                    child: Text(
                      _products.isEmpty
                          ? 'No products yet. Tap + to add one.'
                          : 'No matching products.',
                    ),
                  )
                : RefreshIndicator(
                    onRefresh: () async {
                      if (!_busy && !_loading) await _loadProducts();
                    },
                    child: ListView.builder(
                      physics: const AlwaysScrollableScrollPhysics(),
                      padding: const EdgeInsets.fromLTRB(8, 0, 8, 88),
                      itemCount: filtered.length,
                      itemBuilder: (context, index) =>
                          _productCard(filtered[index], enabled),
                    ),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton(
        tooltip: 'Add product',
        onPressed: enabled ? () => _openForm() : null,
        child: const Icon(Icons.add),
      ),
    );
  }

  Widget _summary(String label, int value, IconData icon) => Expanded(
    child: Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          children: [
            Icon(icon),
            Text(
              _error == null && !_loading ? '$value' : '--',
              style: Theme.of(context).textTheme.headlineMedium,
            ),
            Text(label, textAlign: TextAlign.center),
          ],
        ),
      ),
    ),
  );

  Widget _productCard(Product product, bool enabled) => Card(
    color: product.isLowStock
        ? Theme.of(context).colorScheme.errorContainer
        : null,
    child: Padding(
      padding: const EdgeInsets.all(12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(product.name, style: Theme.of(context).textTheme.titleLarge),
          if (product.isLowStock)
            Text(
              product.stock == 0 ? 'OUT OF STOCK' : 'LOW STOCK',
              style: const TextStyle(fontWeight: FontWeight.bold),
            ),
          const SizedBox(height: 4),
          Text(
            '${product.category} \u2022 \u20a6${product.price.toStringAsFixed(2)}',
          ),
          Text('Minimum stock: ${product.minStock}'),
          Wrap(
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              IconButton(
                tooltip: 'Decrease stock for ${product.name}',
                icon: const Icon(Icons.remove_circle_outline),
                onPressed: enabled && product.stock > 0
                    ? () => _changeStock(product, false)
                    : null,
              ),
              Text(
                '${product.stock}',
                style: Theme.of(context).textTheme.titleLarge,
              ),
              IconButton(
                tooltip: 'Increase stock for ${product.name}',
                icon: const Icon(Icons.add_circle_outline),
                onPressed: enabled && product.stock < ProductService.maxQuantity
                    ? () => _changeStock(product, true)
                    : null,
              ),
              IconButton(
                tooltip: 'Edit ${product.name}',
                icon: const Icon(Icons.edit_outlined),
                onPressed: enabled ? () => _openForm(product) : null,
              ),
              IconButton(
                tooltip: 'Delete ${product.name}',
                icon: const Icon(Icons.delete_outline),
                onPressed: enabled ? () => _deleteProduct(product) : null,
              ),
            ],
          ),
        ],
      ),
    ),
  );
}

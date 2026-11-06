import 'package:flutter/material.dart';

import '../models/product.dart';
import '../services/product_service.dart';

class ProductFormScreen extends StatefulWidget {
  const ProductFormScreen({super.key, required this.service, this.product});
  final ProductService service;
  final Product? product;
  @override
  State<ProductFormScreen> createState() => _ProductFormScreenState();
}

class _ProductFormScreenState extends State<ProductFormScreen> {
  final _form = GlobalKey<FormState>();
  late final _name = TextEditingController(text: widget.product?.name);
  late final _category = TextEditingController(text: widget.product?.category);
  late final _price = TextEditingController(
    text: widget.product?.price.toString(),
  );
  late final _stock = TextEditingController(
    text: '${widget.product?.stock ?? 0}',
  );
  late final _minimum = TextEditingController(
    text: '${widget.product?.minStock ?? 0}',
  );
  bool _saving = false;
  String? _error;

  @override
  void dispose() {
    for (final controller in [_name, _category, _price, _stock, _minimum]) {
      controller.dispose();
    }
    super.dispose();
  }

  String? _quantity(String? value) {
    final number = int.tryParse(value?.trim() ?? '');
    return number == null || number < 0 || number > ProductService.maxQuantity
        ? 'Enter a whole number from 0 to ${ProductService.maxQuantity}'
        : null;
  }

  Future<void> _save() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final product = Product(
        id: widget.product?.id,
        name: _name.text.trim(),
        category: _category.text.trim(),
        price: double.parse(_price.text.trim()),
        stock: int.parse(_stock.text.trim()),
        minStock: int.parse(_minimum.text.trim()),
      );
      if (product.id == null) {
        await widget.service.addProduct(product);
      } else {
        await widget.service.updateProduct(
          product,
          expectedStock: widget.product!.stock,
        );
      }
      if (mounted) Navigator.of(context).pop(true);
    } catch (_) {
      if (mounted) {
        setState(() => _error = 'Could not save product. Please try again.');
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) => PopScope(
    canPop: !_saving,
    child: Scaffold(
      appBar: AppBar(
        title: Text(widget.product == null ? 'Add product' : 'Edit product'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(20),
          children: [
            _field(
              _name,
              'Product name',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a product name' : null,
            ),
            _field(
              _category,
              'Category',
              validator: (v) =>
                  v == null || v.trim().isEmpty ? 'Enter a category' : null,
            ),
            _field(
              _price,
              'Unit price (\u20a6)',
              number: true,
              decimal: true,
              validator: (v) {
                final price = double.tryParse(v?.trim() ?? '');
                return price == null || !price.isFinite || price < 1
                    ? 'Enter a price of 1 or more'
                    : price > ProductService.maxPrice ||
                          (price * 100 - (price * 100).round()).abs() > 0.001
                    ? 'Use at most two decimal places, up to ${ProductService.maxPrice}'
                    : null;
              },
            ),
            _field(
              _stock,
              'Stock quantity',
              number: true,
              validator: _quantity,
            ),
            _field(
              _minimum,
              'Minimum stock',
              number: true,
              validator: _quantity,
            ),
            if (_error != null)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: Text(_error!),
              ),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: Text(_saving ? 'Saving...' : 'Save product'),
            ),
          ],
        ),
      ),
    ),
  );

  Widget _field(
    TextEditingController controller,
    String label, {
    bool number = false,
    bool decimal = false,
    String? Function(String?)? validator,
  }) => Padding(
    padding: const EdgeInsets.only(bottom: 16),
    child: TextFormField(
      controller: controller,
      enabled: !_saving,
      decoration: InputDecoration(
        labelText: label,
        border: const OutlineInputBorder(),
      ),
      keyboardType: number
          ? TextInputType.numberWithOptions(decimal: decimal)
          : TextInputType.text,
      validator: validator,
      autovalidateMode: AutovalidateMode.onUserInteraction,
    ),
  );
}

import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'package:uuid/uuid.dart';

import '../models/product.dart';
import '../models/sale.dart';
import '../services/product_service.dart';

class SellProductScreen extends StatefulWidget {
  const SellProductScreen({
    super.key,
    required this.product,
    required this.service,
  });
  final Product product;
  final ProductService service;

  @override
  State<SellProductScreen> createState() => _SellProductScreenState();
}

class _SellProductScreenState extends State<SellProductScreen> {
  final _form = GlobalKey<FormState>();
  final _quantity = TextEditingController(text: '1');
  // Keep this reference on retry, so a lost response cannot create two sales.
  final _requestId = const Uuid().v4();
  String _paymentMethod = 'cash';
  bool _saving = false;
  bool _attempted = false;
  String? _error;

  @override
  void dispose() {
    _quantity.dispose();
    super.dispose();
  }

  Future<void> _sell() async {
    if (_saving || !_form.currentState!.validate()) return;
    setState(() {
      _saving = true;
      _attempted = true;
      _error = null;
    });
    try {
      final sale = await widget.service.sellProduct(
        widget.product,
        quantity: int.parse(_quantity.text.trim()),
        paymentMethod: _paymentMethod,
        requestId: _requestId,
      );
      if (mounted) Navigator.of(context).pop<Sale>(sale);
    } catch (error) {
      if (mounted) {
        setState(
          () => _error = error is PostgrestException && error.code == 'P0001'
              ? error.message
              : 'Could not confirm the sale. Retry with the same details. If you leave, check sales history before selling again.',
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final quantity = int.tryParse(_quantity.text.trim()) ?? 0;
    final validQuantity = quantity > 0 && quantity <= widget.product.stock;
    return PopScope(
      canPop: !_saving,
      child: Scaffold(
        appBar: AppBar(title: const Text('Sell product')),
        body: Form(
          key: _form,
          child: ListView(
            padding: const EdgeInsets.all(20),
            children: [
              Text(
                widget.product.name,
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              Text(
                '${widget.product.stock} available · \u20a6${widget.product.price.toStringAsFixed(2)} each',
              ),
              const SizedBox(height: 24),
              TextFormField(
                controller: _quantity,
                enabled: !_attempted,
                keyboardType: TextInputType.number,
                decoration: const InputDecoration(
                  labelText: 'Quantity to sell',
                  border: OutlineInputBorder(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (value) {
                  final amount = int.tryParse(value?.trim() ?? '');
                  return amount == null ||
                          amount < 1 ||
                          amount > widget.product.stock
                      ? 'Enter a whole number from 1 to ${widget.product.stock}'
                      : null;
                },
              ),
              const SizedBox(height: 16),
              DropdownButtonFormField<String>(
                initialValue: _paymentMethod,
                decoration: const InputDecoration(
                  labelText: 'Payment method',
                  border: OutlineInputBorder(),
                ),
                items: const [
                  DropdownMenuItem(value: 'cash', child: Text('Cash')),
                  DropdownMenuItem(value: 'transfer', child: Text('Transfer')),
                ],
                onChanged: _attempted
                    ? null
                    : (value) => setState(() => _paymentMethod = value!),
              ),
              const SizedBox(height: 24),
              Text(
                validQuantity
                    ? 'Total: \u20a6${(quantity * widget.product.price).toStringAsFixed(2)}'
                    : 'Total: --',
                style: Theme.of(context).textTheme.headlineSmall,
              ),
              const SizedBox(height: 12),
              const Text(
                'Confirm only after receiving payment. This records the sale; it does not collect or verify payment.',
              ),
              if (_error != null)
                Padding(
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  child: Text(_error!),
                ),
              const SizedBox(height: 16),
              FilledButton.icon(
                onPressed: _saving ? null : _sell,
                icon: const Icon(Icons.point_of_sale),
                label: Text(
                  _saving
                      ? 'Recording sale...'
                      : _attempted
                      ? 'Retry same sale'
                      : 'Confirm sale',
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

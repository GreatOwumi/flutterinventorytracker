import 'package:flutter/material.dart';

import '../models/sale.dart';
import '../services/product_service.dart';

class SalesHistoryScreen extends StatefulWidget {
  const SalesHistoryScreen({super.key, required this.service});
  final ProductService service;

  @override
  State<SalesHistoryScreen> createState() => _SalesHistoryScreenState();
}

class _SalesHistoryScreenState extends State<SalesHistoryScreen> {
  late Future<List<Sale>> _sales;

  @override
  void initState() {
    super.initState();
    _sales = widget.service.getSales();
  }

  void _reload() => setState(() => _sales = widget.service.getSales());

  @override
  Widget build(BuildContext context) => Scaffold(
    appBar: AppBar(
      title: const Text('Sales history'),
      actions: [
        IconButton(
          tooltip: 'Refresh sales',
          onPressed: _reload,
          icon: const Icon(Icons.refresh),
        ),
      ],
    ),
    body: FutureBuilder<List<Sale>>(
      future: _sales,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const Center(child: CircularProgressIndicator());
        }
        if (snapshot.hasError) {
          return Center(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Text('Could not load sales. Please try again.'),
                TextButton(onPressed: _reload, child: const Text('Retry')),
              ],
            ),
          );
        }
        final sales = snapshot.data!;
        if (sales.isEmpty) {
          return const Center(
            child: Text('No sales yet. Use Sell on a product to record one.'),
          );
        }
        return ListView.builder(
          padding: const EdgeInsets.all(12),
          itemCount: sales.length,
          itemBuilder: (context, index) {
            final sale = sales[index];
            final date = MaterialLocalizations.of(context)
                .formatMediumDate(sale.soldAt);
            final time = MaterialLocalizations.of(context)
                .formatTimeOfDay(TimeOfDay.fromDateTime(sale.soldAt));
            return Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      sale.productName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      '${sale.quantity} × \u20a6${sale.unitPrice.toStringAsFixed(2)} = \u20a6${sale.total.toStringAsFixed(2)}',
                    ),
                    Text(
                      '${sale.paymentMethod == 'cash' ? 'Cash' : 'Transfer'} · $date, $time',
                    ),
                    Text('Receipt #${sale.id}'),
                  ],
                ),
              ),
            );
          },
        );
      },
    ),
  );
}

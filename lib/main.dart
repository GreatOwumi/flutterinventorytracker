import 'package:flutter/material.dart';

import 'screens/product_list_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory Tracker',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: const ProductListScreen(),
    );
  }
}

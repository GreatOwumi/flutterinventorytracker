import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'database/supabase_product_repository.dart';
import 'screens/auth_screen.dart';
import 'screens/product_list_screen.dart';
import 'services/product_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  const url = String.fromEnvironment('SUPABASE_URL');
  const key = String.fromEnvironment('SUPABASE_PUBLISHABLE_KEY');
  if (url.isEmpty && key.isEmpty) {
    runApp(const MyApp());
    return;
  }
  try {
    if (url.isEmpty || key.isEmpty) {
      throw StateError('Incomplete Supabase configuration');
    }
    await Supabase.initialize(url: url, publishableKey: key);
    runApp(MyApp(client: Supabase.instance.client));
  } catch (_) {
    runApp(
      const MaterialApp(
        home: Scaffold(
          body: Center(
            child: Padding(
              padding: EdgeInsets.all(24),
              child: Text(
                'Could not start online inventory. Check the Supabase configuration and restart the app.',
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.client});
  final SupabaseClient? client;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Inventory Tracker',
      theme: ThemeData(colorSchemeSeed: Colors.blue, useMaterial3: true),
      home: client == null
          ? const ProductListScreen()
          : _SessionGate(client: client!),
    );
  }
}

class _SessionGate extends StatelessWidget {
  const _SessionGate({required this.client});
  final SupabaseClient client;

  @override
  Widget build(BuildContext context) => StreamBuilder<AuthState>(
    stream: client.auth.onAuthStateChange,
    builder: (context, snapshot) {
      final user = client.auth.currentUser;
      if (user == null) return AuthScreen(client: client);
      // The signed-in routes live inside this navigator. Signing out removes
      // the whole navigator, including any open receipt or product screens.
      return Navigator(
        key: ValueKey(user.id),
        onGenerateRoute: (_) => MaterialPageRoute<void>(
          builder: (_) => ProductListScreen(
            cloudMode: true,
            service: ProductService(
              repository: SupabaseProductRepository(client),
            ),
            onSignOut: () => client.auth.signOut(),
          ),
        ),
      );
    },
  );
}

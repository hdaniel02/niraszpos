import 'package:flutter/material.dart';
import 'package:firebase_core/firebase_core.dart';

import 'firebase_options.dart';
import 'views/login/login_screen.dart';
import 'views/dashboard/dashboard_screen.dart';
import 'views/users/manage_users_screen.dart';
import 'views/product/products_screen.dart';
import 'views/pos/pos_screen.dart';
import 'views/sales/sales_history_screen.dart';
import 'views/profile/profile_screen.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  try {
    await Firebase.initializeApp(
      options: DefaultFirebaseOptions.currentPlatform,
    );
    print('✅ Firebase initialized successfully');
  } catch (e) {
    print('❌ Firebase init failed: $e');
  }

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'NiraszPOS',
      debugShowCheckedModeBanner: false,
      initialRoute: "/",
      onGenerateRoute: (settings) {
        switch (settings.name) {
          case "/":
            return MaterialPageRoute(
              builder: (_) => const LoginScreen(),
            );

          case "/dashboard":
            final args = settings.arguments as Map<String, dynamic>?;
            final role = (args?['role'] ?? "guest").toString();
            return MaterialPageRoute(
              builder: (_) => DashboardScreen(role: role),
            );

          case "/pos":
            return MaterialPageRoute(
              builder: (_) => const PosScreen(),
            );

          case "/products":
            return MaterialPageRoute(
              builder: (_) => ProductsScreen(),
            );

          case "/add-product":
            return MaterialPageRoute(
              builder: (_) => const Scaffold(
                body: Center(child: Text("Add Product")),
              ),
            );

          case "/sales":
            return MaterialPageRoute(
              builder: (_) => SalesHistoryScreen(),
            );

          case "/users":
            return MaterialPageRoute(
              builder: (_) => ManageUsersScreen(),
            );

          case "/profile":
            return MaterialPageRoute(
              builder: (_) => const ProfileScreen(),
            );

          default:
            return MaterialPageRoute(
              builder: (_) => Scaffold(
                body: Center(
                  child: Text("No route defined for ${settings.name}"),
                ),
              ),
            );
        }
      },
    );
  }
}
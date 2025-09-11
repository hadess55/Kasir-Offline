import 'package:flutter/material.dart';
import 'Database/app_db.dart';
import 'UI/products_page.dart';
import 'UI/kasir_page.dart';
import 'UI/riwayat_page.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  runApp(const POSApp());
}

class POSApp extends StatefulWidget {
  const POSApp({super.key});
  @override
  State<POSApp> createState() => _POSAppState();
}

class _POSAppState extends State<POSApp> {
  final db = AppDb(); // satu instance app-wide
  int _index = 0;

  @override
  void dispose() {
    db.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final pages = [
      ProductsPage(db: db),
      KasirPage(db: db),
      RiwayatPage(db: db),
    ];

    return MaterialApp(
      title: 'Kasir Offline',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        useMaterial3: true,
      ),
      home: Scaffold(
        body: SafeArea(child: pages[_index]),
        bottomNavigationBar: NavigationBar(
          selectedIndex: _index,
          onDestinationSelected: (i) => setState(() => _index = i),
          destinations: const [
            NavigationDestination(
              icon: Icon(Icons.inventory_2_outlined),
              selectedIcon: Icon(Icons.inventory_2),
              label: 'Produk',
            ),
            NavigationDestination(
              icon: Icon(Icons.point_of_sale_outlined),
              selectedIcon: Icon(Icons.point_of_sale),
              label: 'Kasir',
            ),
            NavigationDestination(
              icon: Icon(Icons.receipt_long_outlined),
              selectedIcon: Icon(Icons.receipt_long),
              label: 'Riwayat',
            ),
          ],
        ),
      ),
    );
  }
}

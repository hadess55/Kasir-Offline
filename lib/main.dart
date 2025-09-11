import 'package:flutter/material.dart';
import 'Database/app_db.dart';
import 'UI/products_page.dart';
import 'UI/kasir_page.dart';
import 'UI/riwayat_page.dart';
import 'package:flutter/services.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF5A54FF), // samakan dengan warna AppBar
      statusBarIconBrightness:
          Brightness.light, // ikon status bar putih (Android)
      statusBarBrightness: Brightness.dark, // iOS: teks status bar putih
    ),
  );
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
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),

      // ⬇⬇ Scaffold diletakkan di SINI (di dalam MaterialApp.home)
      home: Scaffold(
        body: SafeArea(top: false, child: pages[_index]),

        // bottom nav harus di Scaffold, bukan di MaterialApp
        bottomNavigationBar: Theme(
          data: Theme.of(context).copyWith(
            navigationBarTheme: NavigationBarThemeData(
              height: 68,
              backgroundColor: const Color(0xFF5A54FF),
              surfaceTintColor: Colors.white,
              indicatorColor: Colors.white,
              elevation: 8,
              labelTextStyle: MaterialStateProperty.resolveWith((s) {
                final selected = s.contains(MaterialState.selected);
                final cs = Theme.of(context).colorScheme;
                return TextStyle(
                  fontSize: 12,
                  fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                  color: selected ? Colors.white : Colors.white70,
                );
              }),
              iconTheme: MaterialStateProperty.resolveWith((s) {
                final selected = s.contains(MaterialState.selected);
                final cs = Theme.of(context).colorScheme;
                return IconThemeData(
                  color: selected ? cs.primary : cs.onSurfaceVariant,
                  size: 24,
                );
              }),
            ),
          ),
          child: ClipRRect(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(18)),
            child: NavigationBar(
              selectedIndex: _index,
              onDestinationSelected: (i) => setState(() => _index = i),
              destinations: const [
                NavigationDestination(
                  icon: Icon(Icons.inventory_2_outlined, color: Colors.white),
                  selectedIcon: Icon(Icons.inventory_2),
                  label: 'Produk',
                ),
                NavigationDestination(
                  icon: Icon(Icons.point_of_sale_outlined, color: Colors.white),
                  selectedIcon: Icon(Icons.point_of_sale),
                  label: 'Kasir',
                ),
                NavigationDestination(
                  icon: Icon(Icons.receipt_long_outlined, color: Colors.white),
                  selectedIcon: Icon(Icons.receipt_long),
                  label: 'Riwayat',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

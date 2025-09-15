import 'package:flutter/material.dart';
import 'Database/app_db.dart';
import 'UI/products_page.dart';
import 'UI/kasir_page.dart';
import 'UI/riwayat_page.dart';
import 'UI/pembukuan_page.dart';
import 'UI/splash_screen.dart'; // <— TAMBAH INI
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Color(0xFF5A54FF),
      statusBarIconBrightness: Brightness.light,
      statusBarBrightness: Brightness.dark,
    ),
  );
  runApp(const SplashApp()); // <— GANTI: mulai dari splash
}

/// MaterialApp kecil untuk menampilkan Splash, lalu berpindah ke POSApp.
/// (POSApp milikmu tetap seperti sekarang — tidak perlu diubah.)
class SplashApp extends StatelessWidget {
  const SplashApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Kasir Offline',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorSchemeSeed: const Color(0xFF5A54FF),
        useMaterial3: true,
      ),
      home: const SplashScreen(),
    );
  }
}

// ====== Di bawah ini adalah POSApp milikmu (TIDAK DIUBAH) ======
class POSApp extends StatefulWidget {
  const POSApp({super.key});
  @override
  State<POSApp> createState() => _POSAppState();
}

class _POSAppState extends State<POSApp> {
  final db = AppDb();
  int _index = 0;

  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

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
      PembukuanPage(db: db, currency: _currency),
    ];

    return MaterialApp(
      title: 'Kasir Offline',
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.indigo),
        scaffoldBackgroundColor: Colors.white,
        useMaterial3: true,
      ),
      home: Scaffold(
        body: SafeArea(top: false, child: pages[_index]),
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
                NavigationDestination(
                  icon: Icon(Icons.book, color: Colors.white),
                  selectedIcon: Icon(Icons.book_rounded),
                  label: 'Buku',
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

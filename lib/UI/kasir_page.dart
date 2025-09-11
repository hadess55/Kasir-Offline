import 'package:flutter/material.dart';
import '../Database/app_db.dart';

class KasirPage extends StatelessWidget {
  final AppDb db;
  const KasirPage({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    // Placeholder kasir: nanti kita tambah cart, scanner, dan tombol Bayar
    return Scaffold(
      appBar: AppBar(title: Text('Kasir')),
      body: Center(child: Text('Layar Kasir — coming soon')),
    );
  }
}

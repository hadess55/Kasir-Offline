import 'package:flutter/material.dart';
import '../Database/app_db.dart';

class RiwayatPage extends StatelessWidget {
  final AppDb db;
  const RiwayatPage({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    // Placeholder riwayat: nanti tampilkan list transaksi harian
    return Scaffold(
      appBar: AppBar(title: Text('Riwayat')),
      body: Center(child: Text('Riwayat Penjualan — coming soon')),
    );
  }
}

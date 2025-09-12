import 'package:flutter/material.dart';
import '../Database/app_db.dart';

class PembukuanPage extends StatelessWidget {
  final AppDb db;
  const PembukuanPage({super.key, required this.db});

  @override
  Widget build(BuildContext context) {
    // Placeholder riwayat: nanti tampilkan list transaksi harian
    return Scaffold(
      appBar: AppBar(title: Text('Pembukuan')),
      body: Center(child: Text('Pembukuan — coming soon')),
    );
  }
}

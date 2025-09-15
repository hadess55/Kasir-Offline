// lib/UI/riwayat_page.dart
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import '../Database/app_db.dart';
import 'package:drift/drift.dart' as d;
import 'package:drift/drift.dart' hide Column;
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'widgets/receipt.dart' show buildReceiptText, buildReceiptPdf;
import 'widgets/checkout_success.dart' show ReceiptItem;

class RiwayatPage extends StatefulWidget {
  final AppDb db;
  const RiwayatPage({super.key, required this.db});

  @override
  State<RiwayatPage> createState() => _RiwayatPageState();
}

enum _Range { today, week, all }

class _RiwayatPageState extends State<RiwayatPage> {
  Future<({Sale sale, List<ReceiptItem> items})> _loadSale(int saleId) async {
    final s = widget.db.sales;
    final si = widget.db.saleItems;
    final p = widget.db.products;

    final rows =
        await (widget.db.select(
          si,
        )..where((t) => t.saleId.equals(saleId))).join([
          innerJoin(p, p.id.equalsExp(si.productId)),
          innerJoin(s, s.id.equalsExp(si.saleId)),
        ]).get();

    // Baris sale bisa dibaca dari join (pakai baris pertama)
    final sale = rows.first.readTable(s);

    final items = rows.map((r) {
      final li = r.readTable(si);
      final pr = r.readTable(p);
      return ReceiptItem(
        name: pr.name,
        qty: li.qty, // qty = int
        price: li.price, // double
      );
    }).toList();

    return (sale: sale, items: items);
  }

  final _searchC = TextEditingController();
  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  _Range _range = _Range.today;

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  // ======= STREAM RINGKASAN PENJUALAN =======
  Stream<List<_SaleRow>> _watchSales() {
    final s = widget.db.sales;
    final si = widget.db.saleItems;

    // agregat
    final itemCount = si.id.count();
    final qtySum = si.qty.sum();

    final join =
        widget.db.select(s).join([leftOuterJoin(si, si.saleId.equalsExp(s.id))])
          ..addColumns([itemCount, qtySum])
          ..groupBy([s.id])
          ..orderBy([OrderingTerm.desc(s.createdAt)]);

    // filter waktu
    final now = DateTime.now();
    DateTime? from;
    if (_range == _Range.today) {
      from = DateTime(now.year, now.month, now.day);
    } else if (_range == _Range.week) {
      from = now.subtract(const Duration(days: 7));
    }
    if (from != null) {
      join.where(s.createdAt.isBiggerOrEqualValue(from));
    }

    // NOTE: kalau mau search berdasarkan note / id, taruh di sini
    // (Sales tidak punya kolom 'note' di skema kamu saat ini).
    // final q = _searchC.text.trim();
    // if (q.isNotEmpty) { ... }

    return join.watch().map((rows) {
      return rows.map((r) {
        final sale = r.readTable(s);
        final cnt = r.read(itemCount) ?? 0;
        final qty = (r.read(qtySum) ?? 0).toDouble();
        return _SaleRow(sale: sale, itemCount: cnt, qty: qty);
      }).toList();
    });
  }

  // ======= DETAIL: item transaksi =======
  Future<List<_DetailItem>> _loadItems(int saleId) async {
    final si = widget.db.saleItems;
    final p = widget.db.products;

    final rows =
        await (widget.db.select(si)..where((t) => t.saleId.equals(saleId)))
            .join([innerJoin(p, p.id.equalsExp(si.productId))])
            .get();

    return rows.map((j) {
      final item = j.readTable(si);
      final prod = j.readTable(p);
      return _DetailItem(name: prod.name, qty: item.qty, price: item.price);
    }).toList();
  }

  // ======= SHEET DETAIL =======
  Future<void> _showDetail(_SaleRow row) async {
    final items = await _loadItems(row.sale.id);
    if (!mounted) return;

    await showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.white,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => DraggableScrollableSheet(
        expand: false,
        initialChildSize: .75,
        maxChildSize: .95,
        minChildSize: .5,
        builder: (_, controller) => Padding(
          padding: const EdgeInsets.fromLTRB(16, 8, 16, 16),
          child: Column(
            children: [
              Container(
                width: 36,
                height: 4,
                margin: const EdgeInsets.only(bottom: 12),
                decoration: BoxDecoration(
                  color: Colors.black12,
                  borderRadius: BorderRadius.circular(999),
                ),
              ),
              Row(
                children: [
                  Text(
                    'Transaksi #${row.sale.id}',
                    style: Theme.of(context).textTheme.titleLarge?.copyWith(
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    DateFormat(
                      'dd MMM yyyy • HH:mm',
                    ).format(row.sale.createdAt),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Expanded(
                child: ListView.separated(
                  controller: controller,
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const Divider(height: 1),
                  itemBuilder: (_, i) {
                    final it = items[i];
                    return ListTile(
                      title: Text(it.name),
                      subtitle: Text(
                        '${it.qty} × ${_currency.format(it.price)}',
                      ),
                      trailing: Text(
                        _currency.format(it.total),
                        style: const TextStyle(fontWeight: FontWeight.w700),
                      ),
                    );
                  },
                ),
              ),
              const SizedBox(height: 8),
              _kv('Subtotal', _currency.format(row.sale.subtotal)),
              _kv('Dibayar', _currency.format(row.sale.paid)),
              const Divider(height: 20),
              _kv('Kembalian', _currency.format(row.sale.change), bold: true),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        // 1) muat data transaksi (pakai helper yang sudah kamu buat)
                        final data = await _loadSale(
                          row.sale.id,
                        ); // <— kembalikan (sale, items)

                        // 2) bangun teks struk
                        final text = buildReceiptText(
                          saleId: data.sale.id,
                          items: data.items, // List<ReceiptItem>
                          subtotal: data.sale.subtotal,
                          paid: data.sale.paid,
                          change: data.sale.change,
                          currency: _currency, // NumberFormat
                        );

                        // 3) share
                        await Share.share(
                          text,
                          subject: 'Struk #${data.sale.id}',
                        );
                      },
                      icon: const Icon(Icons.ios_share_rounded),
                      label: const Text('Bagikan'),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: () async {
                        final data = await _loadSale(row.sale.id);

                        // 1) bangun dokumen PDF
                        final pw.Document doc = buildReceiptPdf(
                          saleId: data.sale.id,
                          items: data.items,
                          subtotal: data.sale.subtotal,
                          paid: data.sale.paid,
                          change: data.sale.change,
                          currency: _currency,
                        );

                        // 2) buka dialog print / simpan PDF
                        await Printing.layoutPdf(
                          onLayout: (format) async => await doc.save(),
                        );
                      },
                      icon: const Icon(Icons.print_rounded),
                      label: const Text('Cetak'),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ======= UI =======
  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    return Scaffold(
      appBar: AppBar(
        title: const Text(
          'RIWAYAT',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
        ),
        backgroundColor: const Color(0xFF5A54FF),
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Material(
              elevation: 6,
              borderRadius: BorderRadius.circular(22),
              child: TextField(
                controller: _searchC,
                onChanged: (_) => setState(() {}),
                decoration: InputDecoration(
                  hintText: 'Cari',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: Colors.white,
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                ),
              ),
            ),
          ),
        ),
      ),
      body: Column(
        children: [
          // Filter rentang waktu
          Container(
            decoration: const BoxDecoration(
              color: Colors.white,
              border: Border(
                bottom: BorderSide(
                  color: Color(0xFFE9E9EF),
                  width: 1,
                ), // garis bawah
              ),
            ),
            padding: const EdgeInsets.symmetric(vertical: 8),
            child: SizedBox(
              height: 40,
              child: ListView(
                scrollDirection: Axis.horizontal,
                physics: const BouncingScrollPhysics(),
                padding: const EdgeInsets.symmetric(horizontal: 16),
                children: [
                  _chip('Hari ini', _range == _Range.today, () {
                    setState(() => _range = _Range.today);
                  }),
                  const SizedBox(width: 10),
                  _chip('7 hari', _range == _Range.week, () {
                    setState(() => _range = _Range.week);
                  }),
                  const SizedBox(width: 10),
                  _chip('Semua', _range == _Range.all, () {
                    setState(() => _range = _Range.all);
                  }),
                ],
              ),
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: StreamBuilder<List<_SaleRow>>(
              stream: _watchSales(),
              builder: (context, snap) {
                if (!snap.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final rows = snap.data!;
                if (rows.isEmpty) {
                  return _empty('Belum ada transaksi');
                }

                // (opsional) filter sederhana by id dari TextField
                final q = _searchC.text.trim();
                final filtered = q.isEmpty
                    ? rows
                    : rows.where((r) => '${r.sale.id}'.contains(q)).toList();

                if (filtered.isEmpty) {
                  return _empty('Tidak ada hasil');
                }

                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: filtered.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (_, i) {
                    final r = filtered[i];
                    final date = DateFormat(
                      'dd MMM yyyy • HH:mm',
                    ).format(r.sale.createdAt);
                    return Card(
                      color: Colors.white,
                      surfaceTintColor: Colors.transparent,
                      elevation: 0.5,
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      child: ListTile(
                        contentPadding: const EdgeInsets.all(12),
                        title: Text(
                          _currency.format(r.sale.subtotal),
                          style: const TextStyle(fontWeight: FontWeight.w700),
                        ),
                        subtitle: Text('$date • ${r.itemCount} item'),
                        trailing: Icon(
                          Icons.chevron_right,
                          color: scheme.primary,
                        ),
                        onTap: () => _showDetail(r),
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ======= helpers UI =======
  Widget _chip(String label, bool selected, VoidCallback onTap) {
    const primary = Color(0xFF5A54FF);
    const border = Color(0xFFE9E9EF);

    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(14),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: selected ? primary.withOpacity(.08) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: border),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withOpacity(.03),
              blurRadius: selected ? 8 : 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected) ...[
              const Icon(Icons.check_rounded, size: 16, color: primary),
              const SizedBox(width: 6),
            ],
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _empty(String title) => Center(
    child: Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Icon(
            Icons.receipt_long_outlined,
            size: 64,
            color: Colors.black26,
          ),
          const SizedBox(height: 12),
          Text(title, style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 4),
          const Text(
            'Transaksi yang tersimpan akan muncul di sini.',
            style: TextStyle(color: Colors.black54),
          ),
        ],
      ),
    ),
  );

  Widget _kv(String k, String v, {bool bold = false}) => Row(
    mainAxisAlignment: MainAxisAlignment.spaceBetween,
    children: [
      Text(k, style: const TextStyle(color: Colors.black54)),
      Text(
        v,
        style: TextStyle(fontWeight: bold ? FontWeight.w800 : FontWeight.w600),
      ),
    ],
  );
}

// ======= model kecil untuk tampilan =======
class _SaleRow {
  final Sale sale;
  final int itemCount;
  final double qty;
  _SaleRow({required this.sale, required this.itemCount, required this.qty});
}

class _DetailItem {
  final String name;
  final int qty;
  final double price;
  double get total => qty * price;
  _DetailItem({required this.name, required this.qty, required this.price});
}

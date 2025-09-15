// lib/UI/pembukuan_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:path/path.dart' as p;
import 'package:drift/drift.dart' as d;
import 'package:path_provider/path_provider.dart';
import 'package:open_filex/open_filex.dart';
import 'package:share_plus/share_plus.dart';
import 'package:printing/printing.dart';
import 'package:pdf/widgets.dart' as pw;
import 'widgets/receipt.dart' show buildReceiptText, buildReceiptPdf;
// import 'widgets/checkout_success.dart' show ReceiptItem;
import 'widgets/checkout_success.dart' as receipt;
import 'package:excel/excel.dart' as ex;
import 'package:drift/drift.dart' as d show OrderingTerm;
import '../Database/app_db.dart';
import 'widgets/app_card.dart';

const appPrimary = Color(0xFF5A54FF);

enum _Range { today, week, month, all }

class PembukuanPage extends StatefulWidget {
  final AppDb db;
  final NumberFormat currency;

  const PembukuanPage({super.key, required this.db, required this.currency});

  @override
  State<PembukuanPage> createState() => _PembukuanPageState();
}

class _PembukuanPageState extends State<PembukuanPage> {
  _Range _range = _Range.today;

  // data ringkas per transaksi (untuk list)
  List<_SaleSummary> _rows = [];

  // agregasi
  int _totalItems = 0;
  double _sumSubtotal = 0;
  double _sumPaid = 0;
  double _sumChange = 0;

  bool _loading = true;

  DateTime? _fromDateOf(_Range r) {
    final now = DateTime.now();
    switch (r) {
      case _Range.today:
        return DateTime(now.year, now.month, now.day);
      case _Range.week:
        // 7 hari terakhir
        return now.subtract(const Duration(days: 6));
      case _Range.month:
        return DateTime(now.year, now.month, 1);
      case _Range.all:
        return null;
    }
  }

  @override
  void initState() {
    super.initState();
    _reload();
  }

  Future<void> _reload() async {
    setState(() => _loading = true);

    final from = _fromDateOf(_range);
    // 1) ambil sales dengan filter waktu
    final sel = widget.db.select(widget.db.sales);
    if (from != null) {
      sel.where((t) => t.createdAt.isBiggerOrEqualValue(from));
    }
    sel.orderBy([(t) => d.OrderingTerm.desc(t.createdAt)]);
    final sales = await sel.get();

    // 2) hitung itemCount tiap sale + agregasi
    final rows = <_SaleSummary>[];
    int totalItems = 0;
    double sumSubtotal = 0, sumPaid = 0, sumChange = 0;

    for (final s in sales) {
      final items = await (widget.db.select(
        widget.db.saleItems,
      )..where((t) => t.saleId.equals(s.id))).get();
      final itemCount = items.length;

      rows.add(
        _SaleSummary(
          id: s.id,
          createdAt: s.createdAt,
          subtotal: s.subtotal,
          paid: s.paid,
          change: s.change,
          itemCount: itemCount,
        ),
      );

      totalItems += itemCount;
      sumSubtotal += s.subtotal;
      sumPaid += s.paid;
      sumChange += s.change;
    }

    if (!mounted) return;
    setState(() {
      _rows = rows;
      _totalItems = totalItems;
      _sumSubtotal = sumSubtotal;
      _sumPaid = sumPaid;
      _sumChange = sumChange;
      _loading = false;
    });
  }

  // == Bagikan struk & cetak ==
  Future<void> _shareSale(int saleId) async {
    // 1) ambil data transaksi
    final (sale, items) = await _loadSale(saleId);

    // 2) bangun teks struk
    final text = buildReceiptText(
      saleId: saleId,
      items: items,
      subtotal: sale.subtotal,
      paid: sale.paid,
      change: sale.change,
      currency: widget.currency,
    );

    // 3) bagikan (pakai share_plus)
    await Share.share(text, subject: 'Struk #$saleId');
  }

  Future<void> _printSale(int saleId) async {
    // 1) ambil data transaksi
    final (sale, items) = await _loadSale(saleId);

    // 2) bangun dokumen PDF
    final doc = buildReceiptPdf(
      saleId: saleId,
      items: items,
      subtotal: sale.subtotal,
      paid: sale.paid,
      change: sale.change,
      currency: widget.currency,
    );

    // 3) tampilkan dialog print / simpan PDF
    await Printing.layoutPdf(onLayout: (_) async => doc.save());
  }

  // == Detail sale + items (untuk share/cetak) ==
  // == Detail sale + items (untuk share/cetak) ==
  Future<(_Sale sale, List<receipt.ReceiptItem> items)> _loadSale(
    int saleId,
  ) async {
    final sale = await (widget.db.select(
      widget.db.sales,
    )..where((t) => t.id.equals(saleId))).getSingle();

    final sis = await (widget.db.select(
      widget.db.saleItems,
    )..where((t) => t.saleId.equals(saleId))).get();

    // ⟵ gunakan alias di generic list
    final items = <receipt.ReceiptItem>[];

    for (final it in sis) {
      final p = await (widget.db.select(
        widget.db.products,
      )..where((t) => t.id.equals(it.productId))).getSingle();

      // ⟵ gunakan alias saat membuat objeknya juga
      items.add(
        receipt.ReceiptItem(name: p.name, qty: it.qty, price: it.price),
      );
    }

    return (
      _Sale(
        id: sale.id,
        createdAt: sale.createdAt,
        subtotal: sale.subtotal,
        paid: sale.paid,
        change: sale.change,
      ),
      items,
    );
  }

  // == Export Excel ==
  Future<void> _exportExcel() async {
    final excel = ex.Excel.createExcel();
    final sheet = excel['Pembukuan'];

    // Header
    sheet.appendRow([
      ex.TextCellValue('Tanggal'),
      ex.TextCellValue('ID'),
      ex.TextCellValue('Item'),
      ex.TextCellValue('Subtotal'),
      ex.TextCellValue('Dibayar'),
      ex.TextCellValue('Kembalian'),
    ]);

    // Data
    for (final r in _rows) {
      sheet.appendRow([
        ex.TextCellValue(DateFormat('yyyy-MM-dd HH:mm').format(r.createdAt)),
        ex.IntCellValue(r.id),
        ex.IntCellValue(r.itemCount),
        ex.DoubleCellValue(r.subtotal),
        ex.DoubleCellValue(r.paid),
        ex.DoubleCellValue(r.change),
      ]);
    }

    // Spacer + total
    sheet.appendRow([]);
    sheet.appendRow([
      ex.TextCellValue('TOTAL'),
      ex.TextCellValue(''),
      ex.IntCellValue(_totalItems),
      ex.DoubleCellValue(_sumSubtotal),
      ex.DoubleCellValue(_sumPaid),
      ex.DoubleCellValue(_sumChange),
    ]);

    final bytes = excel.encode();
    if (bytes == null) return;

    final dir = await getTemporaryDirectory();
    final name =
        'Pembukuan_${DateFormat('yyyyMMdd_HHmm').format(DateTime.now())}.xlsx';
    final file = File(p.join(dir.path, name));
    await file.writeAsBytes(bytes, flush: true);

    await OpenFilex.open(file.path);
    if (!mounted) return;
    ScaffoldMessenger.of(
      context,
    ).showSnackBar(SnackBar(content: Text('File tersimpan: ${file.path}')));
  }

  // == UI ==
  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.white,
      appBar: AppBar(
        title: const Text(
          'PEMBUKUAN',
          style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
        ),
        backgroundColor: appPrimary,
        foregroundColor: Colors.white,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(20)),
        ),
      ),
      body: SafeArea(
        child: _loading
            ? const Center(child: CircularProgressIndicator())
            : CustomScrollView(
                slivers: [
                  // ===== Filter chips scrollable (BG putih) =====
                  SliverToBoxAdapter(
                    child: _FilterBar(
                      range: _range,
                      onChanged: (r) {
                        setState(() => _range = r);
                        _reload();
                      },
                    ),
                  ),

                  // ===== Stats grid =====
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 8, 16, 8),
                      child: _StatsGrid(
                        transaksi: _rows.length,
                        itemTerjual: _totalItems,
                        subtotal: widget.currency.format(_sumSubtotal),
                        dibayar: widget.currency.format(_sumPaid),
                        kembalian: widget.currency.format(_sumChange),
                      ),
                    ),
                  ),

                  // ===== Export button =====
                  SliverToBoxAdapter(
                    child: Padding(
                      padding: const EdgeInsets.fromLTRB(16, 4, 16, 12),
                      child: SizedBox(
                        height: 52,
                        child: FilledButton.icon(
                          onPressed: _exportExcel,
                          icon: const Icon(Icons.file_download_done_rounded),
                          label: const Text('Export Excel'),
                          style: FilledButton.styleFrom(
                            backgroundColor: appPrimary,
                            shape: RoundedRectangleBorder(
                              borderRadius: BorderRadius.circular(16),
                            ),
                          ),
                        ),
                      ),
                    ),
                  ),

                  const SliverToBoxAdapter(
                    child: Padding(
                      padding: EdgeInsets.fromLTRB(16, 6, 16, 8),
                      child: Text(
                        'Transaksi',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  ),

                  // ===== List transaksi (cards putih) =====
                  SliverPadding(
                    padding: const EdgeInsets.fromLTRB(16, 0, 16, 20),
                    sliver: SliverList.separated(
                      itemCount: _rows.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 10),
                      itemBuilder: (_, i) {
                        final r = _rows[i];
                        return _SaleCard(
                          title: 'Sale #${r.id}',
                          subtitle: DateFormat(
                            'dd MMM yyyy HH:mm',
                          ).format(r.createdAt),
                          total: widget.currency.format(r.subtotal),
                          itemCount: r.itemCount,
                          onShare: () => _shareSale(r.id),
                          onPrint: () => _printSale(r.id),
                          onTap: () => _shareSale(r.id),
                        );
                      },
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  final _Range range;
  final ValueChanged<_Range> onChanged;
  const _FilterBar({required this.range, required this.onChanged});

  static const _primary = Color(0xFF5A54FF);

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: const BoxDecoration(
        color: Colors.white,
        border: Border(
          bottom: BorderSide(
            color: Color(0xFFE9E9EF), // warna garis
            width: 2, // ketebalan garis
          ),
        ),
      ),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        physics: const BouncingScrollPhysics(),
        child: Row(
          children: [
            _pill('Hari ini', _Range.today),
            SizedBox(width: 10),
            _pill('Minggu ini', _Range.week),
            SizedBox(width: 10),
            _pill('Bulan ini', _Range.month),
            SizedBox(width: 10),
            _pill('Semua', _Range.all),
          ],
        ),
      ),
    );
  }

  Widget _pill(String label, _Range value) {
    final selected = range == value;

    return InkWell(
      borderRadius: BorderRadius.circular(14),
      onTap: () => onChanged(value),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
        decoration: BoxDecoration(
          color: selected ? _primary.withOpacity(.14) : Colors.white,
          borderRadius: BorderRadius.circular(14),
          border: Border.all(
            color: selected
                ? _primary.withOpacity(.18)
                : const Color(0xFFE6E6E6),
          ),
          boxShadow: [
            // lembut, biar tampak “angkat”
            BoxShadow(
              color: Colors.black.withOpacity(0.04),
              blurRadius: 8,
              offset: const Offset(0, 3),
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            if (selected)
              Padding(
                padding: const EdgeInsets.only(right: 6),
                child: Icon(Icons.check_rounded, size: 16, color: _primary),
              ),
            Text(
              label,
              style: TextStyle(
                fontWeight: selected ? FontWeight.w700 : FontWeight.w600,
                color: Colors.black87,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _StatsGrid extends StatelessWidget {
  final int transaksi, itemTerjual;
  final String subtotal, dibayar, kembalian;
  const _StatsGrid({
    required this.transaksi,
    required this.itemTerjual,
    required this.subtotal,
    required this.dibayar,
    required this.kembalian,
  });

  @override
  Widget build(BuildContext context) {
    Widget tile(IconData ico, String label, String value) {
      return AppCard(
        padding: const EdgeInsets.all(14),
        margin: EdgeInsets.zero, // biar gridnya rapi
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Icon(
              Icons.circle, // cuma dipakai sebagai placeholder ukuran
              size: 0,
              color: Colors.transparent,
            ),
            Icon(ico, size: 22, color: const Color(0xFF5A54FF)),
            const SizedBox(height: 8),
            Text(label, style: const TextStyle(color: Colors.black54)),
            const SizedBox(height: 2),
            Text(
              value,
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w800,
                letterSpacing: .2,
              ),
            ),
          ],
        ),
      );
    }

    return GridView(
      padding: EdgeInsets.zero,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisExtent: 140,
        crossAxisSpacing: 12,
        mainAxisSpacing: 12,
      ),
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: [
        tile(Icons.receipt_long_rounded, 'Transaksi', '$transaksi'),
        tile(Icons.shopping_bag_rounded, 'Item terjual', '$itemTerjual'),
        tile(Icons.payments_rounded, 'Subtotal', subtotal),
        tile(Icons.account_balance_wallet_rounded, 'Dibayar', dibayar),
      ],
    );
  }
}

class _SaleCard extends StatelessWidget {
  final String title, subtitle, total;
  final int itemCount;
  final VoidCallback onShare, onPrint, onTap;

  const _SaleCard({
    required this.title,
    required this.subtitle,
    required this.total,
    required this.itemCount,
    required this.onShare,
    required this.onPrint,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return InkWell(
      onTap: onTap,
      borderRadius: BorderRadius.circular(16),
      child: AppCard(
        // <= pakai AppCard
        padding: const EdgeInsets.fromLTRB(16, 14, 12, 12),
        child: Row(
          children: [
            Container(
              width: 40,
              height: 40,
              decoration: BoxDecoration(
                color: const Color(0xFF5A54FF).withOpacity(.12),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Icon(
                Icons.receipt_long_rounded,
                color: Color(0xFF5A54FF), // warna brand
              ),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    style: const TextStyle(
                      fontWeight: FontWeight.w800,
                      fontSize: 16,
                    ),
                  ),
                  const SizedBox(height: 2),
                  const SizedBox(height: 2),
                  Text(subtitle, style: const TextStyle(color: Colors.black54)),
                ],
              ),
            ),
            Column(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: [
                Text(
                  total,
                  style: const TextStyle(
                    fontWeight: FontWeight.w800,
                    letterSpacing: .2,
                  ),
                ),
                Text(
                  '$itemCount item',
                  style: const TextStyle(color: Colors.black45, fontSize: 12),
                ),
                const SizedBox(height: 6),
                Row(
                  children: [
                    IconButton(
                      tooltip: 'Bagikan',
                      icon: const Icon(
                        Icons.ios_share_rounded,
                        size: 20,
                        color: Color(0xFF5A54FF),
                      ),
                      onPressed: onShare,
                    ),
                    IconButton(
                      tooltip: 'Cetak',
                      icon: const Icon(
                        Icons.print_rounded,
                        size: 20,
                        color: Color(0xFF5A54FF),
                      ),
                      onPressed: onPrint,
                    ),
                  ],
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

// ====== Model ringkas untuk list ======
class _SaleSummary {
  final int id;
  final DateTime createdAt;
  final double subtotal, paid, change;
  final int itemCount;
  _SaleSummary({
    required this.id,
    required this.createdAt,
    required this.subtotal,
    required this.paid,
    required this.change,
    required this.itemCount,
  });
}

// ====== Model untuk share/print ======
class _Sale {
  final int id;
  final DateTime createdAt;
  final double subtotal, paid, change;
  _Sale({
    required this.id,
    required this.createdAt,
    required this.subtotal,
    required this.paid,
    required this.change,
  });
}

class ReceiptItem {
  final String name;
  final int qty;
  final double price;
  const ReceiptItem({
    required this.name,
    required this.qty,
    required this.price,
  });
  double get total => qty * price;
}

// ====== Receipt builders ======
String _buildReceiptText({
  required int saleId,
  required List<ReceiptItem> items,
  required double subtotal,
  required double paid,
  required double change,
  required NumberFormat currency,
}) {
  final b = StringBuffer()
    ..writeln('STRUK #$saleId')
    ..writeln(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now()))
    ..writeln('------------------------------');

  for (final it in items) {
    b.writeln('${it.name}  x${it.qty}  @${currency.format(it.price)}');
  }

  b
    ..writeln('------------------------------')
    ..writeln('Subtotal : ${currency.format(subtotal)}')
    ..writeln('Dibayar  : ${currency.format(paid)}')
    ..writeln('Kembalian: ${currency.format(change)}');

  return b.toString();
}

pw.Document _buildReceiptPdf({
  required int saleId,
  required List<ReceiptItem> items,
  required double subtotal,
  required double paid,
  required double change,
  required NumberFormat currency,
}) {
  final doc = pw.Document();
  doc.addPage(
    pw.Page(
      build: (ctx) => pw.Column(
        crossAxisAlignment: pw.CrossAxisAlignment.start,
        children: [
          pw.Text(
            'STRUK #$saleId',
            style: pw.TextStyle(fontSize: 16, fontWeight: pw.FontWeight.bold),
          ),
          pw.SizedBox(height: 4),
          pw.Text(DateFormat('yyyy-MM-dd HH:mm').format(DateTime.now())),
          pw.SizedBox(height: 8),
          pw.Divider(),
          ...items.map(
            (it) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text(it.name)),
                pw.Text('x${it.qty}'),
                pw.Text(currency.format(it.price)),
              ],
            ),
          ),
          pw.Divider(),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [pw.Text('Subtotal'), pw.Text(currency.format(subtotal))],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [pw.Text('Dibayar'), pw.Text(currency.format(paid))],
          ),
          pw.Row(
            mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
            children: [pw.Text('Kembalian'), pw.Text(currency.format(change))],
          ),
        ],
      ),
    ),
  );
  return doc;
}

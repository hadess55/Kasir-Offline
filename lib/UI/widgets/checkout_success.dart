import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';

// === tambahkan untuk PDF/print/share ===
import 'package:pdf/widgets.dart' as pw;
import 'package:printing/printing.dart';
import 'package:share_plus/share_plus.dart';

// Data item untuk struk
class ReceiptItem {
  final String name;
  final int qty;
  final double price;
  const ReceiptItem({
    required this.name,
    required this.qty,
    required this.price,
  });
}

// ==== API yang kamu panggil dari Kasir ====
Future<void> showCheckoutSuccess(
  BuildContext context, {
  required NumberFormat currency,
  required double subtotal,
  required double paid,
  required int itemCount,
  // tambahan:
  required int saleId,
  required List<ReceiptItem> items,
  VoidCallback? onNewSale,
  VoidCallback? onPrint, // opsional override
  VoidCallback? onShare, // opsional override
}) async {
  final kembalian = (paid >= subtotal) ? (paid - subtotal) : 0.0;
  HapticFeedback.mediumImpact();

  await showModalBottomSheet(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    backgroundColor: Colors.white,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (_) => _CheckoutSuccessSheet(
      currency: currency,
      subtotal: subtotal,
      paid: paid,
      change: kembalian,
      itemCount: itemCount,
      saleId: saleId,
      items: items,
      onNewSale: onNewSale,
      onPrint: onPrint,
      onShare: onShare,
    ),
  );
}

class _CheckoutSuccessSheet extends StatelessWidget {
  final NumberFormat currency;
  final double subtotal, paid, change;
  final int itemCount;

  // tambahan:
  final int saleId;
  final List<ReceiptItem> items;

  final VoidCallback? onNewSale, onPrint, onShare;

  const _CheckoutSuccessSheet({
    required this.currency,
    required this.subtotal,
    required this.paid,
    required this.change,
    required this.itemCount,
    required this.saleId,
    required this.items,
    this.onNewSale,
    this.onPrint,
    this.onShare,
  });

  // === builder PDF struk sederhana ===
  Future<pw.Document> _buildReceiptPdf() async {
    final doc = pw.Document();
    final now = DateTime.now();

    doc.addPage(
      pw.Page(
        build: (ctx) {
          return pw.Column(
            crossAxisAlignment: pw.CrossAxisAlignment.start,
            children: [
              pw.Text(
                'STRUK PENJUALAN',
                style: pw.TextStyle(
                  fontSize: 16,
                  fontWeight: pw.FontWeight.bold,
                ),
              ),
              pw.SizedBox(height: 4),
              pw.Text(
                'No: $saleId  •  ${DateFormat('dd/MM/yyyy HH:mm').format(now)}',
              ),
              pw.SizedBox(height: 12),
              pw.Divider(),
              // Header kolom
              pw.Row(
                children: [
                  pw.Expanded(
                    flex: 6,
                    child: pw.Text(
                      'Item',
                      style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
                    ),
                  ),
                  pw.Expanded(
                    flex: 2,
                    child: pw.Text('Qty', textAlign: pw.TextAlign.right),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text('Harga', textAlign: pw.TextAlign.right),
                  ),
                  pw.Expanded(
                    flex: 3,
                    child: pw.Text('Subtotal', textAlign: pw.TextAlign.right),
                  ),
                ],
              ),
              pw.Divider(),
              // Baris item
              ...items.map((it) {
                final sub = it.price * it.qty;
                return pw.Row(
                  children: [
                    pw.Expanded(flex: 6, child: pw.Text(it.name)),
                    pw.Expanded(
                      flex: 2,
                      child: pw.Text(
                        '${it.qty}',
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        currency.format(it.price),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                    pw.Expanded(
                      flex: 3,
                      child: pw.Text(
                        currency.format(sub),
                        textAlign: pw.TextAlign.right,
                      ),
                    ),
                  ],
                );
              }),
              pw.Divider(),
              // Ringkasan
              pw.Row(
                children: [
                  pw.Spacer(),
                  pw.Expanded(
                    flex: 5,
                    child: pw.Column(
                      children: [
                        _kv('Total', currency.format(subtotal)),
                        _kv('Dibayar', currency.format(paid)),
                        _kv('Kembalian', currency.format(change), bold: true),
                      ],
                    ),
                  ),
                ],
              ),
              pw.SizedBox(height: 16),
              pw.Center(
                child: pw.Text(
                  'Terima kasih',
                  style: pw.TextStyle(fontSize: 12),
                ),
              ),
            ],
          );
        },
      ),
    );
    return doc;
  }

  static pw.Widget _kv(String k, String v, {bool bold = false}) => pw.Row(
    mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
    children: [
      pw.Text(k),
      pw.Text(
        v,
        style: pw.TextStyle(
          fontWeight: bold ? pw.FontWeight.bold : pw.FontWeight.normal,
        ),
      ),
    ],
  );

  // aksi default cetak
  Future<void> _defaultPrint() async {
    final pdf = await _buildReceiptPdf();
    await Printing.layoutPdf(onLayout: (format) async => pdf.save());
  }

  // aksi default bagikan
  Future<void> _defaultShare() async {
    final pdf = await _buildReceiptPdf();
    final bytes = await pdf.save();
    await Printing.sharePdf(bytes: bytes, filename: 'Struk-$saleId.pdf');
    // Atau pakai share_plus:
    // final temp = await Printing.convertHtml(...);  // kalau HTML
    // await Share.shareXFiles([XFile.fromData(bytes, name: 'Struk-$saleId.pdf')]);
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;

    Widget kv(String k, String v, {bool bold = false}) => Row(
      mainAxisAlignment: MainAxisAlignment.spaceBetween,
      children: [
        Text(k, style: const TextStyle(color: Colors.black54)),
        Text(
          v,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w700 : FontWeight.w600,
          ),
        ),
      ],
    );

    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 24),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Container(
            width: 36,
            height: 4,
            margin: const EdgeInsets.only(bottom: 16),
            decoration: BoxDecoration(
              color: Colors.black12,
              borderRadius: BorderRadius.circular(999),
            ),
          ),
          CircleAvatar(
            radius: 32,
            backgroundColor: scheme.primary.withOpacity(.12),
            child: Icon(
              Icons.check_circle_rounded,
              size: 44,
              color: scheme.primary,
            ),
          ),
          const SizedBox(height: 12),
          Text(
            'Transaksi selesai',
            style: Theme.of(
              context,
            ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.w800),
          ),
          const SizedBox(height: 4),
          Text(
            '$itemCount item • Total ${currency.format(subtotal)}',
            style: const TextStyle(color: Colors.black54),
          ),

          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: const Color(0xFFF6F6FA),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Column(
              children: [
                kv('Subtotal', currency.format(subtotal)),
                const SizedBox(height: 6),
                kv('Dibayar', currency.format(paid)),
                const Divider(height: 18),
                kv('Kembalian', currency.format(change), bold: true),
              ],
            ),
          ),

          const SizedBox(height: 16),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onShare ?? _defaultShare,
                  icon: const Icon(Icons.ios_share_rounded),
                  label: const Text('Bagikan'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A54FF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: onPrint ?? _defaultPrint,
                  icon: const Icon(Icons.print_rounded),
                  label: const Text('Cetak'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF5A54FF),
                    foregroundColor: Colors.white,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),

          SizedBox(
            width: double.infinity,
            height: 52,
            child: FilledButton.icon(
              onPressed: () {
                Navigator.pop(context);
                onNewSale?.call();
              },
              icon: const Icon(Icons.add_task_rounded),
              label: const Text('Transaksi baru'),
              style: FilledButton.styleFrom(
                backgroundColor: scheme.primary,
                foregroundColor: scheme.onPrimary,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

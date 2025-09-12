import 'package:pdf/widgets.dart' as pw;
import 'package:intl/intl.dart';
import '../widgets/checkout_success.dart' show ReceiptItem;

// Teks untuk share
String buildReceiptText({
  required int saleId,
  required List<ReceiptItem> items,
  required double subtotal,
  required double paid,
  required double change,
  required NumberFormat currency,
}) {
  final b = StringBuffer()
    ..writeln('STRUK #$saleId')
    ..writeln(DateTime.now())
    ..writeln('------------------------------');
  for (final it in items) {
    b.writeln('${it.name}  x${it.qty}  @${currency.format(it.price)}');
  }
  b
    ..writeln('------------------------------')
    ..writeln('Subtotal : ${currency.format(subtotal)}')
    ..writeln('Dibayar  : ${currency.format(paid)}')
    ..writeln('Kembali  : ${currency.format(change)}');
  return b.toString();
}

// PDF untuk cetak
pw.Document buildReceiptPdf({
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
          pw.Text(
            DateTime.now().toString(),
            style: const pw.TextStyle(fontSize: 10),
          ),
          pw.SizedBox(height: 8),
          pw.Divider(),
          ...items.map(
            (it) => pw.Row(
              mainAxisAlignment: pw.MainAxisAlignment.spaceBetween,
              children: [
                pw.Expanded(child: pw.Text('${it.name}  x${it.qty}')),
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
            children: [
              pw.Text(
                'Kembalian',
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
              pw.Text(
                currency.format(change),
                style: pw.TextStyle(fontWeight: pw.FontWeight.bold),
              ),
            ],
          ),
        ],
      ),
    ),
  );
  return doc;
}

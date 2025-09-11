// lib/Database/app_db.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'tables.dart';
part 'app_db.g.dart';

@DriftDatabase(
  tables: [
    Products,
    Categories,
    Sales,
    SaleItems,
    Payments,
    Customers,
    StockMovements,
  ],
)
class AppDb extends _$AppDb {
  AppDb() : super(_openConnection());

  // versi skema: mulai dari 2 karena sudah ada kolom gambar
  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();

      // Index penting untuk performa
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sales_date ON sales(date);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sale_items_product ON sale_items(product_id);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_payments_sale ON payments(sale_id);',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 2) {
        await m.addColumn(products, products.imagePath);
        await m.addColumn(products, products.thumbPath);
      }
      if (from < 3) {
        await m.addColumn(products, products.description);
      }
    },
    beforeOpen: (details) async {
      // PRAGMA untuk keandalan & kecepatan
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement('PRAGMA journal_mode = WAL;');
      await customStatement('PRAGMA synchronous = NORMAL;');
    },
  );

  // ==== Contoh fungsi yang sering dipakai ====

  // Produk
  Future<int> insertProduct(ProductsCompanion data) =>
      into(products).insert(data);
  Future updateProduct(Product p) => update(products).replace(p);
  Future deleteProduct(int id) =>
      (delete(products)..where((t) => t.id.equals(id))).go();

  Future<List<Product>> searchProducts(String q) {
    final pattern = '%${q.trim()}%';
    return (select(products)
          ..where((t) => t.name.like(pattern) | t.sku.like(pattern))
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // Transaksi penjualan atomik
  Future<int> createSale({
    required List<({int productId, double qty, double price, double discount})>
    items,
    double discount = 0,
    double tax = 0,
    String? note,
    int? customerId,
    List<({String method, double amount, String? ref})>? paymentsList,
  }) async {
    return transaction(() async {
      final subtotal = items.fold<double>(
        0,
        (s, it) => s + (it.price * it.qty - it.discount),
      );
      final total = subtotal - discount + tax;
      final saleId = await into(sales).insert(
        SalesCompanion.insert(
          subtotal: subtotal,
          discount: Value(discount),
          tax: Value(tax),
          total: total,
          note: Value(note),
          customerId: Value(customerId),
        ),
      );

      for (final it in items) {
        await into(saleItems).insert(
          SaleItemsCompanion.insert(
            saleId: saleId,
            productId: it.productId,
            qty: it.qty,
            price: it.price,
            discount: Value(it.discount),
            total: (it.price * it.qty - it.discount),
          ),
        );

        // kurangi stok & catat mutasi
        final pRow = await (select(
          products,
        )..where((t) => t.id.equals(it.productId))).getSingle();
        await (update(products)..where((t) => t.id.equals(it.productId))).write(
          ProductsCompanion(stock: Value(pRow.stock - it.qty)),
        );
        await into(stockMovements).insert(
          StockMovementsCompanion.insert(
            productId: it.productId,
            type: 'out',
            qty: it.qty,
            note: Value('sale#$saleId'),
          ),
        );
      }

      double paid = 0;
      if (paymentsList != null) {
        for (final pay in paymentsList) {
          await into(payments).insert(
            PaymentsCompanion.insert(
              saleId: saleId,
              method: pay.method,
              amount: pay.amount,
              ref: Value(pay.ref),
            ),
          );
          paid += pay.amount;
        }
      }
      final change = paid - total;
      await (update(sales)..where((t) => t.id.equals(saleId))).write(
        SalesCompanion(paid: Value(paid), change: Value(change)),
      );

      return saleId;
    });
  }

  // ==== CATEGORIES ====
  // stream daftar kategori (urut nama)
  Stream<List<Category>> watchCategories() =>
      (select(categories)..orderBy([(t) => OrderingTerm.asc(t.name)])).watch();

  Future<List<Category>> getCategories() =>
      (select(categories)..orderBy([(t) => OrderingTerm.asc(t.name)])).get();

  Future<int> insertCategory(String name) =>
      into(categories).insert(CategoriesCompanion.insert(name: name));

  Future updateCategory(Category c) => update(categories).replace(c);

  Future deleteCategory(int id) =>
      (delete(categories)..where((t) => t.id.equals(id))).go();

  // jumlah produk pada kategori (untuk validasi delete)
  Future<int> countProductsInCategory(int categoryId) async {
    final expr = products.id.count();
    final q = selectOnly(products)
      ..addColumns([expr])
      ..where(products.categoryId.equals(categoryId));
    final row = await q.getSingle();
    return row.read(expr) ?? 0;
  }

  // Berapa kali produk ini dipakai di sale_items
  Future<int> countSaleItemsForProduct(int productId) async {
    final cnt = saleItems.id.count();
    final q = selectOnly(saleItems)
      ..addColumns([cnt])
      ..where(saleItems.productId.equals(productId));
    final row = await q.getSingle();
    return row.read(cnt) ?? 0;
  }
}

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'pos.db'));
    return NativeDatabase.createInBackground(file);
  });
}

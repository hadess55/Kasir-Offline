// lib/Database/app_db.dart
import 'dart:io';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

// Tables lain yang sudah ada (Products, Categories, Payments, Customers, StockMovements)
import 'tables.dart';

part 'app_db.g.dart';

/// ---------------- TABEL TAMBAHAN (penjualan) ----------------

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
  RealColumn get subtotal => real()(); // total belanja
  RealColumn get total => real().withDefault(const Constant(0))();
  RealColumn get paid => real()(); // uang diterima
  RealColumn get change => real()(); // kembalian
}

class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId =>
      integer().references(Sales, #id, onDelete: KeyAction.cascade)();
  IntColumn get productId => integer().references(Products, #id)();
  IntColumn get qty => integer()(); // jumlah item
  RealColumn get price => real()(); // harga saat transaksi
  // (opsional) RealColumn get total => real()();
}

/// ---------------- DATABASE ----------------

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

  @override
  int get schemaVersion => 3;

  @override
  MigrationStrategy get migration => MigrationStrategy(
    onCreate: (m) async {
      await m.createAll();

      // Index (pakai nama kolom SQL yang benar)
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_products_name ON products(name);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sales_created_at ON sales(created_at);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sale_items_sale ON sale_items(sale_id);',
      );
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_sale_items_product ON sale_items(product_id);',
      );
      // Index payments/stocks hanya kalau tabel tsb memang ada di tables.dart
      await customStatement(
        'CREATE INDEX IF NOT EXISTS idx_payments_sale ON payments(sale_id);',
      );
    },
    onUpgrade: (m, from, to) async {
      if (from < 3) {
        await m.addColumn(sales, sales.total);
        await customStatement(
          'UPDATE sales SET total = subtotal WHERE total IS NULL;',
        );
      }
    },
    beforeOpen: (details) async {
      await customStatement('PRAGMA foreign_keys = ON;');
      await customStatement('PRAGMA journal_mode = WAL;');
      await customStatement('PRAGMA synchronous = NORMAL;');
    },
  );
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

  // hitung berapa produk di sebuah kategori (untuk validasi hapus)
  Future<int> countProductsInCategory(int categoryId) async {
    final cnt = products.id.count();
    final q = selectOnly(products)
      ..addColumns([cnt])
      ..where(products.categoryId.equals(categoryId));
    final row = await q.getSingle();
    return row.read(cnt) ?? 0;
  }

  // ==== util produk (contoh) ====
  Future<int> insertProduct(ProductsCompanion data) =>
      into(products).insert(data);

  Future updateProduct(Product p) => update(products).replace(p);

  Future deleteProduct(int id) =>
      (delete(products)..where((t) => t.id.equals(id))).go();

  Future<List<Product>> searchProducts(String q) {
    final pattern = '%${q.trim()}%';
    return (select(products)
          ..where((t) => t.name.like(pattern)) // hapus t.sku kalau tidak ada
          ..orderBy([(t) => OrderingTerm.asc(t.name)]))
        .get();
  }

  // Optional: versi count sale items di sini saja (hapus yang lain)
  Future<int> countSaleItemsForProduct(int productId) async {
    final cnt = saleItems.id.count();
    final q = selectOnly(saleItems)
      ..addColumns([cnt])
      ..where(saleItems.productId.equals(productId));
    final row = await q.getSingle();
    return row.read(cnt) ?? 0;
  }
}

/// -------------- KUMPULAN FUNGSI (DAO) ----------------

class SaleItemInput {
  final int productId;
  final int qty;
  final double price;
  const SaleItemInput(this.productId, this.qty, this.price);
}

extension SalesDao on AppDb {
  /// Simpan transaksi sederhana: header (sales) + detail (sale_items)
  Future<int> createSale({
    required double subtotal,
    required double paid,
    required List<SaleItemInput> items,
  }) async {
    return transaction(() async {
      final total = subtotal;
      final saleId = await into(sales).insert(
        SalesCompanion.insert(
          subtotal: subtotal,
          total: Value(total),
          paid: paid,
          change: paid - subtotal,
        ),
      );

      for (final it in items) {
        await into(saleItems).insert(
          SaleItemsCompanion.insert(
            saleId: saleId,
            productId: it.productId,
            qty: it.qty,
            price: it.price,
            // total: it.price * it.qty,
          ),
        );
      }
      return saleId;
    });
  }
}

/// -------------- KONEKSI DB ----------------

LazyDatabase _openConnection() {
  return LazyDatabase(() async {
    final dir = await getApplicationDocumentsDirectory();
    final file = File(p.join(dir.path, 'pos.db'));
    return NativeDatabase.createInBackground(file);
  });
}

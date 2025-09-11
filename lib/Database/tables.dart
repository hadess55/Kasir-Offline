// lib/Database/tables.dart
import 'package:drift/drift.dart';

class Products extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get sku => text().withLength(min: 0, max: 64).nullable()();
  TextColumn get name => text()();
  RealColumn get price => real()(); // harga jual
  RealColumn get cost => real().withDefault(const Constant(0))(); // HPP
  RealColumn get stock => real().withDefault(const Constant(0))();
  IntColumn get categoryId => integer().nullable()();
  BoolColumn get isActive => boolean().withDefault(const Constant(true))();
  TextColumn get imagePath => text().nullable()();
  TextColumn get thumbPath => text().nullable()();
  TextColumn get description => text().nullable()();
}

class Categories extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
}

class Sales extends Table {
  IntColumn get id => integer().autoIncrement()();
  DateTimeColumn get date => dateTime().withDefault(currentDateAndTime)();
  IntColumn get customerId => integer().nullable()();
  RealColumn get subtotal => real()();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get tax => real().withDefault(const Constant(0))();
  RealColumn get total => real()();
  RealColumn get paid => real().withDefault(const Constant(0))();
  RealColumn get change => real().withDefault(const Constant(0))();
  TextColumn get note => text().nullable()();
}

class SaleItems extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer()();
  IntColumn get productId => integer()();
  RealColumn get qty => real()();
  RealColumn get price => real()();
  RealColumn get discount => real().withDefault(const Constant(0))();
  RealColumn get total => real()();
}

class Payments extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get saleId => integer()();
  TextColumn get method => text()(); // cash, qris, transfer, dll
  RealColumn get amount => real()();
  TextColumn get ref => text().nullable()(); // no. transaksi / referensi bank
}

class Customers extends Table {
  IntColumn get id => integer().autoIncrement()();
  TextColumn get name => text()();
  TextColumn get phone => text().nullable()();
}

class StockMovements extends Table {
  IntColumn get id => integer().autoIncrement()();
  IntColumn get productId => integer()();
  TextColumn get type => text()(); // 'in' | 'out' | 'adjust'
  RealColumn get qty => real()();
  TextColumn get note => text().nullable()();
  DateTimeColumn get createdAt => dateTime().withDefault(currentDateAndTime)();
}

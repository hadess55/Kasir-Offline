import 'package:kasir_offline/Database/app_db.dart'; // sesuaikan import root project-mu
import '../utils/image_storage.dart';

class ProductInUseException implements Exception {}

class ProductService {
  static Future<void> deleteProduct(AppDb db, Product p) async {
    final used = await db.countSaleItemsForProduct(p.id);
    if (used > 0) {
      throw ProductInUseException(); // cegah hapus jika ada riwayat penjualan
    }
    await ImageStorage.deleteImagePair(p.imagePath, p.thumbPath);
    await (db.delete(db.products)..where((t) => t.id.equals(p.id))).go();
  }

  // Arsipkan sebagai alternatif jika pernah terjual
  static Future<void> archiveProduct(AppDb db, Product p) async {
    await db.update(db.products).replace(p.copyWith(isActive: false));
  }
}

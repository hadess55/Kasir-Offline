import 'dart:io';
import 'package:image_picker/image_picker.dart';
import 'package:path_provider/path_provider.dart';
import 'package:path/path.dart' as p;
import 'package:flutter_image_compress/flutter_image_compress.dart';

class ImageStorage {
  static final _picker = ImagePicker();

  static Future<({String originalPath, String thumbPath})?> pickAndStore({
    bool fromCamera = false,
  }) async {
    final XFile? picked = await _picker.pickImage(
      source: fromCamera ? ImageSource.camera : ImageSource.gallery,
      imageQuality: 100,
    );
    if (picked == null) return null;

    final dir = await getApplicationDocumentsDirectory();
    final base = Directory(p.join(dir.path, 'pos_images', 'products'));
    if (!await base.exists()) await base.create(recursive: true);

    final ts = DateTime.now().millisecondsSinceEpoch;
    final ext = p
        .extension(picked.path)
        .toLowerCase()
        .replaceAll('.jpeg', '.jpg');
    final originalPath = p.join(base.path, 'product_$ts$ext');

    await File(picked.path).copy(originalPath);

    final thumbBytes = await FlutterImageCompress.compressWithFile(
      originalPath,
      minWidth: 512,
      quality: 70,
      format: ext.endsWith('.png') ? CompressFormat.png : CompressFormat.jpeg,
    );
    final thumbPath = p.join(base.path, 'product_${ts}_thumb.jpg');
    await File(thumbPath).writeAsBytes(thumbBytes!);

    return (originalPath: originalPath, thumbPath: thumbPath);
  }

  static Future<void> deleteImagePair(
    String? originalPath,
    String? thumbPath,
  ) async {
    try {
      if (originalPath != null) {
        final f = File(originalPath);
        if (await f.exists()) await f.delete();
      }
      if (thumbPath != null) {
        final t = File(thumbPath);
        if (await t.exists()) await t.delete();
      }
    } catch (_) {
      // diamkan saja; kegagalan hapus file tidak boleh menggagalkan hapus data
    }
  }
}

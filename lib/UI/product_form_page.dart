// lib/ui/product_form_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' show Value;
import '../Database/app_db.dart';
import '../utils/image_storage.dart';

class ProductFormPage extends StatefulWidget {
  final AppDb db;
  final Product? existing;
  const ProductFormPage({super.key, required this.db, this.existing});

  @override
  State<ProductFormPage> createState() => _ProductFormPageState();
}

class _ProductFormPageState extends State<ProductFormPage> {
  final _form = GlobalKey<FormState>();
  final nameC = TextEditingController();
  final priceC = TextEditingController(text: '0');
  final descC = TextEditingController();

  String? imagePath;
  String? thumbPath;
  bool _available = true;
  int? _categoryId;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    if (e != null) {
      nameC.text = e.name;
      priceC.text = e.price.toStringAsFixed(0);
      descC.text = e.description ?? '';
      imagePath = e.imagePath;
      thumbPath = e.thumbPath;
      _available = e.isActive;
      _categoryId = e.categoryId;
    }
  }

  @override
  void dispose() {
    nameC.dispose();
    priceC.dispose();
    descC.dispose();
    super.dispose();
  }

  Future<void> _pick(bool fromCamera) async {
    final res = await ImageStorage.pickAndStore(fromCamera: fromCamera);
    if (res == null) return;
    setState(() {
      imagePath = res.originalPath;
      thumbPath = res.thumbPath;
    });
  }

  Future<String?> _promptNewCategory(BuildContext ctx) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        backgroundColor: Colors.white,
        title: const Text('Kategori baru'),
        content: TextField(
          controller: c,
          autofocus: true,
          decoration: const InputDecoration(hintText: 'Mis. Nasi, Minuman'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFF5A54FF),
            ),
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;

    final name = nameC.text.trim();
    final price =
        double.tryParse(priceC.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0;
    final desc = descC.text.trim();
    final descVal = desc.isEmpty ? null : desc;

    if (widget.existing == null) {
      await widget.db
          .into(widget.db.products)
          .insert(
            ProductsCompanion.insert(
              name: name,
              price: price,
              isActive: Value(_available),
              categoryId: Value(_categoryId),
              imagePath: Value(imagePath),
              thumbPath: Value(thumbPath),
              description: Value(descVal),
            ),
          );
    } else {
      final e = widget.existing!;
      await widget.db
          .update(widget.db.products)
          .replace(
            e.copyWith(
              name: name,
              price: price,
              isActive: _available,
              categoryId: Value(_categoryId),
              imagePath: Value(imagePath),
              thumbPath: Value(thumbPath),
              description: Value(descVal),
            ),
          );
    }

    try {
      if (!mounted) return;
      Navigator.pop(context, widget.existing == null ? 'created' : 'updated');
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menyimpan: $e')));
    }
  }

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final isEdit = widget.existing != null;

    final imgWidget = (thumbPath != null && File(thumbPath!).existsSync())
        ? Image.file(File(thumbPath!), fit: BoxFit.cover)
        : const Center(
            child: Icon(Icons.image, size: 48, color: Colors.black26),
          );

    return Scaffold(
      appBar: AppBar(
        title: Text(isEdit ? 'Edit Produk' : 'Tambah Produk'),
        backgroundColor: const Color(0xFF5A54FF),
        foregroundColor: Colors.white,
        toolbarHeight: 64,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF5A54FF),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
      ),

      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 12),
          children: [
            // --- area gambar ---
            Container(
              height: 210,
              decoration: BoxDecoration(
                color: const Color(0xFFF0F1F5),
                borderRadius: BorderRadius.circular(16),
              ),
              clipBehavior: Clip.antiAlias,
              child: imgWidget,
            ),
            const SizedBox(height: 10),

            // --- tombol Galeri / Kamera (pill) ---
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(false),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      foregroundColor: scheme.primary,
                      side: BorderSide(color: scheme.outlineVariant),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.image_outlined),
                    label: const Text('Galeri'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(true),
                    style: OutlinedButton.styleFrom(
                      shape: const StadiumBorder(),
                      foregroundColor: scheme.primary,
                      side: BorderSide(color: scheme.outlineVariant),
                      backgroundColor: Colors.white,
                      padding: const EdgeInsets.symmetric(vertical: 12),
                    ),
                    icon: const Icon(Icons.photo_camera_outlined),
                    label: const Text('Kamera'),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 16),

            // --- Nama Produk ---
            TextFormField(
              controller: nameC,
              textInputAction: TextInputAction.next,
              decoration: _input('Nama Produk'),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),

            // --- Kategori + tombol tambah ---
            Row(
              children: [
                Expanded(
                  child: StreamBuilder<List<Category>>(
                    stream: widget.db.watchCategories(),
                    builder: (context, snap) {
                      final cats = snap.data ?? const <Category>[];
                      return DropdownButtonFormField<int?>(
                        value: _categoryId,
                        isExpanded: true,
                        decoration: _input('Kategori'),
                        dropdownColor: Colors.white,
                        borderRadius: BorderRadius.circular(16),
                        items: [
                          const DropdownMenuItem(
                            value: null,
                            child: Text('Tanpa kategori'),
                          ),
                          ...cats.map(
                            (c) => DropdownMenuItem(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v),
                      );
                    },
                  ),
                ),
                const SizedBox(width: 10),
                SizedBox(
                  width: 56,
                  height: 56,
                  child: OutlinedButton(
                    style: OutlinedButton.styleFrom(
                      backgroundColor: Colors.white,
                      side: BorderSide(color: scheme.outlineVariant),
                      shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14),
                      ),
                      foregroundColor: scheme.primary,
                    ),
                    onPressed: () async {
                      final name = await _promptNewCategory(context);
                      if (name == null || name.trim().isEmpty) return;
                      final newId = await widget.db.insertCategory(name.trim());
                      setState(() => _categoryId = newId);
                    },
                    child: const Icon(Icons.add),
                  ),
                ),
              ],
            ),

            const SizedBox(height: 12),

            // --- Harga ---
            TextFormField(
              controller: priceC,
              keyboardType: TextInputType.number,
              decoration: _input('Harga Jual', prefix: const Text('Rp ')),
            ),

            const SizedBox(height: 12),

            // --- Deskripsi ---
            TextFormField(
              controller: descC,
              maxLines: 4,
              decoration: _input('Deskripsi (opsional)'),
            ),

            const SizedBox(height: 8),

            // --- Switch tersedia ---
            SwitchListTile(
              contentPadding: EdgeInsets.zero,
              value: _available,
              onChanged: (v) => setState(() => _available = v),
              title: const Text('Tersedia untuk dijual'),
              subtitle: const Text('Matikan jika produk sedang tidak tersedia'),
              activeColor: scheme.primary,
              shape: RoundedRectangleBorder(
                borderRadius: BorderRadius.circular(12),
              ),
            ),

            const SizedBox(height: 80),
          ],
        ),
      ),

      // --- Tombol SIMPAN besar di bawah ---
      bottomNavigationBar: SafeArea(
        top: false,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
          child: SizedBox(
            height: 54,
            child: ElevatedButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save_rounded),
              label: Text(isEdit ? 'Simpan Perubahan' : 'Simpan'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A54FF),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16),
                ),
                elevation: 0,
              ),
            ),
          ),
        ),
      ),
    );
  }

  // === dekorasi input seragam (putih, radius 14) ===
  InputDecoration _input(String label, {Widget? prefix}) {
    final scheme = Theme.of(context).colorScheme;
    return InputDecoration(
      labelText: label,
      prefix: prefix,
      filled: true,
      fillColor: Colors.white,
      isDense: true,
      contentPadding: const EdgeInsets.symmetric(horizontal: 14, vertical: 14),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(14),
        borderSide: BorderSide(color: scheme.primary, width: 1.6),
      ),
    );
  }
}

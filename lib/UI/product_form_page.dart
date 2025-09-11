import 'dart:io';
import 'package:flutter/material.dart';
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

  // 👉 baru
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
      priceC.text = e.price.toString();
      imagePath = e.imagePath;
      thumbPath = e.thumbPath;
      _available = e.isActive;
      descC.text = e.description ?? ''; // 👉 isi deskripsi
      _categoryId = e.categoryId;
    }
  }

  @override
  void dispose() {
    nameC.dispose();
    priceC.dispose();
    descC.dispose(); // 👉
    super.dispose();
  }

  Future<void> _pick(bool camera) async {
    final res = await ImageStorage.pickAndStore(fromCamera: camera);
    if (res != null) {
      setState(() {
        imagePath = res.originalPath;
        thumbPath = res.thumbPath;
      });
    }
  }

  Future<void> _save() async {
    if (!(_form.currentState?.validate() ?? false)) return;
    final price = double.tryParse(priceC.text) ?? 0;

    final descVal = descC.text.trim().isEmpty ? null : descC.text.trim();

    if (widget.existing == null) {
      await widget.db.insertProduct(
        ProductsCompanion.insert(
          name: nameC.text.trim(),
          price: price,
          isActive: Value(_available),
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
            Product(
              id: e.id,
              name: nameC.text.trim(),
              price: price,
              cost: e.cost,
              stock: e.stock,
              categoryId: _categoryId,
              isActive: _available,
              sku: e.sku,
              imagePath: imagePath,
              thumbPath: thumbPath,
              description: descVal,
            ),
          );
    }

    if (mounted) Navigator.pop(context);
  }

  Future<String?> _promptNewCategory(BuildContext ctx) async {
    final c = TextEditingController();
    return showDialog<String>(
      context: ctx,
      builder: (context) => AlertDialog(
        title: const Text('Kategori baru'),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
            hintText: 'Mis. Nasi, Minuman, Snack',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, c.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final img = (imagePath != null && File(imagePath!).existsSync())
        ? Image.file(File(imagePath!), fit: BoxFit.cover)
        : const Icon(Icons.image, size: 64);

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.existing == null ? 'Tambah Produk' : 'Edit Produk'),
      ),
      body: Form(
        key: _form,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            AspectRatio(
              aspectRatio: 4 / 3,
              child: Container(
                color: Colors.grey.shade200,
                alignment: Alignment.center,
                child: img,
              ),
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(false),
                    icon: const Icon(Icons.photo_library),
                    label: const Text('Galeri'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => _pick(true),
                    icon: const Icon(Icons.photo_camera),
                    label: const Text('Kamera'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            TextFormField(
              controller: nameC,
              decoration: const InputDecoration(
                labelText: 'Nama Produk',
                border: OutlineInputBorder(),
              ),
              validator: (v) =>
                  (v == null || v.trim().isEmpty) ? 'Wajib diisi' : null,
            ),
            const SizedBox(height: 12),

            StreamBuilder<List<Category>>(
              stream: widget.db.watchCategories(),
              builder: (context, snap) {
                final cats = snap.data ?? const <Category>[];

                return Row(
                  children: [
                    Expanded(
                      child: DropdownButtonFormField<int?>(
                        value: _categoryId,
                        isExpanded: true,
                        decoration: const InputDecoration(
                          labelText: 'Kategori',
                          border: OutlineInputBorder(),
                        ),
                        items: [
                          const DropdownMenuItem<int?>(
                            value: null,
                            child: Text('Tanpa kategori'),
                          ),
                          ...cats.map(
                            (c) => DropdownMenuItem<int?>(
                              value: c.id,
                              child: Text(c.name),
                            ),
                          ),
                        ],
                        onChanged: (v) => setState(() => _categoryId = v),
                      ),
                    ),
                    const SizedBox(width: 8),
                    // tombol +
                    IconButton.filledTonal(
                      tooltip: 'Tambah kategori',
                      icon: const Icon(Icons.add),
                      onPressed: () async {
                        final name = await _promptNewCategory(context);
                        if (name == null || name.trim().isEmpty) return;

                        // INSERT ke DB, dapatkan id baris baru
                        final newId = await widget.db.insertCategory(
                          name.trim(),
                        );

                        // pilih otomatis kategori baru
                        setState(() => _categoryId = newId);
                      },
                    ),
                  ],
                );
              },
            ),

            const SizedBox(height: 12),
            TextFormField(
              controller: priceC,
              decoration: const InputDecoration(
                labelText: 'Harga Jual',
                border: OutlineInputBorder(),
                prefixText: 'Rp ',
              ),
              keyboardType: TextInputType.number,
            ),
            const SizedBox(height: 12),

            TextFormField(
              controller: descC,
              decoration: const InputDecoration(
                labelText: 'Deskripsi (opsional)',
                border: OutlineInputBorder(),
                alignLabelWithHint: true,
              ),
              maxLines: 3,
            ),

            const SizedBox(height: 12),
            SwitchListTile(
              title: const Text('Tersedia untuk dijual'),
              subtitle: const Text('Matikan jika produk sedang tidak tersedia'),
              value: _available,
              onChanged: (v) => setState(() => _available = v),
            ),

            const SizedBox(height: 20),
            FilledButton.icon(
              onPressed: _save,
              icon: const Icon(Icons.save),
              label: const Text('Simpan'),
            ),
          ],
        ),
      ),
    );
  }
}

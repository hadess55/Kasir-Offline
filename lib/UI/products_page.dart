import 'dart:io';
import 'package:flutter/material.dart';
import 'package:drift/drift.dart' show OrderingTerm;
import '../Database/app_db.dart';
import 'product_form_page.dart';
import 'categories_page.dart';
import '../services/product_service.dart';

class ProductsPage extends StatefulWidget {
  final AppDb db;
  const ProductsPage({super.key, required this.db});
  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  int? _selectedCat; // null = semua

  @override
  Widget build(BuildContext context) {
    final db = widget.db;
    final baseSelect = db.select(db.products)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (_selectedCat != null) {
      baseSelect.where((t) => t.categoryId.equals(_selectedCat!));
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Produk'),
        actions: [
          IconButton(
            tooltip: 'Kelola Kategori',
            icon: const Icon(Icons.category_outlined),
            onPressed: () async {
              await Navigator.push(
                context,
                MaterialPageRoute(builder: (_) => CategoriesPage(db: db)),
              );
              setState(() {}); // refresh setelah kembali
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProductFormPage(db: db)),
          );
        },
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          // === baris chip filter ===
          SizedBox(
            height: 56,
            child: StreamBuilder<List<Category>>(
              stream: db.watchCategories(),
              builder: (context, snap) {
                final cats = snap.data ?? const <Category>[];
                return ListView(
                  padding: const EdgeInsets.symmetric(horizontal: 12),
                  scrollDirection: Axis.horizontal,
                  children: [
                    FilterChip(
                      label: const Text('Semua'),
                      selected: _selectedCat == null,
                      onSelected: (_) => setState(() => _selectedCat = null),
                    ),
                    const SizedBox(width: 8),
                    ...cats.map(
                      (c) => Padding(
                        padding: const EdgeInsets.only(right: 8),
                        child: FilterChip(
                          label: Text(c.name),
                          selected: _selectedCat == c.id,
                          onSelected: (_) =>
                              setState(() => _selectedCat = c.id),
                        ),
                      ),
                    ),
                  ],
                );
              },
            ),
          ),

          const Divider(height: 1),

          // === daftar produk ===
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: baseSelect.watch(),
              builder: (context, snapshot) {
                if (snapshot.connectionState == ConnectionState.waiting) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data ?? [];
                if (items.isEmpty) {
                  return const Center(child: Text('Belum ada produk.'));
                }
                return ListView.separated(
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 8),
                  itemBuilder: (context, i) {
                    final p = items[i];

                    final thumb =
                        (p.thumbPath != null && File(p.thumbPath!).existsSync())
                        ? Image.file(
                            File(p.thumbPath!),
                            width: 56,
                            height: 56,
                            fit: BoxFit.cover,
                          )
                        : Container(
                            width: 56,
                            height: 56,
                            color: Colors.grey.shade200,
                            alignment: Alignment.center,
                            child: const Icon(Icons.image_not_supported),
                          );

                    return ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(8),
                        child: thumb,
                      ),
                      title: Text(p.name),
                      subtitle: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            'Harga: ${p.price.toStringAsFixed(0)} • ${p.isActive ? 'Tersedia' : 'Tidak tersedia'}',
                          ),
                          if ((p.description ?? '').isNotEmpty)
                            Text(
                              p.description!,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                              style: const TextStyle(color: Colors.black54),
                            ),
                        ],
                      ),
                      onTap: () async {
                        await Navigator.push(
                          context,
                          MaterialPageRoute(
                            builder: (_) =>
                                ProductFormPage(db: db, existing: p),
                          ),
                        );
                      },
                      trailing: PopupMenuButton<String>(
                        onSelected: (v) async {
                          switch (v) {
                            case 'edit':
                              await Navigator.push(
                                context,
                                MaterialPageRoute(
                                  builder: (_) =>
                                      ProductFormPage(db: db, existing: p),
                                ),
                              );
                              break;
                            case 'hapus':
                              await _confirmDelete(context, db, p);
                              break;
                            case 'arsip':
                              await ProductService.archiveProduct(db, p);
                              if (context.mounted) {
                                ScaffoldMessenger.of(context).showSnackBar(
                                  const SnackBar(
                                    content: Text('Produk diarsipkan'),
                                  ),
                                );
                              }
                              break;
                          }
                        },
                        itemBuilder: (ctx) => const [
                          PopupMenuItem(value: 'edit', child: Text('Edit')),
                          PopupMenuItem(value: 'hapus', child: Text('Hapus')),
                          PopupMenuItem(
                            value: 'arsip',
                            child: Text('Arsipkan'),
                          ),
                        ],
                      ),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  Widget _thumb(Product p) {
    if (p.thumbPath != null && File(p.thumbPath!).existsSync()) {
      return ClipRRect(
        borderRadius: BorderRadius.circular(8),
        child: Image.file(
          File(p.thumbPath!),
          width: 56,
          height: 56,
          fit: BoxFit.cover,
        ),
      );
    }
    return Container(
      width: 56,
      height: 56,
      color: Colors.grey.shade200,
      child: const Icon(Icons.image_not_supported),
    );
  }

  Future<void> _confirmDelete(BuildContext context, AppDb db, Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text('Hapus "${p.name}"? Tindakan ini tidak bisa dibatalkan.'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Hapus'),
          ),
        ],
      ),
    );

    if (ok != true) return;

    try {
      await ProductService.deleteProduct(db, p);
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Produk berhasil dihapus')),
        );
      }
    } on ProductInUseException {
      if (!context.mounted) return;
      // Tawarkan arsip jika tidak bisa dihapus
      final arsip = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Tidak bisa dihapus'),
          content: const Text(
            'Produk ini sudah pernah dipakai di transaksi. '
            'Hapus akan merusak riwayat. Arsipkan saja?',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Tutup'),
            ),
            FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Arsipkan'),
            ),
          ],
        ),
      );
      if (arsip == true) {
        await ProductService.archiveProduct(db, p);
        if (context.mounted) {
          ScaffoldMessenger.of(
            context,
          ).showSnackBar(const SnackBar(content: Text('Produk diarsipkan')));
        }
      }
    } catch (e) {
      if (!context.mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('Gagal menghapus: $e')));
    }
  }
}

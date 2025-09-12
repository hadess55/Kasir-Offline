// lib/ui/products_page.dart
import 'dart:io';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:drift/drift.dart' hide Column;
import '../Database/app_db.dart';
import 'product_form_page.dart';
import '../services/product_service.dart';
import 'widgets/chip_cat.dart';
import 'widgets/nice_snack.dart';
import 'package:flutter/services.dart';

class ProductsPage extends StatefulWidget {
  final AppDb db;

  const ProductsPage({super.key, required this.db});

  @override
  State<ProductsPage> createState() => _ProductsPageState();
}

class _ProductsPageState extends State<ProductsPage> {
  void _handleFormResult(dynamic res) {
    if (!mounted || res == null) return;
    if (res == 'created') {
      showProductSaved(context);
    } else if (res == 'updated') {
      showProductUpdated(context);
    }
  }

  Future<void> _openForm({Product? p}) async {
    final res = await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => ProductFormPage(db: widget.db, existing: p),
      ),
    );
    _handleFormResult(res);
  }

  final _searchC = TextEditingController();
  String _query = '';

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );
  int? _selectedCat; // null = semua

  bool _grid = false;
  @override
  Widget build(BuildContext context) {
    final db = widget.db;

    // build query produk dinamis
    final sel = db.select(db.products)
      ..orderBy([(t) => OrderingTerm.asc(t.name)]);
    if (_selectedCat != null) {
      sel.where((t) => t.categoryId.equals(_selectedCat!));
    }
    if (_query.trim().isNotEmpty) {
      final like = '%${_query.trim()}%';
      sel.where((t) => t.name.like(like) | t.description.like(like));
    }

    return Scaffold(
      appBar: AppBar(
        systemOverlayStyle: const SystemUiOverlayStyle(
          statusBarColor: Color(0xFF5A54FF),
          statusBarIconBrightness: Brightness.light,
          statusBarBrightness: Brightness.dark,
        ),
        elevation: 0,
        backgroundColor: const Color(0xFF5A54FF),
        foregroundColor: Colors.white,
        toolbarHeight: 64,
        shape: const RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(bottom: Radius.circular(24)),
        ),
        titleSpacing: 16,
        title: Row(
          children: [
            const Text(
              'PRODUK',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
            ),
            const Spacer(),
            _SquareIconButton(
              icon: _grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
              tooltip: _grid ? 'Tampilan List' : 'Tampilan Grid',
              onTap: () => setState(() => _grid = !_grid),
            ),
            const SizedBox(width: 8),
          ],
        ),
        // search di bagian bawah AppBar
        bottom: PreferredSize(
          preferredSize: const Size.fromHeight(64),
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 12),
            child: Material(
              elevation: 8,
              borderRadius: BorderRadius.circular(22),
              shadowColor: Colors.black26,
              child: TextField(
                controller: _searchC,
                onChanged: (v) => setState(() => _query = v),
                decoration: InputDecoration(
                  hintText: 'Cari Menu',
                  prefixIcon: const Icon(Icons.search),
                  filled: true,
                  fillColor: const Color.fromARGB(255, 255, 255, 255),
                  isDense: true,
                  contentPadding: const EdgeInsets.symmetric(vertical: 12),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: BorderSide.none,
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(22),
                    borderSide: const BorderSide(color: Colors.white24),
                  ),
                ),
              ),
            ),
          ),
        ),
      ),

      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final res = await Navigator.push(
            context,
            MaterialPageRoute(builder: (_) => ProductFormPage(db: widget.db)),
          );
          _handleFormResult(res);
        },
        backgroundColor: const Color(0xFF5A54FF),
        foregroundColor: Colors.white,
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: Column(
        children: [
          Container(
            margin: const EdgeInsets.symmetric(vertical: 10),
            height: 44,
            child: SizedBox(
              height: 44,
              child: StreamBuilder<List<Category>>(
                stream: widget.db.watchCategories(),
                builder: (context, snap) {
                  final cats = snap.data ?? const <Category>[];
                  return ListView.separated(
                    scrollDirection: Axis.horizontal,
                    padding: const EdgeInsets.symmetric(horizontal: 20),
                    itemCount: 1 + cats.length,
                    separatorBuilder: (_, __) => const SizedBox(width: 8),
                    itemBuilder: (context, i) {
                      if (i == 0) {
                        return ChipCat(
                          label: 'Semua',
                          selected: _selectedCat == null,
                          onTap: () => setState(() => _selectedCat = null),
                        );
                      }
                      final c = cats[i - 1];
                      return ChipCat(
                        label: c.name,
                        selected: _selectedCat == c.id,
                        onTap: () => setState(() => _selectedCat = c.id),
                      );
                    },
                  );
                },
              ),
            ),
          ),

          const Divider(height: 1),

          // ====== LIST / GRID ======
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: sel.watch(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return _EmptyState(
                    title: _query.isEmpty
                        ? 'Belum ada produk'
                        : 'Tidak ada hasil',
                    subtitle: _query.isEmpty
                        ? 'Tambah produk via tombol di kanan bawah.'
                        : 'Coba kata kunci lain atau pilih kategori berbeda.',
                  );
                }

                if (_grid) {
                  return AnimatedSwitcher(
                    duration: const Duration(milliseconds: 100),
                    child: GridView.builder(
                      key: const ValueKey('grid'),
                      padding: const EdgeInsets.all(12),
                      gridDelegate:
                          const SliverGridDelegateWithFixedCrossAxisCount(
                            crossAxisCount: 2,
                            childAspectRatio: 3 / 4,
                            crossAxisSpacing: 12,
                            mainAxisSpacing: 12,
                          ),
                      itemCount: items.length,
                      itemBuilder: (context, i) => _ProductCard(
                        p: items[i],
                        currency: _currency,
                        onTap: () async {
                          await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductFormPage(db: db, existing: items[i]),
                            ),
                          );
                        },
                        onDelete: () => _confirmDelete(context, db, items[i]),
                        onArchive: () async {
                          await ProductService.archiveProduct(db, items[i]);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Produk diarsipkan'),
                              ),
                            );
                          }
                        },
                      ),
                    ),
                  );
                }

                return AnimatedSwitcher(
                  duration: const Duration(milliseconds: 100),
                  child: ListView.separated(
                    key: const ValueKey('list'),
                    padding: const EdgeInsets.all(12),
                    itemCount: items.length,
                    separatorBuilder: (_, __) => const SizedBox(height: 10),
                    itemBuilder: (context, i) {
                      final p = items[i];
                      return _ProductTile(
                        p: p,
                        currency: _currency,
                        onTap: () async {
                          final res = await Navigator.push(
                            context,
                            MaterialPageRoute(
                              builder: (_) =>
                                  ProductFormPage(db: widget.db, existing: p),
                            ),
                          );
                          _handleFormResult(res);
                        },
                        onDelete: () => _confirmDelete(context, db, p),
                        onArchive: () async {
                          await ProductService.archiveProduct(db, p);
                          if (context.mounted) {
                            ScaffoldMessenger.of(context).showSnackBar(
                              const SnackBar(
                                content: Text('Produk diarsipkan'),
                              ),
                            );
                          }
                        },
                      );
                    },
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }

  // ====== Dialog konfirmasi hapus ======
  Future<void> _confirmDelete(BuildContext context, AppDb db, Product p) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Hapus Produk'),
        content: Text('Hapus "${p.name}"?'),
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
      if (!mounted) return;
      showProductDeleted(context);
    } on ProductInUseException {
      if (!context.mounted) return;
      final arsip = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('Tidak bisa dihapus'),
          content: const Text(
            'Produk ini sudah pernah dipakai di transaksi.\n'
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

// ====== Widget Kartu/Grid ======
class _ProductCard extends StatelessWidget {
  final Product p;
  final NumberFormat currency;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onArchive;

  const _ProductCard({
    required this.p,
    required this.currency,
    required this.onTap,
    required this.onDelete,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    final image = _thumb(p, radius: 16, size: const Size(double.infinity, 140));
    return InkWell(
      borderRadius: BorderRadius.circular(16),
      onTap: onTap,
      child: Card(
        color: Colors.white, // << tambah
        surfaceTintColor: Colors.transparent,
        clipBehavior: Clip.antiAlias,
        elevation: 1,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Stack(
              children: [
                SizedBox(height: 140, width: double.infinity, child: image),
                if (!p.isActive)
                  Positioned(
                    top: 8,
                    left: 8,
                    child: Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: 8,
                        vertical: 4,
                      ),
                      decoration: BoxDecoration(
                        color: Colors.black54,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: const Text(
                        'Tidak tersedia',
                        style: TextStyle(color: Colors.white, fontSize: 11),
                      ),
                    ),
                  ),
                Positioned(
                  right: 4,
                  top: 4,

                  child: PopupMenuButton<String>(
                    color: Colors.white, // ⬅️ BG putih
                    surfaceTintColor:
                        Colors.transparent, // ⬅️ hilangkan tint M3
                    elevation: 10,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(12),
                    ),
                    onSelected: (v) => v == 'edit'
                        ? onTap()
                        : v == 'hapus'
                        ? onDelete()
                        : onArchive(),
                    itemBuilder: (ctx) => const [
                      PopupMenuItem(value: 'edit', child: Text('Edit')),
                      PopupMenuItem(value: 'hapus', child: Text('Hapus')),
                      PopupMenuItem(value: 'arsip', child: Text('Arsipkan')),
                    ],
                  ),
                ),
              ],
            ),
            Padding(
              padding: const EdgeInsets.fromLTRB(12, 10, 12, 6),
              child: Text(
                p.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 12),
              child: Text(
                '${currency.format(p.price)} • ${p.isActive ? 'Tersedia' : 'Tidak'}',
                style: Theme.of(
                  context,
                ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
              ),
            ),
            if ((p.description ?? '').isNotEmpty)
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 4, 12, 12),
                child: Text(
                  p.description!,
                  maxLines: 2,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(
                    context,
                  ).textTheme.bodySmall?.copyWith(color: Colors.black54),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

// ====== Widget Tile/List ======
class _ProductTile extends StatelessWidget {
  final Product p;
  final NumberFormat currency;
  final VoidCallback onTap;
  final VoidCallback onDelete;
  final VoidCallback onArchive;

  const _ProductTile({
    required this.p,
    required this.currency,
    required this.onTap,
    required this.onDelete,
    required this.onArchive,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        contentPadding: const EdgeInsets.all(10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _thumb(p, size: const Size(56, 56)),
        ),
        title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const SizedBox(height: 2),
            Text(
              '${currency.format(p.price)} • ${p.isActive ? 'Tersedia' : 'Tidak tersedia'}',
              style: const TextStyle(color: Colors.black54),
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
        onTap: onTap,
        trailing: PopupMenuButton<String>(
          color: Colors.white, // ⬅️ BG putih
          surfaceTintColor: Colors.transparent, // ⬅️ hilangkan tint M3
          elevation: 10,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(12),
          ),
          onSelected: (v) => v == 'edit'
              ? onTap()
              : v == 'hapus'
              ? onDelete()
              : onArchive(),
          itemBuilder: (ctx) => const [
            PopupMenuItem(value: 'edit', child: Text('Edit')),
            PopupMenuItem(value: 'hapus', child: Text('Hapus')),
            PopupMenuItem(value: 'arsip', child: Text('Arsipkan')),
          ],
        ),
      ),
    );
  }
}

// ====== Helper gambar ======
Widget _thumb(Product p, {Size size = const Size(56, 56), double radius = 10}) {
  if (p.thumbPath != null && File(p.thumbPath!).existsSync()) {
    return ClipRRect(
      borderRadius: BorderRadius.circular(radius),
      child: Image.file(
        File(p.thumbPath!),
        width: size.width,
        height: size.height,
        fit: BoxFit.cover,
      ),
    );
  }
  return Container(
    width: size.width,
    height: size.height,
    alignment: Alignment.center,
    decoration: BoxDecoration(
      color: const Color(0xFFEFF1F5),
      borderRadius: BorderRadius.circular(radius),
    ),
    child: const Icon(Icons.image_not_supported, color: Colors.black26),
  );
}

// ====== Empty state elegan ======
class _EmptyState extends StatelessWidget {
  final String title;
  final String subtitle;
  const _EmptyState({required this.title, required this.subtitle});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.inventory_2_outlined,
              size: 64,
              color: Colors.black26,
            ),
            const SizedBox(height: 12),
            Text(title, style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 4),
            Text(
              subtitle,
              textAlign: TextAlign.center,
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class _SquareIconButton extends StatelessWidget {
  final IconData icon;
  final String? tooltip;
  final VoidCallback? onTap;
  const _SquareIconButton({required this.icon, this.tooltip, this.onTap});

  @override
  Widget build(BuildContext context) {
    final box = Container(
      width: 34,
      height: 34,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.25),
        borderRadius: BorderRadius.circular(8),
      ),
      alignment: Alignment.center,
      child: Icon(icon, color: Colors.white),
    );

    final child = InkWell(
      borderRadius: BorderRadius.circular(8),
      onTap: onTap,
      child: box,
    );

    return tooltip == null ? child : Tooltip(message: tooltip!, child: child);
  }
}

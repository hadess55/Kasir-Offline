import 'package:flutter/material.dart';
import '../Database/app_db.dart';

class CategoriesPage extends StatelessWidget {
  final AppDb db;
  const CategoriesPage({super.key, required this.db});

  Future<void> _add(BuildContext context) async {
    final name = await _prompt(context, title: 'Kategori baru');
    if (name != null && name.trim().isNotEmpty) {
      await db.insertCategory(name.trim());
    }
  }

  Future<void> _edit(BuildContext context, Category c) async {
    final name = await _prompt(
      context,
      title: 'Ubah kategori',
      initial: c.name,
    );
    if (name != null && name.trim().isNotEmpty) {
      await db.updateCategory(c.copyWith(name: name.trim()));
    }
  }

  Future<void> _delete(BuildContext context, Category c) async {
    final n = await db.countProductsInCategory(c.id);
    if (n > 0) {
      if (context.mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(
            content: Text(
              'Tidak bisa hapus. Ada $n produk di kategori "${c.name}".',
            ),
          ),
        );
      }
      return;
    }
    await db.deleteCategory(c.id);
  }

  Future<String?> _prompt(
    BuildContext ctx, {
    required String title,
    String? initial,
  }) async {
    final c = TextEditingController(text: initial ?? '');
    return showDialog<String>(
      context: ctx,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: TextField(
          controller: c,
          decoration: const InputDecoration(
            hintText: 'Mis. Nasi, Minuman, Snack',
          ),
          autofocus: true,
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: const Text('Batal'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(ctx, c.text),
            child: const Text('Simpan'),
          ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Kategori')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _add(context),
        icon: const Icon(Icons.add),
        label: const Text('Tambah'),
      ),
      body: StreamBuilder<List<Category>>(
        stream: db.watchCategories(),
        builder: (context, snap) {
          if (!snap.hasData) {
            return const Center(child: CircularProgressIndicator());
          }
          final items = snap.data!;
          if (items.isEmpty)
            return const Center(child: Text('Belum ada kategori.'));
          return ListView.separated(
            itemCount: items.length,
            separatorBuilder: (_, __) => const Divider(height: 1),
            itemBuilder: (context, i) {
              final c = items[i];
              return ListTile(
                title: Text(c.name),
                onTap: () => _edit(context, c),
                trailing: IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: () => _delete(context, c),
                ),
              );
            },
          );
        },
      ),
    );
  }
}

// lib/UI/kasir_page.dart
import 'dart:io';
import 'package:drift/drift.dart' hide Column;
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:intl/intl.dart';
import '../Database/app_db.dart';
import 'widgets/chip_cat.dart';
import 'widgets/checkout_success.dart';

class KasirPage extends StatefulWidget {
  final AppDb db;
  const KasirPage({super.key, required this.db});

  @override
  State<KasirPage> createState() => _KasirPageState();
}

class _KasirPageState extends State<KasirPage> {
  final _searchC = TextEditingController();
  String _query = '';
  int? _selectedCat;
  bool _grid = true;

  final _currency = NumberFormat.currency(
    locale: 'id_ID',
    symbol: 'Rp',
    decimalDigits: 0,
  );

  // ===== Cart sederhana (in-memory) =====
  final Map<int, _Line> _cart = {}; // key: product.id

  double get _subtotal =>
      _cart.values.fold(0.0, (sum, l) => sum + (l.product.price * l.qty));

  @override
  void dispose() {
    _searchC.dispose();
    super.dispose();
  }

  void _addToCart(Product p, {int qty = 1}) {
    setState(() {
      final cur = _cart[p.id];
      if (cur == null) {
        _cart[p.id] = _Line(product: p, qty: qty);
      } else {
        _cart[p.id] = cur.copyWith(qty: cur.qty + qty);
      }
    });
  }

  void _setQty(int productId, int qty) {
    if (!_cart.containsKey(productId)) return;
    setState(() {
      if (qty <= 0) {
        _cart.remove(productId);
      } else {
        _cart[productId] = _cart[productId]!.copyWith(qty: qty);
      }
    });
  }

  void _removeLine(int productId) {
    setState(() {
      _cart.remove(productId);
    });
  }

  @override
  Widget build(BuildContext context) {
    // Build query produk
    final sel = widget.db.select(widget.db.products)
      ..where((t) => t.isActive.equals(true))
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
        elevation: 0,
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
        titleSpacing: 16,
        title: Row(
          children: [
            const Text(
              'KASIR',
              style: TextStyle(fontWeight: FontWeight.w900, letterSpacing: 1.0),
            ),
            const Spacer(),
            _SquareIconButton(
              icon: _grid ? Icons.view_list_rounded : Icons.grid_view_rounded,
              tooltip: _grid ? 'Tampilan List' : 'Tampilan Grid',
              onTap: () => setState(() => _grid = !_grid),
            ),
          ],
        ),
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
                  fillColor: Colors.white,
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

      body: Column(
        children: [
          // ===== Kategori Chips =====
          // Sebelum: langsung SizedBox(height: 44, child: StreamBuilder(...))

          // Sesudah:
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: 12,
            ), // jarak atas & bawah
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

          // ===== Daftar Produk =====
          Expanded(
            child: StreamBuilder<List<Product>>(
              stream: sel.watch(),
              builder: (context, snapshot) {
                if (!snapshot.hasData) {
                  return const Center(child: CircularProgressIndicator());
                }
                final items = snapshot.data!;
                if (items.isEmpty) {
                  return const _EmptyStateKasir(
                    title: 'Produk kosong',
                    subtitle:
                        'Belum ada produk aktif. Tambah produk terlebih dahulu.',
                  );
                }

                if (_grid) {
                  return GridView.builder(
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
                    itemBuilder: (context, i) {
                      final p = items[i];
                      return _ProductCard(
                        p: p,
                        onAdd: () => _addToCart(p),
                        currency: _currency,
                      );
                    },
                  );
                }

                return ListView.separated(
                  key: const ValueKey('list'),
                  padding: const EdgeInsets.all(12),
                  itemCount: items.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, i) {
                    final p = items[i];
                    return _ProductTile(
                      p: p,
                      currency: _currency,
                      onAdd: () => _addToCart(p),
                    );
                  },
                );
              },
            ),
          ),
        ],
      ),

      // ===== Bottom cart bar =====
      bottomNavigationBar: _CartBar(
        subtotal: _subtotal,
        currency: _currency,
        itemCount: _cart.values.fold<int>(0, (n, l) => n + l.qty),
        onTap: _cart.isEmpty
            ? null
            : () {
                showModalBottomSheet(
                  context: context,
                  showDragHandle: true,
                  isScrollControlled: true,
                  backgroundColor: Colors.white,
                  shape: const RoundedRectangleBorder(
                    borderRadius: BorderRadius.vertical(
                      top: Radius.circular(20),
                    ),
                  ),
                  builder: (_) => _CartSheet(
                    lines: _cart.values.toList(),
                    currency: _currency,
                    onQtyChanged: (id, q) => _setQty(id, q),
                    onRemove: (id) => _removeLine(id),
                    onClear: () {
                      setState(() => _cart.clear());
                      Navigator.pop(context);
                    },
                    onCheckout: (paid) {
                      // TODO: simpan transaksi ke DB di sini kalau table sudah siap
                      setState(() => _cart.clear());
                      Navigator.pop(context);
                      ScaffoldMessenger.of(context).showSnackBar(
                        const SnackBar(content: Text('Transaksi selesai')),
                      );
                    },
                  ),
                );
              },
      ),
    );
  }
}

// ====== Model cart line ======
class _Line {
  final Product product;
  final int qty;
  _Line({required this.product, required this.qty});
  _Line copyWith({Product? product, int? qty}) =>
      _Line(product: product ?? this.product, qty: qty ?? this.qty);
}

// ====== Widget kecil ======
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

class _ChipCat extends StatelessWidget {
  final String label;
  final bool selected;
  final VoidCallback onTap;
  const _ChipCat({
    required this.label,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    return ChoiceChip(
      label: Text(label),
      selected: selected,
      onSelected: (_) => onTap(),
      backgroundColor: Colors.white,
      selectedColor: Colors.white,
      side: BorderSide(
        color: selected ? scheme.primary : scheme.outlineVariant,
        width: selected ? 1 : 1,
      ),
      labelStyle: TextStyle(
        color: selected ? scheme.primary : scheme.onSurface,
        fontWeight: selected ? FontWeight.w600 : FontWeight.w500,
      ),
      showCheckmark: selected,
      checkmarkColor: scheme.primary,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      labelPadding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      materialTapTargetSize: MaterialTapTargetSize.shrinkWrap,
    );
  }
}

// ====== Produk grid card & list tile (tap = tambah ke cart) ======
class _ProductCard extends StatelessWidget {
  final Product p;
  final NumberFormat currency;
  final VoidCallback? onAdd;
  const _ProductCard({
    required this.p,
    required this.currency,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      clipBehavior: Clip.antiAlias,
      elevation: 1,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      child: Stack(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              SizedBox(height: 140, width: double.infinity, child: _thumb(p)),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
                child: Text(
                  p.name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(12, 0, 12, 12),
                child: Text(
                  currency.format(p.price),
                  style: const TextStyle(color: Colors.black54),
                ),
              ),
              if (onAdd != null)
                const SizedBox(height: 36), // ruang untuk tombol
            ],
          ),

          if (onAdd != null)
            Positioned(
              right: 8,
              bottom: 8,
              child: AddButton(
                onPressed: onAdd!,
                compact: true, // versi kecil agar pas di kartu
              ),
            ),
        ],
      ),
    );
  }
}

class _ProductTile extends StatelessWidget {
  final Product p;
  final NumberFormat currency;
  final VoidCallback onAdd;
  const _ProductTile({
    required this.p,
    required this.currency,
    required this.onAdd,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      color: Colors.white,
      surfaceTintColor: Colors.transparent,
      elevation: 0.5,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
      child: ListTile(
        // onTap: null,  // hapus/biarkan null agar klik tile tidak menambah
        contentPadding: const EdgeInsets.all(10),
        leading: ClipRRect(
          borderRadius: BorderRadius.circular(10),
          child: _thumb(p, size: const Size(56, 56)),
        ),
        title: Text(p.name, maxLines: 1, overflow: TextOverflow.ellipsis),
        subtitle: Text(
          currency.format(p.price),
          style: const TextStyle(color: Colors.black54),
        ),
        trailing: AddButton(onPressed: onAdd),
      ),
    );
  }
}

Widget _thumb(Product p, {Size size = const Size(double.infinity, 140)}) {
  if (p.thumbPath != null && File(p.thumbPath!).existsSync()) {
    return Image.file(
      File(p.thumbPath!),
      width: size.width,
      height: size.height,
      fit: BoxFit.cover,
    );
  }
  return Container(
    width: size.width,
    height: size.height,
    color: const Color(0xFFEFF1F5),
    alignment: Alignment.center,
    child: const Icon(Icons.image_not_supported, color: Colors.black26),
  );
}

// ====== Cart UI ======
class _CartBar extends StatelessWidget {
  final double subtotal;
  final int itemCount;
  final NumberFormat currency;
  final VoidCallback? onTap;
  const _CartBar({
    required this.subtotal,
    required this.itemCount,
    required this.currency,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Container(
        padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
        decoration: const BoxDecoration(
          color: Colors.white,
          borderRadius: BorderRadius.vertical(top: Radius.circular(18)),
          boxShadow: [BoxShadow(color: Colors.black12, blurRadius: 8)],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '${itemCount} item',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 2),
                  Text(
                    currency.format(subtotal),
                    style: const TextStyle(
                      fontSize: 18,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            ),
            ElevatedButton.icon(
              onPressed: onTap,
              icon: const Icon(Icons.shopping_cart),
              label: const Text('Keranjang'),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFF5A54FF),
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(
                  horizontal: 18,
                  vertical: 14,
                ),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
                elevation: 0,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _CartSheet extends StatefulWidget {
  final List<_Line> lines;
  final NumberFormat currency;
  final void Function(int productId, int qty) onQtyChanged;
  final void Function(int productId) onRemove;
  final VoidCallback onClear;
  final void Function(double paid) onCheckout;
  const _CartSheet({
    required this.lines,
    required this.currency,
    required this.onQtyChanged,
    required this.onRemove,
    required this.onClear,
    required this.onCheckout,
  });

  @override
  State<_CartSheet> createState() => _CartSheetState();
}

class _CartSheetState extends State<_CartSheet> {
  final _payC = TextEditingController();

  bool get _canCheckout =>
      _lines.isNotEmpty && _subtotal > 0 && _paid >= _subtotal;
  // salinan lokal agar UI sheet bisa langsung berubah
  late List<_Line> _lines;

  @override
  void initState() {
    super.initState();
    _lines = widget.lines
        .map((e) => _Line(product: e.product, qty: e.qty))
        .toList();
  }

  double get _subtotal =>
      _lines.fold(0.0, (s, l) => s + l.product.price * l.qty);

  double get _paid =>
      double.tryParse(_payC.text.replaceAll(RegExp(r'[^0-9]'), '')) ?? 0.0;

  // helper: ubah qty lokal + kabari parent
  void _changeQty(int id, int qty) {
    final i = _lines.indexWhere((l) => l.product.id == id);
    if (i == -1) return;
    setState(() {
      if (qty <= 0) {
        _lines.removeAt(i);
      } else {
        _lines[i] = _lines[i].copyWith(qty: qty);
      }
    });
    widget.onQtyChanged(id, qty); // update parent
  }

  void _removeLine(int id) {
    setState(() {
      _lines.removeWhere((l) => l.product.id == id);
    });
    widget.onRemove(id); // kabari parent
  }

  @override
  Widget build(BuildContext context) {
    return DraggableScrollableSheet(
      expand: false,
      minChildSize: 0.45,
      initialChildSize: 0.75,
      maxChildSize: 0.95,
      builder: (_, controller) => Padding(
        padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
        child: Column(
          children: [
            // Header
            Row(
              children: [
                const Text(
                  'Keranjang',
                  style: TextStyle(fontSize: 18, fontWeight: FontWeight.w700),
                ),
                const Spacer(),
                TextButton.icon(
                  onPressed: _lines.isEmpty
                      ? null
                      : () {
                          setState(() {
                            _lines.clear(); // kosongkan lokal
                            _payC.clear(); // reset input bayar
                          });
                          widget.onClear(); // kosongkan parent
                        },
                  icon: const Icon(Icons.delete_outline),
                  label: const Text('Kosongkan'),
                ),
              ],
            ),
            const SizedBox(height: 6),

            // Lines
            Expanded(
              child: ListView.separated(
                controller: controller,
                itemCount: _lines.length, // <-- pakai _lines
                separatorBuilder: (_, __) => const SizedBox(height: 10),
                itemBuilder: (_, i) {
                  final l = _lines[i]; // <-- pakai _lines
                  final p = l.product;
                  return Card(
                    color: Colors.white,
                    surfaceTintColor: Colors.transparent,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                    ),
                    child: ListTile(
                      leading: ClipRRect(
                        borderRadius: BorderRadius.circular(10),
                        child: _thumb(p, size: const Size(56, 56)),
                      ),
                      title: Text(
                        p.name,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      subtitle: Text(widget.currency.format(p.price)),
                      trailing: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          IconButton(
                            tooltip: 'Kurangi',
                            icon: const Icon(Icons.remove_circle_outline),
                            onPressed: () =>
                                _changeQty(p.id, l.qty - 1), // <-- lokal
                          ),
                          Text(
                            '${l.qty}',
                            style: const TextStyle(fontWeight: FontWeight.w700),
                          ),
                          IconButton(
                            tooltip: 'Tambah',
                            icon: const Icon(Icons.add_circle_outline),
                            onPressed: () =>
                                _changeQty(p.id, l.qty + 1), // <-- lokal
                          ),
                          IconButton(
                            tooltip: 'Hapus',
                            icon: const Icon(Icons.close),
                            onPressed: () =>
                                _removeLine(p.id), // <-- pakai _removeLine
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),

            const SizedBox(height: 8),

            // Ringkasan & bayar
            Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.white,
                borderRadius: BorderRadius.circular(14),
                boxShadow: const [
                  BoxShadow(color: Colors.black12, blurRadius: 6),
                ],
              ),
              child: Column(
                children: [
                  _kv('Subtotal', widget.currency.format(_subtotal)),
                  const SizedBox(height: 12),
                  TextField(
                    controller: _payC,
                    enabled:
                        _lines.isNotEmpty, // opsional: nonaktifkan saat kosong
                    onChanged: (_) =>
                        setState(() {}), // update kembalian & tombol
                    decoration: const InputDecoration(
                      labelText: 'Uang diterima',
                      prefixText: 'Rp ',
                      filled: true,
                      fillColor: Colors.white,
                      border: OutlineInputBorder(),
                    ),
                    keyboardType: TextInputType.number,
                  ),
                  const SizedBox(height: 8),
                  _kv(
                    'Kembalian',
                    _canCheckout
                        ? widget.currency.format(_paid - _subtotal)
                        : '-',
                    bold: true,
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    height: 52,
                    child: ElevatedButton.icon(
                      onPressed: _canCheckout
                          ? () async {
                              // (Opsional) simpan transaksi ke DB di sini.
                              await showCheckoutSuccess(
                                context,
                                currency: widget.currency,
                                subtotal: _subtotal, // double
                                paid:
                                    _paid, // double dari TextField "Uang diterima"
                                itemCount: _lines.length,
                                onNewSale: () {
                                  // reset keranjang + sinkron ke parent
                                  setState(() {
                                    _lines.clear();
                                    _payC.clear();
                                  });
                                  widget.onClear();

                                  // (opsional) tutup sheet keranjang
                                  Navigator.of(context).maybePop();
                                },
                                onPrint: () {
                                  // TODO: panggil logika cetak struk
                                },
                                onShare: () {
                                  // TODO: bagikan struk (share_plus) atau preview
                                },
                              );
                            }
                          : null,
                      icon: const Icon(Icons.check_circle_outline),
                      label: const Text('Selesaikan'),
                      style: ElevatedButton.styleFrom(
                        backgroundColor: const Color(0xFF5A54FF),
                        foregroundColor: Colors.white,
                        disabledBackgroundColor: const Color(0xFFB8B4FF),
                        shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(14),
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _kv(String k, String v, {bool bold = false}) {
    return Row(
      children: [
        Text(k, style: const TextStyle(color: Colors.black54)),
        const Spacer(),
        Text(
          v,
          style: TextStyle(
            fontWeight: bold ? FontWeight.w800 : FontWeight.w600,
          ),
        ),
      ],
    );
  }
}

class _EmptyStateKasir extends StatelessWidget {
  final String title, subtitle;
  const _EmptyStateKasir({required this.title, required this.subtitle});
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
              style: const TextStyle(color: Colors.black54),
            ),
          ],
        ),
      ),
    );
  }
}

class AddButton extends StatelessWidget {
  final VoidCallback onPressed;
  final bool compact; // true = versi kecil (untuk grid)
  final String label;
  final double? fontSize;

  const AddButton({
    super.key,
    required this.onPressed,
    this.compact = false,
    this.label = '+ Tambah',
    this.fontSize,
  });

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final fs = fontSize ?? (compact ? 12.0 : 14.0);

    return FilledButton.tonal(
      onPressed: onPressed,
      style: FilledButton.styleFrom(
        // warna mengikuti tema (lebih enak dari abu-abu default)
        backgroundColor: const Color(0xFF5A54FF),
        foregroundColor: Colors.white,
        textStyle: TextStyle(
          // <<— kecilkan font di sini
          fontSize: fs,
          fontWeight: FontWeight.w600,
        ),
        padding: EdgeInsets.symmetric(
          horizontal: compact ? 10 : 12,
          vertical: compact ? 6 : 8,
        ),
        shape: const StadiumBorder(),
        elevation: 0,
      ),
      child: Text(label),
    );
  }
}

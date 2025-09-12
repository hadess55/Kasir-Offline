import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

enum NoticeType { success, info, warning, error }

void showNiceSnack(
  BuildContext context, {
  required String title,
  String? message,
  NoticeType type = NoticeType.info,
  String? actionLabel,
  VoidCallback? onAction,
  Duration duration = const Duration(seconds: 3),
}) {
  final scheme = Theme.of(context).colorScheme;

  // warna/icon per tipe
  final (Color bg, IconData icon) = switch (type) {
    NoticeType.success => (scheme.primary, Icons.check_circle_rounded),
    NoticeType.info => (scheme.secondary, Icons.info_rounded),
    NoticeType.warning => (Colors.orange, Icons.warning_amber_rounded),
    NoticeType.error => (Colors.red, Icons.error_rounded),
  };

  HapticFeedback.lightImpact();
  ScaffoldMessenger.of(context).clearSnackBars();

  ScaffoldMessenger.of(context).showSnackBar(
    SnackBar(
      elevation: 0,
      behavior: SnackBarBehavior.floating,
      backgroundColor: Colors.transparent,
      duration: duration,
      content: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
        decoration: BoxDecoration(
          color: bg,
          borderRadius: BorderRadius.circular(16),
          boxShadow: const [
            BoxShadow(
              blurRadius: 24,
              color: Colors.black12,
              offset: Offset(0, 8),
            ),
          ],
        ),
        child: Row(
          children: [
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.white.withOpacity(.18),
              child: Icon(icon, color: Colors.white),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    title,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  if (message != null && message.isNotEmpty)
                    Text(
                      message,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(color: Colors.white),
                    ),
                ],
              ),
            ),
            if (onAction != null && (actionLabel ?? '').isNotEmpty) ...[
              const SizedBox(width: 8),
              TextButton(
                style: TextButton.styleFrom(
                  foregroundColor: Colors.white,
                  padding: const EdgeInsets.symmetric(
                    horizontal: 12,
                    vertical: 8,
                  ),
                ),
                onPressed: onAction,
                child: Text(actionLabel!),
              ),
            ],
          ],
        ),
      ),
    ),
  );
}

void showProductSaved(BuildContext c) => showNiceSnack(
  c,
  title: 'Produk disimpan',
  message: 'Data produk berhasil ditambahkan.',
  type: NoticeType.success,
);

void showProductUpdated(BuildContext c) => showNiceSnack(
  c,
  title: 'Perubahan disimpan',
  message: 'Produk berhasil diperbarui.',
  type: NoticeType.success,
);

void showProductDeleted(BuildContext c) =>
    showNiceSnack(c, title: 'Produk dihapus', type: NoticeType.info);

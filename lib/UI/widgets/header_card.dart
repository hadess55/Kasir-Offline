import 'package:flutter/material.dart';

/// Header gradien reusable dengan slot konten utama + overlay card di bawah.
class AppHeaderCard extends StatelessWidget {
  const AppHeaderCard({
    super.key,
    this.title,
    this.subtitle,
    this.leading,
    this.trailing,
    this.gradientColors,
    this.height = 160,
    this.overlay,
    this.overlayHeight = 72,
    this.overlayOffset = -22,
    this.padding = const EdgeInsets.fromLTRB(16, 16, 16, 72),
  });

  /// Baris judul utama (mis. "Selamat Datang,")
  final String? title;

  /// Subjudul (mis. nama pengguna)
  final String? subtitle;

  /// Widget kiri atas (mis. avatar/icon)
  final Widget? leading;

  /// Widget kanan atas (mis. tombol settings)
  final Widget? trailing;

  /// Warna gradien header. Default: pakai warna tema (primary → primaryContainer)
  final List<Color>? gradientColors;

  /// Tinggi keseluruhan area header (tanpa overlay)
  final double height;

  /// Kartu overlay di bagian bawah (mis. statistik + tombol aksi)
  final Widget? overlay;

  /// Tinggi kartu overlay
  final double overlayHeight;

  /// Offset overlay relatif ke bawah header (negatif = menumpuk keluar)
  final double overlayOffset;

  /// Padding isi header (ruang untuk teks/ikon di dalam kartu gradien)
  final EdgeInsets padding;

  @override
  Widget build(BuildContext context) {
    final scheme = Theme.of(context).colorScheme;
    final colors = gradientColors ?? [scheme.primary, scheme.primaryContainer];

    return Stack(
      clipBehavior: Clip.none,
      children: [
        // Kartu gradien
        Container(
          height: height,
          width: double.infinity,
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(20),
            gradient: LinearGradient(
              begin: Alignment.topLeft,
              end: Alignment.bottomRight,
              colors: colors,
            ),
            boxShadow: [
              BoxShadow(
                color: colors.last.withOpacity(0.20),
                blurRadius: 16,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          padding: padding,
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              if (leading != null) ...[leading!, const SizedBox(width: 12)],
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    if (title != null)
                      Text(
                        title!,
                        style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                          color: scheme.onPrimary.withOpacity(0.9),
                        ),
                      ),
                    if (subtitle != null)
                      Text(
                        subtitle!,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(
                              color: scheme.onPrimary,
                              fontWeight: FontWeight.w700,
                            ),
                      ),
                  ],
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
        ),

        // Overlay card
        if (overlay != null)
          Positioned(
            left: 12,
            right: 12,
            bottom: overlayOffset,
            child: Container(
              height: overlayHeight,
              decoration: BoxDecoration(
                color: scheme.primary,
                borderRadius: BorderRadius.circular(18),
                boxShadow: [
                  BoxShadow(
                    color: scheme.primary.withOpacity(0.25),
                    blurRadius: 16,
                    offset: const Offset(0, 8),
                  ),
                ],
              ),
              child: overlay,
            ),
          ),
      ],
    );
  }
}

/// Spacer kecil untuk memberi ruang di bawah header jika memakai overlay.
class HeaderSpacer extends StatelessWidget {
  final double height;
  const HeaderSpacer({super.key, this.height = 28});
  @override
  Widget build(BuildContext context) => SizedBox(height: height);
}

import 'dart:async';
import 'package:flutter/material.dart';
import '../main.dart' show POSApp; // biar bisa push ke POSApp setelah animasi

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late final AnimationController _c;
  late final Animation<double> _scale;
  late final Animation<double> _fade;

  @override
  void initState() {
    super.initState();
    _c = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    );
    _scale = Tween(
      begin: 0.85,
      end: 1.0,
    ).chain(CurveTween(curve: Curves.easeOutBack)).animate(_c);
    _fade = CurvedAnimation(parent: _c, curve: const Interval(0.35, 1.0));

    unawaited(_run());
  }

  Future<void> _run() async {
    await _c.forward();
    await Future.delayed(const Duration(milliseconds: 400));
    if (!mounted) return;

    // Masuk ke aplikasi utama
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        transitionDuration: const Duration(milliseconds: 450),
        pageBuilder: (_, __, ___) => const POSApp(),
        transitionsBuilder: (_, a, __, child) =>
            FadeTransition(opacity: a, child: child),
      ),
    );
  }

  @override
  void dispose() {
    _c.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    const brand = Color(0xFF5A54FF);

    return Scaffold(
      backgroundColor: Colors.white,
      body: SafeArea(
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              ScaleTransition(
                scale: _scale,
                child: Container(
                  width: 120,
                  height: 120,
                  decoration: BoxDecoration(
                    color: brand,
                    borderRadius: BorderRadius.circular(28),
                    boxShadow: [
                      BoxShadow(
                        color: brand.withOpacity(.28),
                        blurRadius: 24,
                        offset: const Offset(0, 10),
                      ),
                    ],
                  ),
                  padding: const EdgeInsets.all(18),
                  child: Image.asset(
                    'assets/icon/app_icon.png', // pastikan ada
                    fit: BoxFit.contain,
                  ),
                ),
              ),
              const SizedBox(height: 18),

              FadeTransition(
                opacity: _fade,
                child: const Text(
                  'Kasir Offline', // nama aplikasi
                  style: TextStyle(
                    fontSize: 22,
                    fontWeight: FontWeight.w900,
                    letterSpacing: .2,
                  ),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _fade,
                child: const Text(
                  'POS • Cepat & Sederhana',
                  style: TextStyle(color: Colors.black54, fontSize: 13),
                ),
              ),
              const SizedBox(height: 8),
              FadeTransition(
                opacity: _fade,
                child: Text(
                  '© ${DateTime.now().year} Olympus Project', // otomatis ikut tahun berjalan
                  style: const TextStyle(
                    color: Colors.black54,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                    letterSpacing: .1,
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

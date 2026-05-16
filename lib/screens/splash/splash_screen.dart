import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class SplashScreen extends StatefulWidget {
  final VoidCallback onComplete;

  const SplashScreen({
    super.key,
    required this.onComplete,
  });

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _loadingController;

  @override
  void initState() {
    super.initState();
    _loadingController = AnimationController(
      duration: const Duration(milliseconds: 1500),
      vsync: this,
    )..repeat();

    // Esperar 2 segundos e depois chamar onComplete
    Future.delayed(const Duration(seconds: 2), () {
      if (mounted) {
        _loadingController.dispose();
        widget.onComplete();
      }
    });
  }

  @override
  void dispose() {
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        width: double.infinity,
        height: double.infinity,
        decoration: const BoxDecoration(
          gradient: RadialGradient(
            center: Alignment(0.4, 0.35),
            radius: 0.65,
            colors: [
              Color(0xFF0e2248),
              Color(0xFF060f22),
            ],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Logo Palpiteiro
              SizedBox(
                width: 100,
                height: 100,
                child: Image.asset(
                  'assets/images/palpiteiro-icone-small.png',
                  fit: BoxFit.contain,
                ),
              ),
              const SizedBox(height: 14),
              // Nome do app
              Text(
                'Palpiteiro',
                style: GoogleFonts.bebasNeue(
                  fontSize: 28,
                  color: const Color(0xFFEAF3DE),
                  letterSpacing: 0.1,
                ),
              ),
              const SizedBox(height: 4),
              // Subtexto
              Text(
                'Copa do Mundo 2026',
                style: GoogleFonts.dmSans(
                  fontSize: 10,
                  color: const Color(0xFF1D9E75),
                  letterSpacing: 0.1,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 14),
              // Loading bar com animação
              _buildLoadingBar(),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildLoadingBar() {
    return AnimatedBuilder(
      animation: _loadingController,
      builder: (context, child) {
        return Container(
          width: 80,
          height: 2,
          decoration: BoxDecoration(
            color: const Color(0xFF1a3050),
            borderRadius: BorderRadius.circular(2),
          ),
          child: Stack(
            children: [
              Container(
                width: 80 * (_getLoadingValue(_loadingController.value)),
                height: 2,
                decoration: BoxDecoration(
                  gradient: const LinearGradient(
                    begin: Alignment.centerLeft,
                    end: Alignment.centerRight,
                    colors: [
                      Color(0xFFBA7517),
                      Color(0xFFEF9F27),
                    ],
                  ),
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ],
          ),
        );
      },
    );
  }

  double _getLoadingValue(double value) {
    // Animação: 0% -> 85% -> 10% -> repetir
    if (value < 0.6) {
      return (value / 0.6) * 0.85;
    } else {
      return 0.85 - ((value - 0.6) / 0.4) * 0.75;
    }
  }
}



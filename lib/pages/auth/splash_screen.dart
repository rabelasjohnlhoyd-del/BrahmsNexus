import 'dart:async';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart';

/// Clean, high-performance Loading/Splash screen.
/// Balanced vertical proportions, perfectly centered typography in English,
/// elegant double-ring official client logo emblem with soft breathing glow,
/// and "BRAHMS NEXUS 2026" footer.
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _entranceController;
  late final AnimationController _pulseController;
  late final AnimationController _loadingController;

  late final Animation<double> _fadeIn;
  late final Animation<double> _scaleUp;
  late final Animation<double> _textFadeIn;
  late final Animation<Offset> _textSlideUp;

  String _loadingMessage = 'Initializing system...';
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();

    _entranceController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1400),
    );

    _fadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.0, 0.65, curve: Curves.easeOut),
    );

    _scaleUp = Tween<double>(begin: 0.82, end: 1.0).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.0, 0.80, curve: Curves.easeOutBack),
      ),
    );

    _textFadeIn = CurvedAnimation(
      parent: _entranceController,
      curve: const Interval(0.40, 0.95, curve: Curves.easeOut),
    );

    _textSlideUp = Tween<Offset>(
      begin: const Offset(0, 0.20),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _entranceController,
        curve: const Interval(0.40, 0.95, curve: Curves.easeOutCubic),
      ),
    );

    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);

    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1700),
    )..repeat();

    _entranceController.forward();

    // Professional English progress status sequence
    _statusTimer = Timer(const Duration(milliseconds: 1100), () {
      if (mounted) {
        setState(() => _loadingMessage = 'Syncing branch records...');
      }
    });

    final splashDuration = Duration(milliseconds: kIsWeb ? 1800 : 2800);
    Timer(splashDuration, _navigateToLogin);
  }

  void _navigateToLogin() {
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            const LoginScreen(),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 600),
      ),
    );
  }

  @override
  void dispose() {
    _statusTimer?.cancel();
    _pulseController.dispose();
    _entranceController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFF24160E),
      body: Stack(
        fit: StackFit.expand,
        children: [
          // 1. Warm dark ambient gradient backdrop
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.15),
                radius: 1.15,
                colors: [
                  Color(0xFF3D2418), // Warm dark sienna center
                  Color(0xFF28170E), // Deep chocolate
                  Color(0xFF1B0E08), // Soft dark tone
                ],
                stops: [0.0, 0.60, 1.0],
              ),
            ),
          ),

          // 2. Subtle ambient warm lights for depth
          Positioned(
            top: -60,
            right: -60,
            child: _GlowLight(
              size: 260,
              color: AppColors.accent.withValues(alpha: 0.16),
            ),
          ),
          Positioned(
            bottom: -60,
            left: -60,
            child: _GlowLight(
              size: 280,
              color: const Color(0xFFC77A38).withValues(alpha: 0.12),
            ),
          ),

          // 3. Center Content Area with balanced vertical alignment
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                children: [
                  const Spacer(flex: 4),

                  // Client Logo Emblem Badge (Clean circle, no sun spokes)
                  AnimatedBuilder(
                    animation: Listenable.merge([
                      _entranceController,
                      _pulseController,
                    ]),
                    builder: (context, child) {
                      return Transform.scale(
                        scale: _scaleUp.value,
                        child: Opacity(
                          opacity: _fadeIn.value,
                          child: _OfficialLogoBadge(
                            pulseVal: _pulseController.value,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 28),

                  // Typography & Branding with Slide + Fade
                  SlideTransition(
                    position: _textSlideUp,
                    child: FadeTransition(
                      opacity: _textFadeIn,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        crossAxisAlignment: CrossAxisAlignment.center,
                        children: [
                          // Main App Name
                          const Text(
                            'BRAHMS NEXUS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 2.8,
                              color: Color(0xFFFFF6ED),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Subtitle Pill Badge in Warm Terracotta / Sienna
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 16,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFE29A5C).withValues(alpha: 0.40),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              mainAxisAlignment: MainAxisAlignment.center,
                              children: [
                                Icon(
                                  Icons.restaurant_menu_rounded,
                                  size: 14,
                                  color: Color(0xFFFFB677),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Crispy Sisig & Bagnet',
                                  style: TextStyle(
                                    fontSize: 12.5,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 0.8,
                                    color: Color(0xFFFFE0C2),
                                  ),
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(height: 10),

                          Text(
                            'Multi-Branch Operations & Decision Support System',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              color: Colors.white.withValues(alpha: 0.65),
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w500,
                              height: 1.3,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 4),

                  // Shimmer Progress Bar & Status Text in English
                  FadeTransition(
                    opacity: _textFadeIn,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      crossAxisAlignment: CrossAxisAlignment.center,
                      children: [
                        _DarkWarmShimmerProgressBar(
                          controller: _loadingController,
                        ),
                        const SizedBox(height: 14),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _loadingMessage,
                            key: ValueKey<String>(_loadingMessage),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 12,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.6,
                              color: const Color(0xFFE0C4B0).withValues(alpha: 0.90),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // Clean Footer: "BRAHMS NEXUS 2026" with secure portal subtitle
                  FadeTransition(
                    opacity: _textFadeIn,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Container(
                                width: 20,
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.20),
                              ),
                              const SizedBox(width: 10),
                              const Text(
                                'BRAHMS NEXUS 2026',
                                textAlign: TextAlign.center,
                                style: TextStyle(
                                  fontSize: 11,
                                  fontWeight: FontWeight.w800,
                                  letterSpacing: 2.0,
                                  color: Color(0xFFFFD4A8),
                                ),
                              ),
                              const SizedBox(width: 10),
                              Container(
                                width: 20,
                                height: 1,
                                color: Colors.white.withValues(alpha: 0.20),
                              ),
                            ],
                          ),
                          const SizedBox(height: 4),
                          Text(
                            'Internal Operations & Management Network',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 9.5,
                              fontWeight: FontWeight.w500,
                              letterSpacing: 0.8,
                              color: Colors.white.withValues(alpha: 0.35),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

/// Official circular badge framing the client's logo cleanly
class _OfficialLogoBadge extends StatelessWidget {
  const _OfficialLogoBadge({
    required this.pulseVal,
  });

  final double pulseVal;

  @override
  Widget build(BuildContext context) {
    const size = 156.0;

    return SizedBox(
      width: size,
      height: size,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // 1. Warm breathing halo glow
          Container(
            width: size * 0.94 + (pulseVal * 16),
            height: size * 0.94 + (pulseVal * 16),
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: [
                BoxShadow(
                  color: AppColors.accent.withValues(
                    alpha: 0.30 + (pulseVal * 0.20),
                  ),
                  blurRadius: 40 + (pulseVal * 14),
                  spreadRadius: 4,
                ),
              ],
            ),
          ),

          // 2. Ornate outer metallic border (Golden & Sienna)
          Container(
            width: size,
            height: size,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: const LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  Color(0xFFFFCF9E),
                  Color(0xFFC77A38),
                  Color(0xFF8B4513),
                  Color(0xFFE8984E),
                ],
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.50),
                  blurRadius: 20,
                  offset: const Offset(0, 10),
                ),
              ],
            ),
          ),

          // 3. Crisp white inner ring
          Container(
            width: size * 0.92,
            height: size * 0.92,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
              color: Colors.white,
            ),
          ),

          // 4. The Client's Actual Official Logo (assets/images/brahms_logo.jpg)
          Container(
            width: size * 0.86,
            height: size * 0.86,
            decoration: const BoxDecoration(
              shape: BoxShape.circle,
            ),
            clipBehavior: Clip.antiAlias,
            child: Image.asset(
              'assets/images/brahms_logo.jpg',
              fit: BoxFit.cover,
              alignment: const Alignment(-0.45, -0.45),
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  decoration: const BoxDecoration(
                    gradient: LinearGradient(
                      colors: [AppColors.accent, AppColors.accentDark],
                    ),
                  ),
                  child: const Center(
                    child: Column(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        Icon(Icons.restaurant_rounded, color: Colors.white, size: 28),
                        SizedBox(height: 2),
                        Text(
                          'BRAHMS',
                          style: TextStyle(
                            color: Colors.white,
                            fontWeight: FontWeight.w900,
                            fontSize: 14,
                            letterSpacing: 1.5,
                          ),
                        ),
                      ],
                    ),
                  ),
                );
              },
            ),
          ),
        ],
      ),
    );
  }
}

class _DarkWarmShimmerProgressBar extends StatelessWidget {
  const _DarkWarmShimmerProgressBar({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    const barWidth = 180.0;
    const barHeight = 4.5;

    return Container(
      width: barWidth,
      height: barHeight,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(10),
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final progress = controller.value;
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: 1.0,
            child: ShaderMask(
              shaderCallback: (bounds) {
                final double start = (progress * 2.0) - 1.0;
                return LinearGradient(
                  begin: Alignment(start - 0.4, 0),
                  end: Alignment(start + 0.4, 0),
                  colors: const [
                    Color(0xFF7A4220),
                    Color(0xFFFFB574),
                    Color(0xFFFFF0DD),
                    Color(0xFFFFB574),
                    Color(0xFF7A4220),
                  ],
                ).createShader(bounds);
              },
              child: Container(
                decoration: BoxDecoration(
                  color: Colors.white,
                  borderRadius: BorderRadius.circular(10),
                ),
              ),
            ),
          );
        },
      ),
    );
  }
}

class _GlowLight extends StatelessWidget {
  const _GlowLight({required this.size, required this.color});

  final double size;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: color,
        boxShadow: [
          BoxShadow(
            color: color,
            blurRadius: size * 0.45,
            spreadRadius: size * 0.20,
          ),
        ],
      ),
    );
  }
}

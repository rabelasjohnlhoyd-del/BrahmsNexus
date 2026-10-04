import 'dart:async';
import 'dart:math' show min;
import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import '../../config/supabase_config.dart';
import '../../firebase_options.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import 'login_screen.dart';
import 'role_router.dart';

/// Splash Screen with 100% brand-consistent colors ([AppColors.headerStart]):
/// - Deep chocolate background matching the exact Login & Register headers (#2B1B12).
/// - Pure animated golden cursive letter "B" drawing with glowing ink & sparkling star.
/// - Once drawn, the letter "B" gleams in metallic gold (#D4A25A) with ambient breathing glow.
/// - "BRAHMS NEXUS" in bold gold caps, "Crispy Sisig & Bagnet" pill badge.
/// - Dynamic Golden Capsule progress bar matching [AppColors.accent].
class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with TickerProviderStateMixin {
  late final AnimationController _drawController;
  late final AnimationController _pulseController;
  late final AnimationController _loadingController;

  late final Animation<double> _textFadeIn;
  late final Animation<Offset> _textSlideUp;

  String _loadingMessage = 'Initializing system...';
  Timer? _statusTimer;

  @override
  void initState() {
    super.initState();

    // 1. Drawing controller: smoothly draws the cursive letter B (0 to 1.5s)
    _drawController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    );

    // Text fades in when the B is ~60% drawn
    _textFadeIn = CurvedAnimation(
      parent: _drawController,
      curve: const Interval(0.55, 1.0, curve: Curves.easeOut),
    );

    _textSlideUp = Tween<Offset>(
      begin: const Offset(0, 0.18),
      end: Offset.zero,
    ).animate(
      CurvedAnimation(
        parent: _drawController,
        curve: const Interval(0.55, 1.0, curve: Curves.easeOutCubic),
      ),
    );

    // 2. Continuous ambient pulse for the finished letter B's golden glow
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2000),
    )..repeat(reverse: true);

    // 3. Dynamic progress bar shimmer controller
    _loadingController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat();

    _drawController.forward();

    _statusTimer = Timer(const Duration(milliseconds: 1200), () {
      if (mounted) {
        setState(() => _loadingMessage = 'Syncing branch records...');
      }
    });

    _initServicesAndNavigate();
  }

  Future<void> _initServicesAndNavigate() async {
    try {
      if (Firebase.apps.isEmpty) {
        await Firebase.initializeApp(
          options: DefaultFirebaseOptions.currentPlatform,
        );
        FirebaseFirestore.instance.settings = const Settings(
          persistenceEnabled: true,
          cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
        );
      }
    } catch (e) {
      debugPrint('Firebase init error: $e');
    }

    try {
      bool isInit = false;
      try {
        isInit = Supabase.instance.isInitialized;
      } catch (_) {
        isInit = false;
      }
      if (!isInit && SupabaseConfig.isConfigured) {
        await Supabase.initialize(
          url: SupabaseConfig.cleanSupabaseUrl,
          anonKey: SupabaseConfig.supabaseAnonKey,
        );
      }
    } catch (e) {
      debugPrint('Supabase init error: $e');
    }

    final splashDuration = Duration(milliseconds: kIsWeb ? 2000 : 2800);
    await Future.delayed(splashDuration);
    _checkSessionAndNavigate();
  }

  Future<void> _checkSessionAndNavigate() async {
    if (!mounted) return;

    final savedUser = await AuthService.tryAutoLoginWithRememberMe();

    if (!mounted) return;

    if (savedUser != null) {
      final isOwner = savedUser.role == UserRole.owner;
      final isPlatformAllowed = kIsWeb ? isOwner : !isOwner;

      if (isPlatformAllowed) {
        Navigator.of(context).pushReplacement(
          PageRouteBuilder(
            pageBuilder: (context, animation, secondaryAnimation) =>
                RoleRouter.resolveDestination(
              role: savedUser.role,
              status: savedUser.status,
              position: savedUser.position,
              user: savedUser,
            ),
            transitionsBuilder:
                (context, animation, secondaryAnimation, child) {
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
        return;
      } else {
        await AuthService.signOut();
      }
    }

    _navigateToLogin();
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
    _drawController.dispose();
    _loadingController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.headerStart,
      body: Stack(
        fit: StackFit.expand,
        children: [
          // ── Layer 1: Warm ambient dark chocolate gradient ────────────────
          Container(
            decoration: const BoxDecoration(
              gradient: RadialGradient(
                center: Alignment(0, -0.15),
                radius: 1.15,
                colors: [
                  Color(0xFF382216),      // Warm chocolate center
                  AppColors.headerStart,  // #2B1B12 exact system color
                  Color(0xFF1F120B),      // Deep chocolate edge
                ],
                stops: [0.0, 0.55, 1.0],
              ),
            ),
          ),

          // ── Layer 2: Subtle ambient warm glow lights for depth ───────────
          Positioned(
            top: -50,
            right: -50,
            child: _GlowLight(
              size: 240,
              color: AppColors.accent.withValues(alpha: 0.14),
            ),
          ),
          Positioned(
            bottom: -50,
            left: -50,
            child: _GlowLight(
              size: 260,
              color: const Color(0xFFC77A38).withValues(alpha: 0.10),
            ),
          ),

          // ── Layer 3: Main content with balanced vertical spacing ─────────
          SafeArea(
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 28.0),
              child: Column(
                children: [
                  const Spacer(flex: 4),

                  // ── Animated Cursive Letter "B" Drawing ──────────────────
                  AnimatedBuilder(
                    animation: Listenable.merge([_drawController, _pulseController]),
                    builder: (context, child) {
                      return SizedBox(
                        width: 175,
                        height: 175,
                        child: CustomPaint(
                          painter: _PureLetterBPainter(
                            progress: _drawController.value,
                            pulse: _pulseController.value,
                          ),
                        ),
                      );
                    },
                  ),

                  const SizedBox(height: 24),

                  // ── Brand Typography: BRAHMS NEXUS & Subtitle ────────────
                  SlideTransition(
                    position: _textSlideUp,
                    child: FadeTransition(
                      opacity: _textFadeIn,
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Text(
                            'BRAHMS NEXUS',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 27,
                              fontWeight: FontWeight.w900,
                              letterSpacing: 4.0,
                              color: Color(0xFFD4A25A),
                              height: 1.1,
                            ),
                          ),
                          const SizedBox(height: 12),

                          // Crispy Sisig & Bagnet pill badge
                          Container(
                            padding: const EdgeInsets.symmetric(
                              horizontal: 18,
                              vertical: 6,
                            ),
                            decoration: BoxDecoration(
                              color: Colors.white.withValues(alpha: 0.08),
                              borderRadius: BorderRadius.circular(20),
                              border: Border.all(
                                color: const Color(0xFFD4A25A).withValues(alpha: 0.45),
                                width: 1,
                              ),
                            ),
                            child: const Row(
                              mainAxisSize: MainAxisSize.min,
                              children: [
                                Icon(
                                  Icons.restaurant_menu_rounded,
                                  size: 14,
                                  color: Color(0xFFE5B06B),
                                ),
                                SizedBox(width: 6),
                                Text(
                                  'Crispy Sisig & Bagnet',
                                  style: TextStyle(
                                    fontSize: 12,
                                    fontWeight: FontWeight.w800,
                                    letterSpacing: 1.2,
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
                              fontSize: 11.5,
                              color: Colors.white.withValues(alpha: 0.60),
                              letterSpacing: 0.4,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),

                  const Spacer(flex: 4),

                  // ── Dynamic Golden Capsule Progress Bar + Status Text ────
                  FadeTransition(
                    opacity: _textFadeIn,
                    child: Column(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        _GoldenCapsuleProgressBar(
                          controller: _loadingController,
                        ),
                        const SizedBox(height: 12),
                        AnimatedSwitcher(
                          duration: const Duration(milliseconds: 300),
                          child: Text(
                            _loadingMessage,
                            key: ValueKey<String>(_loadingMessage),
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11.5,
                              fontWeight: FontWeight.w600,
                              letterSpacing: 0.8,
                              color: const Color(0xFFE0C4B0).withValues(alpha: 0.85),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),

                  const Spacer(flex: 2),

                  // ── Footer: BRAHMS NEXUS 2026 ────────────────────────────
                  FadeTransition(
                    opacity: _textFadeIn,
                    child: Padding(
                      padding: const EdgeInsets.only(bottom: 16),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 28,
                            height: 1,
                            color: const Color(0xFFD4A25A).withValues(alpha: 0.35),
                          ),
                          const SizedBox(width: 10),
                          const Text(
                            'BRAHMS NEXUS 2026',
                            textAlign: TextAlign.center,
                            style: TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                              letterSpacing: 2.2,
                              color: Color(0xFFD4A25A),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Container(
                            width: 28,
                            height: 1,
                            color: const Color(0xFFD4A25A).withValues(alpha: 0.35),
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

/// CustomPainter that actively paints the cursive letter "B" and leaves
/// a rich metallic gold calligraphic emblem with ambient glow.
class _PureLetterBPainter extends CustomPainter {
  _PureLetterBPainter({
    required this.progress,
    required this.pulse,
  });

  final double progress;
  final double pulse;

  /// Builds the elegant cursive "B" path normalized to the 175x175 widget size.
  static Path _buildCursivePath(Size size) {
    final w = size.width;
    final h = size.height;
    final path = Path();

    // 1. Top of spine
    path.moveTo(w * 0.28, h * 0.16);

    // 2. Stroke gracefully down the spine with calligraphic curve
    path.cubicTo(
      w * 0.26, h * 0.36,
      w * 0.22, h * 0.62,
      w * 0.26, h * 0.84,
    );

    // 3. Small flourish at bottom of spine curving up-right
    path.cubicTo(
      w * 0.20, h * 0.88,
      w * 0.16, h * 0.82,
      w * 0.22, h * 0.72,
    );

    // 4. Ascend gracefully back up the spine to top loop
    path.cubicTo(
      w * 0.26, h * 0.48,
      w * 0.34, h * 0.24,
      w * 0.44, h * 0.14,
    );

    // 5. Sweep out the elegant top loop of B
    path.cubicTo(
      w * 0.64, h * 0.08,
      w * 0.82, h * 0.18,
      w * 0.78, h * 0.38,
    );

    // 6. Inward waist curve of B
    path.cubicTo(
      w * 0.74, h * 0.50,
      w * 0.56, h * 0.52,
      w * 0.44, h * 0.52,
    );

    // 7. Sweep out the larger bottom belly of B
    path.cubicTo(
      w * 0.62, h * 0.52,
      w * 0.90, h * 0.62,
      w * 0.86, h * 0.82,
    );

    // 8. Sweep under the bottom
    path.cubicTo(
      w * 0.82, h * 0.94,
      w * 0.54, h * 0.94,
      w * 0.38, h * 0.90,
    );

    // 9. Sweep into the dramatic bottom-left cursive loop flourish
    path.cubicTo(
      w * 0.20, h * 0.86,
      w * 0.12, h * 0.72,
      w * 0.20, h * 0.60,
    );
    path.cubicTo(
      w * 0.28, h * 0.50,
      w * 0.40, h * 0.54,
      w * 0.48, h * 0.66,
    );

    // 10. Sweep down and right across the bottom
    path.cubicTo(
      w * 0.56, h * 0.80,
      w * 0.70, h * 0.88,
      w * 0.84, h * 0.76,
    );

    return path;
  }

  @override
  void paint(Canvas canvas, Size size) {
    if (progress <= 0.01) return;

    final fullPath = _buildCursivePath(size);
    final metrics = fullPath.computeMetrics().toList();
    if (metrics.isEmpty) return;

    final totalLength = metrics.fold(0.0, (acc, m) => acc + m.length);
    final currentDrawLength = totalLength * progress;

    double remaining = currentDrawLength;
    Offset? tipPoint;

    // 1. Wide ambient golden glow
    final glowPaint = Paint()
      ..color = const Color(0xFFD4A25A).withValues(alpha: 0.24 + (pulse * 0.12))
      ..strokeWidth = 22.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round
      ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 10);

    // 2. Warm shadow bevel for 3D depth
    final shadowPaint = Paint()
      ..color = const Color(0xFF1E1008).withValues(alpha: 0.75)
      ..strokeWidth = 8.0
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 3. Rich metallic warm gold body stroke
    final mainStrokePaint = Paint()
      ..color = const Color(0xFFE5B06B)
      ..strokeWidth = 6.5
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    // 4. Bright luminous core highlight
    final coreStrokePaint = Paint()
      ..color = const Color(0xFFFFF6DF)
      ..strokeWidth = 2.2
      ..style = PaintingStyle.stroke
      ..strokeCap = StrokeCap.round
      ..strokeJoin = StrokeJoin.round;

    for (final metric in metrics) {
      if (remaining <= 0) break;
      final len = min(remaining, metric.length);
      final segment = metric.extractPath(0, len);

      canvas.drawPath(segment, glowPaint);
      canvas.drawPath(segment, shadowPaint);
      canvas.drawPath(segment, mainStrokePaint);
      canvas.drawPath(segment, coreStrokePaint);

      final tangent = metric.getTangentForOffset(len);
      if (tangent != null) {
        tipPoint = tangent.position;
      }

      remaining -= len;
    }

    // ── Glowing Ink Flare at the active tip while drawing ─────────────
    if (tipPoint != null && progress < 0.99) {
      // Outer amber flare
      canvas.drawCircle(
        tipPoint,
        18 + (pulse * 4),
        Paint()
          ..color = const Color(0xFFFFB554).withValues(alpha: 0.45)
          ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 8),
      );

      // Bright golden corona
      canvas.drawCircle(
        tipPoint,
        9,
        Paint()..color = const Color(0xFFFFDE94),
      );

      // 4-point sparkle star
      _drawSparkleStar(canvas, tipPoint, 16 + (pulse * 4));

      // White-hot core
      canvas.drawCircle(
        tipPoint,
        4.0,
        Paint()..color = Colors.white,
      );
    }
  }

  void _drawSparkleStar(Canvas canvas, Offset center, double radius) {
    final paint = Paint()
      ..color = Colors.white.withValues(alpha: 0.90)
      ..style = PaintingStyle.fill;

    final path = Path();
    path.moveTo(center.dx, center.dy - radius);
    path.quadraticBezierTo(center.dx, center.dy, center.dx + radius, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy + radius);
    path.quadraticBezierTo(center.dx, center.dy, center.dx - radius, center.dy);
    path.quadraticBezierTo(center.dx, center.dy, center.dx, center.dy - radius);
    path.close();

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(_PureLetterBPainter old) =>
      old.progress != progress || old.pulse != pulse;
}

/// Dynamic golden capsule progress bar matching AppColors palette.
class _GoldenCapsuleProgressBar extends StatelessWidget {
  const _GoldenCapsuleProgressBar({required this.controller});

  final AnimationController controller;

  @override
  Widget build(BuildContext context) {
    const double barHeight = 8.0;
    const double barWidth = 240.0;

    return Container(
      width: barWidth,
      height: barHeight,
      padding: const EdgeInsets.all(1.2),
      decoration: BoxDecoration(
        color: const Color(0xFF1E1008).withValues(alpha: 0.80),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(
          color: const Color(0xFFD4A25A).withValues(alpha: 0.65),
          width: 1.2,
        ),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFFD4A25A).withValues(alpha: 0.18),
            blurRadius: 8,
            spreadRadius: 1,
          ),
        ],
      ),
      child: AnimatedBuilder(
        animation: controller,
        builder: (context, child) {
          final progress = controller.value;
          return FractionallySizedBox(
            alignment: Alignment.centerLeft,
            widthFactor: (0.15 + (progress * 0.85)).clamp(0.0, 1.0),
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(8),
                gradient: const LinearGradient(
                  begin: Alignment.centerLeft,
                  end: Alignment.centerRight,
                  colors: [
                    AppColors.accentDark, // Saddle brown
                    AppColors.accent,     // Sienna
                    Color(0xFFD4A25A),    // Gold
                    Color(0xFFFFDE9E),    // Bright gold highlight
                  ],
                  stops: [0.0, 0.40, 0.80, 1.0],
                ),
                boxShadow: const [
                  BoxShadow(
                    color: Color(0xFFFFD494),
                    blurRadius: 4,
                  ),
                ],
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

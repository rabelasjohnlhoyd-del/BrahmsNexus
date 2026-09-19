import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';

/// Auth Layout used by the Login and Register screens.
///
/// - On WEB (kIsWeb): shows the full enterprise top bar
///   ("BRAHMS NEXUS · OPERATIONS" + System Online indicator).
/// - On MOBILE (Staff / Driver / Owner app): NO header — just the clean
///   centered floating card on the warm canvas. No web-style bars.
class AuthAdminLayout extends StatelessWidget {
  const AuthAdminLayout({
    super.key,
    required this.child,
    this.maxWidth = 440,
  });

  final Widget child;
  final double maxWidth;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFFAF7F2),
      body: Column(
        children: [
          // ── Top Bar: Web only ──────────────────────────────────────
          if (kIsWeb)
            Container(
              height: 60,
              padding: const EdgeInsets.symmetric(horizontal: 24),
              decoration: const BoxDecoration(
                color: Colors.white,
                border: Border(
                  bottom: BorderSide(color: Color(0xFFEBE2D8), width: 1),
                ),
              ),
              child: Row(
                children: [
                  // Official Logo
                  Container(
                    width: 32,
                    height: 32,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      border: Border.all(
                          color: const Color(0xFFD2B48C), width: 1.2),
                    ),
                    child: ClipOval(
                      child: Image.asset(
                        'assets/images/brahms_logo.jpg',
                        fit: BoxFit.cover,
                        errorBuilder: (context, error, stackTrace) =>
                            const Icon(Icons.restaurant,
                                color: Color(0xFF8B4513), size: 18),
                      ),
                    ),
                  ),
                  const SizedBox(width: 10),

                  // Brand Title
                  const Text(
                    'BRAHMS NEXUS',
                    style: TextStyle(
                      fontSize: 13.5,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 1.2,
                      color: Color(0xFF2B1B12),
                    ),
                  ),
                  const SizedBox(width: 8),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
                    decoration: BoxDecoration(
                      color: const Color(0xFFF3EAE0),
                      borderRadius: BorderRadius.circular(4),
                    ),
                    child: const Text(
                      'OPERATIONS',
                      style: TextStyle(
                        fontSize: 9.5,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                        color: Color(0xFF8B4513),
                      ),
                    ),
                  ),

                  const Spacer(),

                  // System Online Indicator
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Container(
                        width: 7,
                        height: 7,
                        decoration: const BoxDecoration(
                          color: Color(0xFF2E7D32),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text(
                        'System Online',
                        style: TextStyle(
                          fontSize: 11.5,
                          fontWeight: FontWeight.w600,
                          color: Color(0xFF6B584C),
                        ),
                      ),
                    ],
                  ),
                ],
              ),
            ),

          // ── Main Canvas ────────────────────────────────────────────
          Expanded(
            child: Stack(
              children: [
                // Subtle warm radial gradient at the top
                Positioned(
                  top: 0,
                  left: 0,
                  right: 0,
                  height: 260,
                  child: Container(
                    decoration: BoxDecoration(
                      gradient: RadialGradient(
                        center: const Alignment(0, -0.6),
                        radius: 0.9,
                        colors: [
                          const Color(0xFF8B4513).withValues(alpha: 0.04),
                          const Color(0xFFFAF7F2).withValues(alpha: 0.0),
                        ],
                      ),
                    ),
                  ),
                ),

                // Scrollable Centered Card & Footer
                SafeArea(
                  child: Center(
                    child: SingleChildScrollView(
                      padding: const EdgeInsets.symmetric(
                          horizontal: 20, vertical: 32),
                      child: Column(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          // Floating Card Container
                          ConstrainedBox(
                            constraints: BoxConstraints(maxWidth: maxWidth),
                            child: Container(
                              width: double.infinity,
                              decoration: BoxDecoration(
                                color: Colors.white,
                                borderRadius: BorderRadius.circular(16),
                                border:
                                    Border.all(color: const Color(0xFFE8DED3)),
                                boxShadow: [
                                  BoxShadow(
                                    color: const Color(0xFF2B1B12)
                                        .withValues(alpha: 0.06),
                                    blurRadius: 24,
                                    offset: const Offset(0, 8),
                                  ),
                                ],
                              ),
                              child: child,
                            ),
                          ),
                          const SizedBox(height: 24),

                          // Footer
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: const [
                              Icon(Icons.lock_outline_rounded,
                                  size: 13, color: Color(0xFF9E8B7E)),
                              SizedBox(width: 5),
                              Text(
                                'Encrypted & Secure Connection',
                                style: TextStyle(
                                  fontSize: 11.5,
                                  color: Color(0xFF8C7A6E),
                                  fontWeight: FontWeight.w500,
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 6),
                          const Text(
                            '© 2026 Brahms Crispy Sisig Bagnet. All rights reserved.',
                            style: TextStyle(
                              fontSize: 11,
                              color: Color(0xFFA8978B),
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

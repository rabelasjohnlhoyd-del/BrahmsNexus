import 'package:flutter/material.dart';
import 'auth_brand_mark.dart';

/// Left hero panel for Desktop Web view on Login and Register screens.
///
/// Features:
/// - Dark roasted chocolate background matching Brahms brand palette
/// - Official Brahms logo emblem with subtle warm ambient glow
/// - Slogan / Features list
/// - Authentic Sisig food photo with smooth blended mask
class AuthWebHeroPanel extends StatelessWidget {
  const AuthWebHeroPanel({
    super.key,
    required this.isLogin,
  });

  final bool isLogin;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [
            Color(0xFF281810),
            Color(0xFF1D100A),
            Color(0xFF150A06),
          ],
        ),
      ),
      child: Stack(
        children: [
          // 1. Subtle warm ambient light bloom
          Positioned(
            top: -40,
            left: -40,
            right: -40,
            height: 320,
            child: Container(
              decoration: BoxDecoration(
                gradient: RadialGradient(
                  center: const Alignment(0, -0.4),
                  radius: 0.8,
                  colors: [
                    const Color(0xFFA0522D).withValues(alpha: 0.22),
                    const Color(0xFF8B4513).withValues(alpha: 0.10),
                    Colors.transparent,
                  ],
                ),
              ),
            ),
          ),

          // 2. Corner decorative botanical leaf icons
          Positioned(
            top: 24,
            left: 24,
            child: Icon(
              Icons.eco_outlined,
              size: 28,
              color: Colors.white.withValues(alpha: 0.08),
            ),
          ),
          Positioned(
            top: 70,
            right: 20,
            child: Icon(
              Icons.local_florist_outlined,
              size: 24,
              color: Colors.white.withValues(alpha: 0.07),
            ),
          ),

          // 3. Main Panel Content (Header + Middle Highlights + Sisig Photo)
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const SizedBox(height: 36),

              // Official Brand Logo
              const Center(
                child: AuthBrandMark(size: 78),
              ),
              const SizedBox(height: 12),

              // Portal Title & Subtitle
              const Text(
                'Brahms Crispy Sisig Bagnet',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 17.5,
                  fontWeight: FontWeight.w900,
                  letterSpacing: -0.2,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'MULTI-BRANCH OPERATIONS PORTAL',
                textAlign: TextAlign.center,
                style: TextStyle(
                  color: Color(0xFFD2B48C),
                  fontSize: 10,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.3,
                ),
              ),
              const SizedBox(height: 16),

              // Thin separator
              Center(
                child: Container(
                  width: 50,
                  height: 2,
                  decoration: BoxDecoration(
                    color: const Color(0xFF8B4513).withValues(alpha: 0.4),
                    borderRadius: BorderRadius.circular(1),
                  ),
                ),
              ),
              const SizedBox(height: 18),

              // Middle dynamic content
              Expanded(
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 28),
                  child: isLogin ? _buildLoginQuote() : _buildRegisterFeatures(),
                ),
              ),

              // Bottom Food Photography with organic curved frame
              _buildFoodPhotoSection(),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildLoginQuote() {
    return Column(
      mainAxisAlignment: MainAxisAlignment.center,
      children: [
        Icon(
          Icons.format_quote_rounded,
          size: 32,
          color: const Color(0xFFD2B48C).withValues(alpha: 0.35),
        ),
        const SizedBox(height: 6),
        const Text(
          'Good Food\nBuilds Better\nCommunities',
          textAlign: TextAlign.center,
          style: TextStyle(
            fontStyle: FontStyle.italic,
            fontFamily: 'serif',
            fontSize: 23,
            height: 1.25,
            fontWeight: FontWeight.w600,
            color: Color(0xFFF3E5D8),
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 12),
        Container(
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 6),
          decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.05),
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: Colors.white.withValues(alpha: 0.10)),
          ),
          child: const Text(
            'SERVED FRESH DAILY',
            style: TextStyle(
              fontSize: 9.5,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
              color: Color(0xFFD2B48C),
            ),
          ),
        ),
      ],
    );
  }

  Widget _buildRegisterFeatures() {
    final features = [
      (
        icon: Icons.restaurant_menu_rounded,
        title: 'Quality Food',
        subtitle: 'Fresh ingredients, great taste',
      ),
      (
        icon: Icons.storefront_rounded,
        title: 'Multiple Branches',
        subtitle: 'Manage operations across all locations',
      ),
      (
        icon: Icons.insights_rounded,
        title: 'Real-Time Management',
        subtitle: 'Inventory, sales, and team tracking',
      ),
      (
        icon: Icons.diversity_3_rounded,
        title: 'Better Collaboration',
        subtitle: 'For a stronger Brahms community',
      ),
    ];

    return ListView(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      children: features.map((f) {
        return Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Row(
            children: [
              Container(
                width: 38,
                height: 38,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  color: const Color(0xFF8B4513).withValues(alpha: 0.25),
                  border: Border.all(
                    color: const Color(0xFFD2B48C).withValues(alpha: 0.40),
                  ),
                ),
                child: Icon(f.icon, size: 18, color: const Color(0xFFF3E5D8)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      f.title,
                      style: const TextStyle(
                        color: Colors.white,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      f.subtitle,
                      style: TextStyle(
                        color: Colors.white.withValues(alpha: 0.65),
                        fontSize: 11,
                        height: 1.2,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
        );
      }).toList(),
    );
  }

  Widget _buildFoodPhotoSection() {
    return Container(
      height: 210,
      width: double.infinity,
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 16),
      child: ClipRRect(
        borderRadius: BorderRadius.circular(18),
        child: Stack(
          fit: StackFit.expand,
          children: [
            // Sisig Photo
            Image.asset(
              'assets/images/brahms_sisig.jpg',
              fit: BoxFit.cover,
              errorBuilder: (context, error, stackTrace) {
                return Container(
                  color: const Color(0xFF2B1B12),
                  child: const Center(
                    child: Icon(Icons.restaurant, color: Color(0xFFD2B48C), size: 40),
                  ),
                );
              },
            ),

            // Top gradient overlay blending into dark panel
            Positioned.fill(
              child: Container(
                decoration: BoxDecoration(
                  gradient: LinearGradient(
                    begin: Alignment.topCenter,
                    end: Alignment.bottomCenter,
                    colors: [
                      const Color(0xFF281810).withValues(alpha: 0.85),
                      Colors.transparent,
                      Colors.black.withValues(alpha: 0.50),
                    ],
                    stops: const [0.0, 0.4, 1.0],
                  ),
                ),
              ),
            ),

            // Bottom decorative caption
            Positioned(
              bottom: 12,
              left: 14,
              right: 14,
              child: Row(
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.60),
                      borderRadius: BorderRadius.circular(6),
                      border: Border.all(color: Colors.white.withValues(alpha: 0.2)),
                    ),
                    child: const Text(
                      'ORIGINAL RECIPE',
                      style: TextStyle(
                        color: Color(0xFFE8D0B5),
                        fontSize: 9,
                        fontWeight: FontWeight.w800,
                        letterSpacing: 0.8,
                      ),
                    ),
                  ),
                  const Spacer(),
                  Icon(
                    Icons.star_rounded,
                    size: 14,
                    color: Colors.amber.shade400,
                  ),
                  const SizedBox(width: 4),
                  const Text(
                    'Crispy Sisig Bagnet',
                    style: TextStyle(
                      color: Colors.white,
                      fontSize: 11,
                      fontWeight: FontWeight.w700,
                      shadows: [
                        Shadow(color: Colors.black, blurRadius: 4),
                      ],
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
}

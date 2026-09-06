import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'pages/auth/login_screen.dart';
import 'pages/auth/welcome_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // Force off the debug "paint baselines" overlay (the green/yellow
  // lines drawn under every piece of text) regardless of whatever
  // state the Flutter Inspector / DevTools "Toggle Baseline Painting"
  // button was left in during a previous debug session. This runs on
  // every app start, so it can't be silently left on again.
  assert(() {
    debugPaintBaselinesEnabled = false;
    return true;
  }());

  // Draw behind the system status bar / Android gesture-navigation bar
  // consistently (edge-to-edge) instead of leaving Android to pick its
  // own default bar treatment. Without this, Android can silently
  // recompute a translucent scrim behind the status/nav bars based on
  // whatever content is currently underneath them, which is what made
  // the bar colors appear to "shift" while scrolling.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
      // Stops Android from drawing its own auto-contrast scrim behind
      // the system bars, which is the actual mechanism that made bar
      // colors change dynamically while scrolling.
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );
  runApp(const BrahmsNexusApp());
}

class BrahmsNexusApp extends StatelessWidget {
  const BrahmsNexusApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Brahms Nexus',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.lightTheme,
      // Clamp system font scaling app-wide. Without this, a phone set
      // to a large accessibility text size inflates any Text that
      // doesn't set an explicit fontSize (headings, sheet subtitles,
      // etc.) far past what these fixed-size cards/sheets were laid
      // out for — the exact bug that made the branch-inventory sheet's
      // "Items to bring here" heading balloon into two giant, badly
      // wrapped lines. 1.3x still respects the user's larger-text
      // preference; it just stops it from breaking layouts.
      builder: (context, child) {
        final clampedScaler = MediaQuery.textScalerOf(context)
            .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: clampedScaler),
          child: child!,
        );
      },
      home: kIsWeb ? const LoginScreen() : const WelcomeScreen(),
    );
  }
}

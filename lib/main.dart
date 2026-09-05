import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'firebase_options.dart';
import 'pages/auth/welcome_screen.dart';
import 'theme/app_theme.dart';

void main() async {
  WidgetsFlutterBinding.ensureInitialized();

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
      home: const WelcomeScreen(),
    );
  }
}

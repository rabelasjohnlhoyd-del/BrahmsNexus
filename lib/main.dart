import 'package:cloud_firestore/cloud_firestore.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:flutter/foundation.dart' show kIsWeb, debugPrint;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:flutter/services.dart';
import 'package:supabase_flutter/supabase_flutter.dart';
import 'config/supabase_config.dart';
import 'firebase_options.dart';
import 'pages/auth/login_screen.dart';
import 'pages/auth/splash_screen.dart';
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
  // own default bar treatment.
  SystemChrome.setEnabledSystemUIMode(SystemUiMode.edgeToEdge);
  SystemChrome.setSystemUIOverlayStyle(
    const SystemUiOverlayStyle(
      statusBarColor: Colors.transparent,
      statusBarIconBrightness: Brightness.dark,
      statusBarBrightness: Brightness.light,
      systemNavigationBarColor: Colors.white,
      systemNavigationBarIconBrightness: Brightness.dark,
      systemNavigationBarDividerColor: Colors.transparent,
      systemNavigationBarContrastEnforced: false,
      systemStatusBarContrastEnforced: false,
    ),
  );

  await Firebase.initializeApp(
    options: DefaultFirebaseOptions.currentPlatform,
  );

  // Enable Firestore local cache / offline persistence.
  // Documents served from this cache are not billed as reads.
  // Wrapped so a web IndexedDB failure cannot crash app startup.
  try {
    FirebaseFirestore.instance.settings = const Settings(
      persistenceEnabled: true,
      cacheSizeBytes: Settings.CACHE_SIZE_UNLIMITED,
    );
  } catch (e) {
    debugPrint('Firestore persistence settings error: $e');
  }

  if (SupabaseConfig.isConfigured) {
    try {
      await Supabase.initialize(
        url: SupabaseConfig.cleanSupabaseUrl,
        // ignore: deprecated_member_use
        anonKey: SupabaseConfig.supabaseAnonKey,
      );
    } catch (e) {
      debugPrint('Supabase.initialize error: $e');
    }
  } else {
    debugPrint(
      'ℹ️ Brahms Nexus: Supabase is in local fallback mode. '
          'Provide your Supabase URL & Key in lib/config/supabase_config.dart to activate live Supabase sync.',
    );
  }

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
      builder: (context, child) {
        final clampedScaler = MediaQuery.textScalerOf(context)
            .clamp(minScaleFactor: 0.9, maxScaleFactor: 1.3);
        return MediaQuery(
          data: MediaQuery.of(context).copyWith(textScaler: clampedScaler),
          child: child!,
        );
      },
      home: kIsWeb ? const LoginScreen() : const SplashScreen(),
    );
  }
}
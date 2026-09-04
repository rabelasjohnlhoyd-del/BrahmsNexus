import 'package:flutter/material.dart';
import 'pages/auth/login_screen.dart';
import 'theme/app_theme.dart';

void main() {
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
      home: const LoginScreen(),
    );
  }
}

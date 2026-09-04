import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// Ang FAB mismo para sa DSS Chatbot.
class DssChatbotFab extends StatelessWidget {
  const DssChatbotFab({super.key, required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return FloatingActionButton(
      heroTag: 'dss_chatbot_fab',
      onPressed: onTap,
      backgroundColor: AppColors.accent,
      elevation: 4,
      shape: const CircleBorder(),
      child: const Icon(Icons.smart_toy_outlined, color: Colors.white, size: 26),
    );
  }
}

/// Custom FloatingActionButtonLocation:
/// Bottom-right ang position, pero bahagyang nakalutang sa ITAAS
/// mismo ng Bottom Navigation Bar (hindi ito nakatago o nakapatong dito).
class DssFabLocation extends FloatingActionButtonLocation {
  const DssFabLocation({this.extraBottomOffset = 16});

  final double extraBottomOffset;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.minInsets.right -
        scaffoldGeometry.floatingActionButtonSize.width -
        16;

    // contentBottom = taas kung saan nagsisimula ang bottom nav bar,
    // kaya kung ibawas natin ang height ng FAB + extraBottomOffset,
    // "lulutang" ito nang bahagyang mas mataas sa ibabaw ng bottom nav.
    final double fabY = scaffoldGeometry.contentBottom -
        scaffoldGeometry.floatingActionButtonSize.height -
        extraBottomOffset;

    return Offset(fabX, fabY);
  }
}

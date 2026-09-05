import 'package:flutter/material.dart';
import '../theme/app_theme.dart';

/// The FAB itself for the DSS Chatbot.
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
/// Positioned bottom-right, but floating slightly ABOVE the Bottom
/// Navigation Bar (not hidden behind or overlapping it).
class DssFabLocation extends FloatingActionButtonLocation {
  const DssFabLocation({this.extraBottomOffset = 16});

  final double extraBottomOffset;

  @override
  Offset getOffset(ScaffoldPrelayoutGeometry scaffoldGeometry) {
    final double fabX = scaffoldGeometry.scaffoldSize.width -
        scaffoldGeometry.minInsets.right -
        scaffoldGeometry.floatingActionButtonSize.width -
        16;

    // contentBottom = the height at which the bottom nav bar starts,
    // so subtracting the FAB height + extraBottomOffset makes it
    // "float" slightly higher above the bottom nav.
    final double fabY = scaffoldGeometry.contentBottom -
        scaffoldGeometry.floatingActionButtonSize.height -
        extraBottomOffset;

    return Offset(fabX, fabY);
  }
}

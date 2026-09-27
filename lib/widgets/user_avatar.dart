import 'dart:convert';
import 'package:flutter/cupertino.dart';
import '../theme/app_theme.dart';

/// Reusable User Avatar widget that intelligently displays:
/// 1. Remote Supabase Storage image URLs (`http://...` / `https://...`)
/// 2. Offline / local base64 data URIs (`data:image/...;base64,...`)
/// 3. Two-letter initials fallback if no photo exists or image fails to load.
class UserAvatar extends StatelessWidget {
  const UserAvatar({
    super.key,
    required this.initials,
    this.photoUrl = '',
    this.size = 80,
    this.fontSize = 28,
    this.backgroundColor = AppColors.accent,
    this.borderColor = AppColors.background,
    this.borderWidth = 3,
    this.showEditBadge = false,
    this.onTap,
  });

  final String initials;
  final String photoUrl;
  final double size;
  final double fontSize;
  final Color backgroundColor;
  final Color borderColor;
  final double borderWidth;
  final bool showEditBadge;
  final VoidCallback? onTap;

  Widget _buildImageContent() {
    final cleanUrl = photoUrl.trim();
    if (cleanUrl.isNotEmpty) {
      if (cleanUrl.startsWith('data:image')) {
        try {
          final base64Part = cleanUrl.contains(',') ? cleanUrl.split(',').last : cleanUrl;
          final bytes = base64Decode(base64Part);
          return Image.memory(
            bytes,
            width: size,
            height: size,
            fit: BoxFit.cover,
            errorBuilder: (context, error, stackTrace) => _buildInitials(),
          );
        } catch (_) {
          return _buildInitials();
        }
      } else if (cleanUrl.startsWith('http')) {
        return Image.network(
          cleanUrl,
          width: size,
          height: size,
          fit: BoxFit.cover,
          loadingBuilder: (context, child, loadingProgress) {
            if (loadingProgress == null) return child;
            return Container(
              color: backgroundColor,
              child: const Center(
                child: CupertinoActivityIndicator(radius: 10),
              ),
            );
          },
          errorBuilder: (context, error, stackTrace) => _buildInitials(),
        );
      }
    }
    return _buildInitials();
  }

  Widget _buildInitials() {
    return Container(
      width: size,
      height: size,
      color: backgroundColor,
      alignment: Alignment.center,
      child: Text(
        initials.isNotEmpty ? initials : '?',
        style: TextStyle(
          color: CupertinoColors.white,
          fontSize: fontSize,
          fontWeight: FontWeight.bold,
          letterSpacing: 1,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    Widget avatarCircle = Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: backgroundColor,
        border: Border.all(color: borderColor, width: borderWidth),
        boxShadow: [
          BoxShadow(
            color: AppColors.accentDark.withValues(alpha: 0.12),
            blurRadius: 10,
            offset: const Offset(0, 4),
          ),
        ],
      ),
      child: ClipOval(child: _buildImageContent()),
    );

    if (showEditBadge) {
      avatarCircle = Stack(
        clipBehavior: Clip.none,
        alignment: Alignment.center,
        children: [
          avatarCircle,
          Positioned(
            right: 0,
            bottom: 0,
            child: Container(
              padding: const EdgeInsets.all(5),
              decoration: BoxDecoration(
                color: AppColors.accentDark,
                shape: BoxShape.circle,
                border: Border.all(color: CupertinoColors.white, width: 2),
                boxShadow: [
                  BoxShadow(
                    color: CupertinoColors.black.withValues(alpha: 0.2),
                    blurRadius: 4,
                  ),
                ],
              ),
              child: const Icon(
                CupertinoIcons.pencil,
                size: 13,
                color: CupertinoColors.white,
              ),
            ),
          ),
        ],
      );
    }

    if (onTap != null) {
      return GestureDetector(
        onTap: onTap,
        child: avatarCircle,
      );
    }

    return avatarCircle;
  }
}

import 'package:flutter/cupertino.dart';
import '../../theme/app_theme.dart';

class OwnerLockScreen extends StatefulWidget {
  const OwnerLockScreen({super.key, required this.onUnlocked});

  final VoidCallback onUnlocked;

  @override
  State<OwnerLockScreen> createState() => _OwnerLockScreenState();
}

class _OwnerLockScreenState extends State<OwnerLockScreen> {
  String _pin = '';
  final String _correctPin = '1234'; // Mock PIN
  String? _error;

  void _handleKeyPress(String key) {
    setState(() {
      _error = null;
      if (_pin.length < 4) {
        _pin += key;
      }
      
      if (_pin.length == 4) {
        if (_pin == _correctPin) {
          widget.onUnlocked();
        } else {
          _pin = '';
          _error = 'Incorrect PIN. Try again.';
        }
      }
    });
  }

  void _handleBackspace() {
    if (_pin.isNotEmpty) {
      setState(() => _pin = _pin.substring(0, _pin.length - 1));
    }
  }

  @override
  Widget build(BuildContext context) {
    return CupertinoPageScaffold(
      backgroundColor: AppColors.background,
      child: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(vertical: 24),
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Icon(CupertinoIcons.lock_shield_fill,
                size: 64, color: AppColors.accent),
            const SizedBox(height: 16),
            const Text(
              'Owner Access Only',
              style: TextStyle(
                fontSize: 22,
                fontWeight: FontWeight.w800,
                color: AppColors.textPrimary,
              ),
            ),
            const SizedBox(height: 8),
            const Text(
              'Enter your 4-digit PIN to continue.',
              style: TextStyle(fontSize: 14, color: AppColors.textSecondary),
            ),
            const SizedBox(height: 32),
            
            // PIN Indicators
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: List.generate(4, (index) {
                final filled = index < _pin.length;
                return Container(
                  width: 16,
                  height: 16,
                  margin: const EdgeInsets.symmetric(horizontal: 12),
                  decoration: BoxDecoration(
                    shape: BoxShape.circle,
                    color: filled ? AppColors.accent : AppColors.border,
                  ),
                );
              }),
            ),
            
            const SizedBox(height: 16),
            if (_error != null)
              Text(_error!, style: const TextStyle(color: AppColors.error, fontSize: 13, fontWeight: FontWeight.w600)),
            
            const SizedBox(height: 40),
            
            // Number Pad
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: 48),
              child: GridView.count(
                shrinkWrap: true,
                crossAxisCount: 3,
                mainAxisSpacing: 20,
                crossAxisSpacing: 20,
                children: [
                  ...['1', '2', '3', '4', '5', '6', '7', '8', '9'].map(_buildKey),
                  const SizedBox.shrink(),
                  _buildKey('0'),
                  CupertinoButton(
                    padding: EdgeInsets.zero,
                    onPressed: _handleBackspace,
                    child: const Icon(CupertinoIcons.delete_left, color: AppColors.textPrimary),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    ),
  ),
);
  }

  Widget _buildKey(String label) {
    return CupertinoButton(
      padding: EdgeInsets.zero,
      onPressed: () => _handleKeyPress(label),
      child: Container(
        alignment: Alignment.center,
        decoration: BoxDecoration(
          color: CupertinoColors.white,
          shape: BoxShape.circle,
          boxShadow: [
            BoxShadow(
              color: AppColors.textPrimary.withValues(alpha: 0.05),
              blurRadius: 4,
              offset: const Offset(0, 2),
            ),
          ],
        ),
        child: Text(
          label,
          style: const TextStyle(
            fontSize: 24,
            fontWeight: FontWeight.w600,
            color: AppColors.textPrimary,
          ),
        ),
      ),
    );
  }
}

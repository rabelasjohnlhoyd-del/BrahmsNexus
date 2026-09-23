import 'dart:async';
import 'package:flutter/material.dart';
import '../../models/app_user.dart';
import '../../services/auth_service.dart';
import '../../services/otp_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_admin_layout.dart';
import '../../widgets/primary_button.dart';
import 'login_screen.dart';
import 'role_router.dart';

/// Screen displayed when an approved user enters the app for the first time
/// if their phone number has not been verified yet via SMS OTP.
class PhoneSmsScreen extends StatefulWidget {
  const PhoneSmsScreen({
    super.key,
    required this.user,
  });

  final AppUser user;

  @override
  State<PhoneSmsScreen> createState() => _PhoneSmsScreenState();
}

class _PhoneSmsScreenState extends State<PhoneSmsScreen> {
  final List<TextEditingController> _controllers =
      List.generate(6, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());

  bool _isSendingSms = false;
  bool _isVerifying = false;
  bool _smsSent = false;
  String? _verificationId;
  int? _resendToken;
  int _countdown = 0;
  Timer? _timer;
  String? _errorMessage;

  @override
  void dispose() {
    _timer?.cancel();
    for (final c in _controllers) {
      c.dispose();
    }
    for (final f in _focusNodes) {
      f.dispose();
    }
    super.dispose();
  }

  void _startTimer() {
    setState(() => _countdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_countdown > 0) {
        setState(() => _countdown--);
      } else {
        t.cancel();
      }
    });
  }

  String get _maskedPhone {
    final phone = widget.user.contactNumber.trim();
    if (phone.length < 7) return phone;
    final prefix = phone.substring(0, 4);
    final suffix = phone.substring(phone.length - 3);
    return '$prefix •••• $suffix';
  }

  Future<void> _handleSendSms() async {
    setState(() {
      _isSendingSms = true;
      _errorMessage = null;
    });

    await OtpService.sendPhoneSmsOtp(
      rawPhoneNumber: widget.user.contactNumber,
      resendToken: _resendToken,
      onCodeSent: (String verificationId, int? resendToken) {
        if (!mounted) return;
        setState(() {
          _isSendingSms = false;
          _smsSent = true;
          _verificationId = verificationId;
          _resendToken = resendToken;
        });
        _startTimer();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('SMS verification code sent to your phone.'),
            backgroundColor: AppColors.accent,
          ),
        );
      },
      onError: (String message) {
        if (!mounted) return;
        setState(() {
          _isSendingSms = false;
          // Still show pin boxes so bypass code 123456 can be used
          _smsSent = true;
          _errorMessage = message;
        });
      },
      onAutoVerified: (credential) async {
        // Automatically retrieved via Android SMS Retriever
        if (!mounted) return;
        await _completeVerification();
      },
    );
  }

  String get _enteredCode {
    return _controllers.map((c) => c.text).join();
  }

  Future<void> _handleVerifySms() async {
    final code = _enteredCode.trim();
    if (code.length < 6) {
      setState(() => _errorMessage = 'Please enter all 6 digits of the SMS code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final isValid = await OtpService.verifyPhoneSmsCode(
      verificationId: _verificationId ?? 'dev_verification_id',
      smsCode: code,
    );

    if (!mounted) return;

    if (!isValid) {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Invalid or expired SMS code. Try again.';
      });
      return;
    }

    await _completeVerification();
  }

  Future<void> _completeVerification() async {
    setState(() => _isVerifying = true);

    await AuthService.markPhoneAsVerified(widget.user.uid);

    if (!mounted) return;

    final updatedUser = widget.user.copyWith(isPhoneVerified: true);

    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => RoleRouter.resolveDestination(
          role: updatedUser.role,
          status: updatedUser.status,
          position: updatedUser.position,
          user: updatedUser,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthAdminLayout(
      maxWidth: 440,
      child: Center(
        child: SingleChildScrollView(
            padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 32),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 440),
              child: Card(
                elevation: 0,
                color: Colors.white,
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(20),
                  side: const BorderSide(color: AppColors.border, width: 1),
                ),
                child: Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 28),
                  child: Column(
                    mainAxisSize: MainAxisSize.min,
                    crossAxisAlignment: CrossAxisAlignment.stretch,
                    children: [
                      // Header Icon
                      Center(
                        child: Container(
                          width: 64,
                          height: 64,
                          decoration: BoxDecoration(
                            color: AppColors.accent.withValues(alpha: 0.12),
                            shape: BoxShape.circle,
                          ),
                          child: const Icon(
                            Icons.phonelink_lock_rounded,
                            size: 34,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        'Phone SMS Verification',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        _smsSent
                            ? 'Enter the 6-digit SMS code sent to\n$_maskedPhone'
                            : 'To protect your account, please verify your registered phone number ($_maskedPhone) via SMS OTP.',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      if (!_smsSent) ...[
                        PrimaryButton(
                          label: 'Send SMS Code',
                          icon: Icons.sms_rounded,
                          isLoading: _isSendingSms,
                          onPressed: _handleSendSms,
                        ),
                      ] else ...[
                        // 6-digit Pin Fields (Responsive)
                        Row(
                          children: List.generate(6, (index) {
                            return Expanded(
                              child: Container(
                                margin: const EdgeInsets.symmetric(horizontal: 2.5),
                                height: 52,
                                child: TextField(
                                  controller: _controllers[index],
                                  focusNode: _focusNodes[index],
                                  keyboardType: TextInputType.number,
                                  textAlign: TextAlign.center,
                                  maxLength: 1,
                                  style: const TextStyle(
                                    fontSize: 20,
                                    fontWeight: FontWeight.w700,
                                    color: AppColors.textPrimary,
                                  ),
                                  decoration: InputDecoration(
                                    counterText: '',
                                    contentPadding: EdgeInsets.zero,
                                    enabledBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: AppColors.border,
                                        width: 1.5,
                                      ),
                                    ),
                                    focusedBorder: OutlineInputBorder(
                                      borderRadius: BorderRadius.circular(10),
                                      borderSide: const BorderSide(
                                        color: AppColors.accent,
                                        width: 2,
                                      ),
                                    ),
                                  ),
                                  onChanged: (val) {
                                    if (val.isNotEmpty && index < 5) {
                                      _focusNodes[index + 1].requestFocus();
                                    } else if (val.isEmpty && index > 0) {
                                      _focusNodes[index - 1].requestFocus();
                                    }
                                    if (_enteredCode.length == 6) {
                                      _handleVerifySms();
                                    }
                                  },
                                ),
                              ),
                            );
                          }),
                        ),

                        const SizedBox(height: 24),

                        PrimaryButton(
                          label: 'Verify Code & Enter App',
                          icon: Icons.verified_user_rounded,
                          isLoading: _isVerifying,
                          onPressed: _handleVerifySms,
                        ),

                        const SizedBox(height: 16),

                        Center(
                          child: _countdown > 0
                              ? Text(
                                  'Resend SMS in ${_countdown.toString().padLeft(2, '0')}s',
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.textSecondary,
                                    fontWeight: FontWeight.w500,
                                  ),
                                )
                              : TextButton.icon(
                                  onPressed: _isSendingSms ? null : _handleSendSms,
                                  icon: const Icon(Icons.refresh_rounded, size: 16),
                                  label: const Text('Resend SMS Code'),
                                  style: TextButton.styleFrom(
                                    foregroundColor: AppColors.accent,
                                    textStyle: const TextStyle(
                                      fontWeight: FontWeight.w600,
                                      fontSize: 13,
                                    ),
                                  ),
                                ),
                        ),
                      ],

                      if (_errorMessage != null) ...[
                        const SizedBox(height: 16),
                        Container(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 14, vertical: 10),
                          decoration: BoxDecoration(
                            color: AppColors.error.withValues(alpha: 0.08),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(
                                color: AppColors.error.withValues(alpha: 0.3)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.error_outline_rounded,
                                  size: 18, color: AppColors.error),
                              const SizedBox(width: 8),
                              Expanded(
                                child: Text(
                                  _errorMessage!,
                                  style: const TextStyle(
                                    fontSize: 13,
                                    color: AppColors.error,
                                    fontWeight: FontWeight.w500,
                                  ),
                                ),
                              ),
                            ],
                          ),
                        ),
                      ],

                      const SizedBox(height: 16),

                      // Sign out button
                      Center(
                        child: TextButton(
                          onPressed: () async {
                            await AuthService.signOut();
                            if (!context.mounted) return;
                            Navigator.of(context).pushAndRemoveUntil(
                              MaterialPageRoute(builder: (_) => const LoginScreen()),
                              (route) => false,
                            );
                          },
                          child: const Text(
                            'Log in with a different account',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                      // Dev test code banner
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.all(8),
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: Colors.amber.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: const Text(
                          'Dev / Test Bypass Code: 123456',
                          style: TextStyle(
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                            color: Colors.brown,
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ),
    );
  }
}

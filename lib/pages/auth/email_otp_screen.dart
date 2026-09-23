import 'dart:async';
import 'package:flutter/material.dart';
import '../../services/otp_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_admin_layout.dart';
import '../../widgets/primary_button.dart';

/// Screen displayed immediately after filling out the registration form.
/// The applicant must verify their real email address via a 6-digit OTP
/// before their registration is finalized and marked as pending for Owner approval.
class EmailOtpScreen extends StatefulWidget {
  const EmailOtpScreen({
    super.key,
    required this.email,
    required this.onVerified,
  });

  final String email;
  final Future<String?> Function() onVerified;

  @override
  State<EmailOtpScreen> createState() => _EmailOtpScreenState();
}

class _EmailOtpScreenState extends State<EmailOtpScreen> {
  final List<TextEditingController> _controllers =
      List.generate(8, (_) => TextEditingController());
  final List<FocusNode> _focusNodes = List.generate(8, (_) => FocusNode());

  int _resendCountdown = 60;
  Timer? _timer;
  bool _isVerifying = false;
  bool _isResending = false;
  String? _errorMessage;
  String? _sentCodeForHint;

  @override
  void initState() {
    super.initState();
    _startCountdown();
    _sendInitialOtp();
  }

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

  void _startCountdown() {
    setState(() => _resendCountdown = 60);
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (t) {
      if (!mounted) return;
      if (_resendCountdown > 0) {
        setState(() => _resendCountdown--);
      } else {
        t.cancel();
      }
    });
  }

  Future<void> _sendInitialOtp() async {
    try {
      final code = await OtpService.sendEmailOtp(widget.email);
      if (mounted) {
        setState(() {
          _sentCodeForHint = code;
        });
      }
    } catch (_) {}
  }

  Future<void> _resendCode() async {
    if (_resendCountdown > 0 || _isResending) return;
    setState(() {
      _isResending = true;
      _errorMessage = null;
    });

    try {
      final code = await OtpService.sendEmailOtp(widget.email);
      if (mounted) {
        setState(() {
          _sentCodeForHint = code;
          _isResending = false;
        });
        _startCountdown();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(
            content: Text('A new 8-digit verification code has been sent.'),
            backgroundColor: AppColors.accent,
          ),
        );
      }
    } catch (e) {
      if (mounted) {
        setState(() {
          _isResending = false;
          _errorMessage = 'Failed to resend code. Please try again.';
        });
      }
    }
  }

  String get _enteredCode {
    return _controllers.map((c) => c.text).join();
  }

  Future<void> _handleVerify() async {
    final code = _enteredCode.trim();
    if (code.length < 8) {
      setState(() => _errorMessage = 'Please enter all 8 digits of the code.');
      return;
    }

    setState(() {
      _isVerifying = true;
      _errorMessage = null;
    });

    final isValid = await OtpService.verifyEmailOtp(widget.email, code);

    if (!mounted) return;

    if (!isValid) {
      setState(() {
        _isVerifying = false;
        _errorMessage = 'Invalid or expired verification code. Try again.';
      });
      return;
    }

    // Call registration callback
    final regError = await widget.onVerified();

    if (!mounted) return;

    if (regError != null) {
      setState(() {
        _isVerifying = false;
        _errorMessage = regError;
      });
      return;
    }

    // Success handled by caller
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
                            Icons.mark_email_read_rounded,
                            size: 34,
                            color: AppColors.accent,
                          ),
                        ),
                      ),
                      const SizedBox(height: 18),

                      const Text(
                        'Verify Your Email',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 22,
                          fontWeight: FontWeight.w800,
                          color: AppColors.textPrimary,
                        ),
                      ),
                      const SizedBox(height: 8),
                      Text(
                        'We sent an 8-digit confirmation code to\n${widget.email}',
                        textAlign: TextAlign.center,
                        style: const TextStyle(
                          fontSize: 13.5,
                          color: AppColors.textSecondary,
                          height: 1.4,
                        ),
                      ),
                      const SizedBox(height: 24),

                      // 8-digit Pin Fields (Responsive)
                      Row(
                        children: List.generate(8, (index) {
                          return Expanded(
                            child: Container(
                              margin: const EdgeInsets.symmetric(horizontal: 2),
                              height: 52,
                              child: TextField(
                                controller: _controllers[index],
                                focusNode: _focusNodes[index],
                                keyboardType: TextInputType.number,
                                textAlign: TextAlign.center,
                                maxLength: 1,
                                style: const TextStyle(
                                  fontSize: 18,
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
                                  if (val.isNotEmpty && index < 7) {
                                    _focusNodes[index + 1].requestFocus();
                                  } else if (val.isEmpty && index > 0) {
                                    _focusNodes[index - 1].requestFocus();
                                  }
                                  if (_enteredCode.length == 8) {
                                    _handleVerify();
                                  }
                                },
                              ),
                            ),
                          );
                        }),
                      ),

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

                      const SizedBox(height: 28),

                      // Verify Button
                      PrimaryButton(
                        label: 'Verify Email & Submit',
                        icon: Icons.check_circle_outline_rounded,
                        isLoading: _isVerifying,
                        onPressed: _handleVerify,
                      ),
                      const SizedBox(height: 16),

                      // Resend Code Row
                      Center(
                        child: _resendCountdown > 0
                            ? Text(
                                'Resend code in ${_resendCountdown.toString().padLeft(2, '0')}s',
                                style: const TextStyle(
                                  fontSize: 13,
                                  color: AppColors.textSecondary,
                                  fontWeight: FontWeight.w500,
                                ),
                              )
                            : TextButton.icon(
                                onPressed: _isResending ? null : _resendCode,
                                icon: const Icon(Icons.refresh_rounded, size: 16),
                                label: const Text('Resend verification code'),
                                style: TextButton.styleFrom(
                                  foregroundColor: AppColors.accent,
                                  textStyle: const TextStyle(
                                    fontWeight: FontWeight.w600,
                                    fontSize: 13,
                                  ),
                                ),
                              ),
                      ),

                      const SizedBox(height: 12),

                      // Back to Edit Details
                      Center(
                        child: TextButton(
                          onPressed: () => Navigator.of(context).pop(),
                          child: const Text(
                            'Edit registration details',
                            style: TextStyle(
                              color: AppColors.textSecondary,
                              fontSize: 13,
                            ),
                          ),
                        ),
                      ),

                      // Dev helper banner (helps development without live SMTP)
                      if (_sentCodeForHint != null) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.all(8),
                          alignment: Alignment.center,
                          decoration: BoxDecoration(
                            color: Colors.amber.withValues(alpha: 0.12),
                            borderRadius: BorderRadius.circular(8),
                          ),
                          child: Text(
                            'Demo / Dev Code: $_sentCodeForHint (or 123456)',
                            style: const TextStyle(
                              fontSize: 11,
                              fontWeight: FontWeight.w600,
                              color: Colors.brown,
                            ),
                          ),
                        ),
                      ],
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

import 'dart:async';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../../services/auth_service.dart';
import '../../services/rate_limiter.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_brand_mark.dart';
import '../../widgets/auth_card.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _formKey = GlobalKey<FormState>();

  // Step state: 0 = Input email/username, 1 = Verify OTP, 2 = Set new password
  int _currentStep = 0;

  final _identifierController = TextEditingController();
  final _otpController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isLoading = false;
  String? _errorMessage;

  String? _targetEmail;
  String? _targetUsername;
  String? _targetFullName;

  Timer? _resendTimer;
  int _resendCountdown = 60;
  int _otpAttempts = 0;
  int _resendCount = 0;
  static const int _maxOtpAttempts = 5;
  static const int _maxResends = 3;

  @override
  void dispose() {
    _resendTimer?.cancel();
    _identifierController.dispose();
    _otpController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  void _startResendTimer() {
    _resendTimer?.cancel();
    setState(() => _resendCountdown = 60);
    _resendTimer = Timer.periodic(const Duration(seconds: 1), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_resendCountdown > 1) {
        setState(() => _resendCountdown--);
      } else {
        timer.cancel();
        setState(() => _resendCountdown = 0);
      }
    });
  }

  String _maskEmail(String email) {
    final parts = email.split('@');
    if (parts.length != 2) return email;
    final name = parts[0];
    final domain = parts[1];
    if (name.length <= 2) return '${name[0]}*@$domain';
    return '${name[0]}${'*' * (name.length - 2)}${name[name.length - 1]}@$domain';
  }

  // ===========================================================================
  // STEP 0: LOOKUP ACCOUNT & SEND REAL OTP
  // ===========================================================================

  Future<void> _handleFindAccountAndSendOtp() async {
    FocusScope.of(context).unfocus();

    // Rate-limit account lookup to prevent enumeration attacks
    if (!RateLimiter.tryAction(key: 'fp_lookup', cooldown: const Duration(seconds: 5))) {
      final secs = RateLimiter.remainingCooldownSeconds('fp_lookup');
      setState(() => _errorMessage = 'Please wait ${secs}s before searching again.');
      return;
    }

    final input = _identifierController.text.trim();
    if (input.isEmpty) {
      setState(() => _errorMessage = 'Please enter your Email address or Username.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final account = await AuthService.lookupAccountForPasswordReset(input);
      if (account == null) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'No account found with that email or username.';
        });
        return;
      }

      final email = account['email']!;
      final username = account['username']!;
      final fullName = account['fullName'] ?? '';

      // Send official Firebase reset email and Supabase 6-digit OTP
      AuthService.sendPasswordResetEmail(email: email).catchError((_) => false);
      final sent = await AuthService.sendPasswordResetOtp(email: email);
      if (!sent) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _errorMessage = 'Failed to send verification code. Please try again.';
        });
        return;
      }

      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _targetEmail = email;
        _targetUsername = username;
        _targetFullName = fullName;
        _currentStep = 1;
        _errorMessage = null;
        _otpAttempts = 0;
      });
      _startResendTimer();
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred. Please try again.';
      });
    }
  }

  // ===========================================================================
  // STEP 1: VERIFY 6-DIGIT OTP
  // ===========================================================================

  Future<void> _handleVerifyOtp() async {
    FocusScope.of(context).unfocus();

    // Enforce OTP attempt limit (prevent brute-forcing 6-digit code)
    if (_otpAttempts >= _maxOtpAttempts) {
      setState(() => _errorMessage = 'Maximum verification attempts reached ($_maxOtpAttempts). Please request a new code.');
      return;
    }

    final code = _otpController.text.trim();
    if (code.length < 6) {
      setState(() => _errorMessage = 'Please enter the complete 6-digit verification code.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final isValid = await AuthService.verifyPasswordResetOtp(
        email: _targetEmail!,
        enteredOtp: code,
      );

      if (!mounted) return;
      if (!isValid) {
        setState(() {
          _isLoading = false;
          _otpAttempts++;
          final remaining = _maxOtpAttempts - _otpAttempts;
          _errorMessage = remaining > 0
              ? 'Incorrect or expired verification code. ($remaining attempt${remaining == 1 ? "" : "s"} remaining)'
              : 'Maximum attempts reached ($_maxOtpAttempts). Please request a new code.';
        });
        return;
      }

      setState(() {
        _isLoading = false;
        _currentStep = 2;
        _errorMessage = null;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'Failed to verify the code. Please try again.';
      });
    }
  }

  Future<void> _handleResendOtp() async {
    if (_resendCountdown > 0 || _targetEmail == null) return;

    if (_resendCount >= _maxResends) {
      setState(() => _errorMessage = 'Maximum resend limit reached (${_maxResends}x). Please restart the recovery process.');
      return;
    }

    setState(() => _errorMessage = null);
    AuthService.sendPasswordResetEmail(email: _targetEmail!).catchError((_) => false);
    final sent = await AuthService.sendPasswordResetOtp(email: _targetEmail!);
    if (!mounted) return;
    if (sent) {
      _resendCount++;
      _otpAttempts = 0;
      _startResendTimer();
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text('Verification code resent to your email.'),
          backgroundColor: Color(0xFF2E7D32),
        ),
      );
    } else {
      setState(() => _errorMessage = 'Failed to resend the code. Please try again later.');
    }
  }

  // ===========================================================================
  // STEP 2: SET NEW PASSWORD
  // ===========================================================================

  Future<void> _handleSetNewPassword() async {
    FocusScope.of(context).unfocus();
    final newPassword = _passwordController.text;
    final confirmPassword = _confirmPasswordController.text;

    final passwordError = AuthService.validateStrongPassword(newPassword);
    if (passwordError != null) {
      setState(() => _errorMessage = passwordError);
      return;
    }
    if (newPassword != confirmPassword) {
      setState(() => _errorMessage = 'New password and confirmation do not match.');
      return;
    }

    setState(() {
      _isLoading = true;
      _errorMessage = null;
    });

    try {
      final success = await AuthService.completePasswordReset(
        email: _targetEmail!,
        username: _targetUsername!,
        newPassword: newPassword,
      );

      if (!mounted) return;
      setState(() => _isLoading = false);

      if (!success) {
        setState(() => _errorMessage = 'Failed to update your password. Please try again.');
        return;
      }

      // Pre-fill username for convenience
      await AuthService.saveRememberMe(
        rememberMe: false,
        username: _targetUsername!,
      );

      if (!mounted) return;
      showDialog(
        context: context,
        barrierDismissible: false,
        builder: (ctx) => AlertDialog(
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
          title: const Row(
            children: [
              Icon(Icons.check_circle_rounded, color: Color(0xFF2E7D32), size: 24),
              SizedBox(width: 10),
              Text(
                'Password Updated',
                style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
              ),
            ],
          ),
          content: Text(
            'Your new password has been set for account @${_targetUsername!}. If you also received an official confirmation link in your email, click it as well to apply changes across all platforms.',
            style: const TextStyle(fontSize: 14, color: AppColors.textSecondary, height: 1.4),
          ),
          actions: [
            ElevatedButton(
              onPressed: () {
                Navigator.pop(ctx);
                Navigator.pop(context);
              },
              style: ElevatedButton.styleFrom(
                backgroundColor: AppColors.accent,
                foregroundColor: Colors.white,
                padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(10)),
              ),
              child: const Text('PROCEED TO LOGIN', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
          ],
        ),
      );
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _isLoading = false;
        _errorMessage = 'An unexpected error occurred while updating your password.';
      });
    }
  }

  // ===========================================================================
  // BUILD UI
  // ===========================================================================

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: _currentStep == 0,
      onPopInvokedWithResult: (didPop, result) {
        if (!didPop && _currentStep > 0) {
          setState(() {
            _currentStep--;
            _errorMessage = null;
          });
        }
      },
      child: Scaffold(
        backgroundColor: AppColors.background,
        body: SafeArea(
          child: Stack(
            children: [
              // Top Back Navigation
              Positioned(
                top: 10,
                left: 10,
                child: IconButton(
                  icon: const Icon(Icons.arrow_back_ios_new_rounded, color: AppColors.textPrimary, size: 20),
                  onPressed: () {
                    if (_currentStep > 0) {
                      setState(() {
                        _currentStep--;
                        _errorMessage = null;
                      });
                    } else {
                      Navigator.pop(context);
                    }
                  },
                ),
              ),

              // Centered Form
              Center(
                child: SingleChildScrollView(
                  padding: const EdgeInsets.fromLTRB(24, 40, 24, 80),
                  child: ConstrainedBox(
                    constraints: const BoxConstraints(maxWidth: 420),
                    child: Form(
                      key: _formKey,
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Center(child: AuthBrandMark(icon: Icons.lock_reset_rounded)),
                          const SizedBox(height: 24),

                          Text(
                            _currentStep == 0
                                ? 'Reset Password'
                                : _currentStep == 1
                                    ? 'Verify Identity'
                                    : 'Set New Password',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 28,
                              fontWeight: FontWeight.w900,
                              color: AppColors.textPrimary,
                              letterSpacing: -0.5,
                            ),
                          ),
                          const SizedBox(height: 10),

                          Text(
                            _currentStep == 0
                                ? 'Enter your registered Email Address or Username to receive a 6-digit verification code.'
                                : _currentStep == 1
                                    ? 'We sent a 6-digit verification code to ${_targetEmail != null ? _maskEmail(_targetEmail!) : "your email"}.'
                                    : 'Create a new password for the account of ${_targetFullName ?? _targetUsername}.',
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              fontSize: 14,
                              color: Color(0xFF8D6E63),
                              fontWeight: FontWeight.w500,
                              height: 1.45,
                            ),
                          ),
                          const SizedBox(height: 32),

                          // Step Cards
                          AuthCard(
                            padding: const EdgeInsets.all(24),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.stretch,
                              children: [
                                // Step Indicator Dots
                                Row(
                                  mainAxisAlignment: MainAxisAlignment.center,
                                  children: [
                                    _buildStepDot(0),
                                    _buildStepLine(),
                                    _buildStepDot(1),
                                    _buildStepLine(),
                                    _buildStepDot(2),
                                  ],
                                ),
                                const SizedBox(height: 24),

                                // Error message banner
                                if (_errorMessage != null) ...[
                                  Container(
                                    padding: const EdgeInsets.all(12),
                                    decoration: BoxDecoration(
                                      color: AppColors.error.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                                    ),
                                    child: Row(
                                      children: [
                                        const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 18),
                                        const SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            _errorMessage!,
                                            style: const TextStyle(
                                              color: AppColors.error,
                                              fontSize: 12,
                                              fontWeight: FontWeight.w600,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  const SizedBox(height: 20),
                                ],

                                // STEP 0: Email / Username Input
                                if (_currentStep == 0) ...[
                                  TextFormField(
                                    controller: _identifierController,
                                    keyboardType: TextInputType.emailAddress,
                                    decoration: InputDecoration(
                                      labelText: 'EMAIL ADDRESS OR USERNAME',
                                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                                      prefixIcon: const Icon(Icons.alternate_email_rounded, size: 20),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                    ),
                                    onFieldSubmitted: (_) => _handleFindAccountAndSendOtp(),
                                  ),
                                  const SizedBox(height: 24),
                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _handleFindAccountAndSendOtp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('SEND VERIFICATION CODE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8)),
                                  ),
                                ],

                                // STEP 1: 6-Digit OTP Input
                                if (_currentStep == 1) ...[
                                  Container(
                                    padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                                    margin: const EdgeInsets.only(bottom: 18),
                                    decoration: BoxDecoration(
                                      color: AppColors.accent.withValues(alpha: 0.08),
                                      borderRadius: BorderRadius.circular(10),
                                      border: Border.all(color: AppColors.accent.withValues(alpha: 0.2)),
                                    ),
                                    child: const Row(
                                      children: [
                                        Icon(Icons.info_outline_rounded, color: AppColors.accent, size: 18),
                                        SizedBox(width: 8),
                                        Expanded(
                                          child: Text(
                                            'You can also click the official reset link sent to your email for a faster update.',
                                            style: TextStyle(
                                              color: AppColors.accent,
                                              fontSize: 11.5,
                                              fontWeight: FontWeight.w600,
                                              height: 1.3,
                                            ),
                                          ),
                                        ),
                                      ],
                                    ),
                                  ),
                                  TextFormField(
                                    controller: _otpController,
                                    keyboardType: TextInputType.number,
                                    maxLength: 6,
                                    textAlign: TextAlign.center,
                                    style: const TextStyle(
                                      fontSize: 26,
                                      letterSpacing: 10,
                                      fontWeight: FontWeight.w900,
                                      color: AppColors.textPrimary,
                                    ),
                                    inputFormatters: [
                                      FilteringTextInputFormatter.digitsOnly,
                                    ],
                                    decoration: InputDecoration(
                                      counterText: '',
                                      hintText: '000000',
                                      hintStyle: TextStyle(
                                        fontSize: 26,
                                        letterSpacing: 10,
                                        fontWeight: FontWeight.w700,
                                        color: AppColors.border.withValues(alpha: 0.8),
                                      ),
                                      labelText: '6-DIGIT VERIFICATION CODE',
                                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                                      prefixIcon: const Icon(Icons.security_rounded, size: 20),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                    ),
                                    onFieldSubmitted: (_) => _handleVerifyOtp(),
                                  ),
                                  const SizedBox(height: 16),

                                  // Resend timer row
                                  Row(
                                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                                    children: [
                                      const Text(
                                        "Didn't receive the code?",
                                        style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
                                      ),
                                      TextButton(
                                        onPressed: (_resendCountdown == 0 && !_isLoading) ? _handleResendOtp : null,
                                        child: Text(
                                          _resendCountdown > 0
                                              ? 'Resend in ${_resendCountdown}s'
                                              : 'Resend Code',
                                          style: TextStyle(
                                            fontSize: 12,
                                            fontWeight: FontWeight.w800,
                                            color: _resendCountdown > 0 ? AppColors.textSecondary : AppColors.accent,
                                          ),
                                        ),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 20),

                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _handleVerifyOtp,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('VERIFY CODE', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8)),
                                  ),
                                ],

                                // STEP 2: New Password & Confirm Password
                                if (_currentStep == 2) ...[
                                  TextFormField(
                                    controller: _passwordController,
                                    obscureText: _obscurePassword,
                                    decoration: InputDecoration(
                                      labelText: 'NEW PASSWORD',
                                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                                      helperText: 'Must include uppercase, lowercase, a number, and a symbol (min. 6 characters).',
                                      helperStyle: const TextStyle(fontSize: 10.5, color: Color(0xFF8D6E63)),
                                      prefixIcon: const Icon(Icons.lock_outline_rounded, size: 20),
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscurePassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                                        onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                                      ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 16),

                                  TextFormField(
                                    controller: _confirmPasswordController,
                                    obscureText: _obscureConfirmPassword,
                                    decoration: InputDecoration(
                                      labelText: 'CONFIRM NEW PASSWORD',
                                      labelStyle: const TextStyle(fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.8),
                                      prefixIcon: const Icon(Icons.lock_reset_rounded, size: 20),
                                      suffixIcon: IconButton(
                                        icon: Icon(_obscureConfirmPassword ? Icons.visibility_off_outlined : Icons.visibility_outlined, size: 20),
                                        onPressed: () => setState(() => _obscureConfirmPassword = !_obscureConfirmPassword),
                                      ),
                                      border: OutlineInputBorder(borderRadius: BorderRadius.circular(12)),
                                      enabledBorder: OutlineInputBorder(
                                        borderRadius: BorderRadius.circular(12),
                                        borderSide: const BorderSide(color: AppColors.border),
                                      ),
                                    ),
                                    onFieldSubmitted: (_) => _handleSetNewPassword(),
                                  ),
                                  const SizedBox(height: 24),

                                  ElevatedButton(
                                    onPressed: _isLoading ? null : _handleSetNewPassword,
                                    style: ElevatedButton.styleFrom(
                                      backgroundColor: AppColors.accent,
                                      foregroundColor: Colors.white,
                                      padding: const EdgeInsets.symmetric(vertical: 18),
                                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
                                      elevation: 0,
                                    ),
                                    child: _isLoading
                                        ? const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                                        : const Text('UPDATE PASSWORD', style: TextStyle(fontWeight: FontWeight.w900, fontSize: 13, letterSpacing: 0.8)),
                                  ),
                                ],
                              ],
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStepDot(int stepIndex) {
    final isActive = _currentStep == stepIndex;
    final isDone = _currentStep > stepIndex;

    return Container(
      width: 26,
      height: 26,
      decoration: BoxDecoration(
        color: isDone
            ? const Color(0xFF2E7D32)
            : isActive
                ? AppColors.accent
                : AppColors.border.withValues(alpha: 0.5),
        shape: BoxShape.circle,
      ),
      child: Center(
        child: isDone
            ? const Icon(Icons.check, size: 14, color: Colors.white)
            : Text(
                '${stepIndex + 1}',
                style: TextStyle(
                  color: (isActive || isDone) ? Colors.white : AppColors.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w800,
                ),
              ),
      ),
    );
  }

  Widget _buildStepLine() {
    return Container(
      width: 32,
      height: 2,
      color: AppColors.border.withValues(alpha: 0.5),
    );
  }
}

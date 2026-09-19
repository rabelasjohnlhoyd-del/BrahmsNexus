import 'package:flutter/material.dart';
import '../../models/account_status.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import 'mock_accounts.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_admin_layout.dart';
import '../../widgets/auth_brand_mark.dart';
import 'forgot_password_screen.dart';
import 'register_screen.dart';
import 'role_router.dart';

/// Clean, simple, and professional Login Screen for Web Admin & Owner.
///
/// Designed with proper enterprise UI standards:
/// - Ample whitespace and dignified brand typography
/// - Clear, high-contrast form inputs with intuitive validations
/// - "Remember this device" option & "Forgot password?" recovery
class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  bool _obscurePassword = true;
  bool _rememberMe = false;
  bool _isLoading = false;
  String? _authError;

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your username or email';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    setState(() => _authError = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    final username = _usernameController.text.trim();
    final password = _passwordController.text;

    if (username.toLowerCase() != 'owner' && username.toLowerCase() != 'admin') {
      final isDeactivated = await AuthService.isAccountDeactivated(username);
      if (isDeactivated) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _authError =
              'Ang account na ito ay kasalukuyang NAKA-DEACTIVATE (Frozen). Makipag-ugnayan sa Owner para ma-reactivate.';
        });
        return;
      }

      final isOnRestDay = await AuthService.isAccountOnRestDay(username);
      if (isOnRestDay) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _authError =
              'Naka-REST DAY po kayo ngayon ayon sa iskedyul ng Owner kaya hindi maaaring mag-login. Magpahinga po muna kayo!';
        });
        return;
      }
    }

    final mock = kMockAccounts[username];
    if (mock != null && mock.password == password) {
      AppUser? liveUser;
      if (mock.role == UserRole.owner) {
        liveUser = await AuthService.signInOrSeedOwner(
          username: username,
          password: password,
        );
      } else {
        liveUser = await AuthService.signInOrSeedStaff(
          username: username,
          password: password,
          fullName: mock.fullName,
          contactNumber: mock.phone.isNotEmpty ? mock.phone : '09123456789',
          role: mock.role,
          position: mock.position,
        );
      }

      if (liveUser != null) {
        if (!mounted) return;
        setState(() => _isLoading = false);
        _navigateToRole(liveUser);
        return;
      }
    }

    String? signInError;
    final user = await AuthService.signIn(
      username: username,
      password: password,
      onError: (msg) => signInError = msg,
    );

    if (!mounted) return;
    setState(() => _isLoading = false);

    if (user == null) {
      setState(() {
        _authError = signInError ?? 'Invalid username or password';
      });
      return;
    }

    if (user.status == AccountStatus.rejected) {
      setState(() {
        _authError = 'Your registration was not approved. Contact management.';
      });
      return;
    }

    _navigateToRole(user);
  }

  void _navigateToRole(AppUser user) {
    Navigator.of(context).pushAndRemoveUntil(
      MaterialPageRoute(
        builder: (_) => RoleRouter.resolveDestination(
          role: user.role,
          status: user.status,
          position: user.position,
        ),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthAdminLayout(
      maxWidth: 460,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
        child: Form(
          key: _formKey,
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              // Official Logo Emblem
              const Center(
                child: AuthBrandMark(size: 72),
              ),
              const SizedBox(height: 16),

              // Title & Description
              const Text(
                'Sign In',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 24,
                  fontWeight: FontWeight.w900,
                  color: Color(0xFF24140B),
                  letterSpacing: -0.3,
                ),
              ),
              const SizedBox(height: 5),
              const Text(
                'Welcome back. Enter your credentials to access the portal.',
                textAlign: TextAlign.center,
                style: TextStyle(
                  fontSize: 13,
                  color: Color(0xFF7A6556),
                  height: 1.35,
                ),
              ),
              const SizedBox(height: 24),

              // Username / Email Field
              TextFormField(
                controller: _usernameController,
                textInputAction: TextInputAction.next,
                decoration: InputDecoration(
                  labelText: 'Username or Email',
                  hintText: 'e.g. admin or username',
                  labelStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B584C),
                  ),
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF6B584C).withValues(alpha: 0.4),
                  ),
                  prefixIcon: const Icon(Icons.person_outline_rounded, size: 19),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFDCCFC3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
                validator: _validateUsername,
              ),
              const SizedBox(height: 16),

              // Password Field
              TextFormField(
                controller: _passwordController,
                obscureText: _obscurePassword,
                textInputAction: TextInputAction.done,
                onFieldSubmitted: (_) => _handleLogin(),
                decoration: InputDecoration(
                  labelText: 'Password',
                  hintText: '••••••••••••',
                  labelStyle: const TextStyle(
                    fontSize: 12.5,
                    fontWeight: FontWeight.w600,
                    color: Color(0xFF6B584C),
                  ),
                  hintStyle: TextStyle(
                    fontSize: 13,
                    color: const Color(0xFF6B584C).withValues(alpha: 0.4),
                  ),
                  prefixIcon: const Icon(Icons.lock_outline_rounded, size: 19),
                  suffixIcon: IconButton(
                    icon: Icon(
                      _obscurePassword
                          ? Icons.visibility_off_outlined
                          : Icons.visibility_outlined,
                      size: 19,
                      color: const Color(0xFF7A6556),
                    ),
                    onPressed: () => setState(() => _obscurePassword = !_obscurePassword),
                  ),
                  contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
                  border: OutlineInputBorder(borderRadius: BorderRadius.circular(10)),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: Color(0xFFDCCFC3)),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(10),
                    borderSide: const BorderSide(color: AppColors.accent, width: 1.5),
                  ),
                ),
                validator: _validatePassword,
              ),

              // Error Banner
              if (_authError != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
                  decoration: BoxDecoration(
                    color: AppColors.error.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(8),
                    border: Border.all(color: AppColors.error.withValues(alpha: 0.3)),
                  ),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Icon(Icons.error_outline_rounded, color: AppColors.error, size: 17),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          _authError!,
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
              ],

              const SizedBox(height: 12),

              // Options Row: Remember Me & Forgot Password
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  InkWell(
                    onTap: () => setState(() => _rememberMe = !_rememberMe),
                    borderRadius: BorderRadius.circular(6),
                    child: Padding(
                      padding: const EdgeInsets.symmetric(vertical: 4),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          SizedBox(
                            width: 18,
                            height: 18,
                            child: Checkbox(
                              value: _rememberMe,
                              onChanged: (val) => setState(() => _rememberMe = val ?? false),
                              activeColor: AppColors.accent,
                              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(4)),
                              side: const BorderSide(color: Color(0xFFB09E90)),
                            ),
                          ),
                          const SizedBox(width: 8),
                          const Text(
                            'Remember this device',
                            style: TextStyle(
                              fontSize: 12,
                              color: Color(0xFF6B584C),
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  TextButton(
                    onPressed: _isLoading
                        ? null
                        : () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ForgotPasswordScreen(),
                              ),
                            ),
                    style: TextButton.styleFrom(
                      padding: EdgeInsets.zero,
                      minimumSize: Size.zero,
                      tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                    ),
                    child: const Text(
                      'Forgot password?',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w700,
                        fontSize: 12,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),

              // Primary Action: Dignified Sign In Button
              SizedBox(
                height: 46,
                child: ElevatedButton(
                  onPressed: _isLoading ? null : _handleLogin,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFF8B4513),
                    foregroundColor: Colors.white,
                    elevation: 0,
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(10),
                    ),
                  ),
                  child: _isLoading
                      ? const SizedBox(
                          width: 20,
                          height: 20,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Sign In',
                          style: TextStyle(
                            fontWeight: FontWeight.w800,
                            fontSize: 14.5,
                            letterSpacing: 0.3,
                          ),
                        ),
                ),
              ),

              const SizedBox(height: 20),

              // Clean subtle divider
              const Divider(color: Color(0xFFEBE2D8), height: 1),
              const SizedBox(height: 18),

              // Register Link
              Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  const Text(
                    'Need to submit an application? ',
                    style: TextStyle(
                      color: Color(0xFF7A6556),
                      fontSize: 12.5,
                    ),
                  ),
                  GestureDetector(
                    onTap: () {
                      Navigator.of(context).push(
                        PageRouteBuilder(
                          pageBuilder: (context, animation, secondaryAnimation) =>
                              const RegisterScreen(),
                          transitionsBuilder:
                              (context, animation, secondaryAnimation, child) {
                            return FadeTransition(opacity: animation, child: child);
                          },
                          transitionDuration: const Duration(milliseconds: 180),
                        ),
                      );
                    },
                    child: const Text(
                      'Register here',
                      style: TextStyle(
                        color: AppColors.accent,
                        fontWeight: FontWeight.w800,
                        fontSize: 12.5,
                      ),
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }
}

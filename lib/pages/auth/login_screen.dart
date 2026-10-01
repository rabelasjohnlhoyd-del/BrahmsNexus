import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../models/account_status.dart';
import '../../models/app_user.dart';
import '../../models/user_role.dart';
import 'mock_accounts.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_admin_layout.dart';
import '../../widgets/auth_brand_mark.dart';
import '../../widgets/mobile_auth_layout.dart';
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
  void initState() {
    super.initState();
    _loadSavedPreferences();
  }

  Future<void> _loadSavedPreferences() async {
    final prefs = await AuthService.getSavedLoginPreferences();
    if (!mounted) return;
    setState(() {
      _rememberMe = prefs['remember_me'] as bool? ?? false;
      final savedUsername = prefs['saved_username'] as String? ?? '';
      if (savedUsername.isNotEmpty && _usernameController.text.isEmpty) {
        _usernameController.text = savedUsername;
      }
    });
  }

  @override
  void dispose() {
    _usernameController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  String? _validateUsername(String? value) {
    if (value == null || value.trim().isEmpty) {
      return 'Please enter your username or email.';
    }
    if (value.trim().length < 3) {
      return 'Username must be at least 3 characters.';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please enter your password.';
    }
    if (value.length < 6) {
      return 'Password must be at least 6 characters.';
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
              'This account is currently deactivated. Please contact the administrator for assistance.';
        });
        return;
      }

      final isOnRestDay = await AuthService.isAccountOnRestDay(username);
      if (isOnRestDay) {
        if (!mounted) return;
        setState(() {
          _isLoading = false;
          _authError =
              'You are on scheduled rest day today and cannot sign in. Please enjoy your day off!';
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
        if (!kIsWeb && liveUser.role == UserRole.owner) {
          await AuthService.signOut();
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _authError = 'Administrator and Owner accounts can only be accessed on the Web Portal.';
          });
          return;
        }
        if (kIsWeb && liveUser.role != UserRole.owner) {
          await AuthService.signOut();
          if (!mounted) return;
          setState(() {
            _isLoading = false;
            _authError = 'Staff and Driver accounts can only be accessed using the mobile app.';
          });
          return;
        }
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

    // Web-Only Admin Guard: Prevent Owner from accessing the mobile app
    if (!kIsWeb && user.role == UserRole.owner) {
      await AuthService.signOut();
      if (!mounted) return;
      setState(() {
        _authError = 'Administrator and Owner accounts can only be accessed on the Web Portal.';
      });
      return;
    }

    // Mobile-Only Staff Guard: Prevent Staff/Driver from logging in on Web Portal
    if (kIsWeb && user.role != UserRole.owner) {
      await AuthService.signOut();
      if (!mounted) return;
      setState(() {
        _authError = 'Staff and Driver accounts can only be accessed using the mobile app.';
      });
      return;
    }

    _navigateToRole(user);
  }

  void _navigateToRole(AppUser user) {
    AuthService.saveRememberMe(
      rememberMe: _rememberMe,
      username: _usernameController.text.trim().isNotEmpty
          ? _usernameController.text.trim()
          : user.username,
      uid: user.uid,
    );

    Navigator.of(context).pushAndRemoveUntil(
      PageRouteBuilder(
        pageBuilder: (context, animation, secondaryAnimation) =>
            RoleRouter.resolveDestination(
          role: user.role,
          status: user.status,
          position: user.position,
          user: user,
        ),
        transitionsBuilder: (context, animation, secondaryAnimation, child) {
          return FadeTransition(
            opacity: CurvedAnimation(
              parent: animation,
              curve: Curves.easeInOutCubic,
            ),
            child: child,
          );
        },
        transitionDuration: const Duration(milliseconds: 450),
      ),
      (route) => false,
    );
  }

  @override
  Widget build(BuildContext context) {
    // Web: enterprise card layout (unchanged)
    if (kIsWeb) {
      return AuthAdminLayout(
        maxWidth: 460,
        child: Padding(
          padding: const EdgeInsets.fromLTRB(32, 28, 32, 28),
          child: Form(
            key: _formKey,
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                const Center(child: AuthBrandMark(size: 72)),
                const SizedBox(height: 16),
                const Text(
                  'Administrator Portal',
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
                  'Enter your owner credentials to access the Brahms Nexus management system.',
                  textAlign: TextAlign.center,
                  style: TextStyle(
                    fontSize: 13,
                    color: Color(0xFF7A6556),
                    height: 1.35,
                  ),
                ),
                const SizedBox(height: 24),
                ..._buildFormFields(),
                const SizedBox(height: 12),
                _buildOptionsRow(),
                const SizedBox(height: 20),
                _buildSignInButton(),
              ],
            ),
          ),
        ),
      );
    }

    // Mobile: new dark wave header layout
    return MobileAuthLayout(
      subtitle: 'Crispy Sisig & Bagnet',
      child: Form(
        key: _formKey,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            // Left-aligned heading block
            const Text(
              'Sign In',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 26,
                fontWeight: FontWeight.w900,
                color: AppColors.textPrimary,
                letterSpacing: -0.3,
              ),
            ),
            const SizedBox(height: 5),
            const Text(
              'Welcome back. Enter your credentials.',
              textAlign: TextAlign.left,
              style: TextStyle(
                fontSize: 13,
                color: Color(0xFF7A6556),
                height: 1.35,
              ),
            ),
            const SizedBox(height: 24),

            ..._buildFormFields(),
            const SizedBox(height: 14),
            _buildOptionsRow(),
            const SizedBox(height: 20),
            _buildSignInButton(),
            const SizedBox(height: 18),
            const Divider(color: AppColors.border, height: 1),
            const SizedBox(height: 16),
            Wrap(
              alignment: WrapAlignment.center,
              crossAxisAlignment: WrapCrossAlignment.center,
              children: [
                const Text(
                  "Don't have an account? ",
                  style: TextStyle(color: Color(0xFF7A6556), fontSize: 12.5),
                ),
                GestureDetector(
                  onTap: () {
                    Navigator.of(context).push(
                      PageRouteBuilder(
                        opaque: false,
                        pageBuilder:
                            (context, animation, secondaryAnimation) =>
                                const RegisterScreen(),
                        transitionsBuilder:
                            (context, animation, secondaryAnimation, child) {
                          return FadeTransition(
                            opacity: CurvedAnimation(
                              parent: animation,
                              curve: Curves.easeInOutCubic,
                            ),
                            child: child,
                          );
                        },
                        transitionDuration: const Duration(milliseconds: 400),
                        reverseTransitionDuration:
                            const Duration(milliseconds: 400),
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
    );
  }

  // ── Shared form helpers ───────────────────────────────────────────────────

  /// Username + password fields + optional error banner.
  List<Widget> _buildFormFields() => [
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
            prefixIcon:
                const Icon(Icons.person_outline_rounded, size: 19),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDCCFC3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
          validator: _validateUsername,
        ),
        const SizedBox(height: 16),
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
              onPressed: () =>
                  setState(() => _obscurePassword = !_obscurePassword),
            ),
            contentPadding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(10)),
            enabledBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide: const BorderSide(color: Color(0xFFDCCFC3)),
            ),
            focusedBorder: OutlineInputBorder(
              borderRadius: BorderRadius.circular(10),
              borderSide:
                  const BorderSide(color: AppColors.accent, width: 1.5),
            ),
          ),
          validator: _validatePassword,
        ),
        if (_authError != null) ...[
          const SizedBox(height: 12),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 12, vertical: 9),
            decoration: BoxDecoration(
              color: AppColors.error.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(8),
              border: Border.all(
                  color: AppColors.error.withValues(alpha: 0.3)),
            ),
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Icon(Icons.error_outline_rounded,
                    color: AppColors.error, size: 17),
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
      ];

  /// Remember-me checkbox + forgot-password link row.
  Widget _buildOptionsRow() => Row(
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
                      onChanged: (val) =>
                          setState(() => _rememberMe = val ?? false),
                      activeColor: AppColors.accent,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(4)),
                      side: const BorderSide(color: Color(0xFFB09E90)),
                    ),
                  ),
                  const SizedBox(width: 8),
                  const Text(
                    'Remember me',
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
      );

  /// Primary sign-in button with loading spinner.
  Widget _buildSignInButton() => SizedBox(
        height: 48,
        child: ElevatedButton(
          onPressed: _isLoading ? null : _handleLogin,
          style: ElevatedButton.styleFrom(
            backgroundColor: AppColors.accent,
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
      );
}


import 'package:flutter/foundation.dart' show kIsWeb;
import 'package:flutter/material.dart';
import '../../models/user_role.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_brand_mark.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/social_login_row.dart';
import 'mock_accounts.dart';
import 'register_screen.dart';
import 'role_router.dart';
import 'welcome_screen.dart';

/// The one and only login screen — used by Owner, Staff, and Driver
/// alike.
///
/// Deliberately has NO "log in as ___" selector. Role and approval
/// status are never chosen by the person logging in — they're looked
/// up from the account behind the username/password, the same way a
/// real backend would resolve them. See mock_accounts.dart for the
/// dev-only stand-in for that lookup (kept reachable only via the small
/// "Dev: demo accounts" link at the bottom, so it doesn't read as a
/// real feature).
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
      return 'Username is required';
    }
    return null;
  }

  String? _validatePassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Password is required';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();
    setState(() => _authError = null);

    if (!_formKey.currentState!.validate()) return;

    setState(() => _isLoading = true);

    // Mock lookup — stands in for Firebase Auth + a Firestore user-record
    // read. Notice the account (not the person) determines the role and
    // status; nothing here lets the user assert their own role.
    await Future.delayed(const Duration(milliseconds: 700));
    final account = kMockAccounts[_usernameController.text.trim()];

    if (!mounted) return;

    if (account == null || account.password != _passwordController.text) {
      setState(() {
        _isLoading = false;
        _authError = 'Incorrect username or password.';
      });
      return;
    }

    setState(() => _isLoading = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RoleRouter.resolveDestination(
          role: account.role,
          status: account.status,
        ),
      ),
    );
  }

  void _handleBack() {
    // Login is usually reached by pushing on top of WelcomeScreen, so a
    // normal pop takes the user right back there. But after a logout
    // (pushAndRemoveUntil clears the whole stack down to just
    // LoginScreen, on purpose — see the logout flows), there's nothing
    // left to pop to. In that case, go to WelcomeScreen explicitly
    // instead of leaving Back looking broken.
    if (Navigator.of(context).canPop()) {
      Navigator.of(context).pop();
    } else if (!kIsWeb) {
      // WelcomeScreen isn't part of the web flow at all (see main.dart —
      // web goes straight to LoginScreen), so there's nothing to fall
      // back to here on web; only mobile has a WelcomeScreen to return to.
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(builder: (_) => const WelcomeScreen()),
      );
    }
  }

  void _showComingSoon(String feature) {
    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(content: Text('$feature is not available yet.')),
    );
  }

  void _showDemoAccounts() {
    showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (sheetContext) => DraggableScrollableSheet(
        initialChildSize: 0.5,
        minChildSize: 0.3,
        maxChildSize: 0.9,
        expand: false,
        builder: (context, scrollController) => SafeArea(
          child: ListView(
            controller: scrollController,
            padding: const EdgeInsets.fromLTRB(20, 8, 20, 24),
            children: [
              Center(
                child: Container(
                  width: 40,
                  height: 4,
                  margin: const EdgeInsets.only(bottom: 16),
                  decoration: BoxDecoration(
                    color: AppColors.border,
                    borderRadius: BorderRadius.circular(2),
                  ),
                ),
              ),
              const Text(
                'Dev demo accounts',
                style: TextStyle(
                  fontWeight: FontWeight.bold,
                  color: AppColors.textPrimary,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                'Tap one to fill the form. Only reachable in this '
                'pre-backend build — remove once real auth is wired up.',
                style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
              ),
              const SizedBox(height: 12),
              // Web (Owner-only) only ever needs the owner demo account
              // listed here — Staff/Driver accounts belong to the app.
              ...(kIsWeb
                      ? kMockAccounts.entries
                          .where((e) => e.value.role == UserRole.owner)
                      : kMockAccounts.entries)
                  .map(
                (e) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  leading: const Icon(Icons.person_outline,
                      color: AppColors.accent),
                  title: Text(e.key),
                  subtitle: Text(
                    '${e.value.role.label} · ${e.value.status.label}',
                  ),
                  onTap: () {
                    _usernameController.text = e.key;
                    _passwordController.text = e.value.password;
                    Navigator.of(sheetContext).pop();
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      // Always intercept system/hardware back (gesture or button) and
      // route it through the same _handleBack logic as the on-screen
      // arrow above, so both agree: pop if there's something to pop
      // to, otherwise land on WelcomeScreen instead of doing nothing
      // (or closing the app, which is the default when canPop is
      // false and this is left unhandled).
      canPop: false,
      onPopInvokedWithResult: (didPop, result) {
        if (didPop) return;
        _handleBack();
      },
      child: Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(28, 4, 28, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    if (!kIsWeb)
                      Align(
                        alignment: Alignment.centerLeft,
                        child: IconButton(
                          icon: const Icon(Icons.arrow_back_ios_new_rounded,
                              size: 20),
                          color: AppColors.textPrimary,
                          onPressed: _handleBack,
                        ),
                      ),
                    const SizedBox(height: 8),
                    const Center(
                      child: AuthBrandMark(icon: Icons.storefront_rounded),
                    ),
                    const SizedBox(height: 24),
                    const Text(
                      'Welcome back',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 28,
                        fontWeight: FontWeight.w800,
                        color: AppColors.textPrimary,
                        letterSpacing: -0.5,
                      ),
                    ),
                    const SizedBox(height: 8),
                    const Text(
                      'Sign in to keep things running.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 36),
                    TextFormField(
                      controller: _usernameController,
                      textInputAction: TextInputAction.next,
                      autofillHints: const [AutofillHints.username],
                      decoration: const InputDecoration(
                        labelText: 'Username',
                        prefixIcon: Icon(Icons.person_outline),
                      ),
                      validator: _validateUsername,
                    ),
                    const SizedBox(height: 16),
                    TextFormField(
                      controller: _passwordController,
                      obscureText: _obscurePassword,
                      textInputAction: TextInputAction.done,
                      autofillHints: const [AutofillHints.password],
                      onFieldSubmitted: (_) => _handleLogin(),
                      decoration: InputDecoration(
                        labelText: 'Password',
                        prefixIcon: const Icon(Icons.lock_outline),
                        suffixIcon: IconButton(
                          icon: Icon(
                            _obscurePassword
                                ? Icons.visibility_off_outlined
                                : Icons.visibility_outlined,
                          ),
                          onPressed: () => setState(
                            () => _obscurePassword = !_obscurePassword,
                          ),
                        ),
                      ),
                      validator: _validatePassword,
                    ),
                    if (_authError != null) ...[
                      const SizedBox(height: 12),
                      Text(
                        _authError!,
                        style: const TextStyle(
                          color: AppColors.error,
                          fontSize: 12.5,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                    Align(
                      alignment: Alignment.centerRight,
                      child: TextButton(
                        onPressed: _isLoading
                            ? null
                            : () => _showComingSoon('Password reset'),
                        child: const Text('Forgot your password?'),
                      ),
                    ),
                    const SizedBox(height: 4),
                    PrimaryButton(
                      label: 'Sign in',
                      isLoading: _isLoading,
                      onPressed: _handleLogin,
                    ),
                    if (!kIsWeb) ...[
                      const SizedBox(height: 20),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          const Text(
                            "Don't have an account? ",
                            style: TextStyle(color: AppColors.textSecondary),
                          ),
                          GestureDetector(
                            onTap: _isLoading
                                ? null
                                : () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    ),
                            child: const Text(
                              'Create new account',
                              style: TextStyle(
                                color: AppColors.accent,
                                fontWeight: FontWeight.w700,
                              ),
                            ),
                          ),
                        ],
                      ),
                    ],
                    const SizedBox(height: 28),
                    const _OrDivider(),
                    const SizedBox(height: 18),
                    const SocialLoginRow(),
                    const SizedBox(height: 24),
                    Center(
                      child: TextButton.icon(
                        onPressed: _showDemoAccounts,
                        icon: const Icon(Icons.science_outlined, size: 16),
                        label: const Text('Dev: demo accounts'),
                        style: TextButton.styleFrom(
                          foregroundColor: AppColors.textSecondary,
                          textStyle: const TextStyle(fontSize: 12),
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
    ),
    );
  }
}

class _OrDivider extends StatelessWidget {
  const _OrDivider();

  @override
  Widget build(BuildContext context) {
    return Row(
      children: const [
        Expanded(child: Divider(color: AppColors.border)),
        Padding(
          padding: EdgeInsets.symmetric(horizontal: 12),
          child: Text(
            'Or continue with',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

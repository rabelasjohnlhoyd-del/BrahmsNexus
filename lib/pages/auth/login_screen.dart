import 'package:flutter/material.dart';
import '../../models/account_status.dart';
import '../../models/user_role.dart';
import '../../theme/app_theme.dart';
import '../../widgets/primary_button.dart';
import 'register_screen.dart';
import 'role_router.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _formKey = GlobalKey<FormState>();
  final _usernameController = TextEditingController();
  final _passwordController = TextEditingController();

  UserRole _selectedRole = UserRole.owner;

  // DEV-ONLY: walang backend pa kaya wala pang totoong account status.
  // Ginagamit lang ito para masubukan ang Pending/Rejected/Approved
  // screens habang frontend-only phase pa. TANGGALIN ITO once Firebase/
  // Supabase Auth na ang aktwal na nagbibigay ng account status.
  AccountStatus _devSimulatedStatus = AccountStatus.approved;

  bool _obscurePassword = true;
  bool _isLoading = false;

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
    if (value.length < 6) {
      return 'Password must be at least 6 characters';
    }
    return null;
  }

  Future<void> _handleLogin() async {
    FocusScope.of(context).unfocus();

    if (!_formKey.currentState!.validate()) {
      return;
    }

    setState(() => _isLoading = true);

    // NOTE: Authentication is not wired up yet — this is a front-end-only
    // simulation. Firebase/Supabase Auth + role & status lookup will
    // replace this block once the backend is implemented.
    await Future.delayed(const Duration(milliseconds: 900));

    if (!mounted) return;
    setState(() => _isLoading = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => RoleRouter.resolveDestination(
          role: _selectedRole,
          status: _selectedRole == UserRole.owner
              ? AccountStatus.approved // Owner account is pre-seeded/approved
              : _devSimulatedStatus,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: Center(
          child: Padding(
            padding: const EdgeInsets.all(24.0),
            child: SingleChildScrollView(
              child: ConstrainedBox(
                constraints: const BoxConstraints(maxWidth: 420),
                child: Form(
                  key: _formKey,
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(
                        Icons.storefront_rounded,
                        size: 48,
                        color: AppColors.accent,
                      ),
                      const SizedBox(height: 12),
                      const Text(
                        'BRAHMS NEXUS',
                        style: TextStyle(
                          fontSize: 26,
                          fontWeight: FontWeight.bold,
                          color: AppColors.accent,
                          letterSpacing: 1.2,
                        ),
                      ),
                      const SizedBox(height: 8),
                      const Text(
                        'Centralized Operations & Decision Support System',
                        textAlign: TextAlign.center,
                        style: TextStyle(
                          fontSize: 14,
                          color: AppColors.textSecondary,
                        ),
                      ),
                      const SizedBox(height: 32),

                      // Role selector
                      const Align(
                        alignment: Alignment.centerLeft,
                        child: Text(
                          'Log in as',
                          style: TextStyle(
                            fontSize: 13,
                            fontWeight: FontWeight.w600,
                            color: AppColors.textSecondary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 8),
                      SegmentedButton<UserRole>(
                        segments: const [
                          ButtonSegment(
                            value: UserRole.owner,
                            label: Text('Owner'),
                            icon: Icon(Icons.admin_panel_settings_outlined),
                          ),
                          ButtonSegment(
                            value: UserRole.staff,
                            label: Text('Staff'),
                            icon: Icon(Icons.badge_outlined),
                          ),
                          ButtonSegment(
                            value: UserRole.driver,
                            label: Text('Driver'),
                            icon: Icon(Icons.local_shipping_outlined),
                          ),
                        ],
                        selected: {_selectedRole},
                        onSelectionChanged: (value) {
                          setState(() => _selectedRole = value.first);
                        },
                        style: ButtonStyle(
                          backgroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? AppColors.accent
                                : AppColors.surface,
                          ),
                          foregroundColor: WidgetStateProperty.resolveWith(
                            (states) => states.contains(WidgetState.selected)
                                ? Colors.white
                                : AppColors.textPrimary,
                          ),
                        ),
                      ),
                      const SizedBox(height: 24),

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
                            onPressed: () {
                              setState(
                                  () => _obscurePassword = !_obscurePassword);
                            },
                          ),
                        ),
                        validator: _validatePassword,
                      ),

                      if (_selectedRole != UserRole.owner) ...[
                        const SizedBox(height: 16),
                        _DevStatusSimulator(
                          value: _devSimulatedStatus,
                          onChanged: (status) {
                            setState(() => _devSimulatedStatus = status);
                          },
                        ),
                      ],

                      const SizedBox(height: 8),
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => const RegisterScreen(),
                                      ),
                                    );
                                  },
                            child: const Text('Register (Staff/Driver)'),
                          ),
                          TextButton(
                            onPressed: _isLoading
                                ? null
                                : () {
                                    ScaffoldMessenger.of(context)
                                        .showSnackBar(
                                      const SnackBar(
                                        content: Text(
                                          'Password reset is not available '
                                          'yet.',
                                        ),
                                      ),
                                    );
                                  },
                            child: const Text('Forgot password?'),
                          ),
                        ],
                      ),
                      const SizedBox(height: 8),

                      PrimaryButton(
                        label: 'LOGIN',
                        isLoading: _isLoading,
                        onPressed: _handleLogin,
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

/// DEV-ONLY widget — nagpapa-simulate ng account status habang wala
/// pang backend. Alisin na ito kapag naka-Firebase/Supabase Auth na.
class _DevStatusSimulator extends StatelessWidget {
  const _DevStatusSimulator({required this.value, required this.onChanged});

  final AccountStatus value;
  final ValueChanged<AccountStatus> onChanged;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 4),
      decoration: BoxDecoration(
        border: Border.all(color: AppColors.border),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Row(
        children: [
          const Icon(Icons.science_outlined,
              size: 18, color: AppColors.textSecondary),
          const SizedBox(width: 8),
          const Expanded(
            child: Text(
              'DEV: simulate account status',
              style: TextStyle(fontSize: 12, color: AppColors.textSecondary),
            ),
          ),
          DropdownButton<AccountStatus>(
            value: value,
            underline: const SizedBox.shrink(),
            items: AccountStatus.values
                .map((s) => DropdownMenuItem(value: s, child: Text(s.label)))
                .toList(),
            onChanged: (s) {
              if (s != null) onChanged(s);
            },
          ),
        ],
      ),
    );
  }
}

import 'package:flutter/material.dart';
import '../../models/account_status.dart';
import '../../models/user_role.dart';
import '../../services/auth_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/auth_brand_mark.dart';
import '../../widgets/auth_card.dart';
import '../../widgets/primary_button.dart';
import '../../widgets/social_login_row.dart';
import 'account_status_screen.dart';

/// Staff/Driver self-registration.
///
/// There is deliberately NO Owner option here — there is exactly one
/// pre-seeded Owner account, and it never goes through registration.
/// Staff vs. Driver IS shown here (unlike on Login) because it's a
/// legitimate thing the applicant states about themselves — which job
/// they're applying for — not a claim about system-level access.
///
/// Shares its overall shape with LoginScreen on purpose (back button +
/// [AuthBrandMark] on the plain page background, then an [AuthCard]
/// holding the form) rather than the old boxed/colored hero banner —
/// so Login and Register read as two states of the same screen
/// instead of two differently-designed pages.
///
/// NOTE: Front-end only — no backend yet. Submitting immediately shows
/// the "Pending" status screen (mock); real persistence to
/// Supabase/Firebase happens in the backend phase.
class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _formKey = GlobalKey<FormState>();
  final _firstNameController = TextEditingController();
  final _middleNameController = TextEditingController();
  final _lastNameController = TextEditingController();
  final _usernameController = TextEditingController();
  final _contactController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();

  String _selectedRoleString = 'Staff';
  String? _selectedSuffix;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;
  String? _registerError;

  @override
  void dispose() {
    _firstNameController.dispose();
    _middleNameController.dispose();
    _lastNameController.dispose();
    _usernameController.dispose();
    _contactController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  String? _required(String? value, String label) {
    if (value == null || value.trim().isEmpty) {
      return '$label is required';
    }
    return null;
  }

  String? _validateConfirmPassword(String? value) {
    if (value == null || value.isEmpty) {
      return 'Please confirm your password';
    }
    if (value != _passwordController.text) {
      return 'Passwords do not match';
    }
    return null;
  }

  Future<void> _handleRegister() async {
    FocusScope.of(context).unfocus();
    setState(() => _registerError = null);
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    final fullName = [
      _firstNameController.text.trim(),
      if (_middleNameController.text.trim().isNotEmpty)
        _middleNameController.text.trim(),
      _lastNameController.text.trim(),
      ?_selectedSuffix,
    ].join(' ');

    // Registration is always UserRole.staff — there is exactly one
    // pre-seeded Owner account and it never goes through this form
    // (see the class doc comment above). "Driver" vs. "Branch Cook"
    // is stored as `position`, matching how RoleRouter and the old
    // mock_accounts.dart already distinguished them.
    final error = await AuthService.register(
      username: _usernameController.text.trim(),
      password: _passwordController.text,
      fullName: fullName,
      contactNumber: _contactController.text.trim(),
      role: UserRole.staff,
      position: _selectedRoleString == 'Driver' ? 'Driver' : 'Branch Cook',
    );

    if (!mounted) return;

    if (error != null) {
      setState(() {
        _isSubmitting = false;
        _registerError = error;
      });
      return;
    }

    setState(() => _isSubmitting = false);

    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) =>
            const AccountStatusScreen(status: AccountStatus.pending),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Center(
          child: SingleChildScrollView(
            padding: const EdgeInsets.fromLTRB(24, 4, 24, 28),
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 420),
              child: Form(
                key: _formKey,
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.stretch,
                  children: [
                    Align(
                      alignment: Alignment.centerLeft,
                      child: IconButton(
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            size: 20),
                        color: AppColors.textPrimary,
                        onPressed: () => Navigator.of(context).maybePop(),
                      ),
                    ),
                    const SizedBox(height: 4),
                    const Center(
                      child: AuthBrandMark(icon: Icons.person_add_alt_1_rounded),
                    ),
                    const SizedBox(height: 20),
                    const Text(
                      'Create your account',
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
                      'Simplify your workday — an Owner reviews every '
                      'application before it goes live.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                        fontSize: 14.5,
                        color: AppColors.textSecondary,
                        height: 1.4,
                      ),
                    ),
                    const SizedBox(height: 28),

                    // Elevated form card — matches AuthCard on
                    // LoginScreen, so both screens read as one
                    // consistent surface.
                    AuthCard(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.stretch,
                        children: [
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'APPLYING AS',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          // In-app registration is for Staff roles only. Role is determined 
                          // by Owner later. For now, this is just a role suggestion.
                          const SizedBox(height: 12),
                          SegmentedButton<String>(
                            segments: const [
                              ButtonSegment(
                                value: 'Staff',
                                label: Text('STAFF'),
                                icon: Icon(Icons.badge_outlined, size: 18),
                              ),
                              ButtonSegment(
                                value: 'Driver',
                                label: Text('DRIVER'),
                                icon: Icon(Icons.local_shipping_outlined, size: 18),
                              ),
                            ],
                            selected: {_selectedRoleString},
                            onSelectionChanged: (value) {
                              setState(() => _selectedRoleString = value.first);
                            },
                            style: SegmentedButton.styleFrom(
                              selectedBackgroundColor: AppColors.accent,
                              selectedForegroundColor: Colors.white,
                              backgroundColor: Colors.white,
                              foregroundColor: AppColors.textPrimary,
                              side: const BorderSide(color: AppColors.border),
                              textStyle: const TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w700,
                                letterSpacing: 0.5,
                              ),
                            ),
                          ),
                          const SizedBox(height: 24),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'FULL NAME',
                              style: TextStyle(
                                fontSize: 11,
                                fontWeight: FontWeight.w800,
                                letterSpacing: 1.0,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 12),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _firstNameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'FIRST NAME',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.person_outline, size: 20),
                                  ),
                                  validator: (v) => _required(v, 'First name'),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                child: TextFormField(
                                  controller: _lastNameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'LAST NAME',
                                    isDense: true,
                                  ),
                                  validator: (v) => _required(v, 'Last name'),
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                flex: 2,
                                child: TextFormField(
                                  controller: _middleNameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'MIDDLE NAME (OPTIONAL)',
                                    isDense: true,
                                    prefixIcon: Icon(Icons.person_outline, size: 20),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _selectedSuffix,
                                  decoration: const InputDecoration(
                                    labelText: 'SUFFIX',
                                    isDense: true,
                                  ),
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                        value: null, child: Text('—')),
                                    DropdownMenuItem(
                                        value: 'Jr.', child: Text('JR.')),
                                    DropdownMenuItem(
                                        value: 'Sr.', child: Text('SR.')),
                                    DropdownMenuItem(
                                        value: 'II', child: Text('II')),
                                    DropdownMenuItem(
                                        value: 'III', child: Text('III')),
                                    DropdownMenuItem(
                                        value: 'IV', child: Text('IV')),
                                    DropdownMenuItem(
                                        value: 'V', child: Text('V')),
                                  ],
                                  onChanged: (value) {
                                    setState(() => _selectedSuffix = value);
                                  },
                                ),
                              ),
                            ],
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _usernameController,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'USERNAME',
                              isDense: true,
                              prefixIcon: Icon(Icons.alternate_email_rounded, size: 20),
                            ),
                            validator: (v) => _required(v, 'Username'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _contactController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'CONTACT NUMBER',
                              isDense: true,
                              prefixIcon: Icon(Icons.phone_outlined, size: 20),
                            ),
                            validator: (v) => _required(v, 'Contact number'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
                            decoration: InputDecoration(
                              labelText: 'PASSWORD',
                              isDense: true,
                              prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscurePassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscurePassword = !_obscurePassword,
                                ),
                              ),
                            ),
                            validator: (v) => _required(v, 'Password'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleRegister(),
                            decoration: InputDecoration(
                              labelText: 'CONFIRM PASSWORD',
                              isDense: true,
                              prefixIcon: const Icon(Icons.lock_outline, size: 20),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                  size: 20,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                              ),
                            ),
                            validator: _validateConfirmPassword,
                          ),
                          if (_registerError != null) ...[
                            const SizedBox(height: 12),
                            Text(
                              _registerError!,
                              style: const TextStyle(
                                color: AppColors.error,
                                fontSize: 12.5,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ],
                          const SizedBox(height: 28),
                          PrimaryButton(
                            label: 'SIGN UP',
                            isLoading: _isSubmitting,
                            onPressed: _handleRegister,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
                    Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Text(
                          'Already have an account? ',
                          style: TextStyle(
                            color: AppColors.textSecondary,
                            fontSize: 13.5,
                          ),
                        ),
                        GestureDetector(
                          onTap: _isSubmitting
                              ? null
                              : () => Navigator.of(context).maybePop(),
                          child: const Text(
                            'Login',
                            style: TextStyle(
                              color: AppColors.accent,
                              fontWeight: FontWeight.w700,
                              fontSize: 13.5,
                            ),
                          ),
                        ),
                      ],
                    ),
                    const SizedBox(height: 18),
                    const _OrDivider(),
                    const SizedBox(height: 18),
                    const SocialLoginRow(),
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
            'OR CONTINUE WITH',
            style: TextStyle(
              color: AppColors.textSecondary,
              fontSize: 11,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.0,
            ),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

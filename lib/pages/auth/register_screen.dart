import 'package:flutter/material.dart';
import '../../models/account_status.dart';
import '../../models/user_role.dart';
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

  UserRole _selectedRole = UserRole.staff;
  String? _selectedSuffix;
  bool _obscurePassword = true;
  bool _obscureConfirmPassword = true;
  bool _isSubmitting = false;

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
    if (!_formKey.currentState!.validate()) return;

    setState(() => _isSubmitting = true);

    // Mock only — real save to Supabase/Firebase (status: pending)
    // happens in the backend phase.
    await Future.delayed(const Duration(milliseconds: 800));

    if (!mounted) return;
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
                    const SizedBox(height: 12),
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
                              'Applying as',
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
                              backgroundColor:
                                  WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                        ? AppColors.accent
                                        : AppColors.background,
                              ),
                              foregroundColor:
                                  WidgetStateProperty.resolveWith(
                                (states) =>
                                    states.contains(WidgetState.selected)
                                        ? Colors.white
                                        : AppColors.textPrimary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 22),
                          const Align(
                            alignment: Alignment.centerLeft,
                            child: Text(
                              'Full Name',
                              style: TextStyle(
                                fontSize: 13,
                                fontWeight: FontWeight.w600,
                                color: AppColors.textSecondary,
                              ),
                            ),
                          ),
                          const SizedBox(height: 8),
                          Row(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Expanded(
                                child: TextFormField(
                                  controller: _firstNameController,
                                  textInputAction: TextInputAction.next,
                                  decoration: const InputDecoration(
                                    labelText: 'First Name',
                                    prefixIcon: Icon(Icons.person_outline),
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
                                    labelText: 'Last Name',
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
                                    labelText: 'Middle Name (optional)',
                                    prefixIcon: Icon(Icons.person_outline),
                                  ),
                                ),
                              ),
                              const SizedBox(width: 12),
                              Expanded(
                                flex: 1,
                                child: DropdownButtonFormField<String?>(
                                  initialValue: _selectedSuffix,
                                  decoration: const InputDecoration(
                                    labelText: 'Suffix',
                                  ),
                                  isExpanded: true,
                                  items: const [
                                    DropdownMenuItem(
                                        value: null, child: Text('—')),
                                    DropdownMenuItem(
                                        value: 'Jr.', child: Text('Jr.')),
                                    DropdownMenuItem(
                                        value: 'Sr.', child: Text('Sr.')),
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
                              labelText: 'Username',
                              prefixIcon: Icon(Icons.alternate_email_rounded),
                            ),
                            validator: (v) => _required(v, 'Username'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _contactController,
                            keyboardType: TextInputType.phone,
                            textInputAction: TextInputAction.next,
                            decoration: const InputDecoration(
                              labelText: 'Contact Number',
                              prefixIcon: Icon(Icons.phone_outlined),
                            ),
                            validator: (v) => _required(v, 'Contact number'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _passwordController,
                            obscureText: _obscurePassword,
                            textInputAction: TextInputAction.next,
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
                            validator: (v) => _required(v, 'Password'),
                          ),
                          const SizedBox(height: 16),
                          TextFormField(
                            controller: _confirmPasswordController,
                            obscureText: _obscureConfirmPassword,
                            textInputAction: TextInputAction.done,
                            onFieldSubmitted: (_) => _handleRegister(),
                            decoration: InputDecoration(
                              labelText: 'Confirm Password',
                              prefixIcon: const Icon(Icons.lock_outline),
                              suffixIcon: IconButton(
                                icon: Icon(
                                  _obscureConfirmPassword
                                      ? Icons.visibility_off_outlined
                                      : Icons.visibility_outlined,
                                ),
                                onPressed: () => setState(
                                  () => _obscureConfirmPassword =
                                      !_obscureConfirmPassword,
                                ),
                              ),
                            ),
                            validator: _validateConfirmPassword,
                          ),
                          const SizedBox(height: 22),
                          PrimaryButton(
                            label: 'Sign up',
                            isLoading: _isSubmitting,
                            onPressed: _handleRegister,
                          ),
                        ],
                      ),
                    ),

                    const SizedBox(height: 28),
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
            'Or Continue With',
            style: TextStyle(color: AppColors.textSecondary, fontSize: 12.5),
          ),
        ),
        Expanded(child: Divider(color: AppColors.border)),
      ],
    );
  }
}

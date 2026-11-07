import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class RegisterScreen extends StatefulWidget {
  const RegisterScreen({super.key});

  @override
  State<RegisterScreen> createState() => _RegisterScreenState();
}

class _RegisterScreenState extends State<RegisterScreen> {
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _register() async {
    if (_phoneController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      showAppSnack(context, 'Enter your phone number and a password', error: true);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      showAppSnack(context, 'Passwords do not match', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.register(
        _phoneController.text,
        _passwordController.text,
        'CUSTOMER',
        email: _emailController.text,
      );
      if (!mounted) return;
      if (result.containsKey('phone_number') && result['phone_number'] is! List) {
        showAppSnack(context, 'Account created! Sign in to place your first order.', success: true);
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      final String error = result['phone_number'] is List
          ? result['phone_number'][0].toString()
          : (result['error']?.toString() ?? 'Registration failed. Please try again.');
      showAppSnack(context, error, error: true);
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Create your account',
      subtitle: 'Order a refill in seconds. We match you with the nearest trusted dealer.',
      footer: Wrap(
        alignment: WrapAlignment.center,
        crossAxisAlignment: WrapCrossAlignment.center,
        children: [
          const Text('Already have an account?', style: TextStyle(color: AppColors.inkSoft)),
          TextButton(
            onPressed: () => Navigator.pushReplacementNamed(context, '/login'),
            child: const Text('Sign in'),
          ),
        ],
      ),
      child: AutofillGroup(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            AppTextField(
              controller: _phoneController,
              label: 'Phone number',
              hint: '07XX XXX XXX',
              icon: Icons.phone_iphone_rounded,
              keyboardType: TextInputType.phone,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.telephoneNumber],
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _emailController,
              label: 'Email (optional)',
              icon: Icons.alternate_email_rounded,
              helper: 'Used only to reset your password',
              keyboardType: TextInputType.emailAddress,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.email],
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              helper: 'At least 8 characters, not only numbers',
              isPassword: true,
              textInputAction: TextInputAction.next,
              autofillHints: const [AutofillHints.newPassword],
            ),
            const SizedBox(height: 16),
            AppTextField(
              controller: _confirmPasswordController,
              label: 'Confirm password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.done,
              onSubmitted: (_) => _register(),
            ),
            const SizedBox(height: 24),
            GradientButton(label: 'Create account', loading: _isLoading, onPressed: _register),
            const SizedBox(height: 20),
            AppCard(
              onTap: () => Navigator.pushNamed(context, '/dealer_apply'),
              color: AppColors.field,
              child: const Row(
                children: [
                  IconBadge(icon: Icons.storefront_rounded),
                  SizedBox(width: 14),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text('Own a gas shop?', style: TextStyle(fontWeight: FontWeight.w800)),
                        SizedBox(height: 2),
                        Text('Apply to become a dealer and get orders from customers near you.',
                            style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppColors.inkSoft),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

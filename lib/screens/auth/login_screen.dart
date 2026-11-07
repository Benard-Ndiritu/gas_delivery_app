import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _phoneController = TextEditingController();
  final _passwordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _phoneController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  Future<void> _login() async {
    if (_phoneController.text.trim().isEmpty || _passwordController.text.isEmpty) {
      showAppSnack(context, 'Enter your phone number and password', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.login(_phoneController.text, _passwordController.text);
      if (!mounted) return;
      if (result.containsKey('access')) {
        // ApiService.login has already stored the session.
        if (result['role'] == 'CUSTOMER') {
          Navigator.pushReplacementNamed(context, '/customer_home');
          return;
        }
        if (result['role'] == 'DEALER') {
          Navigator.pushReplacementNamed(context, '/dealer_home');
          return;
        }
        // Admins use the web dashboard, not the mobile app.
        await ApiService.logout();
        if (!mounted) return;
        showAppSnack(context, 'Admin accounts should use the admin dashboard.', error: true);
      } else {
        showAppSnack(context, result['error']?.toString() ?? 'Invalid credentials', error: true);
      }
    } catch (e) {
      if (mounted) showAppSnack(context, e.toString(), error: true);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      title: 'Welcome back',
      subtitle: 'Sign in to order cooking gas to your door, or to manage your shop.',
      footer: Center(
        child: TextButton.icon(
          onPressed: () => Navigator.pushNamed(context, '/dealer_apply'),
          style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
          icon: const Icon(Icons.storefront_rounded, size: 20),
          label: const Text('Sell gas? Become a dealer'),
        ),
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
              controller: _passwordController,
              label: 'Password',
              icon: Icons.lock_outline_rounded,
              isPassword: true,
              textInputAction: TextInputAction.done,
              autofillHints: const [AutofillHints.password],
              onSubmitted: (_) => _login(),
            ),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: () => Navigator.pushNamed(context, '/forgot_password'),
                child: const Text('Forgot password?'),
              ),
            ),
            const SizedBox(height: 8),
            GradientButton(
              label: 'Sign in',
              icon: Icons.arrow_forward_rounded,
              loading: _isLoading,
              onPressed: _login,
            ),
            const SizedBox(height: 28),
            const OrDivider('New to Gas Delivery?'),
            const SizedBox(height: 20),
            OutlinedButton(
              onPressed: () => Navigator.pushNamed(context, '/register'),
              child: const Text('Create an account'),
            ),
          ],
        ),
      ),
    );
  }
}

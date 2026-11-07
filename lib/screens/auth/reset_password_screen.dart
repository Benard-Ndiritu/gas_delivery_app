import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/common.dart';

class ResetPasswordScreen extends StatefulWidget {
  const ResetPasswordScreen({super.key});

  @override
  State<ResetPasswordScreen> createState() => _ResetPasswordScreenState();
}

class _ResetPasswordScreenState extends State<ResetPasswordScreen> {
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _resetPassword() async {
    final args = ModalRoute.of(context)!.settings.arguments as Map<String, String>;

    if (_passwordController.text.isEmpty || _confirmPasswordController.text.isEmpty) {
      showAppSnack(context, 'Please fill in both fields', error: true);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      showAppSnack(context, 'Passwords do not match', error: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    final result = await ApiService.resetPassword(args['email']!, args['otp']!, _passwordController.text);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result['success'] == true) {
      showAppSnack(context, 'Password updated. Sign in with your new password.', success: true);
      Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
    } else {
      showAppSnack(context, result['message']?.toString() ?? 'Something went wrong', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      heroIcon: Icons.key_rounded,
      title: 'Set a new password',
      subtitle: 'Choose something you haven\'t used before. At least 8 characters, not only numbers.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _passwordController,
            label: 'New password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            textInputAction: TextInputAction.next,
            autofillHints: const [AutofillHints.newPassword],
          ),
          const SizedBox(height: 16),
          AppTextField(
            controller: _confirmPasswordController,
            label: 'Confirm new password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _resetPassword(),
          ),
          const SizedBox(height: 24),
          GradientButton(label: 'Update password', loading: _isLoading, onPressed: _resetPassword),
        ],
      ),
    );
  }
}

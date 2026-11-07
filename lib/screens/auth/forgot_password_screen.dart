import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../widgets/common.dart';

class ForgotPasswordScreen extends StatefulWidget {
  const ForgotPasswordScreen({super.key});

  @override
  State<ForgotPasswordScreen> createState() => _ForgotPasswordScreenState();
}

class _ForgotPasswordScreenState extends State<ForgotPasswordScreen> {
  final _emailController = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _emailController.dispose();
    super.dispose();
  }

  Future<void> _requestOTP() async {
    final email = _emailController.text.trim();
    if (email.isEmpty) {
      showAppSnack(context, 'Please enter your email', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    final result = await ApiService.requestPasswordResetOTP(email);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result['success'] == true) {
      Navigator.pushNamed(context, '/verify_otp', arguments: email);
    } else {
      showAppSnack(context, result['message']?.toString() ?? 'Something went wrong', error: true);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      heroIcon: Icons.lock_reset_rounded,
      title: 'Forgot your password?',
      subtitle: "Enter the email on your account and we'll send you a 6-digit code.",
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          AppTextField(
            controller: _emailController,
            label: 'Email address',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.done,
            autofillHints: const [AutofillHints.email],
            onSubmitted: (_) => _requestOTP(),
          ),
          const SizedBox(height: 24),
          GradientButton(label: 'Send code', icon: Icons.send_rounded, loading: _isLoading, onPressed: _requestOTP),
        ],
      ),
    );
  }
}

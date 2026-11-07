import 'package:flutter/material.dart';
import 'package:flutter/services.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class VerifyOTPScreen extends StatefulWidget {
  const VerifyOTPScreen({super.key});

  @override
  State<VerifyOTPScreen> createState() => _VerifyOTPScreenState();
}

class _VerifyOTPScreenState extends State<VerifyOTPScreen> {
  final _otpController = TextEditingController();
  bool _isLoading = false;
  bool _resending = false;

  String get _email => ModalRoute.of(context)!.settings.arguments as String;

  @override
  void dispose() {
    _otpController.dispose();
    super.dispose();
  }

  Future<void> _verifyOTP() async {
    final otp = _otpController.text.trim();
    if (otp.length != 6) {
      showAppSnack(context, 'Enter the 6-digit code from your email', error: true);
      return;
    }
    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    final result = await ApiService.verifyPasswordResetOTP(_email, otp);
    if (!mounted) return;
    setState(() => _isLoading = false);
    if (result['success'] == true) {
      Navigator.pushNamed(context, '/reset_password', arguments: {'email': _email, 'otp': otp});
    } else {
      showAppSnack(context, result['message']?.toString() ?? 'Invalid code', error: true);
    }
  }

  Future<void> _resend() async {
    setState(() => _resending = true);
    final result = await ApiService.requestPasswordResetOTP(_email);
    if (!mounted) return;
    setState(() => _resending = false);
    showAppSnack(
      context,
      result['success'] == true ? 'A new code is on its way' : (result['message']?.toString() ?? 'Could not resend'),
      error: result['success'] != true,
      success: result['success'] == true,
    );
  }

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      heroIcon: Icons.mark_email_read_rounded,
      title: 'Check your email',
      subtitle: 'We sent a 6-digit code to $_email. It expires in 10 minutes.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          TextField(
            controller: _otpController,
            keyboardType: TextInputType.number,
            textAlign: TextAlign.center,
            maxLength: 6,
            autofocus: true,
            autofillHints: const [AutofillHints.oneTimeCode],
            inputFormatters: [FilteringTextInputFormatter.digitsOnly],
            onChanged: (value) {
              if (value.length == 6 && !_isLoading) _verifyOTP();
            },
            style: const TextStyle(fontSize: 30, fontWeight: FontWeight.w800, letterSpacing: 14),
            decoration: const InputDecoration(
              counterText: '',
              hintText: '••••••',
              contentPadding: EdgeInsets.symmetric(vertical: 22),
            ),
          ),
          const SizedBox(height: 24),
          GradientButton(label: 'Verify code', loading: _isLoading, onPressed: _verifyOTP),
          const SizedBox(height: 12),
          Wrap(
            alignment: WrapAlignment.center,
            crossAxisAlignment: WrapCrossAlignment.center,
            children: [
              const Text("Didn't get it?", style: TextStyle(color: AppColors.inkSoft)),
              TextButton(
                onPressed: _resending ? null : _resend,
                child: Text(_resending ? 'Sending…' : 'Resend code'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

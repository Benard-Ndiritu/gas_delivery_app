import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

enum _Stage { idle, sending, waiting, paid, failed }

class PaymentScreen extends StatefulWidget {
  final int orderId;
  final String amount;

  const PaymentScreen({super.key, required this.orderId, required this.amount});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  final _phoneController = TextEditingController();
  _Stage _stage = _Stage.idle;
  String _message = '';
  String? _receipt;
  Timer? _poller;
  int _polls = 0;

  static const _pollEvery = Duration(seconds: 5);
  static const _maxPolls = 24; // about two minutes

  @override
  void dispose() {
    _poller?.cancel();
    _phoneController.dispose();
    super.dispose();
  }

  Future<void> _sendPrompt() async {
    FocusScope.of(context).unfocus();
    setState(() {
      _stage = _Stage.sending;
      _message = '';
    });
    final result = await ApiService.initiateMpesaPayment(widget.orderId, phoneNumber: _phoneController.text);
    if (!mounted) return;
    if (result.containsKey('message') && result['error'] == null) {
      setState(() => _stage = _Stage.waiting);
      _startPolling();
    } else {
      setState(() {
        _stage = _Stage.failed;
        _message = result['error']?.toString() ?? 'Could not send the payment request';
      });
    }
  }

  void _startPolling() {
    _poller?.cancel();
    _polls = 0;
    _poller = Timer.periodic(_pollEvery, (_) => _checkStatus(fromTimer: true));
  }

  Future<void> _checkStatus({bool fromTimer = false}) async {
    _polls++;
    final result = await ApiService.getPaymentStatus(widget.orderId);
    if (!mounted) return;
    final status = result['status'];
    if (status == 'PAID') {
      _poller?.cancel();
      setState(() {
        _stage = _Stage.paid;
        _receipt = result['mpesa_receipt']?.toString();
      });
    } else if (status == 'FAILED') {
      _poller?.cancel();
      setState(() {
        _stage = _Stage.failed;
        final desc = result['result_desc']?.toString() ?? '';
        _message = desc.isNotEmpty ? desc : 'The payment was not completed.';
      });
    } else if (fromTimer && _polls >= _maxPolls) {
      _poller?.cancel();
      setState(() {
        _stage = _Stage.idle;
        _message = "We haven't received confirmation yet. If you paid, tap \"I've paid, check now\".";
      });
    } else if (!fromTimer) {
      showAppSnack(context, 'Still waiting for M-Pesa to confirm…');
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Payment')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          _AmountCard(amount: widget.amount, orderId: widget.orderId),
          const SizedBox(height: 20),
          AnimatedSwitcher(
            duration: const Duration(milliseconds: 300),
            child: KeyedSubtree(key: ValueKey(_stage), child: _buildStageContent()),
          ),
        ],
      ),
      bottomNavigationBar: _stage == _Stage.paid || _stage == _Stage.waiting
          ? null
          : SafeArea(
              child: Padding(
                padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
                child: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    GradientButton(
                      label: _stage == _Stage.failed ? 'Try again' : 'Send M-Pesa prompt',
                      icon: Icons.phone_android_rounded,
                      gradient: AppColors.mpesaGradient,
                      loading: _stage == _Stage.sending,
                      onPressed: _sendPrompt,
                    ),
                    TextButton(
                      onPressed: () {
                        showAppSnack(context, 'No problem. Pay the dealer in cash when your gas arrives.');
                        Navigator.pop(context);
                      },
                      style: TextButton.styleFrom(foregroundColor: AppColors.inkSoft),
                      child: const Text("I'll pay cash on delivery"),
                    ),
                  ],
                ),
              ),
            ),
    );
  }

  Widget _buildStageContent() {
    switch (_stage) {
      case _Stage.waiting:
        return _StatusPanel(
          color: AppColors.amber,
          leading: const SizedBox(width: 40, height: 40, child: CircularProgressIndicator(strokeWidth: 3)),
          title: 'Check your phone',
          message: 'Enter your M-Pesa PIN to pay ${formatKsh(widget.amount)}. We confirm automatically.',
          action: TextButton(onPressed: () => _checkStatus(), child: const Text("I've paid, check now")),
        );
      case _Stage.paid:
        return _StatusPanel(
          color: AppColors.success,
          leading: const Icon(Icons.check_circle_rounded, color: AppColors.success, size: 56),
          title: 'Payment received',
          message: _receipt == null ? 'Thank you! Your dealer has been notified.' : 'M-Pesa receipt: $_receipt',
          action: FilledButton(
            onPressed: () => Navigator.pop(context),
            style: FilledButton.styleFrom(backgroundColor: AppColors.success, minimumSize: const Size.fromHeight(50)),
            child: const Text('Done'),
          ),
        );
      case _Stage.idle:
      case _Stage.sending:
      case _Stage.failed:
        return Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            if (_stage == _Stage.failed)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _StatusPanel(
                  color: AppColors.danger,
                  leading: const Icon(Icons.error_rounded, color: AppColors.danger, size: 40),
                  title: 'Payment not completed',
                  message: _message,
                ),
              )
            else if (_message.isNotEmpty)
              Padding(
                padding: const EdgeInsets.only(bottom: 16),
                child: _StatusPanel(
                  color: AppColors.amber,
                  leading: const Icon(Icons.hourglass_bottom_rounded, color: AppColors.amber, size: 40),
                  title: 'Waiting for confirmation',
                  message: _message,
                  action: TextButton(onPressed: () => _checkStatus(), child: const Text("I've paid, check now")),
                ),
              ),
            AppCard(
              padding: const EdgeInsets.all(18),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          gradient: AppColors.mpesaGradient,
                          borderRadius: BorderRadius.circular(10),
                        ),
                        child: const Text(
                          'M-PESA',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w900, letterSpacing: 1),
                        ),
                      ),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text('Pay with M-Pesa', style: TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ),
                    ],
                  ),
                  const SizedBox(height: 18),
                  AppTextField(
                    controller: _phoneController,
                    label: 'M-Pesa number (optional)',
                    hint: 'Leave empty to use your account number',
                    icon: Icons.phone_iphone_rounded,
                    keyboardType: TextInputType.phone,
                  ),
                  const SizedBox(height: 18),
                  const _HowStep(icon: Icons.touch_app_rounded, text: 'Tap "Send M-Pesa prompt" below'),
                  const _HowStep(icon: Icons.dialpad_rounded, text: 'Enter your M-Pesa PIN on your phone'),
                  const _HowStep(icon: Icons.verified_rounded, text: 'We confirm your payment automatically'),
                ],
              ),
            ),
          ],
        );
    }
  }
}

class _AmountCard extends StatelessWidget {
  const _AmountCard({required this.amount, required this.orderId});

  final String amount;
  final int orderId;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        gradient: AppColors.night,
        borderRadius: BorderRadius.circular(26),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        clipBehavior: Clip.none,
        children: [
          Positioned(
            right: -30,
            top: -30,
            child: Icon(Icons.local_fire_department_rounded, size: 140, color: AppColors.primary.withValues(alpha: 0.25)),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('Amount to pay', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
              const SizedBox(height: 6),
              Text(
                formatKsh(amount),
                style: const TextStyle(color: Colors.white, fontSize: 38, fontWeight: FontWeight.w800, letterSpacing: -1),
              ),
              const SizedBox(height: 12),
              Pill('Order #$orderId', color: Colors.white),
            ],
          ),
        ],
      ),
    );
  }
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({required this.color, required this.leading, required this.title, required this.message, this.action});

  final Color color;
  final Widget leading;
  final String title;
  final String message;
  final Widget? action;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.3)),
      ),
      child: Column(
        children: [
          leading,
          const SizedBox(height: 14),
          Text(title, textAlign: TextAlign.center, style: const TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
          const SizedBox(height: 6),
          Text(message, textAlign: TextAlign.center, style: const TextStyle(color: AppColors.inkSoft)),
          if (action != null) ...[const SizedBox(height: 14), action!],
        ],
      ),
    );
  }
}

class _HowStep extends StatelessWidget {
  const _HowStep({required this.icon, required this.text});

  final IconData icon;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        children: [
          Icon(icon, size: 18, color: AppColors.mpesa),
          const SizedBox(width: 10),
          Expanded(child: Text(text, style: const TextStyle(fontSize: 13))),
        ],
      ),
    );
  }
}

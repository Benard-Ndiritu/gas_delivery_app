import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class DealerApplyScreen extends StatefulWidget {
  const DealerApplyScreen({super.key});

  @override
  State<DealerApplyScreen> createState() => _DealerApplyScreenState();
}

class _DealerApplyScreenState extends State<DealerApplyScreen> {
  final _nameController = TextEditingController();
  final _shopNameController = TextEditingController();
  final _phoneController = TextEditingController();
  final _emailController = TextEditingController();
  final _passwordController = TextEditingController();
  final _confirmPasswordController = TextEditingController();
  int _deliveryRadius = 5;
  bool _isLoading = false;

  @override
  void dispose() {
    _nameController.dispose();
    _shopNameController.dispose();
    _phoneController.dispose();
    _emailController.dispose();
    _passwordController.dispose();
    _confirmPasswordController.dispose();
    super.dispose();
  }

  Future<void> _applyAsDealer() async {
    if (_phoneController.text.trim().isEmpty ||
        _passwordController.text.isEmpty ||
        _nameController.text.trim().isEmpty ||
        _shopNameController.text.trim().isEmpty) {
      showAppSnack(context, 'Please fill in your name, shop name, phone and password', error: true);
      return;
    }
    if (_passwordController.text != _confirmPasswordController.text) {
      showAppSnack(context, 'Passwords do not match', error: true);
      return;
    }

    FocusScope.of(context).unfocus();
    setState(() => _isLoading = true);
    try {
      // The shop's location is what customers are matched against.
      final position = await LocationService.currentPosition();
      final result = await ApiService.applyAsDealer(
        phoneNumber: _phoneController.text,
        password: _passwordController.text,
        name: _nameController.text,
        shopName: _shopNameController.text,
        deliveryRadius: _deliveryRadius,
        email: _emailController.text,
        latitude: position.latitude,
        longitude: position.longitude,
      );
      if (!mounted) return;

      if (result['success'] == true) {
        await showDialog<void>(
          context: context,
          builder: (context) => AlertDialog(
            icon: const IconBadge(icon: Icons.verified_rounded, color: AppColors.success, size: 56),
            title: const Text('Application received', style: TextStyle(fontWeight: FontWeight.w800)),
            content: const Text(
              "We'll review your shop and approve it shortly. You can sign in as soon as you're approved.",
              textAlign: TextAlign.center,
              style: TextStyle(color: AppColors.inkSoft),
            ),
            actions: [
              FilledButton(
                onPressed: () => Navigator.pop(context),
                style: FilledButton.styleFrom(minimumSize: const Size.fromHeight(48)),
                child: const Text('Got it'),
              ),
            ],
          ),
        );
        if (!mounted) return;
        Navigator.pushReplacementNamed(context, '/login');
        return;
      }
      showAppSnack(context, result['message']?.toString() ?? 'Something went wrong', error: true);
    } catch (e) {
      if (mounted) showAppSnack(context, e is ApiException ? e.message : e.toString(), error: true);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Widget _label(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 12, top: 4),
        child: Text(
          text.toUpperCase(),
          style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w800, color: AppColors.inkSoft, letterSpacing: 1),
        ),
      );

  @override
  Widget build(BuildContext context) {
    return AuthScaffold(
      heroIcon: Icons.storefront_rounded,
      title: 'Become a dealer',
      subtitle: 'Get gas orders from customers near your shop. Free to join, approved within a day.',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          _label('About you'),
          AppTextField(
            controller: _nameController,
            label: 'Full name',
            icon: Icons.person_outline_rounded,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _phoneController,
            label: 'Phone number',
            hint: '07XX XXX XXX',
            icon: Icons.phone_iphone_rounded,
            keyboardType: TextInputType.phone,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _emailController,
            label: 'Email (optional)',
            icon: Icons.alternate_email_rounded,
            keyboardType: TextInputType.emailAddress,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 24),
          _label('Your shop'),
          AppTextField(
            controller: _shopNameController,
            label: 'Shop name',
            icon: Icons.storefront_outlined,
            textCapitalization: TextCapitalization.words,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 16),
          const Text('How far do you deliver?', style: TextStyle(fontWeight: FontWeight.w700)),
          const SizedBox(height: 10),
          SegmentedButton<int>(
            segments: const [
              ButtonSegment(value: 5, label: Text('5 km')),
              ButtonSegment(value: 7, label: Text('7 km')),
              ButtonSegment(value: 10, label: Text('10 km')),
            ],
            selected: {_deliveryRadius},
            showSelectedIcon: false,
            onSelectionChanged: (value) => setState(() => _deliveryRadius = value.first),
            style: SegmentedButton.styleFrom(
              selectedBackgroundColor: AppColors.ink,
              selectedForegroundColor: Colors.white,
              side: const BorderSide(color: AppColors.line),
              minimumSize: const Size(0, 48),
              textStyle: Theme.of(context).textTheme.labelLarge?.copyWith(fontWeight: FontWeight.w700),
            ),
          ),
          const SizedBox(height: 16),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.amber.withValues(alpha: 0.12),
              borderRadius: BorderRadius.circular(16),
            ),
            child: const Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Icon(Icons.my_location_rounded, color: AppColors.primaryDeep, size: 22),
                SizedBox(width: 12),
                Expanded(
                  child: Text(
                    'Submit this form from your shop. Your current location is saved as the shop location customers are matched to.',
                    style: TextStyle(fontSize: 13, color: AppColors.ink),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _label('Security'),
          AppTextField(
            controller: _passwordController,
            label: 'Password',
            icon: Icons.lock_outline_rounded,
            helper: 'At least 8 characters, not only numbers',
            isPassword: true,
            textInputAction: TextInputAction.next,
          ),
          const SizedBox(height: 14),
          AppTextField(
            controller: _confirmPasswordController,
            label: 'Confirm password',
            icon: Icons.lock_outline_rounded,
            isPassword: true,
            textInputAction: TextInputAction.done,
            onSubmitted: (_) => _applyAsDealer(),
          ),
          const SizedBox(height: 28),
          GradientButton(
            label: 'Submit application',
            icon: Icons.send_rounded,
            loading: _isLoading,
            onPressed: _applyAsDealer,
          ),
        ],
      ),
    );
  }
}

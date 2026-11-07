import 'package:flutter/material.dart';

import '../../config.dart';
import '../../services/api_service.dart';
import '../../services/launcher.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../widgets/common.dart';

class DealerProfileScreen extends StatefulWidget {
  /// When shown as a tab inside the dealer home, there is no back button.
  final bool embedded;

  const DealerProfileScreen({super.key, this.embedded = false});

  @override
  State<DealerProfileScreen> createState() => _DealerProfileScreenState();
}

class _DealerProfileScreenState extends State<DealerProfileScreen> {
  Map<String, dynamic>? _profile;
  bool _isLoading = true;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    _loadProfile();
  }

  Future<void> _loadProfile() async {
    final profile = await ApiService.getDealerProfile();
    if (!mounted) return;
    setState(() {
      _isLoading = false;
      if (profile['error'] != null) {
        _error = profile['error'].toString();
      } else {
        _profile = profile;
        _error = null;
      }
    });
  }

  Future<void> _update(Map<String, dynamic> changes, String successMessage) async {
    setState(() => _saving = true);
    final result = await ApiService.updateDealerProfile(changes);
    if (!mounted) return;
    setState(() => _saving = false);
    if (result['error'] != null) {
      showAppSnack(context, result['error'].toString(), error: true);
      return;
    }
    setState(() => _profile = result);
    showAppSnack(context, successMessage, success: true);
  }

  Future<void> _changeRadius() async {
    final current = _profile?['delivery_radius'] ?? 5;
    final selected = await showModalBottomSheet<int>(
      context: context,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text('Delivery radius', style: TextStyle(fontSize: 22, fontWeight: FontWeight.w800)),
              const SizedBox(height: 4),
              const Text('Customers within this distance of your shop can order from you.',
                  style: TextStyle(color: AppColors.inkSoft)),
              const SizedBox(height: 16),
              for (final km in const [5, 7, 10])
                Padding(
                  padding: const EdgeInsets.only(bottom: 10),
                  child: AppCard(
                    onTap: () => Navigator.pop(context, km),
                    color: km == current ? AppColors.primary.withValues(alpha: 0.06) : null,
                    child: Row(
                      children: [
                        Icon(km == current ? Icons.radio_button_checked_rounded : Icons.radio_button_off_rounded,
                            color: km == current ? AppColors.primary : AppColors.inkSoft),
                        const SizedBox(width: 12),
                        Text('$km km', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                      ],
                    ),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
    if (selected != null && selected != current) {
      await _update({'delivery_radius': selected}, 'Delivery radius set to $selected km');
    }
  }

  Future<void> _updateLocation() async {
    final ok = await confirmDialog(
      context,
      title: 'Use your current location?',
      message: 'Your shop location will be set to where you are standing now. Do this from inside your shop.',
      confirmLabel: 'Update location',
    );
    if (!ok) return;
    try {
      final position = await LocationService.currentPosition();
      await _update(
        {'latitude': position.latitude, 'longitude': position.longitude},
        'Shop location updated',
      );
    } catch (e) {
      if (mounted) showAppSnack(context, e is ApiException ? e.message : e.toString(), error: true);
    }
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(context, title: 'Log out?', message: 'You will stop seeing new orders until you sign in again.', confirmLabel: 'Log out');
    if (!ok) return;
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('My shop'),
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
              ? ErrorState(message: _error!, onRetry: _loadProfile)
              : _buildContent(),
    );
  }

  Widget _buildContent() {
    final p = _profile!;
    final approved = p['status'] == 'APPROVED';
    final lat = (p['latitude'] as num?)?.toDouble();
    final lon = (p['longitude'] as num?)?.toDouble();
    final hasLocation = lat != null && lon != null && !(lat == 0 && lon == 0);

    return ListView(
      padding: const EdgeInsets.fromLTRB(20, 4, 20, 32),
      children: [
        Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(gradient: AppColors.flame, borderRadius: BorderRadius.circular(26)),
          clipBehavior: Clip.antiAlias,
          child: Stack(
            clipBehavior: Clip.none,
            children: [
              Positioned(
                right: -30,
                bottom: -40,
                child: Icon(Icons.storefront_rounded, size: 140, color: Colors.white.withValues(alpha: 0.15)),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.25), borderRadius: BorderRadius.circular(18)),
                    child: const Icon(Icons.storefront_rounded, color: Colors.white, size: 30),
                  ),
                  const SizedBox(height: 16),
                  Text(
                    '${p['shop_name'] ?? 'My shop'}',
                    style: const TextStyle(color: Colors.white, fontSize: 24, fontWeight: FontWeight.w800, letterSpacing: -0.4),
                  ),
                  Text('${p['name'] ?? ''}', style: TextStyle(color: Colors.white.withValues(alpha: 0.85))),
                  const SizedBox(height: 14),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                    decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(30)),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Icon(approved ? Icons.verified_rounded : Icons.hourglass_top_rounded,
                            size: 16, color: approved ? AppColors.success : AppColors.amber),
                        const SizedBox(width: 6),
                        Text(
                          approved ? 'Verified dealer' : '${p['status']}',
                          style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 12, color: AppColors.ink),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            ],
          ),
        ),
        const SizedBox(height: 24),
        const SectionTitle('Shop details'),
        _InfoTile(icon: Icons.phone_rounded, label: 'Phone', value: '${p['phone_number'] ?? '—'}'),
        if (p['email'] != null) _InfoTile(icon: Icons.mail_rounded, label: 'Email', value: '${p['email']}'),
        _InfoTile(
          icon: Icons.radar_rounded,
          label: 'Delivery radius',
          value: '${p['delivery_radius'] ?? 5} km',
          actionLabel: 'Change',
          onAction: _saving ? null : _changeRadius,
        ),
        _InfoTile(
          icon: Icons.location_on_rounded,
          label: 'Shop location',
          value: hasLocation ? '${lat.toStringAsFixed(4)}, ${lon.toStringAsFixed(4)}' : 'Not set: customers can\'t find you',
          warning: !hasLocation,
          actionLabel: 'Update',
          onAction: _saving ? null : _updateLocation,
        ),
        if (hasLocation)
          Align(
            alignment: Alignment.centerLeft,
            child: TextButton.icon(
              onPressed: () => Launcher.directions(lat, lon),
              icon: const Icon(Icons.map_rounded, size: 18),
              label: const Text('View on map'),
            ),
          ),
        const SizedBox(height: 16),
        const SectionTitle('Help'),
        AppCard(
          onTap: () => Launcher.whatsapp(AppConfig.supportWhatsApp, text: 'Hi, I am a dealer and need help.'),
          child: const Row(
            children: [
              IconBadge(icon: Icons.chat_rounded, color: AppColors.mpesa),
              SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('Dealer support', style: TextStyle(fontWeight: FontWeight.w800)),
                    Text('Chat with us on WhatsApp', style: TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                  ],
                ),
              ),
              Icon(Icons.arrow_outward_rounded, color: AppColors.inkSoft, size: 20),
            ],
          ),
        ),
        const SizedBox(height: 28),
        OutlinedButton.icon(
          onPressed: _logout,
          style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger),
          icon: const Icon(Icons.logout_rounded),
          label: const Text('Log out'),
        ),
      ],
    );
  }
}

class _InfoTile extends StatelessWidget {
  const _InfoTile({
    required this.icon,
    required this.label,
    required this.value,
    this.actionLabel,
    this.onAction,
    this.warning = false,
  });

  final IconData icon;
  final String label;
  final String value;
  final String? actionLabel;
  final VoidCallback? onAction;
  final bool warning;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: const EdgeInsets.fromLTRB(16, 12, 8, 12),
        child: Row(
          children: [
            IconBadge(icon: icon, color: warning ? AppColors.danger : AppColors.primary, size: 40),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(label, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                  Text(
                    value,
                    style: TextStyle(fontWeight: FontWeight.w700, color: warning ? AppColors.danger : AppColors.ink),
                  ),
                ],
              ),
            ),
            if (actionLabel != null) TextButton(onPressed: onAction, child: Text(actionLabel!)),
          ],
        ),
      ),
    );
  }
}

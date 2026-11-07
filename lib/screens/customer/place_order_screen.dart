import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/location_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

class PlaceOrderScreen extends StatefulWidget {
  const PlaceOrderScreen({super.key});

  @override
  State<PlaceOrderScreen> createState() => _PlaceOrderScreenState();
}

class _PlaceOrderScreenState extends State<PlaceOrderScreen> {
  List<dynamic> _gasTypes = [];
  int? _selectedGasTypeId;
  String _orderType = 'refill';
  bool _isLoading = false;
  bool _isLoadingGas = true;
  String? _loadError;

  @override
  void initState() {
    super.initState();
    _loadGasTypes();
  }

  Future<void> _loadGasTypes() async {
    setState(() {
      _isLoadingGas = true;
      _loadError = null;
    });
    try {
      final types = await ApiService.getGasTypes();
      if (!mounted) return;
      setState(() {
        _gasTypes = types;
        _isLoadingGas = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _loadError = e.toString();
        _isLoadingGas = false;
      });
    }
  }

  Future<void> _placeOrder() async {
    if (_selectedGasTypeId == null) {
      showAppSnack(context, 'Choose the gas you need first', error: true);
      return;
    }

    setState(() => _isLoading = true);
    try {
      final position = await LocationService.currentPosition();
      final result = await ApiService.placeOrder(
        _selectedGasTypeId!,
        _orderType,
        position.latitude,
        position.longitude,
      );
      if (!mounted) return;
      if (result.containsKey('id')) {
        showAppSnack(
          context,
          'Order placed with ${result['shop_name'] ?? 'a nearby dealer'} · ${formatKsh(result['total'] ?? result['price'])}',
          success: true,
        );
        Navigator.pushReplacementNamed(context, '/order_history');
        return;
      }
      showAppSnack(context, result['error']?.toString() ?? 'Could not place the order.', error: true);
    } catch (e) {
      if (mounted) showAppSnack(context, e is ApiException ? e.message : e.toString(), error: true);
    }
    if (mounted) setState(() => _isLoading = false);
  }

  Widget _stepTitle(int number, String title) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12, top: 8),
      child: Row(
        children: [
          Container(
            width: 26,
            height: 26,
            decoration: const BoxDecoration(color: AppColors.ink, shape: BoxShape.circle),
            child: Center(
              child: Text('$number', style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w800)),
            ),
          ),
          const SizedBox(width: 10),
          Expanded(child: Text(title, style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800))),
        ],
      ),
    );
  }

  Widget _buildGasGrid() {
    if (_isLoadingGas) {
      return const Padding(padding: EdgeInsets.all(32), child: Center(child: CircularProgressIndicator()));
    }
    if (_loadError != null) return ErrorState(message: _loadError!, onRetry: _loadGasTypes);
    if (_gasTypes.isEmpty) {
      return const EmptyState(
        icon: Icons.propane_tank_outlined,
        title: 'No gas listed yet',
        message: 'Check back soon. We are adding dealers in your area.',
      );
    }
    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: _gasTypes.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        mainAxisSpacing: 12,
        crossAxisSpacing: 12,
        mainAxisExtent: 128,
      ),
      itemBuilder: (context, index) {
        final gas = _gasTypes[index];
        final selected = gas['id'] == _selectedGasTypeId;
        return _SelectableCard(
          selected: selected,
          onTap: () => setState(() => _selectedGasTypeId = gas['id']),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  IconBadge(icon: Icons.propane_tank_rounded, color: selected ? AppColors.primary : AppColors.inkSoft),
                  const Spacer(),
                  Pill('${gas['cylinder_size']}', color: selected ? AppColors.primary : AppColors.ink),
                ],
              ),
              const Spacer(),
              Text(
                '${gas['name']}',
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16),
              ),
              Text('${gas['cylinder_size']} cylinder', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
            ],
          ),
        );
      },
    );
  }

  Widget _orderTypeOption(String value, IconData icon, String title, String text) {
    final selected = _orderType == value;
    return Expanded(
      child: _SelectableCard(
        selected: selected,
        onTap: () => setState(() => _orderType = value),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: selected ? AppColors.primary : AppColors.inkSoft),
            const SizedBox(height: 10),
            Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
            const SizedBox(height: 2),
            Text(text, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Order gas')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(20, 4, 20, 24),
        children: [
          _stepTitle(1, 'Choose your gas'),
          _buildGasGrid(),
          const SizedBox(height: 24),
          _stepTitle(2, 'Refill or exchange?'),
          IntrinsicHeight(
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.stretch,
              children: [
                _orderTypeOption('refill', Icons.autorenew_rounded, 'Refill', 'Refill your own cylinder'),
                const SizedBox(width: 12),
                _orderTypeOption('exchange', Icons.swap_horiz_rounded, 'Exchange', 'Swap your empty for a full one'),
              ],
            ),
          ),
          const SizedBox(height: 24),
          _stepTitle(3, 'Delivery'),
          const AppCard(
            child: Row(
              children: [
                IconBadge(icon: Icons.my_location_rounded, color: AppColors.info),
                SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('To your current location', style: TextStyle(fontWeight: FontWeight.w800)),
                      SizedBox(height: 2),
                      Text(
                        "We'll detect it when you confirm and match you with the nearest dealer.",
                        style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          const Row(
            children: [
              Icon(Icons.info_outline_rounded, size: 16, color: AppColors.inkSoft),
              SizedBox(width: 8),
              Expanded(
                child: Text(
                  'You see the price as soon as a dealer is matched. Pay with M-Pesa or cash on delivery.',
                  style: TextStyle(color: AppColors.inkSoft, fontSize: 12),
                ),
              ),
            ],
          ),
        ],
      ),
      bottomNavigationBar: SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(20, 8, 20, 12),
          child: GradientButton(
            label: 'Place order',
            icon: Icons.local_fire_department_rounded,
            loading: _isLoading,
            onPressed: _selectedGasTypeId == null ? null : _placeOrder,
          ),
        ),
      ),
    );
  }
}

class _SelectableCard extends StatelessWidget {
  const _SelectableCard({required this.selected, required this.onTap, required this.child});

  final bool selected;
  final VoidCallback onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 200),
      decoration: BoxDecoration(
        color: selected ? AppColors.primary.withValues(alpha: 0.06) : AppColors.surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: selected ? AppColors.primary : AppColors.line, width: selected ? 2 : 1),
        boxShadow: selected
            ? [BoxShadow(color: AppColors.primary.withValues(alpha: 0.15), blurRadius: 16, offset: const Offset(0, 6))]
            : null,
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(20),
          onTap: onTap,
          child: Padding(padding: const EdgeInsets.all(14), child: child),
        ),
      ),
    );
  }
}

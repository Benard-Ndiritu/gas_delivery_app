import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/launcher.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import 'payment_screen.dart';
import 'place_order_screen.dart';

class OrderHistoryScreen extends StatefulWidget {
  /// When shown as a tab inside the customer home, there is no back button.
  final bool embedded;

  const OrderHistoryScreen({super.key, this.embedded = false});

  @override
  State<OrderHistoryScreen> createState() => _OrderHistoryScreenState();
}

enum _Filter { all, active, delivered, cancelled }

class _OrderHistoryScreenState extends State<OrderHistoryScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _error;
  _Filter _filter = _Filter.all;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = _orders.isEmpty);
    try {
      final orders = await ApiService.getMyOrders();
      if (!mounted) return;
      setState(() {
        _orders = orders;
        _error = null;
        _isLoading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString();
        _isLoading = false;
      });
    }
  }

  List<dynamic> get _visible {
    switch (_filter) {
      case _Filter.all:
        return _orders;
      case _Filter.active:
        return _orders.where(isActiveOrder).toList();
      case _Filter.delivered:
        return _orders.where((o) => o['status'] == 'completed').toList();
      case _Filter.cancelled:
        return _orders.where((o) => o['status'] == 'cancelled').toList();
    }
  }

  bool _canPay(dynamic order) => isActiveOrder(order) && order['payment_status'] != 'PAID';

  bool _canCancel(dynamic order) => order['status'] == 'pending' && order['payment_status'] != 'PAID';

  Future<void> _pay(dynamic order) async {
    await Navigator.push(
      context,
      MaterialPageRoute(
        builder: (_) => PaymentScreen(
          orderId: order['id'],
          amount: (order['total'] ?? order['price']).toString(),
        ),
      ),
    );
    if (mounted) _loadOrders();
  }

  Future<void> _cancel(dynamic order) async {
    final ok = await confirmDialog(
      context,
      title: 'Cancel this order?',
      message: 'Order #${order['id']} for ${gasLabel(order)} will be cancelled.',
      confirmLabel: 'Cancel order',
      destructive: true,
    );
    if (!ok) return;
    final result = await ApiService.cancelOrder(order['id']);
    if (!mounted) return;
    final error = result['error'];
    showAppSnack(context, error?.toString() ?? 'Order cancelled', error: error != null, success: error == null);
    _loadOrders();
  }

  Future<void> _orderGas() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const PlaceOrderScreen()));
    if (mounted) _loadOrders();
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _loadOrders);
    if (_orders.isEmpty) {
      return EmptyState(
        icon: Icons.receipt_long_rounded,
        title: 'No orders yet',
        message: 'Your gas orders will show up here so you can track and pay for them.',
        action: FilledButton.icon(
          onPressed: _orderGas,
          icon: const Icon(Icons.local_fire_department_rounded),
          label: const Text('Order gas'),
        ),
      );
    }

    final visible = _visible;
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 24),
        children: [
          SingleChildScrollView(
            scrollDirection: Axis.horizontal,
            child: Row(
              children: [
                for (final entry in const {
                  _Filter.all: 'All',
                  _Filter.active: 'Active',
                  _Filter.delivered: 'Delivered',
                  _Filter.cancelled: 'Cancelled',
                }.entries)
                  Padding(
                    padding: const EdgeInsets.only(right: 8),
                    child: ChoiceChip(
                      label: Text(entry.value),
                      selected: _filter == entry.key,
                      onSelected: (_) => setState(() => _filter = entry.key),
                    ),
                  ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          if (visible.isEmpty)
            const Padding(
              padding: EdgeInsets.only(top: 48),
              child: Center(child: Text('No orders here', style: TextStyle(color: AppColors.inkSoft))),
            ),
          for (final order in visible)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _OrderCard(
                order: order,
                onPay: _canPay(order) ? () => _pay(order) : null,
                onCancel: _canCancel(order) ? () => _cancel(order) : null,
              ),
            ),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        automaticallyImplyLeading: !widget.embedded,
        title: const Text('My orders'),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _loadOrders, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
    );
  }
}

class _OrderCard extends StatelessWidget {
  const _OrderCard({required this.order, this.onPay, this.onCancel});

  final dynamic order;
  final VoidCallback? onPay;
  final VoidCallback? onCancel;

  @override
  Widget build(BuildContext context) {
    final paid = order['payment_status'] == 'PAID';
    final active = isActiveOrder(order);
    final dealerPhone = order['dealer_phone'];

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: Icons.propane_tank_rounded, color: AppColors.forStatus(order['status'])),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gasLabel(order), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(
                      '${orderTypeLabel(order['order_type'])} · #${order['id']} · ${formatDateTime(order['created_at'])}',
                      style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
                    ),
                  ],
                ),
              ),
              StatusChip(order['status']),
            ],
          ),
          if (active) ...[
            const SizedBox(height: 18),
            OrderProgress(order['status']),
          ],
          const SizedBox(height: 16),
          const Divider(),
          const SizedBox(height: 12),
          if (order['shop_name'] != null)
            Row(
              children: [
                const Icon(Icons.storefront_rounded, size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${order['shop_name']}', style: const TextStyle(fontWeight: FontWeight.w600)),
                ),
                if (active && dealerPhone != null)
                  IconButton(
                    tooltip: 'Call dealer',
                    visualDensity: VisualDensity.compact,
                    onPressed: () => Launcher.call('$dealerPhone'),
                    style: IconButton.styleFrom(backgroundColor: AppColors.success.withValues(alpha: 0.12)),
                    icon: const Icon(Icons.call_rounded, color: AppColors.success, size: 18),
                  ),
              ],
            ),
          const SizedBox(height: 8),
          Row(
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text('Total', style: TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                    Text(formatKsh(order['total'] ?? order['price']),
                        style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 18)),
                  ],
                ),
              ),
              if (paid)
                Pill(
                  order['payment_method'] == 'CASH' ? 'Paid cash' : 'Paid M-Pesa',
                  color: AppColors.success,
                  icon: Icons.check_circle_rounded,
                ),
            ],
          ),
          if (onPay != null || onCancel != null) ...[
            const SizedBox(height: 14),
            Row(
              children: [
                if (onCancel != null)
                  Expanded(
                    child: OutlinedButton(
                      onPressed: onCancel,
                      style: OutlinedButton.styleFrom(foregroundColor: AppColors.danger, minimumSize: const Size(0, 46)),
                      child: const Text('Cancel'),
                    ),
                  ),
                if (onCancel != null && onPay != null) const SizedBox(width: 10),
                if (onPay != null)
                  Expanded(
                    flex: 2,
                    child: FilledButton.icon(
                      onPressed: onPay,
                      style: FilledButton.styleFrom(backgroundColor: AppColors.mpesa, minimumSize: const Size(0, 46)),
                      icon: const Icon(Icons.phone_android_rounded, size: 18),
                      label: const Text('Pay with M-Pesa'),
                    ),
                  ),
              ],
            ),
          ],
        ],
      ),
    );
  }
}

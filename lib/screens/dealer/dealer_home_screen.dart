import 'dart:async';

import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../services/launcher.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import 'dealer_inventory_screen.dart';
import 'dealer_profile_screen.dart';

/// Dealer shell: Orders, Inventory and Shop tabs.
class DealerHomeScreen extends StatefulWidget {
  const DealerHomeScreen({super.key});

  @override
  State<DealerHomeScreen> createState() => _DealerHomeScreenState();
}

class _DealerHomeScreenState extends State<DealerHomeScreen> {
  int _tab = 0;

  @override
  Widget build(BuildContext context) {
    final pages = [
      _OrdersTab(onOpenInventory: () => setState(() => _tab = 1)),
      const DealerInventoryScreen(embedded: true),
      const DealerProfileScreen(embedded: true),
    ];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: (i) => setState(() => _tab = i),
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.inventory_2_outlined),
            selectedIcon: Icon(Icons.inventory_2_rounded),
            label: 'Inventory',
          ),
          NavigationDestination(
            icon: Icon(Icons.storefront_outlined),
            selectedIcon: Icon(Icons.storefront_rounded),
            label: 'Shop',
          ),
        ],
      ),
    );
  }
}

enum _Filter { needsAction, inProgress, all }

class _OrdersTab extends StatefulWidget {
  const _OrdersTab({required this.onOpenInventory});

  final VoidCallback onOpenInventory;

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> {
  List<dynamic> _orders = [];
  bool _isLoading = true;
  String? _error;
  int? _busyOrderId;
  _Filter _filter = _Filter.all;
  Timer? _poll;

  @override
  void initState() {
    super.initState();
    _loadOrders();
    // Keep the list fresh so new orders show up without a manual refresh.
    _poll = Timer.periodic(const Duration(seconds: 30), (_) => _loadOrders(silent: true));
  }

  @override
  void dispose() {
    _poll?.cancel();
    super.dispose();
  }

  Future<void> _loadOrders({bool silent = false}) async {
    if (!silent && _orders.isEmpty) setState(() => _isLoading = true);
    try {
      final orders = await ApiService.getDealerOrders();
      if (!mounted) return;
      final hadPending = _orders.where((o) => o['status'] == 'pending').length;
      final nowPending = orders.where((o) => o['status'] == 'pending').length;
      setState(() {
        _orders = orders;
        _error = null;
        _isLoading = false;
      });
      if (silent && nowPending > hadPending) {
        showAppSnack(context, 'You have a new order!', success: true);
      }
    } catch (e) {
      if (!mounted) return;
      setState(() {
        if (!silent) _error = e.toString();
        _isLoading = false;
      });
    }
  }

  int _count(bool Function(dynamic) test) => _orders.where(test).length;

  List<dynamic> get _visible {
    switch (_filter) {
      case _Filter.needsAction:
        return _orders.where((o) => o['status'] == 'pending').toList();
      case _Filter.inProgress:
        return _orders.where((o) => ['accepted', 'delivering'].contains(o['status'])).toList();
      case _Filter.all:
        return _orders;
    }
  }

  Future<void> _updateStatus(dynamic order, String newStatus) async {
    if (newStatus == 'cancelled') {
      final ok = await confirmDialog(
        context,
        title: order['status'] == 'pending' ? 'Decline this order?' : 'Cancel this order?',
        message: 'The customer will see that order #${order['id']} was cancelled.',
        confirmLabel: order['status'] == 'pending' ? 'Decline' : 'Cancel order',
        destructive: true,
      );
      if (!ok) return;
    }
    setState(() => _busyOrderId = order['id']);
    final result = await ApiService.updateOrderStatus(order['id'], newStatus);
    if (!mounted) return;
    setState(() => _busyOrderId = null);
    if (result.containsKey('id')) {
      showAppSnack(context, 'Order #${order['id']}: ${statusLabel(newStatus).toLowerCase()}', success: true);
    } else {
      showAppSnack(context, result['error']?.toString() ?? 'Could not update the order', error: true);
    }
    _loadOrders();
  }

  Future<void> _confirmCash(dynamic order) async {
    final ok = await confirmDialog(
      context,
      title: 'Cash received?',
      message: 'Confirm you received ${formatKsh(order['total'] ?? order['price'])} in cash for order #${order['id']}. '
          'This also marks the order as delivered.',
      confirmLabel: 'Yes, received',
    );
    if (!ok) return;
    setState(() => _busyOrderId = order['id']);
    final result = await ApiService.confirmCashPayment(order['id']);
    if (!mounted) return;
    setState(() => _busyOrderId = null);
    final error = result['error'];
    showAppSnack(context, error?.toString() ?? 'Cash payment recorded', error: error != null, success: error == null);
    _loadOrders();
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadOrders,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHeader(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 20, 20, 24),
            child: _buildList(),
          ),
        ],
      ),
    );
  }

  Widget _buildHeader() {
    final pending = _count((o) => o['status'] == 'pending');
    final inProgress = _count((o) => ['accepted', 'delivering'].contains(o['status']));
    final delivered = _count((o) => o['status'] == 'completed');

    return Container(
      decoration: const BoxDecoration(
        gradient: AppColors.night,
        borderRadius: BorderRadius.vertical(bottom: Radius.circular(32)),
      ),
      clipBehavior: Clip.antiAlias,
      child: Stack(
        children: [
          const Positioned.fill(child: GlowBlobs()),
          SafeArea(
            bottom: false,
            child: Padding(
              padding: const EdgeInsets.fromLTRB(20, 12, 20, 24),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const BrandMark(size: 40),
                      const SizedBox(width: 12),
                      const Expanded(
                        child: Text(
                          'Dealer dashboard',
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Refresh',
                        onPressed: _loadOrders,
                        style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1)),
                        icon: const Icon(Icons.refresh_rounded, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 24),
                  Text('${greeting()} 👋', style: TextStyle(color: Colors.white.withValues(alpha: 0.7))),
                  const SizedBox(height: 4),
                  Text(
                    pending == 0 ? 'All caught up' : '$pending new ${pending == 1 ? 'order' : 'orders'} waiting',
                    style: const TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6),
                  ),
                  const SizedBox(height: 20),
                  Row(
                    children: [
                      _StatTile(label: 'New', value: pending, color: AppColors.amber),
                      const SizedBox(width: 10),
                      _StatTile(label: 'In progress', value: inProgress, color: const Color(0xFF93C5FD)),
                      const SizedBox(width: 10),
                      _StatTile(label: 'Delivered', value: delivered, color: const Color(0xFF86EFAC)),
                    ],
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildList() {
    if (_isLoading) {
      return const Padding(padding: EdgeInsets.only(top: 60), child: Center(child: CircularProgressIndicator()));
    }
    if (_error != null) return ErrorState(message: _error!, onRetry: _loadOrders);
    if (_orders.isEmpty) {
      return EmptyState(
        icon: Icons.inbox_rounded,
        title: 'No orders yet',
        message: 'Customers near you are matched to dealers that have gas in stock. Keep your inventory up to date.',
        action: FilledButton.icon(
          onPressed: widget.onOpenInventory,
          icon: const Icon(Icons.inventory_2_rounded),
          label: const Text('Set up inventory'),
        ),
      );
    }

    final visible = _visible;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: Row(
            children: [
              for (final entry in const {
                _Filter.all: 'All orders',
                _Filter.needsAction: 'New',
                _Filter.inProgress: 'In progress',
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
            padding: EdgeInsets.only(top: 40),
            child: Center(child: Text('Nothing here right now', style: TextStyle(color: AppColors.inkSoft))),
          ),
        for (final order in visible)
          Padding(
            padding: const EdgeInsets.only(bottom: 14),
            child: _DealerOrderCard(
              order: order,
              busy: _busyOrderId == order['id'],
              onStatus: (status) => _updateStatus(order, status),
              onCash: () => _confirmCash(order),
            ),
          ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  const _StatTile({required this.label, required this.value, required this.color});

  final String label;
  final int value;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Expanded(
      child: Container(
        padding: const EdgeInsets.all(14),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.08),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('$value', style: TextStyle(color: color, fontSize: 26, fontWeight: FontWeight.w800)),
            Text(label, style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 12)),
          ],
        ),
      ),
    );
  }
}

class _DealerOrderCard extends StatelessWidget {
  const _DealerOrderCard({required this.order, required this.busy, required this.onStatus, required this.onCash});

  final dynamic order;
  final bool busy;
  final ValueChanged<String> onStatus;
  final VoidCallback onCash;

  @override
  Widget build(BuildContext context) {
    final status = order['status'] as String?;
    final paid = order['payment_status'] == 'PAID';
    final active = isActiveOrder(order);
    final lat = order['customer_latitude'];
    final lon = order['customer_longitude'];

    return AppCard(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Text('Order #${order['id']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  timeAgo(order['created_at']),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(color: AppColors.inkSoft, fontSize: 12),
                ),
              ),
              StatusChip(status),
            ],
          ),
          const SizedBox(height: 14),
          Row(
            children: [
              IconBadge(icon: Icons.propane_tank_rounded, color: AppColors.forStatus(status)),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gasLabel(order), style: const TextStyle(fontWeight: FontWeight.w800)),
                    Text(orderTypeLabel(order['order_type']), style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                  ],
                ),
              ),
              Column(
                crossAxisAlignment: CrossAxisAlignment.end,
                children: [
                  Text(formatKsh(order['total'] ?? order['price']),
                      style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 17)),
                  const SizedBox(height: 2),
                  paid
                      ? Pill(order['payment_method'] == 'CASH' ? 'Paid cash' : 'Paid M-Pesa',
                          color: AppColors.success, icon: Icons.check_circle_rounded)
                      : const Pill('Not paid', color: AppColors.inkSoft),
                ],
              ),
            ],
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.fromLTRB(14, 6, 6, 6),
            decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(16)),
            child: Row(
              children: [
                const Icon(Icons.person_rounded, size: 18, color: AppColors.inkSoft),
                const SizedBox(width: 8),
                Expanded(
                  child: Text('${order['customer_phone']}', style: const TextStyle(fontWeight: FontWeight.w700)),
                ),
                if (active) ...[
                  IconButton(
                    tooltip: 'Call customer',
                    onPressed: () => Launcher.call('${order['customer_phone']}'),
                    style: IconButton.styleFrom(backgroundColor: AppColors.success.withValues(alpha: 0.14)),
                    icon: const Icon(Icons.call_rounded, color: AppColors.success, size: 20),
                  ),
                  if (lat != null && lon != null)
                    IconButton(
                      tooltip: 'Directions',
                      onPressed: () => Launcher.directions(lat, lon),
                      style: IconButton.styleFrom(backgroundColor: AppColors.info.withValues(alpha: 0.14)),
                      icon: const Icon(Icons.directions_rounded, color: AppColors.info, size: 20),
                    ),
                ],
              ],
            ),
          ),
          if (active) ...[
            const SizedBox(height: 14),
            _buildActions(status, paid),
          ],
        ],
      ),
    );
  }

  Widget _buildActions(String? status, bool paid) {
    if (busy) {
      return const SizedBox(height: 52, child: Center(child: CircularProgressIndicator()));
    }

    Widget primary(String label, IconData icon, VoidCallback onPressed, {Color color = AppColors.primary}) => Expanded(
          flex: 2,
          child: FilledButton.icon(
            onPressed: onPressed,
            style: FilledButton.styleFrom(backgroundColor: color, minimumSize: const Size(0, 50)),
            icon: Icon(icon, size: 20),
            label: Text(label),
          ),
        );

    Widget secondary(String label, VoidCallback onPressed, {Color color = AppColors.danger}) => Expanded(
          child: OutlinedButton(
            onPressed: onPressed,
            style: OutlinedButton.styleFrom(foregroundColor: color, minimumSize: const Size(0, 50)),
            child: Text(label),
          ),
        );

    switch (status) {
      case 'pending':
        return Row(children: [
          secondary('Decline', () => onStatus('cancelled')),
          const SizedBox(width: 10),
          primary('Accept order', Icons.check_rounded, () => onStatus('accepted')),
        ]);
      case 'accepted':
        return Row(children: [
          secondary('Cancel', () => onStatus('cancelled')),
          const SizedBox(width: 10),
          primary('Start delivery', Icons.delivery_dining_rounded, () => onStatus('delivering'), color: AppColors.purple),
        ]);
      case 'delivering':
        return Row(children: [
          if (!paid) ...[
            secondary('Cash received', onCash, color: AppColors.ink),
            const SizedBox(width: 10),
          ],
          primary('Mark delivered', Icons.home_rounded, () => onStatus('completed'), color: AppColors.success),
        ]);
      default:
        return const SizedBox.shrink();
    }
  }
}

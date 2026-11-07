import 'package:flutter/material.dart';

import '../../config.dart';
import '../../services/api_service.dart';
import '../../services/launcher.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';
import 'order_history_screen.dart';
import 'payment_screen.dart';
import 'place_order_screen.dart';

/// Customer shell: Home, Orders and Support tabs.
class CustomerHomeScreen extends StatefulWidget {
  const CustomerHomeScreen({super.key});

  @override
  State<CustomerHomeScreen> createState() => _CustomerHomeScreenState();
}

class _CustomerHomeScreenState extends State<CustomerHomeScreen> {
  int _tab = 0;

  void _goTo(int tab) => setState(() => _tab = tab);

  @override
  Widget build(BuildContext context) {
    final pages = [
      _HomeTab(onOpenOrders: () => _goTo(1), onOpenSupport: () => _goTo(2)),
      const OrderHistoryScreen(embedded: true),
      const _SupportTab(),
    ];
    return Scaffold(
      body: AnimatedSwitcher(
        duration: const Duration(milliseconds: 250),
        child: KeyedSubtree(key: ValueKey(_tab), child: pages[_tab]),
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _tab,
        onDestinationSelected: _goTo,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home_rounded),
            label: 'Home',
          ),
          NavigationDestination(
            icon: Icon(Icons.receipt_long_outlined),
            selectedIcon: Icon(Icons.receipt_long_rounded),
            label: 'Orders',
          ),
          NavigationDestination(
            icon: Icon(Icons.support_agent_outlined),
            selectedIcon: Icon(Icons.support_agent_rounded),
            label: 'Support',
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Home
// -----------------------------------------------------------------------------

class _HomeTab extends StatefulWidget {
  const _HomeTab({required this.onOpenOrders, required this.onOpenSupport});

  final VoidCallback onOpenOrders;
  final VoidCallback onOpenSupport;

  @override
  State<_HomeTab> createState() => _HomeTabState();
}

class _HomeTabState extends State<_HomeTab> {
  dynamic _activeOrder;

  @override
  void initState() {
    super.initState();
    _loadActiveOrder();
  }

  Future<void> _loadActiveOrder() async {
    try {
      final orders = await ApiService.getMyOrders();
      if (!mounted) return;
      setState(() => _activeOrder = orders.cast<dynamic>().where(isActiveOrder).firstOrNull);
    } catch (_) {
      // The home screen still works without it.
    }
  }

  Future<void> _orderGas() async {
    await Navigator.push(context, MaterialPageRoute(builder: (_) => const PlaceOrderScreen()));
    if (mounted) _loadActiveOrder();
  }

  Future<void> _logout() async {
    final ok = await confirmDialog(context, title: 'Log out?', message: 'You can sign back in any time.', confirmLabel: 'Log out');
    if (!ok) return;
    await ApiService.logout();
    if (!mounted) return;
    Navigator.pushNamedAndRemoveUntil(context, '/login', (route) => false);
  }

  @override
  Widget build(BuildContext context) {
    return RefreshIndicator(
      onRefresh: _loadActiveOrder,
      child: ListView(
        padding: EdgeInsets.zero,
        children: [
          _buildHero(),
          Padding(
            padding: const EdgeInsets.fromLTRB(20, 24, 20, 32),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                if (_activeOrder != null) ...[
                  const SectionTitle('Your active order'),
                  EntranceFade(child: _ActiveOrderCard(order: _activeOrder, onChanged: _loadActiveOrder, onOpenOrders: widget.onOpenOrders)),
                  const SizedBox(height: 24),
                ],
                Row(
                  children: [
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.receipt_long_rounded,
                        color: AppColors.info,
                        title: 'My orders',
                        subtitle: 'Track & pay',
                        onTap: widget.onOpenOrders,
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: _QuickAction(
                        icon: Icons.support_agent_rounded,
                        color: AppColors.purple,
                        title: 'Need help?',
                        subtitle: 'Call or WhatsApp',
                        onTap: widget.onOpenSupport,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 28),
                const SectionTitle('Why order with us'),
                SizedBox(
                  height: 148,
                  child: ListView(
                    scrollDirection: Axis.horizontal,
                    clipBehavior: Clip.none,
                    children: const [
                      _FeatureCard(icon: Icons.bolt_rounded, color: AppColors.primary, title: 'Fast delivery', text: 'From the nearest dealer to your door'),
                      _FeatureCard(icon: Icons.verified_rounded, color: AppColors.success, title: 'Trusted dealers', text: 'Every shop is reviewed and approved'),
                      _FeatureCard(icon: Icons.phone_android_rounded, color: AppColors.mpesa, title: 'Pay your way', text: 'M-Pesa or cash on delivery'),
                      _FeatureCard(icon: Icons.health_and_safety_rounded, color: AppColors.info, title: 'Safe handling', text: 'Sealed, checked cylinders'),
                    ],
                  ),
                ),
                const SizedBox(height: 28),
                const SectionTitle('How it works'),
                const _Step(number: 1, title: 'Choose your gas', text: 'Pick the brand and cylinder size, refill or exchange.'),
                const _Step(number: 2, title: 'A nearby dealer accepts', text: 'We match you with the closest dealer who has it in stock.'),
                const _Step(number: 3, title: 'Track the delivery', text: 'Follow your order from accepted to on the way.'),
                const _Step(number: 4, title: 'Pay with M-Pesa or cash', text: 'Pay from the app, or hand cash to the dealer.', last: true),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildHero() {
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
                          AppConfig.appName,
                          style: TextStyle(color: Colors.white, fontWeight: FontWeight.w800, fontSize: 17),
                        ),
                      ),
                      IconButton(
                        tooltip: 'Log out',
                        onPressed: _logout,
                        style: IconButton.styleFrom(backgroundColor: Colors.white.withValues(alpha: 0.1)),
                        icon: const Icon(Icons.logout_rounded, color: Colors.white, size: 20),
                      ),
                    ],
                  ),
                  const SizedBox(height: 28),
                  Text('${greeting()} 👋', style: TextStyle(color: Colors.white.withValues(alpha: 0.7), fontSize: 15)),
                  const SizedBox(height: 6),
                  const Text(
                    'Cooking gas,\ndelivered fast.',
                    style: TextStyle(color: Colors.white, fontSize: 34, height: 1.1, fontWeight: FontWeight.w800, letterSpacing: -1),
                  ),
                  const SizedBox(height: 24),
                  _OrderGasCard(onTap: _orderGas),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderGasCard extends StatelessWidget {
  const _OrderGasCard({required this.onTap});

  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppColors.flame,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [BoxShadow(color: AppColors.primary.withValues(alpha: 0.3), blurRadius: 30, offset: const Offset(0, 6))],
      ),
      clipBehavior: Clip.antiAlias,
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          onTap: onTap,
          child: Stack(
            children: [
              Positioned(
                right: -18,
                bottom: -26,
                child: Icon(Icons.local_fire_department_rounded, size: 150, color: Colors.white.withValues(alpha: 0.14)),
              ),
              Padding(
                padding: const EdgeInsets.all(22),
                child: Row(
                  children: [
                    const Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('Order gas now', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.w800)),
                          SizedBox(height: 6),
                          Text(
                            'Nearest dealer · M-Pesa or cash',
                            style: TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
                          ),
                        ],
                      ),
                    ),
                    Container(
                      width: 48,
                      height: 48,
                      decoration: const BoxDecoration(color: Colors.white, shape: BoxShape.circle),
                      child: const Icon(Icons.arrow_forward_rounded, color: AppColors.primaryDeep),
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ActiveOrderCard extends StatelessWidget {
  const _ActiveOrderCard({required this.order, required this.onChanged, required this.onOpenOrders});

  final dynamic order;
  final VoidCallback onChanged;
  final VoidCallback onOpenOrders;

  @override
  Widget build(BuildContext context) {
    final paid = order['payment_status'] == 'PAID';
    return AppCard(
      onTap: onOpenOrders,
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const IconBadge(icon: Icons.propane_tank_rounded),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(gasLabel(order), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text(
                      '${orderTypeLabel(order['order_type'])} · ${order['shop_name'] ?? 'Dealer'}',
                      style: const TextStyle(color: AppColors.inkSoft, fontSize: 13),
                    ),
                  ],
                ),
              ),
              StatusChip(order['status']),
            ],
          ),
          const SizedBox(height: 20),
          OrderProgress(order['status']),
          const SizedBox(height: 18),
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
                const Pill('Paid', color: AppColors.success, icon: Icons.check_circle_rounded)
              else
                FilledButton.icon(
                  onPressed: () async {
                    await Navigator.push(
                      context,
                      MaterialPageRoute(
                        builder: (_) => PaymentScreen(
                          orderId: order['id'],
                          amount: (order['total'] ?? order['price']).toString(),
                        ),
                      ),
                    );
                    onChanged();
                  },
                  style: FilledButton.styleFrom(backgroundColor: AppColors.mpesa, minimumSize: const Size(0, 44)),
                  icon: const Icon(Icons.phone_android_rounded, size: 18),
                  label: const Text('Pay now'),
                ),
            ],
          ),
        ],
      ),
    );
  }
}

class _QuickAction extends StatelessWidget {
  const _QuickAction({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return AppCard(
      onTap: onTap,
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          IconBadge(icon: icon, color: color),
          const SizedBox(height: 14),
          Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
          const SizedBox(height: 2),
          Text(subtitle, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
        ],
      ),
    );
  }
}

class _FeatureCard extends StatelessWidget {
  const _FeatureCard({required this.icon, required this.color, required this.title, required this.text});

  final IconData icon;
  final Color color;
  final String title;
  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 168,
      margin: const EdgeInsets.only(right: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: color, size: 28),
          const Spacer(),
          Text(title, maxLines: 1, overflow: TextOverflow.ellipsis, style: const TextStyle(fontWeight: FontWeight.w800)),
          const SizedBox(height: 2),
          Text(text, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12), maxLines: 2, overflow: TextOverflow.ellipsis),
        ],
      ),
    );
  }
}

class _Step extends StatelessWidget {
  const _Step({required this.number, required this.title, required this.text, this.last = false});

  final int number;
  final String title;
  final String text;
  final bool last;

  @override
  Widget build(BuildContext context) {
    return IntrinsicHeight(
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Column(
            children: [
              Container(
                width: 32,
                height: 32,
                decoration: const BoxDecoration(gradient: AppColors.flame, shape: BoxShape.circle),
                child: Center(
                  child: Text('$number', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.w800)),
                ),
              ),
              if (!last)
                Expanded(
                  child: Container(width: 2, margin: const EdgeInsets.symmetric(vertical: 4), color: AppColors.line),
                ),
            ],
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Padding(
              padding: EdgeInsets.only(top: 5, bottom: last ? 0 : 20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800)),
                  const SizedBox(height: 2),
                  Text(text, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// -----------------------------------------------------------------------------
// Support
// -----------------------------------------------------------------------------

class _SupportTab extends StatelessWidget {
  const _SupportTab();

  Future<void> _open(BuildContext context, Future<bool> Function() action) async {
    final ok = await action();
    if (!ok && context.mounted) showAppSnack(context, 'Could not open that app on this phone', error: true);
  }

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      bottom: false,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 16, 20, 32),
        children: [
          const Text('We\'re here to help', style: TextStyle(fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6)),
          const SizedBox(height: 6),
          const Text('Questions about an order or a payment? Reach us any time.', style: TextStyle(color: AppColors.inkSoft)),
          const SizedBox(height: 24),
          _ContactTile(
            icon: Icons.chat_rounded,
            color: AppColors.mpesa,
            title: 'WhatsApp',
            subtitle: 'Fastest replies',
            onTap: () => _open(context, () => Launcher.whatsapp(AppConfig.supportWhatsApp, text: 'Hi, I need help with my gas order.')),
          ),
          _ContactTile(
            icon: Icons.call_rounded,
            color: AppColors.primary,
            title: 'Call us',
            subtitle: AppConfig.supportPhone,
            onTap: () => _open(context, () => Launcher.call(AppConfig.supportPhone)),
          ),
          _ContactTile(
            icon: Icons.mail_rounded,
            color: AppColors.info,
            title: 'Email',
            subtitle: AppConfig.supportEmail,
            onTap: () => _open(context, () => Launcher.email(AppConfig.supportEmail, subject: 'Gas Delivery support')),
          ),
          const SizedBox(height: 16),
          const SectionTitle('Frequently asked'),
          const _Faq('How do I place an order?', 'Tap "Order gas now" on the home screen, choose your gas and refill or exchange, then confirm. We use your current location to find the nearest dealer.'),
          const _Faq('How long does delivery take?', 'Usually 30–60 minutes, depending on your distance from the dealer and how busy they are.'),
          const _Faq('How do I pay?', 'Pay with M-Pesa from the Orders tab before or after delivery, or pay the dealer in cash when your gas arrives.'),
          const _Faq('Can I cancel an order?', 'Yes. You can cancel any order that a dealer has not accepted yet, as long as it is not already paid.'),
          const _Faq('What if no dealer is available?', 'It means no dealer near you has that gas in stock right now. Try another size or brand, or try again a little later.'),
        ],
      ),
    );
  }
}

class _ContactTile extends StatelessWidget {
  const _ContactTile({required this.icon, required this.color, required this.title, required this.subtitle, required this.onTap});

  final IconData icon;
  final Color color;
  final String title;
  final String subtitle;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: AppCard(
        onTap: onTap,
        child: Row(
          children: [
            IconBadge(icon: icon, color: color),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 15)),
                  Text(subtitle, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13)),
                ],
              ),
            ),
            const Icon(Icons.arrow_outward_rounded, color: AppColors.inkSoft, size: 20),
          ],
        ),
      ),
    );
  }
}

class _Faq extends StatelessWidget {
  const _Faq(this.question, this.answer);

  final String question;
  final String answer;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: AppCard(
        padding: EdgeInsets.zero,
        child: Theme(
          data: Theme.of(context).copyWith(dividerColor: Colors.transparent),
          child: ExpansionTile(
            shape: const Border(),
            collapsedShape: const Border(),
            iconColor: AppColors.primary,
            collapsedIconColor: AppColors.inkSoft,
            title: Text(question, style: const TextStyle(fontWeight: FontWeight.w700, fontSize: 14)),
            childrenPadding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            expandedAlignment: Alignment.centerLeft,
            children: [Text(answer, style: const TextStyle(color: AppColors.inkSoft, fontSize: 13, height: 1.5))],
          ),
        ),
      ),
    );
  }
}

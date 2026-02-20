import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class DealerHomeScreen extends StatefulWidget {
  const DealerHomeScreen({super.key});

  @override
  State<DealerHomeScreen> createState() => _DealerHomeScreenState();
}

class _DealerHomeScreenState extends State<DealerHomeScreen> {
  List<dynamic> _orders = [];
  bool _isLoading = true;

  @override
  void initState() {
    super.initState();
    _loadOrders();
  }

  Future<void> _loadOrders() async {
    setState(() => _isLoading = true);
    final orders = await ApiService.getDealerOrders();
    setState(() {
      _orders = orders;
      _isLoading = false;
    });
  }

  Color _statusColor(String status) {
    switch (status) {
      case 'pending': return Colors.orange;
      case 'accepted': return Colors.blue;
      case 'delivering': return Colors.purple;
      case 'completed': return Colors.green;
      case 'cancelled': return Colors.red;
      default: return Colors.grey;
    }
  }

  Future<void> _updateStatus(int orderId, String newStatus) async {
    final result = await ApiService.updateOrderStatus(orderId, newStatus);
    if (result.containsKey('id')) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Order $newStatus successfully')),
      );
      _loadOrders();
    }
  }

  List<String> _nextStatuses(String currentStatus) {
    switch (currentStatus) {
      case 'pending': return ['accepted', 'cancelled'];
      case 'accepted': return ['delivering', 'cancelled'];
      case 'delivering': return ['completed'];
      default: return [];
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Dealer Dashboard'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
        actions: [
          IconButton(
            icon: const Icon(Icons.refresh),
            onPressed: _loadOrders,
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            onPressed: () async {
              await ApiService.clearToken();
              if (!context.mounted) return;
              Navigator.pushReplacementNamed(context, '/login');
            },
          ),
        ],
      ),
      body: _isLoading
          ? const Center(child: CircularProgressIndicator())
          : _orders.isEmpty
              ? const Center(child: Text('No orders yet'))
              : ListView.builder(
                  padding: const EdgeInsets.all(16),
                  itemCount: _orders.length,
                  itemBuilder: (context, index) {
                    final order = _orders[index];
                    final nextStatuses = _nextStatuses(order['status']);
                    return Card(
                      margin: const EdgeInsets.only(bottom: 12),
                      child: Padding(
                        padding: const EdgeInsets.all(16),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceBetween,
                              children: [
                                Text('Order #${order['id']}',
                                    style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 16)),
                                Container(
                                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                  decoration: BoxDecoration(
                                    color: _statusColor(order['status']),
                                    borderRadius: BorderRadius.circular(8),
                                  ),
                                  child: Text(
                                    order['status'].toUpperCase(),
                                    style: const TextStyle(color: Colors.white, fontSize: 12),
                                  ),
                                ),
                              ],
                            ),
                            const SizedBox(height: 8),
                            Text('Customer: ${order['customer_phone']}'),
                            Text('Gas: ${order['gas_type_name']} - ${order['order_type']}'),
                            Text('Price: KSh ${order['price']}'),
                            if (nextStatuses.isNotEmpty) ...[
                              const SizedBox(height: 12),
                              Row(
                                children: nextStatuses.map((status) {
                                  return Padding(
                                    padding: const EdgeInsets.only(right: 8),
                                    child: ElevatedButton(
                                      onPressed: () => _updateStatus(order['id'], status),
                                      style: ElevatedButton.styleFrom(
                                        backgroundColor: status == 'cancelled' ? Colors.red : Colors.orange,
                                      ),
                                      child: Text(status.toUpperCase(),
                                          style: const TextStyle(color: Colors.white)),
                                    ),
                                  );
                                }).toList(),
                              ),
                            ],
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}
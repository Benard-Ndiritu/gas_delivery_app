import 'package:flutter/material.dart';
import '../../services/api_service.dart';

class PaymentScreen extends StatefulWidget {
  final int orderId;
  final String amount;

  const PaymentScreen({super.key, required this.orderId, required this.amount});

  @override
  State<PaymentScreen> createState() => _PaymentScreenState();
}

class _PaymentScreenState extends State<PaymentScreen> {
  bool _isLoading = false;
  String _paymentStatus = '';

  Future<void> _initiateMpesa() async {
    setState(() {
      _isLoading = true;
      _paymentStatus = '';
    });

    try {
      final result = await ApiService.initiateMpesaPayment(widget.orderId);

      if (!mounted) return;
      if (result.containsKey('message')) {
        setState(() {
          _paymentStatus = 'STK Push sent! Check your phone and enter M-Pesa PIN.';
        });
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Check your phone for M-Pesa prompt')),
        );
      } else {
        setState(() {
          _paymentStatus = 'Failed: ${result['error'] ?? 'Unknown error'}';
        });
      }
    } catch (e) {
      setState(() {
        _paymentStatus = 'Error: $e';
      });
    }

    setState(() => _isLoading = false);
  }

  Future<void> _checkPaymentStatus() async {
    setState(() => _isLoading = true);
    try {
      final result = await ApiService.getPaymentStatus(widget.orderId);
      if (!mounted) return;
      setState(() {
        _paymentStatus = 'Payment Status: ${result['status']}';
      });

      if (result['status'] == 'PAID') {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Payment confirmed!')),
        );
      }
    } catch (e) {
      setState(() {
        _paymentStatus = 'Error: $e';
      });
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Payment'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: Colors.orange,
                borderRadius: BorderRadius.circular(16),
              ),
              child: Column(
                children: [
                  const Text('Amount to Pay', style: TextStyle(color: Colors.white, fontSize: 16)),
                  const SizedBox(height: 8),
                  Text(
                    'KSh ${widget.amount}',
                    style: const TextStyle(color: Colors.white, fontSize: 36, fontWeight: FontWeight.bold),
                  ),
                  const SizedBox(height: 4),
                  Text('Order #${widget.orderId}', style: const TextStyle(color: Colors.white70)),
                ],
              ),
            ),
            const SizedBox(height: 32),
            const Text('Pay with M-Pesa', style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            const Text(
              'Click the button below to receive an STK Push on your phone. Enter your M-Pesa PIN to complete payment.',
              style: TextStyle(color: Colors.grey),
            ),
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                onPressed: _isLoading ? null : _initiateMpesa,
                style: ElevatedButton.styleFrom(backgroundColor: Colors.green),
                icon: const Icon(Icons.phone_android, color: Colors.white),
                label: _isLoading
                    ? const CircularProgressIndicator(color: Colors.white)
                    : const Text('Pay with M-Pesa', style: TextStyle(fontSize: 18, color: Colors.white)),
              ),
            ),
            const SizedBox(height: 16),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton.icon(
                onPressed: _isLoading ? null : _checkPaymentStatus,
                icon: const Icon(Icons.refresh),
                label: const Text('Check Payment Status', style: TextStyle(fontSize: 16)),
              ),
            ),
            if (_paymentStatus.isNotEmpty) ...[
              const SizedBox(height: 24),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(16),
                decoration: BoxDecoration(
                  color: _paymentStatus.contains('PAID') ? Colors.green[50] : Colors.orange[50],
                  borderRadius: BorderRadius.circular(8),
                  border: Border.all(
                    color: _paymentStatus.contains('PAID') ? Colors.green : Colors.orange,
                  ),
                ),
                child: Text(
                  _paymentStatus,
                  style: TextStyle(
                    color: _paymentStatus.contains('PAID') ? Colors.green : Colors.orange,
                    fontWeight: FontWeight.bold,
                  ),
                ),
              ),
            ],
          ],
        ),
      ),
    );
  }
}
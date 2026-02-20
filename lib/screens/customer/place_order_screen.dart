import 'package:flutter/material.dart';
import 'package:geolocator/geolocator.dart';
import '../../services/api_service.dart';

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

  @override
  void initState() {
    super.initState();
    _loadGasTypes();
  }

  Future<void> _loadGasTypes() async {
    final types = await ApiService.getGasTypes();
    setState(() {
      _gasTypes = types;
      _isLoadingGas = false;
    });
  }

  Future<Position> _getLocation() async {
    bool serviceEnabled = await Geolocator.isLocationServiceEnabled();
    if (!serviceEnabled) throw Exception('Location services disabled');

    LocationPermission permission = await Geolocator.checkPermission();
    if (permission == LocationPermission.denied) {
      permission = await Geolocator.requestPermission();
    }

    return await Geolocator.getCurrentPosition();
  }

  Future<void> _placeOrder() async {
    if (_selectedGasTypeId == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Please select a gas type')),
      );
      return;
    }

    setState(() => _isLoading = true);
    try {
      final position = await _getLocation();
      final result = await ApiService.placeOrder(
        _selectedGasTypeId!,
        _orderType,
        position.latitude,
        position.longitude,
      );

      if (!mounted) return;
      if (result.containsKey('id')) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Order placed successfully!')),
        );
        Navigator.pop(context);
      } else {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('Error: ${result['error']}')),
        );
      }
    } catch (e) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Error: $e')),
      );
    }
    setState(() => _isLoading = false);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Place Order'),
        backgroundColor: Colors.orange,
        foregroundColor: Colors.white,
      ),
      body: Padding(
        padding: const EdgeInsets.all(24.0),
        child: _isLoadingGas
            ? const Center(child: CircularProgressIndicator())
            : Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text('Select Gas Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  DropdownButtonFormField<int>(
                    decoration: const InputDecoration(border: OutlineInputBorder()),
                    hint: const Text('Choose gas type'),
                    value: _selectedGasTypeId,
                    items: _gasTypes.map((gas) {
                      return DropdownMenuItem<int>(
                        value: gas['id'],
                        child: Text('${gas['name']} - ${gas['cylinder_size']}'),
                      );
                    }).toList(),
                    onChanged: (value) => setState(() => _selectedGasTypeId = value),
                  ),
                  const SizedBox(height: 24),
                  const Text('Order Type', style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold)),
                  const SizedBox(height: 8),
                  Row(
                    children: [
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Refill'),
                          value: 'refill',
                          groupValue: _orderType,
                          onChanged: (value) => setState(() => _orderType = value!),
                        ),
                      ),
                      Expanded(
                        child: RadioListTile<String>(
                          title: const Text('Exchange'),
                          value: 'exchange',
                          groupValue: _orderType,
                          onChanged: (value) => setState(() => _orderType = value!),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 32),
                  SizedBox(
                    width: double.infinity,
                    height: 50,
                    child: ElevatedButton(
                      onPressed: _isLoading ? null : _placeOrder,
                      style: ElevatedButton.styleFrom(backgroundColor: Colors.orange),
                      child: _isLoading
                          ? const CircularProgressIndicator(color: Colors.white)
                          : const Text('Place Order', style: TextStyle(fontSize: 18, color: Colors.white)),
                    ),
                  ),
                ],
              ),
      ),
    );
  }
}
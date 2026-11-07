import 'package:flutter/material.dart';

import '../../services/api_service.dart';
import '../../theme/app_theme.dart';
import '../../utils/format.dart';
import '../../widgets/common.dart';

/// Lets a dealer list the gas they stock, set prices and mark items in/out of stock.
/// Customers are only matched to dealers who have the requested gas in stock.
class DealerInventoryScreen extends StatefulWidget {
  /// When shown as a tab inside the dealer home, there is no back button.
  final bool embedded;

  const DealerInventoryScreen({super.key, this.embedded = false});

  @override
  State<DealerInventoryScreen> createState() => _DealerInventoryScreenState();
}

class _DealerInventoryScreenState extends State<DealerInventoryScreen> {
  List<dynamic> _items = [];
  List<dynamic> _gasTypes = [];
  bool _isLoading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _isLoading = _items.isEmpty;
      _error = null;
    });
    try {
      final results = await Future.wait([ApiService.getMyInventory(), ApiService.getGasTypes()]);
      if (!mounted) return;
      setState(() {
        _items = results[0];
        _gasTypes = results[1];
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

  List<dynamic> get _unlistedGasTypes {
    final listed = _items.map((item) => item['gas_type']).toSet();
    return _gasTypes.where((gas) => !listed.contains(gas['id'])).toList();
  }

  Future<void> _toggleStock(dynamic item, bool value) async {
    setState(() => item['stock_available'] = value); // optimistic
    final result = await ApiService.updateInventory(item['id'], {'stock_available': value});
    if (!mounted) return;
    if (result['error'] != null) {
      showAppSnack(context, result['error'].toString(), error: true);
      _load();
    }
  }

  Future<void> _delete(dynamic item) async {
    final ok = await confirmDialog(
      context,
      title: 'Remove ${item['gas_type_name']} ${item['cylinder_size']}?',
      message: 'Customers will no longer be able to order it from you.',
      confirmLabel: 'Remove',
      destructive: true,
    );
    if (!ok) return;
    final result = await ApiService.deleteInventory(item['id']);
    if (!mounted) return;
    final error = result['error'];
    showAppSnack(context, error?.toString() ?? 'Item removed', error: error != null, success: error == null);
    _load();
  }

  /// Add a new item (item == null) or edit an existing item's prices.
  Future<void> _openEditor({dynamic item}) async {
    final available = _unlistedGasTypes;
    if (item == null && available.isEmpty) {
      showAppSnack(
        context,
        _gasTypes.isEmpty
            ? 'No gas types have been set up yet. Please contact the administrator.'
            : 'You already list every gas type. Edit an existing item instead.',
      );
      return;
    }

    final saved = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      builder: (_) => _InventoryEditor(item: item, available: available),
    );
    if (saved == true && mounted) {
      showAppSnack(context, item == null ? 'Gas added to your shop' : 'Prices updated', success: true);
      _load();
    }
  }

  Widget _buildBody() {
    if (_isLoading) return const Center(child: CircularProgressIndicator());
    if (_error != null) return ErrorState(message: _error!, onRetry: _load);
    if (_items.isEmpty) {
      return EmptyState(
        icon: Icons.inventory_2_rounded,
        title: 'Your shop is empty',
        message: 'Add the gas you sell and its prices so customers near you can start ordering.',
        action: FilledButton.icon(
          onPressed: () => _openEditor(),
          icon: const Icon(Icons.add_rounded),
          label: const Text('Add gas'),
        ),
      );
    }

    final inStock = _items.where((i) => i['stock_available'] == true).length;
    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.fromLTRB(20, 0, 20, 100),
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppColors.info.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
            ),
            child: Row(
              children: [
                const Icon(Icons.visibility_rounded, color: AppColors.info, size: 20),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    '$inStock of ${_items.length} items are in stock and visible to customers.',
                    style: const TextStyle(fontSize: 13),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 16),
          for (final item in _items)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: _InventoryCard(
                item: item,
                onEdit: () => _openEditor(item: item),
                onDelete: () => _delete(item),
                onToggle: (value) => _toggleStock(item, value),
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
        title: const Text('Inventory & prices'),
        actions: [
          IconButton(tooltip: 'Refresh', onPressed: _load, icon: const Icon(Icons.refresh_rounded)),
          const SizedBox(width: 8),
        ],
      ),
      body: _buildBody(),
      floatingActionButton: _isLoading || _error != null || _items.isEmpty
          ? null
          : FloatingActionButton.extended(
              onPressed: () => _openEditor(),
              icon: const Icon(Icons.add_rounded),
              label: const Text('Add gas', style: TextStyle(fontWeight: FontWeight.w700)),
            ),
    );
  }
}

class _InventoryCard extends StatelessWidget {
  const _InventoryCard({required this.item, required this.onEdit, required this.onDelete, required this.onToggle});

  final dynamic item;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final ValueChanged<bool> onToggle;

  @override
  Widget build(BuildContext context) {
    final inStock = item['stock_available'] == true;

    Widget price(String label, dynamic value) => Expanded(
          child: Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(color: AppColors.field, borderRadius: BorderRadius.circular(14)),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(label, style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                const SizedBox(height: 2),
                Text(formatKsh(value), style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
              ],
            ),
          ),
        );

    return AppCard(
      padding: const EdgeInsets.fromLTRB(18, 14, 8, 14),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              IconBadge(icon: Icons.propane_tank_rounded, color: inStock ? AppColors.primary : AppColors.inkSoft),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text('${item['gas_type_name']}', style: const TextStyle(fontWeight: FontWeight.w800, fontSize: 16)),
                    Text('${item['cylinder_size']} cylinder', style: const TextStyle(color: AppColors.inkSoft, fontSize: 12)),
                  ],
                ),
              ),
              IconButton(tooltip: 'Edit prices', onPressed: onEdit, icon: const Icon(Icons.edit_rounded, size: 20)),
              IconButton(
                tooltip: 'Remove',
                onPressed: onDelete,
                icon: const Icon(Icons.delete_outline_rounded, color: AppColors.danger, size: 20),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Padding(
            padding: const EdgeInsets.only(right: 10),
            child: Row(
              children: [
                price('Refill', item['price_refill']),
                const SizedBox(width: 10),
                price('Exchange', item['price_exchange']),
              ],
            ),
          ),
          const SizedBox(height: 4),
          SwitchListTile(
            contentPadding: const EdgeInsets.only(right: 4),
            title: Text(
              inStock ? 'In stock' : 'Out of stock',
              style: TextStyle(fontWeight: FontWeight.w700, color: inStock ? AppColors.success : AppColors.inkSoft),
            ),
            subtitle: Text(
              inStock ? 'Customers can order this' : 'Hidden from customers',
              style: const TextStyle(fontSize: 12),
            ),
            value: inStock,
            activeThumbColor: Colors.white,
            activeTrackColor: AppColors.success,
            onChanged: onToggle,
          ),
        ],
      ),
    );
  }
}

class _InventoryEditor extends StatefulWidget {
  const _InventoryEditor({required this.item, required this.available});

  final dynamic item;
  final List<dynamic> available;

  @override
  State<_InventoryEditor> createState() => _InventoryEditorState();
}

class _InventoryEditorState extends State<_InventoryEditor> {
  late final _refill = TextEditingController(text: widget.item?['price_refill']?.toString() ?? '');
  late final _exchange = TextEditingController(text: widget.item?['price_exchange']?.toString() ?? '');
  late int? _gasTypeId = widget.item?['gas_type'] ?? widget.available.first['id'];
  String? _error;
  bool _saving = false;

  @override
  void dispose() {
    _refill.dispose();
    _exchange.dispose();
    super.dispose();
  }

  Future<void> _save() async {
    final refill = _refill.text.trim();
    final exchange = _exchange.text.trim();
    if (double.tryParse(refill) == null || double.tryParse(exchange) == null) {
      setState(() => _error = 'Enter both prices as numbers.');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final item = widget.item;
    final result = item == null
        ? await ApiService.addInventory(gasTypeId: _gasTypeId!, priceRefill: refill, priceExchange: exchange)
        : await ApiService.updateInventory(item['id'], {'price_refill': refill, 'price_exchange': exchange});
    if (!mounted) return;
    if (result['error'] != null) {
      setState(() {
        _saving = false;
        _error = result['error'].toString();
      });
      return;
    }
    Navigator.pop(context, true);
  }

  @override
  Widget build(BuildContext context) {
    final item = widget.item;
    return Padding(
      padding: EdgeInsets.fromLTRB(24, 0, 24, 24 + MediaQuery.viewInsetsOf(context).bottom),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Text(
            item == null ? 'Add gas to your shop' : 'Edit ${item['gas_type_name']} ${item['cylinder_size']}',
            style: const TextStyle(fontSize: 22, fontWeight: FontWeight.w800, letterSpacing: -0.4),
          ),
          const SizedBox(height: 4),
          const Text('Set the prices customers pay, including delivery.', style: TextStyle(color: AppColors.inkSoft)),
          const SizedBox(height: 20),
          if (item == null) ...[
            DropdownButtonFormField<int>(
              initialValue: _gasTypeId,
              decoration: const InputDecoration(labelText: 'Gas type', prefixIcon: Icon(Icons.propane_tank_rounded)),
              items: widget.available
                  .map((gas) => DropdownMenuItem<int>(
                        value: gas['id'],
                        child: Text('${gas['name']} · ${gas['cylinder_size']}'),
                      ))
                  .toList(),
              onChanged: (value) => setState(() => _gasTypeId = value),
            ),
            const SizedBox(height: 14),
          ],
          Row(
            children: [
              Expanded(
                child: AppTextField(
                  controller: _refill,
                  label: 'Refill (KSh)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.next,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: AppTextField(
                  controller: _exchange,
                  label: 'Exchange (KSh)',
                  keyboardType: const TextInputType.numberWithOptions(decimal: true),
                  textInputAction: TextInputAction.done,
                  onSubmitted: (_) => _save(),
                ),
              ),
            ],
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(_error!, style: const TextStyle(color: AppColors.danger, fontWeight: FontWeight.w600)),
          ],
          const SizedBox(height: 24),
          GradientButton(label: item == null ? 'Add to shop' : 'Save prices', loading: _saving, onPressed: _save),
        ],
      ),
    );
  }
}

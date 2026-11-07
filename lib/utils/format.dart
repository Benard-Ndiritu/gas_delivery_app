// Display helpers shared by the screens.

String formatKsh(dynamic amount) {
  final value = double.tryParse(amount?.toString() ?? '') ?? 0;
  final isWhole = value == value.roundToDouble();
  final fixed = value.abs().toStringAsFixed(isWhole ? 0 : 2);
  final parts = fixed.split('.');
  final digits = parts[0];

  final grouped = StringBuffer();
  for (var i = 0; i < digits.length; i++) {
    if (i > 0 && (digits.length - i) % 3 == 0) grouped.write(',');
    grouped.write(digits[i]);
  }
  final decimals = parts.length > 1 ? '.${parts[1]}' : '';
  return 'KSh ${value < 0 ? '-' : ''}$grouped$decimals';
}

const _months = ['Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'];

String formatDateTime(String? iso) {
  if (iso == null) return '';
  final date = DateTime.tryParse(iso)?.toLocal();
  if (date == null) return '';
  final now = DateTime.now();
  final time = '${date.hour.toString().padLeft(2, '0')}:${date.minute.toString().padLeft(2, '0')}';
  final today = DateTime(now.year, now.month, now.day);
  final day = DateTime(date.year, date.month, date.day);
  final diff = today.difference(day).inDays;
  if (diff == 0) return 'Today, $time';
  if (diff == 1) return 'Yesterday, $time';
  return '${date.day} ${_months[date.month - 1]}${date.year != now.year ? ' ${date.year}' : ''}, $time';
}

String timeAgo(String? iso) {
  final date = iso == null ? null : DateTime.tryParse(iso)?.toLocal();
  if (date == null) return '';
  final diff = DateTime.now().difference(date);
  if (diff.inMinutes < 1) return 'Just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  if (diff.inHours < 24) return '${diff.inHours} h ago';
  return formatDateTime(iso);
}

String statusLabel(String? status) {
  switch (status) {
    case 'pending':
      return 'Placed';
    case 'accepted':
      return 'Accepted';
    case 'delivering':
      return 'On the way';
    case 'completed':
      return 'Delivered';
    case 'cancelled':
      return 'Cancelled';
    default:
      return status ?? '';
  }
}

String orderTypeLabel(String? type) => type == 'exchange' ? 'Exchange' : 'Refill';

String gasLabel(dynamic order) {
  final name = order['gas_type_name'] ?? 'Gas';
  final size = order['cylinder_size'];
  return size == null ? '$name' : '$name $size';
}

bool isActiveOrder(dynamic order) => ['pending', 'accepted', 'delivering'].contains(order['status']);

String greeting() {
  final hour = DateTime.now().hour;
  if (hour < 12) return 'Good morning';
  if (hour < 17) return 'Good afternoon';
  return 'Good evening';
}

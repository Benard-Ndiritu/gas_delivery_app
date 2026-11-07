import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gas_delivery_app/main.dart';
import 'package:gas_delivery_app/screens/auth/dealer_apply_screen.dart';
import 'package:gas_delivery_app/screens/auth/forgot_password_screen.dart';
import 'package:gas_delivery_app/screens/auth/login_screen.dart';
import 'package:gas_delivery_app/screens/auth/register_screen.dart';
import 'package:gas_delivery_app/screens/customer/customer_home_screen.dart';
import 'package:gas_delivery_app/screens/customer/payment_screen.dart';
import 'package:gas_delivery_app/screens/customer/place_order_screen.dart';
import 'package:gas_delivery_app/screens/dealer/dealer_home_screen.dart';
import 'package:gas_delivery_app/utils/format.dart';

/// Renders each screen on a typical phone-sized surface and fails on layout
/// errors such as overflows. Network calls fail in tests, so screens that load
/// data show their error state.
void main() {
  setUp(() => SharedPreferences.setMockInitialValues({}));

  Future<void> render(WidgetTester tester, Widget screen) async {
    tester.view.physicalSize = const Size(1080, 2340); // 360 x 780 logical
    tester.view.devicePixelRatio = 3;
    addTearDown(tester.view.reset);
    await tester.pumpWidget(MyApp(home: screen));
    await tester.pump(const Duration(milliseconds: 800));
    expect(tester.takeException(), isNull);
  }

  final screens = <String, Widget>{
    'login': const LoginScreen(),
    'register': const RegisterScreen(),
    'dealer apply': const DealerApplyScreen(),
    'forgot password': const ForgotPasswordScreen(),
    'customer home': const CustomerHomeScreen(),
    'place order': const PlaceOrderScreen(),
    'payment': const PaymentScreen(orderId: 12, amount: '2500.00'),
    'dealer home': const DealerHomeScreen(),
  };

  screens.forEach((name, screen) {
    testWidgets('$name renders without layout errors', (tester) => render(tester, screen));
  });

  testWidgets('customer home tabs switch', (tester) async {
    await render(tester, const CustomerHomeScreen());
    await tester.tap(find.text('Support'));
    await tester.pump(const Duration(milliseconds: 400));
    expect(find.text("We're here to help"), findsOneWidget);
    expect(tester.takeException(), isNull);
  });

  test('formatKsh groups thousands', () {
    expect(formatKsh('2500.00'), 'KSh 2,500');
    expect(formatKsh(1234567.5), 'KSh 1,234,567.50');
    expect(formatKsh(null), 'KSh 0');
  });
}

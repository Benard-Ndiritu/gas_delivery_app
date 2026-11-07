import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:gas_delivery_app/main.dart';
import 'package:gas_delivery_app/screens/auth/login_screen.dart';

void main() {
  setUp(() {
    SharedPreferences.setMockInitialValues({});
  });

  testWidgets('Shows the login screen when no session is stored', (WidgetTester tester) async {
    await tester.pumpWidget(const MyApp());
    // Let the AuthGate future resolve (the login screen animates forever, so no pumpAndSettle).
    await tester.pump();
    await tester.pump(const Duration(milliseconds: 100));

    expect(find.byType(LoginScreen), findsOneWidget);
    expect(find.byType(TextField), findsWidgets);
  });
}

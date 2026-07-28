import 'package:flutter/material.dart';
import 'package:gas_delivery_app/screens/auth/login_screen.dart';
import 'package:gas_delivery_app/screens/auth/register_screen.dart';
import 'package:gas_delivery_app/screens/customer/customer_home_screen.dart';
import 'package:gas_delivery_app/screens/dealer/dealer_home_screen.dart';
import 'package:gas_delivery_app/screens/auth/forgot_password_screen.dart';
import 'package:gas_delivery_app/screens/auth/verify_otp_screen.dart';
import 'package:gas_delivery_app/screens/auth/reset_password_screen.dart';
import 'package:gas_delivery_app/screens/auth/dealer_apply_screen.dart';

void main() {
  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});
  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gas Delivery',
      debugShowCheckedModeBanner: false,
      theme: ThemeData(
        colorScheme: ColorScheme.fromSeed(seedColor: Colors.orange),
        useMaterial3: true,
      ),
      home: const LoginScreen(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/customer_home': (context) => const CustomerHomeScreen(),
        '/dealer_home': (context) => const DealerHomeScreen(),
        '/forgot_password': (context) => ForgotPasswordScreen(),
        '/verify_otp': (context) => VerifyOTPScreen(),
        '/reset_password': (context) => ResetPasswordScreen(),
        '/dealer_apply': (context) => DealerApplyScreen(),
      },
    );
  }
}

import 'package:flutter/material.dart';

import 'screens/auth/dealer_apply_screen.dart';
import 'screens/auth/forgot_password_screen.dart';
import 'screens/auth/login_screen.dart';
import 'screens/auth/register_screen.dart';
import 'screens/auth/reset_password_screen.dart';
import 'screens/auth/verify_otp_screen.dart';
import 'screens/customer/customer_home_screen.dart';
import 'screens/customer/order_history_screen.dart';
import 'screens/dealer/dealer_home_screen.dart';
import 'screens/dealer/dealer_inventory_screen.dart';
import 'screens/dealer/dealer_profile_screen.dart';
import 'services/api_service.dart';
import 'theme/app_theme.dart';
import 'widgets/common.dart';

final GlobalKey<NavigatorState> navigatorKey = GlobalKey<NavigatorState>();

void main() {
  WidgetsFlutterBinding.ensureInitialized();

  // When the session can't be refreshed any more, send the user back to login.
  ApiService.onSessionExpired = () {
    navigatorKey.currentState?.pushNamedAndRemoveUntil('/login', (route) => false);
  };

  runApp(const MyApp());
}

class MyApp extends StatelessWidget {
  const MyApp({super.key, this.home});

  /// Overridable for tests.
  final Widget? home;

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: 'Gas Delivery',
      navigatorKey: navigatorKey,
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      home: home ?? const AuthGate(),
      routes: {
        '/login': (context) => const LoginScreen(),
        '/register': (context) => const RegisterScreen(),
        '/customer_home': (context) => const CustomerHomeScreen(),
        '/dealer_home': (context) => const DealerHomeScreen(),
        '/dealer_inventory': (context) => const DealerInventoryScreen(),
        '/dealer_profile': (context) => const DealerProfileScreen(),
        '/forgot_password': (context) => const ForgotPasswordScreen(),
        '/verify_otp': (context) => const VerifyOTPScreen(),
        '/reset_password': (context) => const ResetPasswordScreen(),
        '/dealer_apply': (context) => const DealerApplyScreen(),
        '/order_history': (context) => const OrderHistoryScreen(),
      },
    );
  }
}

/// Opens the right home screen if a session is stored, otherwise the login screen.
class AuthGate extends StatefulWidget {
  const AuthGate({super.key});

  @override
  State<AuthGate> createState() => _AuthGateState();
}

class _AuthGateState extends State<AuthGate> {
  late final Future<String?> _role = _storedRole();

  Future<String?> _storedRole() async {
    if (!await ApiService.isLoggedIn()) return null;
    return ApiService.getRole();
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<String?>(
      future: _role,
      builder: (context, snapshot) {
        if (snapshot.connectionState != ConnectionState.done) {
          return const _Splash();
        }
        switch (snapshot.data) {
          case 'CUSTOMER':
            return const CustomerHomeScreen();
          case 'DEALER':
            return const DealerHomeScreen();
          default:
            return const LoginScreen();
        }
      },
    );
  }
}

class _Splash extends StatelessWidget {
  const _Splash();

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(gradient: AppColors.night),
        child: const Stack(
          children: [
            GlowBlobs(),
            Center(
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  BrandMark(size: 84),
                  SizedBox(height: 24),
                  Text(
                    'Gas Delivery',
                    style: TextStyle(color: Colors.white, fontSize: 28, fontWeight: FontWeight.w800, letterSpacing: -0.6),
                  ),
                  SizedBox(height: 6),
                  Text('Cooking gas, delivered fast.', style: TextStyle(color: Colors.white60)),
                  SizedBox(height: 32),
                  SizedBox(
                    width: 22,
                    height: 22,
                    child: CircularProgressIndicator(strokeWidth: 2.4, color: AppColors.amber),
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}

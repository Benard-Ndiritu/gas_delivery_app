import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://gas-delivery-backend-ekqu.onrender.com/api';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('access_token');
  }

  static Future<void> saveToken(String token, String role) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('access_token', token);
    await prefs.setString('role', role);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.clear();
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('role');
  }

  static Future<Map<String, dynamic>> login(
    String phone,
    String password,
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/login/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'phone_number': phone, 'password': password}),
    );
    print('STATUS: ${response.statusCode}');
    print('BODY: ${response.body}');
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> register(
    String phone,
    String password,
    String role, {
    String? email,
  }
  ) async {
    final response = await http.post(
      Uri.parse('$baseUrl/users/register/'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({
        'phone_number': phone,
        'password': password,
        'role': role,
        if (email != null && email.isNotEmpty) 'email': email,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getGasTypes() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/gas/types/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> placeOrder(
    int gasTypeId,
    String orderType,
    double lat,
    double lon,
  ) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/orders/place/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({
        'gas_type_id': gasTypeId,
        'order_type': orderType,
        'latitude': lat,
        'longitude': lon,
      }),
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getMyOrders() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/orders/my/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<List<dynamic>> getDealerOrders() async {
    final token = await getToken();
    final response = await http.get(
      Uri.parse('$baseUrl/orders/dealer/'),
      headers: {'Authorization': 'Bearer $token'},
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> updateOrderStatus(
    int orderId,
    String status,
  ) async {
    final token = await getToken();
    final response = await http.put(
      Uri.parse('$baseUrl/orders/$orderId/status/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'status': status}),
    );
    return jsonDecode(response.body);
  }

  static Future<Map<String, dynamic>> initiateMpesaPayment(int orderId) async {
    final token = await getToken();
    final response = await http.post(
      Uri.parse('$baseUrl/payments/mpesa-stk/'),
      headers: {
        'Authorization': 'Bearer $token',
        'Content-Type': 'application/json',
      },
      body: jsonEncode({'order_id': orderId}),
    );
    return jsonDecode(response.body);
  }
  static Future<Map<String, dynamic>> getPaymentStatus(int orderId) async {
  final token = await getToken();
  final response = await http.get(
    Uri.parse('$baseUrl/payments/status/$orderId/'),
    headers: {'Authorization': 'Bearer $token'},
  );
  return jsonDecode(response.body);
}
  static Future<Map<String, dynamic>> requestPasswordResetOTP(String email) async {
  final response = await http.post(
    Uri.parse('$baseUrl/users/request-otp/'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email}),
  );
  final data = jsonDecode(response.body);
  return {
    'success': response.statusCode == 200,
    'message': data['message'] ?? data['error'],
  };
  
}

static Future<Map<String, dynamic>> verifyPasswordResetOTP(String email, String otp) async {
  final response = await http.post(
    Uri.parse('$baseUrl/users/verify-otp/'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'otp': otp}),
  );
  final data = jsonDecode(response.body);
  return {
    'success': response.statusCode == 200,
    'message': data['message'] ?? data['error'],
  };
}

static Future<Map<String, dynamic>> getDealerProfile() async {
  final token = await getToken();
  final response = await http.get(
    Uri.parse('$baseUrl/dealers/application/status/'),
    headers: {'Authorization': 'Bearer $token'},
  );
  return jsonDecode(response.body);
}

static Future<Map<String, dynamic>> resetPassword(String email, String otp, String newPassword) async {
  final response = await http.post(
    Uri.parse('$baseUrl/users/reset-password/'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({'email': email, 'otp': otp, 'new_password': newPassword}),
  );
  final data = jsonDecode(response.body);
  return {
    'success': response.statusCode == 200,
    'message': data['message'] ?? data['error'],
  };
}

static Future<Map<String, dynamic>> applyAsDealer({
  required String phoneNumber,
  required String password,
  required String name,
  required String shopName,
  required int deliveryRadius,
  required String email,  // String not string
}) async {
  final response = await http.post(
    Uri.parse('$baseUrl/dealers/apply/'),
    headers: {'Content-Type': 'application/json'},
    body: jsonEncode({
      'phone_number': phoneNumber,
      'password': password,
      'name': name,
      'shop_name': shopName,
      'delivery_radius': deliveryRadius,
      'email': email,
    }),
  );
  final data = jsonDecode(response.body);
  return {
    'success': response.statusCode == 201,
    'message': data['message'] ?? data['error'],
  };
}

}

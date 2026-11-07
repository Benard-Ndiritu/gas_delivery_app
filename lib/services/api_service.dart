import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;
import 'package:shared_preferences/shared_preferences.dart';

/// Error with a message that is safe to show to the user.
class ApiException implements Exception {
  final String message;
  final int? statusCode;

  ApiException(this.message, [this.statusCode]);

  @override
  String toString() => message;
}

class ApiService {
  /// Override per build: flutter build apk --dart-define=API_BASE_URL=https://.../api
  static const String baseUrl = String.fromEnvironment(
    'API_BASE_URL',
    defaultValue: 'https://gas-delivery-backend-ekqu.onrender.com/api',
  );

  // Generous, because free hosting tiers can take a while to wake up.
  static const Duration _timeout = Duration(seconds: 60);

  static const _kAccess = 'access_token';
  static const _kRefresh = 'refresh_token';
  static const _kRole = 'role';
  static const _kDealerId = 'dealer_id';

  /// Called when the session can no longer be refreshed (user must log in again).
  static void Function()? onSessionExpired;

  static Future<bool>? _refreshing;

  // ---------------------------------------------------------------------------
  // Session storage
  // ---------------------------------------------------------------------------

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kAccess);
  }

  static Future<String?> getRole() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRole);
  }

  static Future<bool> isLoggedIn() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString(_kRefresh) != null && prefs.getString(_kRole) != null;
  }

  static Future<void> saveToken(String token, String role, {String? refresh, int? dealerId}) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString(_kAccess, token);
    await prefs.setString(_kRole, role);
    if (refresh != null) await prefs.setString(_kRefresh, refresh);
    if (dealerId != null) await prefs.setInt(_kDealerId, dealerId);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    for (final key in [_kAccess, _kRefresh, _kRole, _kDealerId]) {
      await prefs.remove(key);
    }
  }

  /// Revoke the refresh token on the server (best effort) and clear the session.
  static Future<void> logout() async {
    final prefs = await SharedPreferences.getInstance();
    final refresh = prefs.getString(_kRefresh);
    if (refresh != null) {
      try {
        await _send('POST', '/users/logout/', body: {'refresh': refresh}, auth: false);
      } catch (_) {
        // Ignore: we're logging out locally regardless.
      }
    }
    await clearToken();
  }

  // ---------------------------------------------------------------------------
  // HTTP plumbing
  // ---------------------------------------------------------------------------

  static Future<http.Response> _send(
    String method,
    String path, {
    Object? body,
    bool auth = true,
    bool retryOnUnauthorized = true,
  }) async {
    final headers = <String, String>{
      'Content-Type': 'application/json',
      'Accept': 'application/json',
    };
    if (auth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }

    final uri = Uri.parse('$baseUrl$path');
    final encoded = body == null ? null : jsonEncode(body);

    http.Response response;
    try {
      switch (method) {
        case 'GET':
          response = await http.get(uri, headers: headers).timeout(_timeout);
          break;
        case 'POST':
          response = await http.post(uri, headers: headers, body: encoded).timeout(_timeout);
          break;
        case 'PUT':
          response = await http.put(uri, headers: headers, body: encoded).timeout(_timeout);
          break;
        case 'PATCH':
          response = await http.patch(uri, headers: headers, body: encoded).timeout(_timeout);
          break;
        case 'DELETE':
          response = await http.delete(uri, headers: headers).timeout(_timeout);
          break;
        default:
          throw ArgumentError('Unsupported method $method');
      }
    } on TimeoutException {
      throw ApiException('The server took too long to respond. Please try again.');
    } on http.ClientException {
      throw ApiException('Could not reach the server. Check your internet connection.');
    }

    if (response.statusCode == 401 && auth) {
      if (retryOnUnauthorized && await _refreshAccessToken()) {
        return _send(method, path, body: body, auth: auth, retryOnUnauthorized: false);
      }
      await clearToken();
      onSessionExpired?.call();
    }
    return response;
  }

  /// Exchange the stored refresh token for a new access token. Concurrent
  /// callers share a single refresh request.
  static Future<bool> _refreshAccessToken() {
    return _refreshing ??= () async {
      try {
        final prefs = await SharedPreferences.getInstance();
        final refresh = prefs.getString(_kRefresh);
        if (refresh == null) return false;
        final response = await _send(
          'POST',
          '/users/token/refresh/',
          body: {'refresh': refresh},
          auth: false,
        );
        if (response.statusCode != 200) return false;
        final data = _decode(response);
        if (data is! Map || data['access'] == null) return false;
        await prefs.setString(_kAccess, data['access']);
        if (data['refresh'] != null) await prefs.setString(_kRefresh, data['refresh']);
        return true;
      } catch (_) {
        return false;
      } finally {
        _refreshing = null;
      }
    }();
  }

  static dynamic _decode(http.Response response) {
    if (response.body.isEmpty) return <String, dynamic>{};
    try {
      return jsonDecode(utf8.decode(response.bodyBytes));
    } catch (_) {
      return <String, dynamic>{
        'error': 'Unexpected server response (${response.statusCode}). Please try again.',
      };
    }
  }

  static String _errorMessage(dynamic data, String fallback) {
    if (data is Map) {
      final error = data['error'] ?? data['detail'] ?? data['message'];
      if (error != null) return error.toString();
    }
    return fallback;
  }

  /// Request returning a JSON object. Errors come back as a map with an "error" key.
  static Future<Map<String, dynamic>> _object(String method, String path, {Object? body, bool auth = true}) async {
    try {
      final response = await _send(method, path, body: body, auth: auth);
      final data = _decode(response);
      if (data is Map<String, dynamic>) {
        if (response.statusCode >= 400 && !data.containsKey('error')) {
          data['error'] = _errorMessage(data, 'Request failed (${response.statusCode})');
        }
        return data;
      }
      return {'data': data};
    } on ApiException catch (e) {
      return {'error': e.message};
    }
  }

  /// Request returning a JSON list. Throws [ApiException] on failure.
  static Future<List<dynamic>> _list(String path) async {
    final response = await _send('GET', path);
    final data = _decode(response);
    if (response.statusCode == 200 && data is List) return data;
    throw ApiException(_errorMessage(data, 'Could not load data (${response.statusCode})'), response.statusCode);
  }

  static Future<Map<String, dynamic>> _result(String method, String path, Object body, int successCode) async {
    try {
      final response = await _send(method, path, body: body, auth: false);
      final data = _decode(response);
      return {
        'success': response.statusCode == successCode,
        'message': _errorMessage(data, 'Something went wrong'),
      };
    } on ApiException catch (e) {
      return {'success': false, 'message': e.message};
    }
  }

  // ---------------------------------------------------------------------------
  // Auth
  // ---------------------------------------------------------------------------

  /// On success the session is stored and the map contains "access" and "role".
  static Future<Map<String, dynamic>> login(String phone, String password) async {
    final result = await _object(
      'POST',
      '/users/login/',
      body: {'phone_number': phone.trim(), 'password': password},
      auth: false,
    );
    if (result['access'] != null) {
      await saveToken(
        result['access'],
        result['role'],
        refresh: result['refresh'],
        dealerId: result['dealer_id'],
      );
    }
    return result;
  }

  static Future<Map<String, dynamic>> register(String phone, String password, String role, {String? email}) {
    // The server always creates a CUSTOMER account; `role` is kept for compatibility.
    return _object('POST', '/users/register/', auth: false, body: {
      'phone_number': phone.trim(),
      'password': password,
      if (email != null && email.trim().isNotEmpty) 'email': email.trim(),
    });
  }

  static Future<Map<String, dynamic>> requestPasswordResetOTP(String email) =>
      _result('POST', '/users/request-otp/', {'email': email.trim()}, 200);

  static Future<Map<String, dynamic>> verifyPasswordResetOTP(String email, String otp) =>
      _result('POST', '/users/verify-otp/', {'email': email.trim(), 'otp': otp.trim()}, 200);

  static Future<Map<String, dynamic>> resetPassword(String email, String otp, String newPassword) =>
      _result('POST', '/users/reset-password/',
          {'email': email.trim(), 'otp': otp.trim(), 'new_password': newPassword}, 200);

  // ---------------------------------------------------------------------------
  // Customer
  // ---------------------------------------------------------------------------

  static Future<List<dynamic>> getGasTypes() => _list('/gas/types/');

  static Future<Map<String, dynamic>> placeOrder(int gasTypeId, String orderType, double lat, double lon) {
    return _object('POST', '/orders/place/', body: {
      'gas_type_id': gasTypeId,
      'order_type': orderType,
      'latitude': lat,
      'longitude': lon,
    });
  }

  static Future<List<dynamic>> getMyOrders() => _list('/orders/my/');

  static Future<Map<String, dynamic>> cancelOrder(int orderId) =>
      _object('PUT', '/orders/$orderId/cancel/');

  static Future<Map<String, dynamic>> initiateMpesaPayment(int orderId, {String? phoneNumber}) {
    return _object('POST', '/payments/mpesa-stk/', body: {
      'order_id': orderId,
      if (phoneNumber != null && phoneNumber.trim().isNotEmpty) 'phone_number': phoneNumber.trim(),
    });
  }

  static Future<Map<String, dynamic>> getPaymentStatus(int orderId) =>
      _object('GET', '/payments/status/$orderId/');

  // ---------------------------------------------------------------------------
  // Dealer
  // ---------------------------------------------------------------------------

  static Future<Map<String, dynamic>> applyAsDealer({
    required String phoneNumber,
    required String password,
    required String name,
    required String shopName,
    required int deliveryRadius,
    String email = '',
    double? latitude,
    double? longitude,
  }) {
    return _result('POST', '/dealers/apply/', {
      'phone_number': phoneNumber.trim(),
      'password': password,
      'name': name.trim(),
      'shop_name': shopName.trim(),
      'delivery_radius': deliveryRadius,
      if (email.trim().isNotEmpty) 'email': email.trim(),
      if (latitude != null) 'latitude': latitude,
      if (longitude != null) 'longitude': longitude,
    }, 201);
  }

  static Future<Map<String, dynamic>> getDealerProfile() =>
      _object('GET', '/dealers/application/status/');

  static Future<Map<String, dynamic>> updateDealerProfile(Map<String, dynamic> changes) =>
      _object('PATCH', '/dealers/update/', body: changes);

  static Future<List<dynamic>> getDealerOrders() => _list('/orders/dealer/');

  static Future<Map<String, dynamic>> updateOrderStatus(int orderId, String status) =>
      _object('PUT', '/orders/$orderId/status/', body: {'status': status});

  static Future<Map<String, dynamic>> confirmCashPayment(int orderId) =>
      _object('POST', '/payments/cash-confirm/$orderId/');

  static Future<List<dynamic>> getMyInventory() => _list('/gas/inventory/');

  static Future<Map<String, dynamic>> addInventory({
    required int gasTypeId,
    required String priceRefill,
    required String priceExchange,
    bool stockAvailable = true,
  }) {
    return _object('POST', '/gas/inventory/', body: {
      'gas_type': gasTypeId,
      'price_refill': priceRefill,
      'price_exchange': priceExchange,
      'stock_available': stockAvailable,
    });
  }

  static Future<Map<String, dynamic>> updateInventory(int id, Map<String, dynamic> changes) =>
      _object('PATCH', '/gas/inventory/$id/', body: changes);

  /// Returns an empty map on success (204), or a map with "error".
  static Future<Map<String, dynamic>> deleteInventory(int id) =>
      _object('DELETE', '/gas/inventory/$id/');
}

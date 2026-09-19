import 'dart:convert';
import 'package:http/http.dart' as http;
import 'package:image_picker/image_picker.dart';
import 'package:shared_preferences/shared_preferences.dart';

class ApiService {
  static const String baseUrl = 'https://api.finbassshamar.online';

  static Future<String?> getToken() async {
    final prefs = await SharedPreferences.getInstance();
    return prefs.getString('admin_auth_token');
  }

  static Future<void> saveToken(String token) async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setString('admin_auth_token', token);
  }

  static Future<void> clearToken() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.remove('admin_auth_token');
  }

  static const String appKey = 'mg2026-adm1n-K3y-9xQ7zR-secure';

  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = {
      'Content-Type': 'application/json; charset=utf-8',
      'x-app-key': appKey,
    };
    if (withAuth) {
      final token = await getToken();
      if (token != null) headers['Authorization'] = 'Bearer $token';
    }
    return headers;
  }

  static Future<Map<String, dynamic>> _handle(http.Response res) async {
    final body = jsonDecode(utf8.decode(res.bodyBytes));
    if (res.statusCode >= 200 && res.statusCode < 300) {
      return body;
    } else {
      final errorMsg = body['error'] ?? 'Request failed (${res.statusCode})';
      throw Exception(errorMsg);
    }
  }

  // ---------- AUTH ----------
  static Future<String> adminLogin(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/admin-login'),
      headers: await _headers(withAuth: false),
      body: jsonEncode({'email': email, 'password': password}),
    );
    final data = await _handle(res);
    return data['email'];
  }

  static Future<void> adminVerifyLogin(String email, String code) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/admin-verify-login'),
      headers: await _headers(withAuth: false),
      body: jsonEncode({'email': email, 'code': code}),
    );
    final data = await _handle(res);
    await saveToken(data['token']);
  }

  static Future<void> logout() async {
    await clearToken();
  }

  // ---------- FCM ----------
  static Future<void> saveFcmToken(String fcmToken) async {
    final res = await http.post(
      Uri.parse('$baseUrl/notifications/fcm-token'),
      headers: await _headers(),
      body: jsonEncode({'token': fcmToken}),
    );
    await _handle(res);
  }

  // ---------- USERS ----------
  static Future<List<dynamic>> getUsers() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/users'), headers: await _headers());
    final data = await _handle(res);
    return data['users'];
  }

  static Future<Map<String, dynamic>> getUserDetail(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/admin/users/$id'), headers: await _headers());
    return await _handle(res);
  }

  static Future<void> banUser(int id, String reason) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/users/$id/ban'),
      headers: await _headers(),
      body: jsonEncode({'reason': reason}),
    );
    await _handle(res);
  }

  static Future<void> unbanUser(int id) async {
    final res = await http.post(Uri.parse('$baseUrl/admin/users/$id/unban'), headers: await _headers());
    await _handle(res);
  }

  static Future<void> adjustWallet(int id, double amount, String reason) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/users/$id/adjust-wallet'),
      headers: await _headers(),
      body: jsonEncode({'amount': amount, 'reason': reason}),
    );
    await _handle(res);
  }

  static Future<Map<String, dynamic>> addViolation(int id, String reason) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/users/$id/violation'),
      headers: await _headers(),
      body: jsonEncode({'reason': reason}),
    );
    return await _handle(res);
  }

  // ---------- UPLOAD ----------
  static Future<String> uploadImage(XFile file) async {
    final token = await getToken();
    final uri = Uri.parse('$baseUrl/upload');
    final request = http.MultipartRequest('POST', uri);
    if (token != null) request.headers['Authorization'] = 'Bearer $token';
    final bytes = await file.readAsBytes();
    request.files.add(http.MultipartFile.fromBytes('file', bytes, filename: file.name));

    final streamedRes = await request.send();
    final resBody = await streamedRes.stream.bytesToString();

    if (streamedRes.statusCode != 200) {
      try {
        final err = jsonDecode(resBody);
        throw Exception(err['error'] ?? 'Upload failed (${streamedRes.statusCode})');
      } catch (e) {
        if (e is Exception) rethrow;
        throw Exception('Upload failed (${streamedRes.statusCode})');
      }
    }
    final data = jsonDecode(resBody);
    return data['url'];
  }

  // ---------- DEPOSIT METHODS ----------
  static Future<List<dynamic>> getDepositMethods() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/deposit-methods'), headers: await _headers());
    final data = await _handle(res);
    return data['methods'];
  }

  static Future<void> addDepositMethod(Map<String, dynamic> body) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/deposit-methods'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    await _handle(res);
  }

  static Future<void> updateDepositMethod(int id, Map<String, dynamic> body) async {
    final res = await http.put(
      Uri.parse('$baseUrl/admin/deposit-methods/$id'),
      headers: await _headers(),
      body: jsonEncode(body),
    );
    await _handle(res);
  }

  static Future<void> toggleDepositMethod(int id) async {
    final res = await http.post(Uri.parse('$baseUrl/admin/deposit-methods/$id/toggle'), headers: await _headers());
    await _handle(res);
  }

  static Future<void> deleteDepositMethod(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/admin/deposit-methods/$id'), headers: await _headers());
    await _handle(res);
  }
  

  // ---------- VERIFICATIONS ----------
  static Future<List<dynamic>> getVerifications() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/verifications'), headers: await _headers());
    final data = await _handle(res);
    return data['verifications'];
  }

  static Future<void> decideVerification(int userId, bool approve) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/verifications/$userId/decide'),
      headers: await _headers(),
      body: jsonEncode({'approve': approve}),
    );
    await _handle(res);
  }

  // ---------- WALLET REQUESTS ----------
  static Future<List<dynamic>> getTopups() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/topups'), headers: await _headers());
    final data = await _handle(res);
    return data['topups'];
  }

  static Future<void> decideTopup(int id, bool approve, {double? adjustedAmount}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/topups/$id/decide'),
      headers: await _headers(),
      body: jsonEncode({'approve': approve, if (adjustedAmount != null) 'adjustedAmount': adjustedAmount}),
    );
    await _handle(res);
  }

  static Future<List<dynamic>> getWithdrawals() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/withdrawals'), headers: await _headers());
    final data = await _handle(res);
    return data['withdrawals'];
  }

  static Future<void> decideWithdrawal(int id, bool approve) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/withdrawals/$id/decide'),
      headers: await _headers(),
      body: jsonEncode({'approve': approve}),
    );
    await _handle(res);
  }

  // ---------- DISPUTES ----------
  static Future<List<dynamic>> getDisputes() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/disputes'), headers: await _headers());
    final data = await _handle(res);
    return data['disputes'];
  }

  static Future<void> resolveDispute(int id, String resolution) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/disputes/$id/resolve'),
      headers: await _headers(),
      body: jsonEncode({'resolution': resolution}),
    );
    await _handle(res);
  }

  // ---------- MODERATOR CREATION ----------
  static Future<void> sendModeratorOtp(String email) async {
    final res = await http.post(
      Uri.parse('$baseUrl/subadmin/admin-create/send-otp'),
      headers: await _headers(),
      body: jsonEncode({'email': email}),
    );
    await _handle(res);
  }

  static Future<int> createModerator({
    required String email,
    required String code,
    required String password,
    required String fullName,
    required List<String> permissions,
  }) async {
    final res = await http.post(
      Uri.parse('$baseUrl/subadmin/admin-create'),
      headers: await _headers(),
      body: jsonEncode({
        'email': email,
        'code': code,
        'password': password,
        'fullName': fullName,
        'permissions': permissions,
      }),
    );
    final data = await _handle(res);
    return data['id'];
  }

  // ---------- SUPPORT REQUESTS ----------
  static Future<List<dynamic>> getSupportRequests() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/support-requests'), headers: await _headers());
    final data = await _handle(res);
    return data['requests'];
  }

  static Future<Map<String, dynamic>> getSupportMessages(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/admin/support-requests/$id/messages'), headers: await _headers());
    return await _handle(res);
  }

  static Future<void> replySupportRequest(int id, String content) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/support-requests/$id/reply'),
      headers: await _headers(),
      body: jsonEncode({'content': content}),
    );
    await _handle(res);
  }

  static Future<void> closeSupportRequest(int id) async {
    final res = await http.post(Uri.parse('$baseUrl/admin/support-requests/$id/close'), headers: await _headers());
    await _handle(res);
  }

  // ---------- ORDERS ----------
  static Future<List<dynamic>> getOrders({String status = 'all'}) async {
    final res = await http.get(Uri.parse('$baseUrl/admin/orders?status=$status'), headers: await _headers());
    final data = await _handle(res);
    return data['orders'];
  }

  static Future<Map<String, dynamic>> getOrderDetail(int id) async {
    final res = await http.get(Uri.parse('$baseUrl/admin/orders/$id'), headers: await _headers());
    return await _handle(res);
  }

  static Future<void> updateVault(int orderId, {required String email, required String password, String? recoveryCodes}) async {
    final res = await http.put(
      Uri.parse('$baseUrl/admin/orders/$orderId/vault'),
      headers: await _headers(),
      body: jsonEncode({'email': email, 'password': password, 'recoveryCodes': recoveryCodes}),
    );
    await _handle(res);
  }

  static Future<void> releaseCredentials(int orderId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/orders/$orderId/release-credentials'),
      headers: await _headers(),
    );
    await _handle(res);
  }

  static Future<void> cancelOrder(int orderId, String reason) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/orders/$orderId/cancel'),
      headers: await _headers(),
      body: jsonEncode({'reason': reason}),
    );
    await _handle(res);
  }

  static Future<List<dynamic>> getOrderMessages(int orderId, String type) async {
    final res = await http.get(
      Uri.parse('$baseUrl/admin/orders/$orderId/messages?type=$type'),
      headers: await _headers(),
    );
    final data = await _handle(res);
    return data['messages'];
  }

  static Future<void> sendOrderMessage(int orderId, String type, String content) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/orders/$orderId/messages'),
      headers: await _headers(),
      body: jsonEncode({'type': type, 'content': content}),
    );
    await _handle(res);
  }

  // ---------- LISTINGS ----------
  static Future<List<dynamic>> getAdminListings({String status = 'all'}) async {
    final res = await http.get(Uri.parse('$baseUrl/admin/listings?status=$status'), headers: await _headers());
    final data = await _handle(res);
    return data['listings'];
  }

  static Future<void> removeListing(int id, {String? reason}) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/listings/$id/remove'),
      headers: await _headers(),
      body: jsonEncode({'reason': reason}),
    );
    await _handle(res);
  }

  // ---------- BROADCAST ----------
  static Future<String> sendBroadcast(String title, String body) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/broadcast'),
      headers: await _headers(),
      body: jsonEncode({'title': title, 'body': body}),
    );
    final data = await _handle(res);
    return data['message'] ?? 'Broadcast sent';
  }

  // ---------- FINANCE ----------
  static Future<double> getCommissionRate() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/settings/commission'), headers: await _headers());
    final data = await _handle(res);
    return (data['commissionRate'] as num).toDouble();
  }

  static Future<String> updateCommissionRate(double rate) async {
    final res = await http.put(
      Uri.parse('$baseUrl/admin/settings/commission'),
      headers: await _headers(),
      body: jsonEncode({'rate': rate}),
    );
    final data = await _handle(res);
    return data['message'] ?? 'Updated';
  }

  // ---------- PROMOTIONS ----------
  static Future<List<dynamic>> getAllPromotions() async {
    final res = await http.get(Uri.parse('$baseUrl/promotions/admin/all'), headers: await _headers());
    final data = await _handle(res);
    return data['promotions'];
  }

  static Future<void> createPromotion(String title, String description, String imageUrl, String? linkUrl) async {
    final res = await http.post(
      Uri.parse('$baseUrl/promotions'),
      headers: await _headers(),
      body: jsonEncode({'title': title, 'description': description, 'imageUrl': imageUrl, 'linkUrl': linkUrl}),
    );
    await _handle(res);
  }

  static Future<void> togglePromotion(int id) async {
    final res = await http.put(Uri.parse('$baseUrl/promotions/$id/toggle'), headers: await _headers());
    await _handle(res);
  }

  static Future<void> deletePromotion(int id) async {
    final res = await http.delete(Uri.parse('$baseUrl/promotions/$id'), headers: await _headers());
    await _handle(res);
  }

  // ---------- RENTALS & INSTALLMENTS ----------
  static Future<List<dynamic>> getRentals() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/rentals'), headers: await _headers());
    final data = await _handle(res);
    return data['rentals'];
  }

  static Future<List<dynamic>> getInstallmentPlans() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/installments'), headers: await _headers());
    final data = await _handle(res);
    return data['plans'];
  }

  // ---------- REPORTS ----------
  static Future<Map<String, dynamic>> getReportsSummary() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/reports/summary'), headers: await _headers());
    return await _handle(res);
  }

  // ---------- ADMIN SETTINGS ----------
  static Future<String> changeAdminPassword(String currentPassword, String newPassword) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/admin-change-password'),
      headers: await _headers(),
      body: jsonEncode({'currentPassword': currentPassword, 'newPassword': newPassword}),
    );
    final data = await _handle(res);
    return data['message'] ?? 'Password changed';
  }

  // ---------- SUB-ADMIN APPROVAL ----------
  static Future<List<dynamic>> getSubAdminRequests() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/sub-admins/requests'), headers: await _headers());
    final data = await _handle(res);
    return data['requests'] ?? data['subAdmins'] ?? [];
  }

  static Future<void> decideSubAdmin(int userId, bool approve) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/sub-admins/$userId/decide'),
      headers: await _headers(),
      body: jsonEncode({'approve': approve}),
    );
    await _handle(res);
  }

  // ---------- SUB-ADMIN DEVICE APPROVAL / ACTIVE SUB-ADMINS ----------
  static Future<List<dynamic>> getSubAdminDeviceRequests() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/sub-admins/device-requests'), headers: await _headers());
    final data = await _handle(res);
    return data['requests'] ?? [];
  }

  static Future<void> decideSubAdminDeviceRequest(int id, bool approve) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/sub-admins/device-requests/$id/decide'),
      headers: await _headers(),
      body: jsonEncode({'approve': approve}),
    );
    await _handle(res);
  }

  static Future<List<dynamic>> getActiveSubAdmins() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/sub-admins/active'), headers: await _headers());
    final data = await _handle(res);
    return data['subAdmins'] ?? [];
  }

  static Future<void> forceLogoutSubAdmin(int userId) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/sub-admins/$userId/force-logout'),
      headers: await _headers(),
    );
    await _handle(res);
  }
}

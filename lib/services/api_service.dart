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

  static Future<Map<String, String>> _headers({bool withAuth = true}) async {
    final headers = {'Content-Type': 'application/json; charset=utf-8'};
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
}

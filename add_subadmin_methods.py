import re, sys
p = 'lib/services/api_service.dart'
s = open(p, encoding='utf-8').read()
if 'getSubAdminDeviceRequests' in s:
    print('Already added, nothing to do.')
    sys.exit(0)
body = s.rstrip()
if not body.endswith('}'):
    print('ERROR: file does not end with "}" - send me the last 10 lines.')
    sys.exit(1)
methods = '''
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
'''
s = body[:-1].rstrip() + '\n' + methods + '}\n'
open(p, 'w', encoding='utf-8').write(s)
print('Added 4 methods.')

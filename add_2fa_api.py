import re, sys
p = 'lib/services/api_service.dart'
s = open(p, encoding='utf-8').read()
if 'adminTotpGenerate' in s:
    print('Already added, nothing to do.')
    sys.exit(0)
body = s.rstrip()
if not body.endswith('}'):
    print('ERROR: file does not end with "}" - send me the last 10 lines.')
    sys.exit(1)

# Reuse exactly the headers expression the existing adminLogin uses (it must send x-app-key)
hdr = 'await _headers(withAuth: false)'
m = re.search(r'adminLogin\(.*?headers:\s*(.+?),\s*\n', s, re.S)
if m:
    hdr = m.group(1).strip()
print('Headers used for pre-login calls:', hdr)

methods = '''
  // ---------- ADMIN 2FA (Google Authenticator) ----------
  static Future<Map<String, dynamic>> adminLoginFull(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/admin-login'),
      headers: HDR,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return await _handle(res);
  }

  static Future<void> adminVerifyTotp(String email, String code) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/admin-verify-totp'),
      headers: HDR,
      body: jsonEncode({'email': email, 'code': code}),
    );
    final data = await _handle(res);
    await saveToken(data['token']);
  }

  static Future<Map<String, dynamic>> adminTotpGenerate(String email, String password) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/admin-totp-generate'),
      headers: HDR,
      body: jsonEncode({'email': email, 'password': password}),
    );
    return await _handle(res);
  }

  static Future<String> adminTotpConfirm(String email, String password, String secret, String code) async {
    final res = await http.post(
      Uri.parse('$baseUrl/auth/admin-totp-confirm'),
      headers: HDR,
      body: jsonEncode({'email': email, 'password': password, 'secret': secret, 'code': code}),
    );
    final data = await _handle(res);
    return data['message'] ?? 'Enabled';
  }
'''.replace('HDR', hdr)
s = body[:-1].rstrip() + '\n' + methods + '}\n'
open(p, 'w', encoding='utf-8').write(s)
print('Added 4 methods.')

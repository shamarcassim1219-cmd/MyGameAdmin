#!/usr/bin/env python3
"""Admin app: adds Settings -> "Free Fire Info API" (change the API URL and key).
Run from ~/MyGameAdmin:  python3 apply_ff_admin.py"""
import os, sys

API = 'lib/services/api_service.dart'
SET = 'lib/screens/admin_settings_screen.dart'
done = []

# ---- api_service.dart ----
s = open(API, encoding='utf-8').read()
if 'getFfConfig' not in s:
    body = s.rstrip()
    if not body.endswith('}'):
        print('ERROR: api_service.dart does not end with "}". Nothing changed.')
        sys.exit(1)
    methods = '''
  // ---------- FREE FIRE INFO API SETTINGS ----------
  static Future<Map<String, dynamic>> getFfConfig() async {
    final res = await http.get(Uri.parse('$baseUrl/admin/ff-config'), headers: await _headers());
    return await _handle(res);
  }

  static Future<void> saveFfConfig(String url, String key) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/ff-config'),
      headers: await _headers(),
      body: jsonEncode({'url': url, 'key': key}),
    );
    await _handle(res);
  }

  static Future<Map<String, dynamic>> testFfConfig(String url, String key) async {
    final res = await http.post(
      Uri.parse('$baseUrl/admin/ff-config/test'),
      headers: await _headers(),
      body: jsonEncode({'url': url, 'key': key}),
    );
    return await _handle(res);
  }
'''
    open(API, 'w', encoding='utf-8').write(body[:-1].rstrip() + '\n' + methods + '}\n')
    done.append('API methods added')

# ---- admin_settings_screen.dart ----
t = open(SET, encoding='utf-8').read()
if 'FfApiSettingsScreen' not in t:
    anchors = [
        "                label: const Text('Google Authenticator (2FA)'),\n              ),\n            ),\n",
        "                label: const Text('Sub-Admin Requests'),\n              ),\n            ),\n",
    ]
    anchor = next((a for a in anchors if t.count(a) == 1), None)
    if anchor is None:
        print('ERROR: could not find where to add the button in admin_settings_screen.dart. Nothing else changed.')
        sys.exit(1)
    button = """            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const FfApiSettingsScreen())),
                icon: const Icon(Icons.sports_esports_outlined),
                label: const Text('Free Fire Info API'),
              ),
            ),
"""
    t = t.replace(anchor, anchor + button, 1)
    imp = "import 'sub_admin_requests_screen.dart';\n"
    if imp not in t:
        print('ERROR: import anchor not found. Nothing else changed.')
        sys.exit(1)
    t = t.replace(imp, imp + "import 'ff_api_settings_screen.dart';\n", 1)
    open(SET, 'w', encoding='utf-8').write(t)
    done.append('Settings button added')

print('Done:' if done else 'Already done.')
for d in done:
    print('  +', d)
if not os.path.exists('lib/screens/ff_api_settings_screen.dart'):
    print('WARNING: copy lib/screens/ff_api_settings_screen.dart into the project first!')

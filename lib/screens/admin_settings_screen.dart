import 'package:flutter/material.dart';
import 'package:package_info_plus/package_info_plus.dart';
import '../main.dart';
import '../services/api_service.dart';
import '../services/update_service.dart';
import 'create_moderator_screen.dart';
import 'sub_admin_requests_screen.dart';
import 'more_tools_admin_screen.dart';
import 'totp_setup_screen.dart';

class AdminSettingsScreen extends StatefulWidget {
  const AdminSettingsScreen({super.key});

  @override
  State<AdminSettingsScreen> createState() => _AdminSettingsScreenState();
}

class _AdminSettingsScreenState extends State<AdminSettingsScreen> {
  final _currentCtrl = TextEditingController();
  final _newCtrl = TextEditingController();
  final _confirmCtrl = TextEditingController();
  bool _obscureCurrent = true;
  bool _obscureNew = true;
  bool _saving = false;
  bool _checkingUpdate = false;
  String? _error;
  String _version = '';

  @override
  void initState() {
    super.initState();
    _loadVersion();
  }

  Future<void> _loadVersion() async {
    try {
      final info = await PackageInfo.fromPlatform();
      setState(() => _version = '${info.version} (${info.buildNumber})');
    } catch (_) {}
  }

  Future<void> _checkForUpdate() async {
    setState(() => _checkingUpdate = true);
    await UpdateService.checkForUpdate(context, silent: false);
    if (mounted) setState(() => _checkingUpdate = false);
  }

  @override
  void dispose() {
    _currentCtrl.dispose();
    _newCtrl.dispose();
    _confirmCtrl.dispose();
    super.dispose();
  }

  Future<void> _changePassword() async {
    final current = _currentCtrl.text.trim();
    final newPass = _newCtrl.text.trim();
    final confirm = _confirmCtrl.text.trim();

    if (current.isEmpty || newPass.isEmpty) {
      setState(() => _error = 'Fill in both password fields');
      return;
    }
    if (newPass.length < 6) {
      setState(() => _error = 'New password must be at least 6 characters');
      return;
    }
    if (newPass != confirm) {
      setState(() => _error = 'New password and confirmation do not match');
      return;
    }

    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      final msg = await ApiService.changeAdminPassword(current, newPass);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(msg)));
        _currentCtrl.clear();
        _newCtrl.clear();
        _confirmCtrl.clear();
      }
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Settings')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const CreateModeratorScreen())),
                icon: const Icon(Icons.person_add_alt_1_outlined),
                label: const Text('Create Moderator Account'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const SubAdminRequestsScreen())),
                icon: const Icon(Icons.pending_actions_outlined),
                label: const Text('Sub-Admin Requests'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const MoreToolsAdminScreen())),
                icon: const Icon(Icons.apps),
                label: const Text('More Tools (Free Fire Check)'),
              ),
            ),
            const SizedBox(height: 12),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: OutlinedButton.icon(
                onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const TotpSetupScreen())),
                icon: const Icon(Icons.security),
                label: const Text('Google Authenticator (2FA)'),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(color: AppColors.border),
            const SizedBox(height: 16),
            const Text('Change Password', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            TextField(
              controller: _currentCtrl,
              obscureText: _obscureCurrent,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Current Password',
                suffixIcon: IconButton(
                  icon: Icon(_obscureCurrent ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.hint, size: 20),
                  onPressed: () => setState(() => _obscureCurrent = !_obscureCurrent),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _newCtrl,
              obscureText: _obscureNew,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'New Password',
                suffixIcon: IconButton(
                  icon: Icon(_obscureNew ? Icons.visibility_off_outlined : Icons.visibility_outlined, color: AppColors.hint, size: 20),
                  onPressed: () => setState(() => _obscureNew = !_obscureNew),
                ),
              ),
            ),
            const SizedBox(height: 14),
            TextField(
              controller: _confirmCtrl,
              obscureText: _obscureNew,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Confirm New Password'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton(
                onPressed: _saving ? null : _changePassword,
                child: _saving
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Update Password'),
              ),
            ),
            const SizedBox(height: 32),
            const Divider(color: AppColors.border),
            const SizedBox(height: 16),
            const Text('About', style: TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Row(
              children: [
                const Icon(Icons.admin_panel_settings, color: AppColors.primary, size: 20),
                const SizedBox(width: 10),
                const Text('MYGame Admin', style: TextStyle(color: Colors.white, fontSize: 14)),
                const Spacer(),
                Text(_version, style: const TextStyle(color: AppColors.hint, fontSize: 12)),
              ],
            ),
            const SizedBox(height: 14),
            SizedBox(
              width: double.infinity,
              height: 48,
              child: OutlinedButton.icon(
                onPressed: _checkingUpdate ? null : _checkForUpdate,
                icon: _checkingUpdate
                    ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                    : const Icon(Icons.system_update_alt_outlined),
                label: Text(_checkingUpdate ? 'Checking...' : 'Check for Updates'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

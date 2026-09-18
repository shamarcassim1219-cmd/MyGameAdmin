import 'package:flutter/material.dart';
import 'package:url_launcher/url_launcher.dart';
import '../main.dart';
import '../services/api_service.dart';

class CreateModeratorScreen extends StatefulWidget {
  const CreateModeratorScreen({super.key});

  @override
  State<CreateModeratorScreen> createState() => _CreateModeratorScreenState();
}

class _CreateModeratorScreenState extends State<CreateModeratorScreen> {
  final _emailCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();
  final _nameCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _phoneCtrl = TextEditingController();

  bool _otpSent = false;
  bool _sending = false;
  bool _creating = false;
  String? _error;

  final Map<String, bool> _permissions = {
    'verification': false,
    'orders': false,
    'disputes': false,
    'support': false,
  };

  final Map<String, String> _permissionLabels = {
    'verification': 'Verification',
    'orders': 'Orders',
    'disputes': 'Disputes',
    'support': 'Support Requests',
  };

  @override
  void dispose() {
    _emailCtrl.dispose();
    _codeCtrl.dispose();
    _nameCtrl.dispose();
    _passCtrl.dispose();
    _phoneCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendOtp() async {
    final email = _emailCtrl.text.trim();
    if (email.isEmpty || !email.contains('@')) {
      setState(() => _error = 'Enter a valid email');
      return;
    }
    setState(() {
      _sending = true;
      _error = null;
    });
    try {
      await ApiService.sendModeratorOtp(email);
      setState(() => _otpSent = true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Verification code sent to email')));
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _sending = false);
    }
  }

  Future<void> _create() async {
    final email = _emailCtrl.text.trim();
    final code = _codeCtrl.text.trim();
    final name = _nameCtrl.text.trim();
    final password = _passCtrl.text.trim();

    if (code.isEmpty) {
      setState(() => _error = 'Enter the verification code');
      return;
    }
    if (name.isEmpty) {
      setState(() => _error = 'Enter a full name');
      return;
    }
    if (password.length < 6) {
      setState(() => _error = 'Password must be at least 6 characters');
      return;
    }
    final selectedPerms = _permissions.entries.where((e) => e.value).map((e) => e.key).toList();
    if (selectedPerms.isEmpty) {
      setState(() => _error = 'Select at least one section');
      return;
    }

    setState(() {
      _creating = true;
      _error = null;
    });
    try {
      await ApiService.createModerator(
        email: email,
        code: code,
        password: password,
        fullName: name,
        permissions: selectedPerms,
      );
      if (mounted) await _showShareSheet(email, password, name);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _creating = false);
    }
  }

  Future<void> _showShareSheet(String email, String password, String name) async {
    final message =
        'Hi $name, your MYGame Moderator account is ready.\n\n'
        'Email: $email\n'
        'Password: $password\n\n'
        'Download the Moderator app and log in with these details:\n'
        'https://github.com/shamarcassim1219-cmd/SubAdminApp/releases/latest';

    final phone = _phoneCtrl.text.trim().replaceAll(RegExp(r'[^0-9]'), '');

    if (!mounted) return;
    await showModalBottomSheet(
      context: context,
      backgroundColor: AppColors.bg,
      builder: (_) => Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Row(
              children: [
                Icon(Icons.check_circle, color: Colors.greenAccent),
                SizedBox(width: 8),
                Text('Moderator Created', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
              ],
            ),
            const SizedBox(height: 16),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(10)),
              child: Text(message, style: const TextStyle(color: AppColors.hint, fontSize: 13)),
            ),
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton.icon(
                icon: const Icon(Icons.chat_bubble_outline),
                label: const Text('Send via WhatsApp'),
                onPressed: () async {
                  final encoded = Uri.encodeComponent(message);
                  final uri = phone.isNotEmpty
                      ? Uri.parse('https://wa.me/$phone?text=$encoded')
                      : Uri.parse('https://wa.me/?text=$encoded');
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
                },
              ),
            ),
            const SizedBox(height: 10),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: OutlinedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.pop(context, true);
                },
                child: const Text('Done'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Create Moderator')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            TextField(
              controller: _emailCtrl,
              enabled: !_otpSent,
              keyboardType: TextInputType.emailAddress,
              style: const TextStyle(color: Colors.white),
              decoration: InputDecoration(
                labelText: 'Email',
                suffixIcon: _otpSent
                    ? const Icon(Icons.check_circle, color: Colors.greenAccent, size: 20)
                    : null,
              ),
            ),
            if (!_otpSent) ...[
              const SizedBox(height: 14),
              SizedBox(
                width: double.infinity,
                height: 48,
                child: OutlinedButton(
                  onPressed: _sending ? null : _sendOtp,
                  child: _sending
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Text('Send Verification Code'),
                ),
              ),
            ],
            if (_otpSent) ...[
              const SizedBox(height: 14),
              TextField(
                controller: _codeCtrl,
                keyboardType: TextInputType.number,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Verification Code'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Full Name'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _passCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Password (min 6 chars)'),
              ),
              const SizedBox(height: 14),
              TextField(
                controller: _phoneCtrl,
                keyboardType: TextInputType.phone,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'WhatsApp Number (optional, with country code)', hintText: 'e.g. 94771234567'),
              ),
              const SizedBox(height: 20),
              const Text('Section Access', style: TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
              const SizedBox(height: 8),
              ..._permissionLabels.entries.map((e) => CheckboxListTile(
                    value: _permissions[e.key],
                    onChanged: (v) => setState(() => _permissions[e.key] = v ?? false),
                    title: Text(e.value, style: const TextStyle(color: Colors.white, fontSize: 14)),
                    activeColor: AppColors.primary,
                    contentPadding: EdgeInsets.zero,
                    controlAffinity: ListTileControlAffinity.leading,
                  )),
            ],
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            if (_otpSent) ...[
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _creating ? null : _create,
                  child: _creating
                      ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                      : const Text('Create Moderator Account'),
                ),
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

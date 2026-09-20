import 'dart:convert';
import 'dart:typed_data';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import '../main.dart';
import '../services/api_service.dart';

/// Set up Google Authenticator (TOTP) for an admin account.
/// Step 1: confirm email + password  ->  Step 2: scan QR + enter code  ->  Step 3: done.
class TotpSetupScreen extends StatefulWidget {
  const TotpSetupScreen({super.key});

  @override
  State<TotpSetupScreen> createState() => _TotpSetupScreenState();
}

class _TotpSetupScreenState extends State<TotpSetupScreen> {
  final _emailCtrl = TextEditingController();
  final _passCtrl = TextEditingController();
  final _codeCtrl = TextEditingController();

  int _step = 0; // 0 = credentials, 1 = scan + confirm, 2 = done
  bool _loading = false;
  String? _error;
  String? _secret;
  Uint8List? _qrBytes;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passCtrl.dispose();
    _codeCtrl.dispose();
    super.dispose();
  }

  Future<void> _generate() async {
    if (_emailCtrl.text.trim().isEmpty || _passCtrl.text.isEmpty) {
      setState(() => _error = 'Email and password required');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.adminTotpGenerate(_emailCtrl.text.trim(), _passCtrl.text);
      final qr = (data['qrCode'] ?? '').toString();
      Uint8List? bytes;
      if (qr.contains(',')) {
        try {
          bytes = base64Decode(qr.split(',').last);
        } catch (_) {}
      }
      setState(() {
        _secret = data['secret']?.toString();
        _qrBytes = bytes;
        _step = 1;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _confirm() async {
    if (_codeCtrl.text.trim().length != 6) {
      setState(() => _error = 'Enter the 6-digit code from the app');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      await ApiService.adminTotpConfirm(
        _emailCtrl.text.trim(),
        _passCtrl.text,
        _secret ?? '',
        _codeCtrl.text.trim(),
      );
      setState(() {
        _step = 2;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Widget _spinnerOr(String label) => _loading
      ? const SizedBox(height: 20, width: 20, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
      : Text(label);

  Widget _errorText() => _error == null
      ? const SizedBox.shrink()
      : Padding(
          padding: const EdgeInsets.only(bottom: 12),
          child: Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
        );

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Google Authenticator')),
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: _step == 0 ? _credentialsStep() : _step == 1 ? _scanStep() : _doneStep(),
        ),
      ),
    );
  }

  Widget _credentialsStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Icon(Icons.security, size: 48, color: AppColors.primary),
        const SizedBox(height: 12),
        const Text(
          'Add a second step to your admin login. Confirm your account first.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.hint, fontSize: 13),
        ),
        const SizedBox(height: 24),
        TextField(
          controller: _emailCtrl,
          style: const TextStyle(color: Colors.white),
          keyboardType: TextInputType.emailAddress,
          decoration: const InputDecoration(labelText: 'Admin email'),
        ),
        const SizedBox(height: 14),
        TextField(
          controller: _passCtrl,
          style: const TextStyle(color: Colors.white),
          obscureText: true,
          decoration: const InputDecoration(labelText: 'Password'),
        ),
        const SizedBox(height: 20),
        _errorText(),
        SizedBox(
          height: 50,
          child: ElevatedButton(onPressed: _loading ? null : _generate, child: _spinnerOr('Continue')),
        ),
      ],
    );
  }

  Widget _scanStep() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        const Text(
          '1. Open Google Authenticator (or any authenticator app)\n2. Tap + and scan this QR code\n3. Enter the 6-digit code it shows',
          style: TextStyle(color: AppColors.hint, fontSize: 13, height: 1.5),
        ),
        const SizedBox(height: 16),
        if (_qrBytes != null)
          Center(
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(color: Colors.white, borderRadius: BorderRadius.circular(12)),
              child: Image.memory(_qrBytes!, width: 220, height: 220),
            ),
          ),
        const SizedBox(height: 16),
        const Text("Can't scan? Enter this key manually:",
            style: TextStyle(color: AppColors.hint, fontSize: 12), textAlign: TextAlign.center),
        const SizedBox(height: 6),
        InkWell(
          onTap: () {
            Clipboard.setData(ClipboardData(text: _secret ?? ''));
            ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Key copied')));
          },
          child: Padding(
            padding: const EdgeInsets.symmetric(vertical: 6),
            child: SelectableText(
              _secret ?? '',
              textAlign: TextAlign.center,
              style: const TextStyle(color: AppColors.primary, fontSize: 14, letterSpacing: 1.5),
            ),
          ),
        ),
        const SizedBox(height: 16),
        TextField(
          controller: _codeCtrl,
          style: const TextStyle(color: Colors.white, letterSpacing: 6, fontSize: 20),
          textAlign: TextAlign.center,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(labelText: '6-digit code'),
        ),
        const SizedBox(height: 8),
        _errorText(),
        SizedBox(
          height: 50,
          child: ElevatedButton(onPressed: _loading ? null : _confirm, child: _spinnerOr('Verify & Enable')),
        ),
      ],
    );
  }

  Widget _doneStep() {
    return Column(
      children: [
        const SizedBox(height: 40),
        const Icon(Icons.verified_user, size: 72, color: Colors.greenAccent),
        const SizedBox(height: 16),
        const Text('Google Authenticator enabled',
            style: TextStyle(color: Colors.white, fontSize: 20, fontWeight: FontWeight.bold)),
        const SizedBox(height: 10),
        const Text(
          'From now on, login asks for the code from your authenticator app instead of an email code.\n\nKeep your phone safe. If you lose it, the account needs to be reset by the database owner.',
          textAlign: TextAlign.center,
          style: TextStyle(color: AppColors.hint, fontSize: 13),
        ),
        const SizedBox(height: 28),
        SizedBox(
          width: double.infinity,
          height: 50,
          child: ElevatedButton(onPressed: () => Navigator.pop(context), child: const Text('Done')),
        ),
      ],
    );
  }
}

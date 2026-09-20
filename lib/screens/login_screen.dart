import 'package:flutter/material.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'dashboard_screen.dart';

enum _LoginStep { credentials, emailCode, authenticator }

class LoginScreen extends StatefulWidget {
  const LoginScreen({super.key});

  @override
  State<LoginScreen> createState() => _LoginScreenState();
}

class _LoginScreenState extends State<LoginScreen> {
  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _otpCtrl = TextEditingController();
  bool _loading = false;
  _LoginStep _step = _LoginStep.credentials;
  String? _error;

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _otpCtrl.dispose();
    super.dispose();
  }

  Future<void> _sendLogin() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.isEmpty) {
      setState(() => _error = 'Email and password required');
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final data = await ApiService.adminLoginFull(_emailCtrl.text.trim(), _passwordCtrl.text);
      // Server says requiresTotp when Google Authenticator is enabled for this admin,
      // otherwise it emails a 6-digit code.
      final totp = data['requiresTotp'] == true;
      setState(() {
        _step = totp ? _LoginStep.authenticator : _LoginStep.emailCode;
        _otpCtrl.clear();
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _verifyCode() async {
    if (_otpCtrl.text.trim().isEmpty) return;
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      if (_step == _LoginStep.authenticator) {
        await ApiService.adminVerifyTotp(_emailCtrl.text.trim(), _otpCtrl.text.trim());
      } else {
        await ApiService.adminVerifyLogin(_emailCtrl.text.trim(), _otpCtrl.text.trim());
      }
      try { final t = await FirebaseMessaging.instance.getToken(); if (t != null) await ApiService.saveFcmToken(t); } catch (_) {}
      if (!mounted) return;
      Navigator.of(context).pushAndRemoveUntil(
        MaterialPageRoute(builder: (_) => const DashboardScreen()),
        (route) => false,
      );
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

  @override
  Widget build(BuildContext context) {
    final isTotp = _step == _LoginStep.authenticator;
    return Scaffold(
      backgroundColor: AppColors.bg,
      body: Center(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.admin_panel_settings, size: 60, color: AppColors.primary),
              const SizedBox(height: 16),
              const Text('MYGame Admin', style: TextStyle(color: Colors.white, fontSize: 22, fontWeight: FontWeight.bold)),
              const SizedBox(height: 32),
              if (_step == _LoginStep.credentials) ...[
                TextField(
                  controller: _emailCtrl,
                  style: const TextStyle(color: Colors.white),
                  keyboardType: TextInputType.emailAddress,
                  decoration: const InputDecoration(labelText: 'Email'),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _passwordCtrl,
                  style: const TextStyle(color: Colors.white),
                  obscureText: true,
                  decoration: const InputDecoration(labelText: 'Password'),
                ),
                const SizedBox(height: 20),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _sendLogin,
                    child: _spinnerOr('Continue'),
                  ),
                ),
              ] else ...[
                Icon(isTotp ? Icons.phonelink_lock : Icons.mark_email_read_outlined,
                    size: 36, color: AppColors.primary),
                const SizedBox(height: 10),
                Text(
                  isTotp
                      ? 'Open Google Authenticator and enter the 6-digit code for MYGame Admin'
                      : 'Code sent to ${_emailCtrl.text.trim()}',
                  textAlign: TextAlign.center,
                  style: const TextStyle(color: AppColors.hint, fontSize: 13),
                ),
                const SizedBox(height: 14),
                TextField(
                  controller: _otpCtrl,
                  autofocus: true,
                  style: const TextStyle(color: Colors.white, letterSpacing: 6, fontSize: 20),
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  maxLength: 6,
                  onSubmitted: (_) => _loading ? null : _verifyCode(),
                  decoration: InputDecoration(labelText: isTotp ? 'Authenticator Code' : 'Verification Code'),
                ),
                const SizedBox(height: 12),
                if (_error != null) ...[
                  Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  const SizedBox(height: 12),
                ],
                SizedBox(
                  width: double.infinity,
                  height: 50,
                  child: ElevatedButton(
                    onPressed: _loading ? null : _verifyCode,
                    child: _spinnerOr('Verify & Login'),
                  ),
                ),
                TextButton(
                  onPressed: () => setState(() {
                    _step = _LoginStep.credentials;
                    _error = null;
                  }),
                  child: const Text('Back', style: TextStyle(color: AppColors.hint)),
                ),
              ],
            ],
          ),
        ),
      ),
    );
  }
}

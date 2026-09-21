import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

/// Change the Free Fire info API (URL + key) without touching the server.
class FfApiSettingsScreen extends StatefulWidget {
  const FfApiSettingsScreen({super.key});

  @override
  State<FfApiSettingsScreen> createState() => _FfApiSettingsScreenState();
}

class _FfApiSettingsScreenState extends State<FfApiSettingsScreen> {
  final _urlCtrl = TextEditingController();
  final _keyCtrl = TextEditingController();
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  bool _obscure = true;
  String _keyHint = '';
  String? _error;
  String? _testMessage;
  bool? _testOk;

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _urlCtrl.dispose();
    _keyCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    try {
      final data = await ApiService.getFfConfig();
      if (!mounted) return;
      setState(() {
        _urlCtrl.text = (data['url'] ?? '').toString();
        _keyHint = (data['keyMasked'] ?? '').toString();
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _test() async {
    if (_urlCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Enter the API URL first');
      return;
    }
    setState(() {
      _testing = true;
      _error = null;
      _testMessage = null;
      _testOk = null;
    });
    try {
      final r = await ApiService.testFfConfig(_urlCtrl.text.trim(), _keyCtrl.text.trim());
      if (!mounted) return;
      final ok = r['ok'] == true;
      setState(() {
        _testOk = ok;
        _testMessage = ok
            ? 'API works. Sample account: ${r['nickname'] ?? '-'}'
            : '${r['message'] ?? 'Test failed'} (status ${r['status'] ?? '-'})';
      });
    } catch (e) {
      if (!mounted) return;
      setState(() {
        _testOk = false;
        _testMessage = e.toString().replaceFirst('Exception: ', '');
      });
    } finally {
      if (mounted) setState(() => _testing = false);
    }
  }

  Future<void> _save() async {
    final url = _urlCtrl.text.trim();
    if (url.isEmpty) {
      setState(() => _error = 'API URL is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await ApiService.saveFfConfig(url, _keyCtrl.text.trim());
      if (!mounted) return;
      _keyCtrl.clear();
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Saved')));
      await _load();
    } catch (e) {
      if (mounted) setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Free Fire Info API')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : SingleChildScrollView(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.stretch,
                children: [
                  const Text(
                    'The app asks this API for account info (Free Fire Info Check). '
                    'Enter the base URL only. The server adds region, uid and key by itself.',
                    style: TextStyle(color: AppColors.hint, fontSize: 13),
                  ),
                  const SizedBox(height: 16),
                  TextField(
                    controller: _urlCtrl,
                    style: const TextStyle(color: Colors.white),
                    keyboardType: TextInputType.url,
                    decoration: const InputDecoration(
                      labelText: 'API URL',
                      hintText: 'https://ff.ggbluewhale.store/api/data',
                    ),
                  ),
                  const SizedBox(height: 14),
                  TextField(
                    controller: _keyCtrl,
                    obscureText: _obscure,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'API key',
                      helperText: _keyHint.isEmpty
                          ? 'No key saved yet'
                          : 'Saved key: $_keyHint. Leave empty to keep it.',
                      suffixIcon: IconButton(
                        icon: Icon(_obscure ? Icons.visibility_off_outlined : Icons.visibility_outlined,
                            color: AppColors.hint, size: 20),
                        onPressed: () => setState(() => _obscure = !_obscure),
                      ),
                    ),
                  ),
                  if (_error != null) ...[
                    const SizedBox(height: 12),
                    Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
                  ],
                  if (_testMessage != null) ...[
                    const SizedBox(height: 12),
                    Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: (_testOk == true ? Colors.green : Colors.redAccent).withOpacity(0.12),
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(color: _testOk == true ? Colors.greenAccent : Colors.redAccent),
                      ),
                      child: Text(_testMessage!, style: const TextStyle(color: Colors.white, fontSize: 13)),
                    ),
                  ],
                  const SizedBox(height: 20),
                  SizedBox(
                    height: 48,
                    child: OutlinedButton.icon(
                      onPressed: (_testing || _saving) ? null : _test,
                      icon: _testing
                          ? const SizedBox(width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2, color: AppColors.primary))
                          : const Icon(Icons.play_arrow_outlined),
                      label: Text(_testing ? 'Testing...' : 'Test API'),
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    height: 52,
                    child: ElevatedButton(
                      onPressed: (_saving || _testing) ? null : _save,
                      child: _saving
                          ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Text('Save'),
                    ),
                  ),
                ],
              ),
            ),
    );
  }
}

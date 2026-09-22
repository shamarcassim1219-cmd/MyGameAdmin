import 'package:flutter/material.dart';
import '../services/api_service.dart';

String _err(Object e) => e.toString().replaceFirst('Exception: ', '');

String _two(int n) => n.toString().padLeft(2, '0');

String _fmt(dynamic ms) {
  final v = int.tryParse('${ms ?? ''}');
  if (v == null || v == 0) return '-';
  final d = DateTime.fromMillisecondsSinceEpoch(v);
  return '${d.year}-${_two(d.month)}-${_two(d.day)} ${_two(d.hour)}:${_two(d.minute)}';
}

class BinanceAdminScreen extends StatefulWidget {
  const BinanceAdminScreen({super.key});

  @override
  State<BinanceAdminScreen> createState() => _BinanceAdminScreenState();
}

class _BinanceAdminScreenState extends State<BinanceAdminScreen> {
  final _binanceId = TextEditingController();
  final _rate = TextEditingController();
  final _fee = TextEditingController();
  final _min = TextEditingController();
  final _window = TextEditingController();
  final _note = TextEditingController();
  final _orderId = TextEditingController();
  bool _enabled = false;
  bool _keys = false;
  bool _loading = true;
  bool _saving = false;
  bool _testing = false;
  Map<String, dynamic>? _testResult;
  List<dynamic> _deposits = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _binanceId.dispose();
    _rate.dispose();
    _fee.dispose();
    _min.dispose();
    _window.dispose();
    _note.dispose();
    _orderId.dispose();
    super.dispose();
  }

  void _msg(String m) {
    if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));
  }

  String _num(dynamic v) {
    final n = double.tryParse('${v ?? 0}') ?? 0;
    return n == n.roundToDouble() ? n.toStringAsFixed(0) : '$n';
  }

  Future<void> _load() async {
    try {
      final d = await ApiService.getBinanceSettings();
      final s = Map<String, dynamic>.from((d['settings'] as Map?) ?? {});
      final deps = await ApiService.getBinanceDeposits();
      if (!mounted) return;
      setState(() {
        _keys = d['keysConfigured'] == true;
        _enabled = s['enabled'] == true;
        _binanceId.text = '${s['binanceId'] ?? ''}';
        _rate.text = _num(s['rate']);
        _fee.text = _num(s['feePercent']);
        _min.text = _num(s['minUsdt']);
        _window.text = _num(s['windowHours']);
        _note.text = '${s['note'] ?? ''}';
        _deposits = deps;
        _loading = false;
      });
    } catch (e) {
      if (!mounted) return;
      setState(() => _loading = false);
      _msg(_err(e));
    }
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    try {
      await ApiService.saveBinanceSettings({
        'enabled': _enabled,
        'binanceId': _binanceId.text.trim(),
        'rate': double.tryParse(_rate.text.trim()) ?? 0,
        'feePercent': double.tryParse(_fee.text.trim()) ?? 0,
        'minUsdt': double.tryParse(_min.text.trim()) ?? 0,
        'windowHours': int.tryParse(_window.text.trim()) ?? 72,
        'note': _note.text.trim(),
      });
      _msg('Saved');
    } catch (e) {
      _msg(_err(e));
    }
    if (mounted) setState(() => _saving = false);
  }

  Future<void> _test() async {
    setState(() {
      _testing = true;
      _testResult = null;
    });
    try {
      final r = await ApiService.testBinanceOrder(_orderId.text.trim());
      if (mounted) setState(() => _testResult = r);
    } catch (e) {
      _msg(_err(e));
    }
    if (mounted) setState(() => _testing = false);
  }

  Widget _field(TextEditingController c, String label, {String? helper, bool number = false, int lines = 1}) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: TextField(
        controller: c,
        maxLines: lines,
        keyboardType: number ? const TextInputType.numberWithOptions(decimal: true) : null,
        decoration: InputDecoration(labelText: label, helperText: helper, border: const OutlineInputBorder(), isDense: true),
      ),
    );
  }

  Widget _txRow(Map t) {
    return ListTile(
      dense: true,
      contentPadding: EdgeInsets.zero,
      title: Text('${t['amount']} ${t['currency']}  |  ${t['orderType']}'),
      subtitle: Text('ID ${t['transactionId']}\n${_fmt(t['time'])}${t['payer'] != null ? '  |  ${t['payer']}' : ''}'),
      isThreeLine: true,
    );
  }

  Widget _testCard() {
    final r = _testResult!;
    final found = r['found'] == true;
    final would = r['wouldCredit'] as Map?;
    final recent = (r['recent'] as List?) ?? [];
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            if (_orderId.text.trim().isNotEmpty) ...[
              Text(found ? 'Order found' : 'Order NOT found', style: TextStyle(fontWeight: FontWeight.w800, color: found ? Colors.green : Colors.red)),
              if (found) _txRow(r['transaction'] as Map),
              if (r['alreadyUsed'] == true) const Text('This Order ID was already credited.', style: TextStyle(color: Colors.orange)),
              if (would != null) Text('Would credit: ${would['usdt']} USDT = LKR ${would['lkr']}', style: const TextStyle(fontWeight: FontWeight.w700))
              else if (r['reason'] != null) Text('Would be refused: ${r['reason']}'),
              const Divider(),
            ],
            Text('Latest ${recent.length} Binance Pay transactions (${r['totalInWindow']} in the time window)', style: const TextStyle(fontWeight: FontWeight.w700)),
            ...recent.map((e) => _txRow(e as Map)),
          ],
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Binance deposits')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(14),
                children: [
                  Card(
                    color: (_keys ? Colors.green : Colors.red).withValues(alpha: 0.12),
                    child: ListTile(
                      leading: Icon(_keys ? Icons.check_circle : Icons.error_outline, color: _keys ? Colors.green : Colors.red),
                      title: Text(_keys ? 'Binance API key found on the server' : 'Binance API key is missing on the server'),
                      subtitle: Text(_keys ? 'Use "Test" below to check that it works.' : 'Add BINANCE_API_KEY and BINANCE_API_SECRET in the Node app environment, then restart.'),
                    ),
                  ),
                  SwitchListTile(
                    contentPadding: EdgeInsets.zero,
                    title: const Text('Enable Binance deposits'),
                    subtitle: const Text('Customers see the Binance option only when this is on and the rate is set'),
                    value: _enabled,
                    onChanged: (v) => setState(() => _enabled = v),
                  ),
                  _field(_binanceId, 'Your Binance Pay ID', helper: 'Customers send USDT to this ID'),
                  _field(_rate, 'Rate: LKR for 1 USDT', number: true, helper: 'Change this any time. 0 = deposits off'),
                  Row(
                    children: [
                      Expanded(child: _field(_fee, 'Fee %', number: true)),
                      const SizedBox(width: 10),
                      Expanded(child: _field(_min, 'Min USDT', number: true)),
                    ],
                  ),
                  _field(_window, 'Accept payments made in the last (hours)', number: true, helper: 'Default 72'),
                  _field(_note, 'Note shown to customers (optional)', lines: 2),
                  FilledButton(
                    onPressed: _saving ? null : _save,
                    child: Padding(padding: const EdgeInsets.symmetric(vertical: 12), child: Text(_saving ? 'Saving...' : 'Save settings')),
                  ),
                  const Divider(height: 36),
                  const Text('Test an Order ID', style: TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  const SizedBox(height: 4),
                  const Text('Nothing is credited here. Leave empty to only list the latest transactions.', style: TextStyle(fontSize: 12)),
                  const SizedBox(height: 8),
                  _field(_orderId, 'Order ID'),
                  OutlinedButton.icon(
                    onPressed: _testing ? null : _test,
                    icon: const Icon(Icons.search),
                    label: Text(_testing ? 'Checking Binance...' : 'Test'),
                  ),
                  if (_testResult != null) _testCard(),
                  const Divider(height: 36),
                  Text('Recent credited deposits (${_deposits.length})', style: const TextStyle(fontSize: 16, fontWeight: FontWeight.w800)),
                  ..._deposits.map((d) {
                    final m = d as Map;
                    return ListTile(
                      dense: true,
                      contentPadding: EdgeInsets.zero,
                      title: Text('${m['name'] ?? m['email'] ?? 'User ${m['userId']}'}: ${m['usdt']} USDT = LKR ${m['lkr']}'),
                      subtitle: Text('Order ${m['orderId']}  |  rate ${m['rate']}${(m['feePercent'] ?? 0) != 0 ? '  fee ${m['feePercent']}%' : ''}'),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

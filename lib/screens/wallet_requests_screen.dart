import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'package:flutter/services.dart';
import 'deposit_methods_screen.dart';

class WalletRequestsScreen extends StatefulWidget {
  const WalletRequestsScreen({super.key});

  @override
  State<WalletRequestsScreen> createState() => _WalletRequestsScreenState();
}

class _WalletRequestsScreenState extends State<WalletRequestsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  List<dynamic> _topups = [];
  List<dynamic> _withdrawals = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();
  bool _searching = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
    _searchCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final topups = await ApiService.getTopups();
      final withdrawals = await ApiService.getWithdrawals();
      setState(() {
        _topups = topups;
        _withdrawals = withdrawals;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _search() async {
    final q = _searchCtrl.text.trim();
    if (q.isEmpty) {
      _clearSearch();
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
      _searching = true;
    });
    try {
      if (_tabController.index == 0) {
        final r = await ApiService.searchTopups(q);
        setState(() {
          _topups = r;
          _loading = false;
        });
      } else {
        final r = await ApiService.searchWithdrawals(q);
        setState(() {
          _withdrawals = r;
          _loading = false;
        });
      }
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _clearSearch() {
    _searchCtrl.clear();
    setState(() => _searching = false);
    _load();
  }

  String _get(Map v, List<String> keys) {
    for (final k in keys) {
      if (v[k] != null && v[k].toString().isNotEmpty) return v[k].toString();
    }
    return '';
  }

  Future<void> _decideTopup(Map t) async {
    final id = t['id'];
    final amountCtrl = TextEditingController(text: _get(t, ['amount']));
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Approve Top-up?', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Amount credited to the user\'s wallet (edit if needed):', style: TextStyle(color: AppColors.hint, fontSize: 12)),
            const SizedBox(height: 8),
            TextField(
              controller: amountCtrl,
              keyboardType: const TextInputType.numberWithOptions(decimal: true),
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Amount (LKR)'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirm != true) return;
    final adjusted = double.tryParse(amountCtrl.text.trim());
    try {
      await ApiService.decideTopup(id is int ? id : int.parse(id.toString()), true, adjustedAmount: adjusted);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Top-up approved')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _rejectTopup(Map t) async {
    final id = t['id'];
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reject Top-up?', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: reasonCtrl,
          maxLines: 3,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Reason (shown to the user)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.decideTopup(id is int ? id : int.parse(id.toString()), false, reason: reasonCtrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Top-up rejected')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _decideWithdrawal(Map w, bool approve) async {
    final id = w['id'];
    final amount = _get(w, ['amount']);
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(approve ? 'Approve Withdrawal?' : 'Reject Withdrawal?', style: const TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              approve
                  ? 'Confirm LKR $amount has been sent to the user\'s bank account.'
                  : 'The amount will be refunded to the user\'s wallet.',
              style: const TextStyle(color: AppColors.hint),
            ),
            if (!approve) ...[
              const SizedBox(height: 10),
              TextField(
                controller: reasonCtrl,
                maxLines: 3,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Reason (shown to the user)'),
              ),
            ],
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(approve ? 'Approve' : 'Reject')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.decideWithdrawal(
        id is int ? id : int.parse(id.toString()),
        approve,
        reason: approve ? null : reasonCtrl.text.trim(),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'Withdrawal confirmed' : 'Withdrawal rejected & refunded')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Widget _topupTile(Map t) {
    final email = _get(t, ['email']);
    final amount = _get(t, ['amount']);
    final ref = _get(t, ['reference_number']);
    final slip = _get(t, ['slip_url']);
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('LKR $amount · Ref: $ref', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
            if (slip.isNotEmpty) ...[
              const SizedBox(height: 8),
              GestureDetector(
                onTap: () => showDialog(
                  context: context,
                  builder: (_) => Dialog(backgroundColor: Colors.black, child: InteractiveViewer(child: Image.network(slip))),
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(8),
                  child: Image.network(slip, height: 120, fit: BoxFit.cover,
                      errorBuilder: (_, __, ___) => Container(height: 120, color: AppColors.fieldFill, child: const Icon(Icons.broken_image_outlined, color: AppColors.hint))),
                ),
              ),
            ],
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _rejectTopup(t),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                    child: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(onPressed: () => _decideTopup(t), child: const Text('Approve')),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }

  void _copyToClipboard(String text, String label) {
    Clipboard.setData(ClipboardData(text: text));
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('$label copied'), duration: const Duration(seconds: 1)));
  }

  Widget _bankRow(String label, String value, {bool copyable = false}) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          SizedBox(width: 80, child: Text(label, style: const TextStyle(color: AppColors.hint, fontSize: 12))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.w600))),
          if (copyable)
            InkWell(
              onTap: () => _copyToClipboard(value, label),
              child: const Padding(
                padding: EdgeInsets.all(4),
                child: Icon(Icons.copy_outlined, size: 16, color: AppColors.primary),
              ),
            ),
        ],
      ),
    );
  }

  Widget _withdrawalTile(Map w) {
    final email = _get(w, ['email']);
    final amount = _get(w, ['amount']);
    final bankName = _get(w, ['bank_name']);
    final accName = _get(w, ['bank_account_name']);
    final accNum = _get(w, ['bank_account_number']);
    final branch = _get(w, ['bank_branch']);
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(email, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
            const SizedBox(height: 4),
            Text('LKR $amount', style: const TextStyle(color: Colors.greenAccent, fontSize: 13, fontWeight: FontWeight.bold)),
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(10), border: Border.all(color: AppColors.border)),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _bankRow('Bank', bankName),
                  _bankRow('Name', accName),
                  _bankRow('Account', accNum, copyable: true),
                  _bankRow('Branch', branch),
                ],
              ),
            ),
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: () => _decideWithdrawal(w, false),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                    child: const Text('Reject & Refund', style: TextStyle(color: Colors.redAccent, fontSize: 12)),
                  ),
                ),
                const SizedBox(width: 10),
                Expanded(
                  child: ElevatedButton(onPressed: () => _decideWithdrawal(w, true), child: const Text('Confirm Sent')),
                ),
              ],
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
      appBar: AppBar(
        title: const Text('Wallet'),
        actions: [
          IconButton(
            icon: const Icon(Icons.account_balance_outlined),
            tooltip: 'Deposit Methods',
            onPressed: () => Navigator.push(context, MaterialPageRoute(builder: (_) => const DepositMethodsScreen())),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.hint,
          tabs: [
            Tab(text: 'Top-ups (${_topups.length})'),
            Tab(text: 'Withdrawals (${_withdrawals.length})'),
          ],
        ),
      ),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.fromLTRB(12, 10, 12, 4),
            child: Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _searchCtrl,
                    style: const TextStyle(color: Colors.white),
                    decoration: InputDecoration(
                      labelText: 'Search by order ID',
                      isDense: true,
                      suffixIcon: _searching
                          ? IconButton(icon: const Icon(Icons.close, size: 18), onPressed: _clearSearch)
                          : null,
                    ),
                    onSubmitted: (_) => _search(),
                  ),
                ),
                const SizedBox(width: 8),
                ElevatedButton(onPressed: _search, child: const Text('Search')),
              ],
            ),
          ),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
                : _error != null
                    ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
                    : RefreshIndicator(
                        onRefresh: _load,
                        color: AppColors.primary,
                        child: TabBarView(
                          controller: _tabController,
                          children: [
                      _topups.isEmpty
                          ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No pending top-ups', style: TextStyle(color: AppColors.hint)))])
                          : ListView.builder(itemCount: _topups.length, itemBuilder: (c, i) => _topupTile(_topups[i])),
                      _withdrawals.isEmpty
                          ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No pending withdrawals', style: TextStyle(color: AppColors.hint)))])
                          : ListView.builder(itemCount: _withdrawals.length, itemBuilder: (c, i) => _withdrawalTile(_withdrawals[i])),
                          ],
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

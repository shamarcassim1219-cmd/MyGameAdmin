import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
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

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
    _load();
  }

  @override
  void dispose() {
    _tabController.dispose();
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

  String _get(Map v, List<String> keys) {
    for (final k in keys) {
      if (v[k] != null && v[k].toString().isNotEmpty) return v[k].toString();
    }
    return '';
  }

  Future<void> _decideTopup(Map t) async {
    final id = t['id'];
    final amount = _get(t, ['amount']);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Approve Top-up?', style: TextStyle(color: Colors.white)),
        content: Text('LKR $amount will be added to the user\'s wallet.', style: const TextStyle(color: AppColors.hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Approve')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.decideTopup(id is int ? id : int.parse(id.toString()), true);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Top-up approved')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _rejectTopup(Map t) async {
    final id = t['id'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Reject Top-up?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.decideTopup(id is int ? id : int.parse(id.toString()), false);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Top-up rejected')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _decideWithdrawal(Map w, bool approve) async {
    final id = w['id'];
    final amount = _get(w, ['amount']);
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(approve ? 'Approve Withdrawal?' : 'Reject Withdrawal?', style: const TextStyle(color: Colors.white)),
        content: Text(
          approve
              ? 'Confirm LKR $amount has been sent to the user\'s bank account.'
              : 'The amount will be refunded to the user\'s wallet.',
          style: const TextStyle(color: AppColors.hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(approve ? 'Approve' : 'Reject')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.decideWithdrawal(id is int ? id : int.parse(id.toString()), approve);
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
            const SizedBox(height: 6),
            Text('$bankName · $accName · $accNum · $branch', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
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
      body: _loading
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
    );
  }
}

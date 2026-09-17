import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class UserDetailScreen extends StatefulWidget {
  final int userId;
  const UserDetailScreen({super.key, required this.userId});

  @override
  State<UserDetailScreen> createState() => _UserDetailScreenState();
}

class _UserDetailScreenState extends State<UserDetailScreen> {
  Map<String, dynamic>? _user;
  bool _loading = true;
  String? _error;
  bool _acting = false;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final u = await ApiService.getUserDetail(widget.userId);
      setState(() {
        _user = u;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _toggleBan() async {
    final banned = _user?['isBanned'] == true;
    if (!banned) {
      final reasonCtrl = TextEditingController();
      final confirmed = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Ban User', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: reasonCtrl,
            style: const TextStyle(color: Colors.white),
            decoration: const InputDecoration(labelText: 'Reason'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Ban')),
          ],
        ),
      );
      if (confirmed != true) return;
      setState(() => _acting = true);
      try {
        await ApiService.banUser(widget.userId, reasonCtrl.text.trim());
        await _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      } finally {
        if (mounted) setState(() => _acting = false);
      }
    } else {
      setState(() => _acting = true);
      try {
        await ApiService.unbanUser(widget.userId);
        await _load();
      } catch (e) {
        if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
      } finally {
        if (mounted) setState(() => _acting = false);
      }
    }
  }

  Future<void> _adjustWallet() async {
    final amountCtrl = TextEditingController();
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Adjust Wallet', style: TextStyle(color: Colors.white)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: amountCtrl,
              style: const TextStyle(color: Colors.white),
              keyboardType: const TextInputType.numberWithOptions(decimal: true, signed: true),
              decoration: const InputDecoration(labelText: 'Amount (+ to add, - to deduct)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: reasonCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Reason'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Apply')),
        ],
      ),
    );
    if (confirmed != true) return;
    final amount = double.tryParse(amountCtrl.text.trim());
    if (amount == null || amount == 0) return;
    setState(() => _acting = true);
    try {
      await ApiService.adjustWallet(widget.userId, amount, reasonCtrl.text.trim());
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Widget _row(String label, String value) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label, style: const TextStyle(color: AppColors.hint, fontSize: 13)),
          Flexible(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13, fontWeight: FontWeight.bold), textAlign: TextAlign.right)),
        ],
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final u = _user;
    final banned = u?['isBanned'] == true;
    final code = u != null ? 'MG-U${u['id'].toString().padLeft(6, '0')}' : '';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('User Details')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : ListView(
                  padding: const EdgeInsets.all(16),
                  children: [
                    Container(
                      width: double.infinity,
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          _row('Account ID', code),
                          _row('Name', u?['displayName'] ?? '—'),
                          _row('Email', u?['email'] ?? '—'),
                          _row('Phone', u?['phone'] ?? '—'),
                          _row('Wallet Balance', 'LKR ${(u?['walletBalance'] as num? ?? 0).toStringAsFixed(2)}'),
                          _row('Referral Points', '${u?['referralPoints'] ?? 0}'),
                          _row('Verified Status', u?['verifiedStatus'] ?? '—'),
                          _row('Listings', '${u?['listingsCount'] ?? 0}'),
                          _row('Orders', '${u?['ordersCount'] ?? 0}'),
                          if (banned) _row('Ban Reason', u?['banReason'] ?? '—'),
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: ElevatedButton.icon(
                        onPressed: _acting ? null : _adjustWallet,
                        icon: const Icon(Icons.account_balance_wallet_outlined),
                        label: const Text('Adjust Wallet'),
                      ),
                    ),
                    const SizedBox(height: 12),
                    SizedBox(
                      width: double.infinity,
                      height: 50,
                      child: OutlinedButton.icon(
                        onPressed: _acting ? null : _toggleBan,
                        icon: Icon(banned ? Icons.check_circle_outline : Icons.block, color: banned ? Colors.greenAccent : Colors.redAccent),
                        label: Text(banned ? 'Unban User' : 'Ban User', style: TextStyle(color: banned ? Colors.greenAccent : Colors.redAccent)),
                        style: OutlinedButton.styleFrom(side: BorderSide(color: banned ? Colors.greenAccent : Colors.redAccent)),
                      ),
                    ),
                  ],
                ),
    );
  }
}

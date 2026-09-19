import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'order_chat_screen.dart';

class OrderDetailScreen extends StatefulWidget {
  final int orderId;
  const OrderDetailScreen({super.key, required this.orderId});

  @override
  State<OrderDetailScreen> createState() => _OrderDetailScreenState();
}

class _OrderDetailScreenState extends State<OrderDetailScreen> {
  Map<String, dynamic>? _order;
  bool _loading = true;
  String? _error;
  bool _acting = false;

  final _emailCtrl = TextEditingController();
  final _passwordCtrl = TextEditingController();
  final _recoveryCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
  }

  @override
  void dispose() {
    _emailCtrl.dispose();
    _passwordCtrl.dispose();
    _recoveryCtrl.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final o = await ApiService.getOrderDetail(widget.orderId);
      setState(() {
        _order = o;
        _loading = false;
        _error = null;
        final vault = o['vault'];
        _emailCtrl.text = vault != null ? (vault['email'] ?? '') : '';
        _passwordCtrl.text = vault != null ? (vault['password'] ?? '') : '';
        _recoveryCtrl.text = vault != null ? (vault['recoveryCodes'] ?? '') : '';
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _saveVault() async {
    if (_emailCtrl.text.trim().isEmpty || _passwordCtrl.text.trim().isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Email and password are required')));
      return;
    }
    setState(() => _acting = true);
    try {
      await ApiService.updateVault(
        widget.orderId,
        email: _emailCtrl.text.trim(),
        password: _passwordCtrl.text.trim(),
        recoveryCodes: _recoveryCtrl.text.trim().isEmpty ? null : _recoveryCtrl.text.trim(),
      );
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credentials saved')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _releaseCredentials() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Release Credentials?', style: TextStyle(color: Colors.white)),
        content: const Text('This will send the saved credentials to the buyer and unlock their vault.', style: TextStyle(color: AppColors.hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Release')),
        ],
      ),
    );
    if (confirmed != true) return;
    setState(() => _acting = true);
    try {
      await ApiService.releaseCredentials(widget.orderId);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Credentials released to buyer')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Future<void> _cancelOrder() async {
    final reasonCtrl = TextEditingController();
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Cancel Order & Refund Buyer', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 3,
          decoration: const InputDecoration(labelText: 'Reason (required)', hintText: 'Why is this order being cancelled?'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Back')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Cancel & Refund'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    if (reasonCtrl.text.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('A reason is required')));
      return;
    }
    setState(() => _acting = true);
    try {
      await ApiService.cancelOrder(widget.orderId, reasonCtrl.text.trim());
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Order cancelled — buyer refunded')));
      await _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    } finally {
      if (mounted) setState(() => _acting = false);
    }
  }

  Widget _partyTile({required String label, required String email, required int? conversationId, required String type}) {
    return Card(
      color: AppColors.surface,
      margin: const EdgeInsets.only(bottom: 10),
      child: ListTile(
        leading: CircleAvatar(
          backgroundColor: AppColors.primary.withOpacity(0.2),
          child: Text(email.isNotEmpty ? email[0].toUpperCase() : '?', style: const TextStyle(color: AppColors.primary)),
        ),
        title: Text(label, style: const TextStyle(color: AppColors.hint, fontSize: 11)),
        subtitle: Text(email, style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
        trailing: const Icon(Icons.chat_bubble_outline, color: AppColors.primary),
        onTap: () {
          Navigator.push(
            context,
            MaterialPageRoute(
              builder: (_) => OrderChatScreen(orderId: widget.orderId, conversationType: type, otherPartyLabel: email),
            ),
          );
        },
      ),
    );
  }

  Widget _sectionTitle(String text) => Padding(
        padding: const EdgeInsets.only(bottom: 10, top: 4),
        child: Text(text, style: const TextStyle(color: Colors.white, fontSize: 15, fontWeight: FontWeight.bold)),
      );

  @override
  Widget build(BuildContext context) {
    final o = _order;
    final status = o?['status']?.toString() ?? '';
    final canCancel = o != null && !['completed', 'refunded', 'cancelled'].contains(status);
    final alreadyReleased = o != null && o['credentials_released_at'] != null;

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: Text(o != null ? 'Order #${o['id']}' : 'Order'),
        actions: [
          IconButton(icon: const Icon(Icons.refresh), onPressed: _load),
        ],
      ),
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
                          Text(o?['title']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontSize: 16, fontWeight: FontWeight.bold)),
                          const SizedBox(height: 6),
                          Text('${o?['game'] ?? ''} · LKR ${o?['price']}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                          const SizedBox(height: 4),
                          Text('Status: $status', style: const TextStyle(color: AppColors.primary, fontSize: 12, fontWeight: FontWeight.bold)),
                          if (o?['cancellation_reason'] != null) ...[
                            const SizedBox(height: 4),
                            Text('Cancellation reason: ${o!['cancellation_reason']}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                          ],
                        ],
                      ),
                    ),
                    const SizedBox(height: 20),
                    _sectionTitle('Buyer & Seller'),
                    _partyTile(label: 'BUYER', email: o?['buyer_email']?.toString() ?? '', conversationId: o?['buyerConversationId'], type: 'admin_buyer'),
                    _partyTile(label: 'SELLER', email: o?['seller_email']?.toString() ?? '', conversationId: o?['sellerConversationId'], type: 'admin_seller'),
                    const SizedBox(height: 10),
                    _sectionTitle('Account Credentials'),
                    Container(
                      padding: const EdgeInsets.all(14),
                      decoration: BoxDecoration(color: AppColors.surface, borderRadius: BorderRadius.circular(14), border: Border.all(color: AppColors.border)),
                      child: Column(
                        children: [
                          if (alreadyReleased)
                            Container(
                              width: double.infinity,
                              margin: const EdgeInsets.only(bottom: 12),
                              padding: const EdgeInsets.all(10),
                              decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                              child: const Text('✓ Already released to buyer', style: TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                            ),
                          TextField(
                            controller: _emailCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'Account Email/Username'),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _passwordCtrl,
                            style: const TextStyle(color: Colors.white),
                            decoration: const InputDecoration(labelText: 'Account Password'),
                          ),
                          const SizedBox(height: 10),
                          TextField(
                            controller: _recoveryCtrl,
                            style: const TextStyle(color: Colors.white),
                            maxLines: 2,
                            decoration: const InputDecoration(labelText: 'Recovery Codes (optional)'),
                          ),
                          const SizedBox(height: 14),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: OutlinedButton.icon(
                              onPressed: _acting ? null : _saveVault,
                              icon: const Icon(Icons.save_outlined),
                              label: const Text('Save Credentials'),
                            ),
                          ),
                          const SizedBox(height: 10),
                          SizedBox(
                            width: double.infinity,
                            height: 46,
                            child: ElevatedButton.icon(
                              onPressed: _acting ? null : _releaseCredentials,
                              icon: const Icon(Icons.lock_open_outlined),
                              label: Text(alreadyReleased ? 'Re-release to Buyer' : 'Release to Buyer'),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: 24),
                    if (canCancel)
                      SizedBox(
                        width: double.infinity,
                        height: 50,
                        child: OutlinedButton.icon(
                          onPressed: _acting ? null : _cancelOrder,
                          icon: const Icon(Icons.cancel_outlined, color: Colors.redAccent),
                          label: const Text('Cancel Order & Refund Buyer', style: TextStyle(color: Colors.redAccent)),
                          style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                        ),
                      ),
                  ],
                ),
    );
  }
}

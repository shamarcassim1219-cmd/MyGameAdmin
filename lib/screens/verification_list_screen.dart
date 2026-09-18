import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class VerificationListScreen extends StatefulWidget {
  const VerificationListScreen({super.key});

  @override
  State<VerificationListScreen> createState() => _VerificationListScreenState();
}

class _VerificationListScreenState extends State<VerificationListScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<String> _statuses = ['pending', 'approved', 'rejected'];
  Map<String, List<dynamic>> _cache = {};
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _statuses.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _loadCurrent();
    });
    _loadCurrent();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadCurrent() async {
    final status = _statuses[_tabController.index];
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getVerifications(status: status);
      setState(() {
        _cache[status] = list;
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

  @override
  Widget build(BuildContext context) {
    final status = _statuses[_tabController.index];
    final list = _cache[status] ?? [];

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Verification'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.hint,
          tabs: const [
            Tab(text: 'Pending'),
            Tab(text: 'Approved'),
            Tab(text: 'Rejected'),
          ],
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : RefreshIndicator(
                  onRefresh: _loadCurrent,
                  color: AppColors.primary,
                  child: list.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No verifications here', style: TextStyle(color: AppColors.hint))),
                          ],
                        )
                      : ListView.builder(
                          itemCount: list.length,
                          itemBuilder: (context, i) {
                            final v = list[i];
                            final name = _get(v, ['fullName', 'full_name']);
                            final nic = _get(v, ['nicNumber', 'nic_number']);
                            final submitted = _get(v, ['createdAt', 'created_at']);
                            final userId = v['userId'] ?? v['user_id'];
                            final code = userId != null ? 'MG-U${userId.toString().padLeft(6, '0')}' : '';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(0.15),
                                child: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 18),
                              ),
                              title: Text(name.isEmpty ? 'Unknown' : name, style: const TextStyle(color: Colors.white)),
                              subtitle: Text('$code · NIC: $nic', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                              trailing: submitted.isEmpty
                                  ? null
                                  : Text(submitted.split('T').first, style: const TextStyle(color: AppColors.hint, fontSize: 11)),
                              onTap: () async {
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(builder: (_) => VerificationDetailScreen(verification: v)),
                                );
                                if (changed == true) _loadCurrent();
                              },
                            );
                          },
                        ),
                ),
    );
  }
}

class VerificationDetailScreen extends StatefulWidget {
  final Map verification;
  const VerificationDetailScreen({super.key, required this.verification});

  @override
  State<VerificationDetailScreen> createState() => _VerificationDetailScreenState();
}

class _VerificationDetailScreenState extends State<VerificationDetailScreen> {
  bool _processing = false;

  String _get(List<String> keys) {
    for (final k in keys) {
      final val = widget.verification[k];
      if (val != null && val.toString().isNotEmpty) return val.toString();
    }
    return '';
  }

  Widget _imageBox(String label, String? url) {
    if (url == null || url.isEmpty) return const SizedBox.shrink();
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(label, style: const TextStyle(color: AppColors.hint, fontSize: 12)),
        const SizedBox(height: 6),
        ClipRRect(
          borderRadius: BorderRadius.circular(12),
          child: GestureDetector(
            onTap: () => showDialog(
              context: context,
              builder: (_) => Dialog(
                backgroundColor: Colors.black,
                child: InteractiveViewer(child: Image.network(url)),
              ),
            ),
            child: Image.network(
              url,
              height: 160,
              width: double.infinity,
              fit: BoxFit.cover,
              errorBuilder: (_, __, ___) => Container(
                height: 160,
                color: AppColors.fieldFill,
                child: const Icon(Icons.broken_image_outlined, color: AppColors.hint),
              ),
            ),
          ),
        ),
        const SizedBox(height: 16),
      ],
    );
  }

  Widget _infoRow(String label, String value) {
    if (value.isEmpty) return const SizedBox.shrink();
    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          SizedBox(width: 110, child: Text(label, style: const TextStyle(color: AppColors.hint, fontSize: 13))),
          Expanded(child: Text(value, style: const TextStyle(color: Colors.white, fontSize: 13))),
        ],
      ),
    );
  }

  Future<void> _decide(String decision) async {
    String? reason;
    if (decision == 'reject') {
      final ctrl = TextEditingController();
      reason = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Reject Reason', style: TextStyle(color: Colors.white)),
          content: TextField(
            controller: ctrl,
            style: const TextStyle(color: Colors.white),
            maxLines: 3,
            decoration: const InputDecoration(hintText: 'Why is this being rejected?'),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Confirm')),
          ],
        ),
      );
      if (reason == null || reason.isEmpty) return;
    }

    final userId = widget.verification['userId'] ?? widget.verification['user_id'];
    if (userId == null) return;

    setState(() => _processing = true);
    try {
      await ApiService.decideVerification(
        userId is int ? userId : int.parse(userId.toString()),
        decision,
        reason: reason,
      );
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(decision == 'approve' ? 'Approved' : 'Rejected')),
      );
      Navigator.pop(context, true);
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))),
        );
      }
    } finally {
      if (mounted) setState(() => _processing = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final status = _get(['status']).toLowerCase();
    final isPending = status.isEmpty || status == 'pending';

    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Verification Detail')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Full Name', _get(['fullName', 'full_name'])),
            _infoRow('NIC Number', _get(['nicNumber', 'nic_number'])),
            _infoRow('Document Type', _get(['documentType', 'document_type'])),
            _infoRow('Address', _get(['address'])),
            _infoRow('Province', _get(['province'])),
            _infoRow('District', _get(['district'])),
            _infoRow('Status', _get(['status']).isEmpty ? 'pending' : _get(['status'])),
            _infoRow('Submitted', _get(['createdAt', 'created_at'])),
            const SizedBox(height: 8),
            _imageBox('Front Image', _get(['frontImageUrl', 'front_image_url'])),
            _imageBox('Back Image', _get(['backImageUrl', 'back_image_url'])),
            _imageBox('Selfie', _get(['selfieImageUrl', 'selfie_image_url'])),
            if (isPending) ...[
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _processing ? null : () => _decide('reject'),
                      icon: const Icon(Icons.close, color: Colors.redAccent),
                      label: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
                      style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: _processing ? null : () => _decide('approve'),
                      icon: _processing
                          ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                          : const Icon(Icons.check),
                      label: const Text('Approve'),
                    ),
                  ),
                ],
              ),
            ],
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

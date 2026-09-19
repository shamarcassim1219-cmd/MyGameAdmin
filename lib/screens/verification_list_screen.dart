import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class VerificationListScreen extends StatefulWidget {
  const VerificationListScreen({super.key});

  @override
  State<VerificationListScreen> createState() => _VerificationListScreenState();
}

class _VerificationListScreenState extends State<VerificationListScreen> {
  List<dynamic> _list = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getVerifications();
      setState(() {
        _list = list;
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Verification — Pending')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: _list.isEmpty
                      ? ListView(
                          children: const [
                            SizedBox(height: 120),
                            Center(child: Text('No pending verifications', style: TextStyle(color: AppColors.hint))),
                          ],
                        )
                      : ListView.builder(
                          itemCount: _list.length,
                          itemBuilder: (context, i) {
                            final v = _list[i];
                            final name = _get(v, ['full_name', 'fullName']);
                            final nic = _get(v, ['nic_number', 'nicNumber']);
                            final email = _get(v, ['email']);
                            final userId = v['user_id'] ?? v['userId'];
                            final code = userId != null ? 'MG-U${userId.toString().padLeft(6, '0')}' : '';

                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: AppColors.primary.withOpacity(0.15),
                                child: const Icon(Icons.badge_outlined, color: AppColors.primary, size: 18),
                              ),
                              title: Text(name.isEmpty ? email : name, style: const TextStyle(color: Colors.white)),
                              subtitle: Text('$code · NIC: $nic', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                              onTap: () async {
                                final changed = await Navigator.push<bool>(
                                  context,
                                  MaterialPageRoute(builder: (_) => VerificationDetailScreen(verification: v)),
                                );
                                if (changed == true) _load();
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

  Widget _imageBox(String label, String url) {
    if (url.isEmpty) return const SizedBox.shrink();
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

  Future<void> _decide(bool approve) async {
    if (!approve) {
      final confirm = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: const Text('Reject Verification?', style: TextStyle(color: Colors.white)),
          content: const Text('The user will be notified and can resubmit.', style: TextStyle(color: AppColors.hint)),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Reject')),
          ],
        ),
      );
      if (confirm != true) return;
    }

    final userId = widget.verification['user_id'] ?? widget.verification['userId'];
    if (userId == null) return;

    setState(() => _processing = true);
    try {
      await ApiService.decideVerification(userId is int ? userId : int.parse(userId.toString()), approve);
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(approve ? 'Approved' : 'Rejected')),
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
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Verification Detail')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            _infoRow('Email', _get(['email'])),
            _infoRow('Full Name', _get(['full_name', 'fullName'])),
            _infoRow('NIC Number', _get(['nic_number', 'nicNumber'])),
            _infoRow('Document Type', _get(['document_type', 'documentType'])),
            _infoRow('Address', _get(['address'])),
            _infoRow('Province', _get(['province'])),
            _infoRow('District', _get(['district'])),
            _infoRow('Submitted', _get(['created_at', 'createdAt'])),
            const SizedBox(height: 8),
            _imageBox('Front Image', _get(['nic_image_url', 'frontImageUrl'])),
            _imageBox('Back Image', _get(['back_image_url', 'backImageUrl'])),
            _imageBox('Selfie', _get(['selfie_image_url', 'selfieImageUrl'])),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: _processing ? null : () => _decide(false),
                    icon: const Icon(Icons.close, color: Colors.redAccent),
                    label: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
                    style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: ElevatedButton.icon(
                    onPressed: _processing ? null : () => _decide(true),
                    icon: _processing
                        ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                        : const Icon(Icons.check),
                    label: const Text('Approve'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 20),
          ],
        ),
      ),
    );
  }
}

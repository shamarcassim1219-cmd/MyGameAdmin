import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class SubAdminRequestsScreen extends StatefulWidget {
  const SubAdminRequestsScreen({super.key});

  @override
  State<SubAdminRequestsScreen> createState() => _SubAdminRequestsScreenState();
}

class _SubAdminRequestsScreenState extends State<SubAdminRequestsScreen> {
  List<dynamic> _requests = [];
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
      final list = await ApiService.getSubAdminRequests();
      setState(() {
        _requests = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _decide(Map r, bool approve) async {
    final userId = r['user_id'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(approve ? 'Approve this sub-admin?' : 'Reject this request?', style: const TextStyle(color: Colors.white)),
        content: Text('${r['full_name'] ?? r['email'] ?? ''}', style: const TextStyle(color: AppColors.hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: Text(approve ? 'Approve' : 'Reject')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.decideSubAdmin(userId is int ? userId : int.parse(userId.toString()), approve);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'Approved' : 'Rejected')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Sub-Admin Requests')),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: _requests.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No pending sub-admin requests', style: TextStyle(color: AppColors.hint)))])
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _requests.length,
                          itemBuilder: (context, i) {
                            final r = _requests[i];
                            return Card(
                              color: AppColors.surface,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: Padding(
                                padding: const EdgeInsets.all(12),
                                child: Column(
                                  crossAxisAlignment: CrossAxisAlignment.start,
                                  children: [
                                    Text(r['full_name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                    const SizedBox(height: 4),
                                    Text(r['email']?.toString() ?? '', style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                                    const SizedBox(height: 4),
                                    Text('NIC: ${r['nic_number'] ?? ''}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                    Text('${r['address'] ?? ''}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                    const SizedBox(height: 10),
                                    Row(
                                      children: [
                                        Expanded(
                                          child: OutlinedButton(
                                            onPressed: () => _decide(r, false),
                                            style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                                            child: const Text('Reject', style: TextStyle(color: Colors.redAccent)),
                                          ),
                                        ),
                                        const SizedBox(width: 10),
                                        Expanded(
                                          child: ElevatedButton(onPressed: () => _decide(r, true), child: const Text('Approve')),
                                        ),
                                      ],
                                    ),
                                  ],
                                ),
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

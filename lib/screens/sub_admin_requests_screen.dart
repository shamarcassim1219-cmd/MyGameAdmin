import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class SubAdminRequestsScreen extends StatefulWidget {
  const SubAdminRequestsScreen({super.key});

  @override
  State<SubAdminRequestsScreen> createState() => _SubAdminRequestsScreenState();
}

class _SubAdminRequestsScreenState extends State<SubAdminRequestsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Sub-Admins'),
        bottom: TabBar(
          controller: _tabController,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.hint,
          tabs: const [
            Tab(text: 'Access Requests'),
            Tab(text: 'Device Requests'),
            Tab(text: 'Active'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: const [
          _AccessRequestsTab(),
          _DeviceRequestsTab(),
          _ActiveSubAdminsTab(),
        ],
      ),
    );
  }
}

// ============================== ACCESS REQUESTS ==============================
class _AccessRequestsTab extends StatefulWidget {
  const _AccessRequestsTab();

  @override
  State<_AccessRequestsTab> createState() => _AccessRequestsTabState();
}

class _AccessRequestsTabState extends State<_AccessRequestsTab> {
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
    return _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primary,
                child: _requests.isEmpty
                    ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No pending access requests', style: TextStyle(color: AppColors.hint)))])
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
              );
  }
}

// ============================== DEVICE CHANGE REQUESTS ==============================
class _DeviceRequestsTab extends StatefulWidget {
  const _DeviceRequestsTab();

  @override
  State<_DeviceRequestsTab> createState() => _DeviceRequestsTabState();
}

class _DeviceRequestsTabState extends State<_DeviceRequestsTab> {
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
      final list = await ApiService.getSubAdminDeviceRequests();
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
    final id = r['id'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: Text(approve ? 'Approve this new device?' : 'Reject this device?', style: const TextStyle(color: Colors.white)),
        content: Text(
          '${r['display_name'] ?? r['email'] ?? ''}\nDevice: ${r['device_model'] ?? 'Unknown'}\nIP: ${r['ip_address'] ?? '—'}',
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
      await ApiService.decideSubAdminDeviceRequest(id is int ? id : int.parse(id.toString()), approve);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(approve ? 'Device approved' : 'Device rejected')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primary,
                child: _requests.isEmpty
                    ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No pending device change requests', style: TextStyle(color: AppColors.hint)))])
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
                                  Row(
                                    children: [
                                      const Icon(Icons.phone_android, color: AppColors.primary, size: 18),
                                      const SizedBox(width: 8),
                                      Expanded(
                                        child: Text(r['display_name']?.toString() ?? r['email']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(r['email']?.toString() ?? '', style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                                  const SizedBox(height: 6),
                                  Text('New device: ${r['device_model'] ?? 'Unknown'}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                  Text('IP address: ${r['ip_address'] ?? '—'}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                  Text('Requested: ${r['created_at'] ?? ''}', style: const TextStyle(color: AppColors.hint, fontSize: 11)),
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
                                        child: ElevatedButton(onPressed: () => _decide(r, true), child: const Text('Approve Device')),
                                      ),
                                    ],
                                  ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              );
  }
}

// ============================== ACTIVE / LOGGED-IN SUB-ADMINS ==============================
class _ActiveSubAdminsTab extends StatefulWidget {
  const _ActiveSubAdminsTab();

  @override
  State<_ActiveSubAdminsTab> createState() => _ActiveSubAdminsTabState();
}

class _ActiveSubAdminsTabState extends State<_ActiveSubAdminsTab> {
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
      final list = await ApiService.getActiveSubAdmins();
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

  Future<void> _forceLogout(Map r) async {
    final userId = r['user_id'];
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Force logout this sub-admin?', style: TextStyle(color: Colors.white)),
        content: Text(
          '${r['full_name'] ?? r['email'] ?? ''} will be logged out immediately and will need device re-approval to log in again.',
          style: const TextStyle(color: AppColors.hint),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Force Logout'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.forceLogoutSubAdmin(userId is int ? userId : int.parse(userId.toString()));
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Sub-admin logged out')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return _loading
        ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
        : _error != null
            ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
            : RefreshIndicator(
                onRefresh: _load,
                color: AppColors.primary,
                child: _list.isEmpty
                    ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No active sub-admins', style: TextStyle(color: AppColors.hint)))])
                    : ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _list.length,
                        itemBuilder: (context, i) {
                          final r = _list[i];
                          final status = r['status']?.toString() ?? '';
                          final banned = r['is_banned'] == true || r['is_banned'] == 1;
                          final statusColor = banned
                              ? Colors.redAccent
                              : status == 'approved'
                                  ? Colors.greenAccent
                                  : Colors.orangeAccent;
                          final statusLabel = banned ? 'Banned' : status == 'approved' ? 'Logged in / Approved' : 'Pending re-approval';
                          return Card(
                            color: AppColors.surface,
                            margin: const EdgeInsets.only(bottom: 10),
                            child: Padding(
                              padding: const EdgeInsets.all(12),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  Row(
                                    children: [
                                      Expanded(
                                        child: Text(r['full_name']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      ),
                                      Container(
                                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                        decoration: BoxDecoration(color: statusColor.withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                        child: Text(statusLabel, style: TextStyle(color: statusColor, fontSize: 11, fontWeight: FontWeight.bold)),
                                      ),
                                    ],
                                  ),
                                  const SizedBox(height: 4),
                                  Text(r['email']?.toString() ?? '', style: const TextStyle(color: AppColors.primary, fontSize: 12)),
                                  const SizedBox(height: 10),
                                  if (status == 'approved' && !banned)
                                    SizedBox(
                                      width: double.infinity,
                                      child: OutlinedButton.icon(
                                        onPressed: () => _forceLogout(r),
                                        icon: const Icon(Icons.logout, color: Colors.redAccent, size: 16),
                                        label: const Text('Force Logout', style: TextStyle(color: Colors.redAccent)),
                                        style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                                      ),
                                    ),
                                ],
                              ),
                            ),
                          );
                        },
                      ),
              );
  }
}

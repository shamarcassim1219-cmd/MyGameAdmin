import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class AdminListingsScreen extends StatefulWidget {
  const AdminListingsScreen({super.key});

  @override
  State<AdminListingsScreen> createState() => _AdminListingsScreenState();
}

class _AdminListingsScreenState extends State<AdminListingsScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final List<Map<String, String>> _tabs = [
    {'label': 'All', 'status': 'all'},
    {'label': 'Active', 'status': 'active'},
    {'label': 'Sold', 'status': 'sold'},
    {'label': 'Removed', 'status': 'expired'},
  ];
  List<dynamic> _listings = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
    _tabController.addListener(() {
      if (!_tabController.indexIsChanging) _load();
    });
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
      final list = await ApiService.getAdminListings(status: _tabs[_tabController.index]['status']!);
      setState(() {
        _listings = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _confirmRemove(Map l) async {
    final ctrl = TextEditingController();
    final reason = await showDialog<String>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Remove Listing?', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: ctrl,
          style: const TextStyle(color: Colors.white),
          maxLines: 2,
          decoration: const InputDecoration(hintText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, ctrl.text.trim()), child: const Text('Remove')),
        ],
      ),
    );
    if (reason == null) return;
    try {
      final id = l['id'];
      await ApiService.removeListing(id is int ? id : int.parse(id.toString()), reason: reason.isEmpty ? null : reason);
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Listing removed')));
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(
        title: const Text('Listings'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.hint,
          tabs: _tabs.map((t) => Tab(text: t['label'])).toList(),
        ),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: _listings.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No listings here', style: TextStyle(color: AppColors.hint)))])
                      : ListView.builder(
                          itemCount: _listings.length,
                          itemBuilder: (context, i) {
                            final l = _listings[i];
                            final status = l['status']?.toString() ?? '';
                            final screenshots = (l['screenshots'] as List?) ?? [];
                            final thumb = screenshots.isNotEmpty ? screenshots.first.toString() : null;
                            return Card(
                              color: AppColors.surface,
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: ListTile(
                                leading: thumb != null
                                    ? ClipRRect(
                                        borderRadius: BorderRadius.circular(8),
                                        child: Image.network(thumb, width: 48, height: 48, fit: BoxFit.cover,
                                            errorBuilder: (_, __, ___) => const Icon(Icons.videogame_asset_outlined, color: AppColors.hint)),
                                      )
                                    : const Icon(Icons.videogame_asset_outlined, color: AppColors.hint),
                                title: Text(l['title']?.toString() ?? '', style: const TextStyle(color: Colors.white)),
                                subtitle: Text(
                                  '${l['game']} · LKR ${l['price']} · $status\n${l['sellerEmail'] ?? l['sellerName'] ?? ''}',
                                  style: const TextStyle(color: AppColors.hint, fontSize: 12),
                                ),
                                isThreeLine: true,
                                trailing: status == 'active'
                                    ? IconButton(
                                        icon: const Icon(Icons.delete_outline, color: Colors.redAccent),
                                        onPressed: () => _confirmRemove(l),
                                      )
                                    : null,
                              ),
                            );
                          },
                        ),
                ),
    );
  }
}

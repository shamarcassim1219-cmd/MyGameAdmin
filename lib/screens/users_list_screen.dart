import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'user_detail_screen.dart';

class UsersListScreen extends StatefulWidget {
  const UsersListScreen({super.key});

  @override
  State<UsersListScreen> createState() => _UsersListScreenState();
}

class _UsersListScreenState extends State<UsersListScreen> {
  List<dynamic> _users = [];
  List<dynamic> _filtered = [];
  bool _loading = true;
  String? _error;
  final _searchCtrl = TextEditingController();

  @override
  void initState() {
    super.initState();
    _load();
    _searchCtrl.addListener(_filter);
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final users = await ApiService.getUsers();
      setState(() {
        _users = users;
        _filtered = users;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  void _filter() {
    final q = _searchCtrl.text.trim().toLowerCase();
    setState(() {
      _filtered = q.isEmpty
          ? _users
          : _users.where((u) {
              final email = (u['email'] ?? '').toString().toLowerCase();
              final name = (u['display_name'] ?? u['displayName'] ?? '').toString().toLowerCase();
              final id = 'mg-u${u['id'].toString().padLeft(6, '0')}';
              final rawId = u['id'].toString();
              return email.contains(q) || name.contains(q) || id.contains(q) || rawId == q;
            }).toList();
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Users')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(12),
            child: TextField(
              controller: _searchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(
                labelText: 'Search by email, name, or Account ID',
                prefixIcon: Icon(Icons.search, color: AppColors.hint),
              ),
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
                        child: ListView.builder(
                          itemCount: _filtered.length,
                          itemBuilder: (context, i) {
                            final u = _filtered[i];
                            final banned = u['is_banned'] == 1 || u['is_banned'] == true;
                            final code = 'MG-U${u['id'].toString().padLeft(6, '0')}';
                            return ListTile(
                              leading: CircleAvatar(
                                backgroundColor: banned ? Colors.redAccent.withOpacity(0.15) : AppColors.primary.withOpacity(0.15),
                                child: Icon(banned ? Icons.block : Icons.person, color: banned ? Colors.redAccent : AppColors.primary, size: 18),
                              ),
                              title: Text(u['display_name'] ?? u['email'] ?? '', style: const TextStyle(color: Colors.white)),
                              subtitle: Text('$code · ${u['email'] ?? ''}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                              trailing: Text('LKR ${(num.tryParse(u['wallet_balance'].toString()) ?? 0).toStringAsFixed(2)}',
                                  style: const TextStyle(color: Colors.greenAccent, fontSize: 12, fontWeight: FontWeight.bold)),
                              onTap: () async {
                                await Navigator.push(context, MaterialPageRoute(builder: (_) => UserDetailScreen(userId: u['id'])));
                                _load();
                              },
                            );
                          },
                        ),
                      ),
          ),
        ],
      ),
    );
  }
}

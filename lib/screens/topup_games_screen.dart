import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';
import 'topup_packages_screen.dart';

class TopupGamesScreen extends StatefulWidget {
  const TopupGamesScreen({super.key});

  @override
  State<TopupGamesScreen> createState() => _TopupGamesScreenState();
}

class _TopupGamesScreenState extends State<TopupGamesScreen> with SingleTickerProviderStateMixin {
  late final TabController _tabController;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 2, vsync: this);
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
        title: const Text('Top-Up Store'),
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.hint,
          tabs: const [Tab(text: 'Games'), Tab(text: 'Orders')],
        ),
      ),
      body: TabBarView(controller: _tabController, children: const [_GamesTab(), _OrdersTab()]),
    );
  }
}

// ============================== GAMES ==============================
class _GamesTab extends StatefulWidget {
  const _GamesTab();

  @override
  State<_GamesTab> createState() => _GamesTabState();
}

class _GamesTabState extends State<_GamesTab> {
  List<dynamic> _games = [];
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
      final list = await ApiService.getTopupGames();
      setState(() {
        _games = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _showEditor({Map? existing}) async {
    final nameCtrl = TextEditingController(text: existing?['name']?.toString() ?? '');
    final iconCtrl = TextEditingController(text: existing?['icon_url']?.toString() ?? '');
    bool requiresZone = existing != null && (existing['requires_zone_id'] == true || existing['requires_zone_id'] == 1);

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(existing == null ? 'Add Game' : 'Edit Game', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Game name', hintText: 'e.g. Free Fire'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: iconCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Icon URL (optional)'),
              ),
              const SizedBox(height: 8),
              SwitchListTile(
                contentPadding: EdgeInsets.zero,
                title: const Text('Requires Zone ID', style: TextStyle(color: Colors.white, fontSize: 13)),
                activeColor: AppColors.primary,
                value: requiresZone,
                onChanged: (v) => setDlg(() => requiresZone = v),
              ),
            ],
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
          ],
        ),
      ),
    );

    if (saved != true) return;
    if (nameCtrl.text.trim().isEmpty) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a game name')));
      return;
    }
    try {
      if (existing == null) {
        await ApiService.addTopupGame(name: nameCtrl.text.trim(), iconUrl: iconCtrl.text.trim().isEmpty ? null : iconCtrl.text.trim(), requiresZoneId: requiresZone);
      } else {
        await ApiService.updateTopupGame(existing['id'], name: nameCtrl.text.trim(), iconUrl: iconCtrl.text.trim().isEmpty ? null : iconCtrl.text.trim(), requiresZoneId: requiresZone);
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _toggle(Map g) async {
    try {
      await ApiService.toggleTopupGame(g['id']);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _delete(Map g) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete this game?', style: TextStyle(color: Colors.white)),
        content: Text('${g['name']} and all its packages will be deleted.', style: const TextStyle(color: AppColors.hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deleteTopupGame(g['id']);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _showEditor(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: _games.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No games yet — tap + to add one', style: TextStyle(color: AppColors.hint)))])
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _games.length,
                          itemBuilder: (context, i) {
                            final g = _games[i];
                            final active = g['is_active'] == true || g['is_active'] == 1;
                            return Card(
                              color: AppColors.surface,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                leading: CircleAvatar(
                                  backgroundColor: AppColors.primary.withOpacity(0.15),
                                  backgroundImage: (g['icon_url'] != null && g['icon_url'].toString().isNotEmpty) ? NetworkImage(g['icon_url']) : null,
                                  child: (g['icon_url'] == null || g['icon_url'].toString().isEmpty) ? const Icon(Icons.videogame_asset, color: AppColors.primary) : null,
                                ),
                                title: Text(g['name']?.toString() ?? '', style: TextStyle(color: active ? Colors.white : AppColors.hint, fontWeight: FontWeight.bold)),
                                subtitle: Text('${g['package_count'] ?? 0} packages${(g['requires_zone_id'] == true || g['requires_zone_id'] == 1) ? ' · needs Zone ID' : ''}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                onTap: () => Navigator.push(context, MaterialPageRoute(builder: (_) => TopupPackagesScreen(gameId: g['id'], gameName: g['name']))),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(value: active, activeColor: AppColors.primary, onChanged: (_) => _toggle(g)),
                                    PopupMenuButton<String>(
                                      color: AppColors.surface,
                                      icon: const Icon(Icons.more_vert, color: AppColors.hint),
                                      onSelected: (v) {
                                        if (v == 'edit') _showEditor(existing: g);
                                        if (v == 'delete') _delete(g);
                                      },
                                      itemBuilder: (ctx) => const [
                                        PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                                        PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
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

// ============================== ORDERS ==============================
class _OrdersTab extends StatefulWidget {
  const _OrdersTab();

  @override
  State<_OrdersTab> createState() => _OrdersTabState();
}

class _OrdersTabState extends State<_OrdersTab> with SingleTickerProviderStateMixin {
  late final TabController _statusTab;
  final List<Map<String, String>> _statuses = [
    {'label': 'Pending', 'value': 'pending'},
    {'label': 'Completed', 'value': 'completed'},
    {'label': 'Failed', 'value': 'failed'},
    {'label': 'All', 'value': 'all'},
  ];
  List<dynamic> _orders = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _statusTab = TabController(length: _statuses.length, vsync: this);
    _statusTab.addListener(() {
      if (!_statusTab.indexIsChanging) _load();
    });
    _load();
  }

  @override
  void dispose() {
    _statusTab.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final list = await ApiService.getTopupOrders(status: _statuses[_statusTab.index]['value']!);
      setState(() {
        _orders = list;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _complete(Map o) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Mark as delivered?', style: TextStyle(color: Colors.white)),
        content: Text('Confirm you have delivered ${o['package_name']} to player ${o['player_id']} in ${o['game_name']}.', style: const TextStyle(color: AppColors.hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Confirm')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.completeTopupOrder(o['id']);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _fail(Map o) async {
    final reasonCtrl = TextEditingController();
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Mark as failed & refund', style: TextStyle(color: Colors.white)),
        content: TextField(
          controller: reasonCtrl,
          style: const TextStyle(color: Colors.white),
          decoration: const InputDecoration(labelText: 'Reason (optional)'),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Fail & Refund'),
          ),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.failTopupOrder(o['id'], reasonCtrl.text.trim());
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Color _statusColor(String s) {
    switch (s) {
      case 'completed':
        return Colors.greenAccent;
      case 'failed':
        return Colors.redAccent;
      case 'refunded':
        return Colors.orangeAccent;
      default:
        return AppColors.primary;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        TabBar(
          controller: _statusTab,
          isScrollable: true,
          indicatorColor: AppColors.primary,
          labelColor: Colors.white,
          unselectedLabelColor: AppColors.hint,
          tabs: _statuses.map((s) => Tab(text: s['label'])).toList(),
        ),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
              : _error != null
                  ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: _orders.isEmpty
                          ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No orders here', style: TextStyle(color: AppColors.hint)))])
                          : ListView.builder(
                              padding: const EdgeInsets.all(12),
                              itemCount: _orders.length,
                              itemBuilder: (context, i) {
                                final o = _orders[i];
                                final status = o['status']?.toString() ?? '';
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
                                              child: Text('${o['game_name']} — ${o['package_name']}', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                            ),
                                            Container(
                                              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                                              decoration: BoxDecoration(color: _statusColor(status).withOpacity(0.15), borderRadius: BorderRadius.circular(8)),
                                              child: Text(status, style: TextStyle(color: _statusColor(status), fontSize: 11, fontWeight: FontWeight.bold)),
                                            ),
                                          ],
                                        ),
                                        const SizedBox(height: 6),
                                        Text('Player ID: ${o['player_id']}${o['zone_id'] != null ? ' (Zone: ${o['zone_id']})' : ''}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                        if (o['region'] != null) Text('Region: ${o['region']}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                        Text('Buyer: ${o['user_email']} · LKR ${o['price']}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                        if (o['admin_note'] != null) Text('Note: ${o['admin_note']}', style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
                                        if (status == 'pending') ...[
                                          const SizedBox(height: 10),
                                          Row(
                                            children: [
                                              Expanded(
                                                child: OutlinedButton(
                                                  onPressed: () => _fail(o),
                                                  style: OutlinedButton.styleFrom(side: const BorderSide(color: Colors.redAccent)),
                                                  child: const Text('Fail & Refund', style: TextStyle(color: Colors.redAccent)),
                                                ),
                                              ),
                                              const SizedBox(width: 10),
                                              Expanded(
                                                child: ElevatedButton(onPressed: () => _complete(o), child: const Text('Mark Delivered')),
                                              ),
                                            ],
                                          ),
                                        ],
                                      ],
                                    ),
                                  ),
                                );
                              },
                            ),
                    ),
        ),
      ],
    );
  }
}

import 'package:flutter/material.dart';
import '../services/api_service.dart';

class MoreToolsAdminScreen extends StatefulWidget {
  const MoreToolsAdminScreen({super.key});

  @override
  State<MoreToolsAdminScreen> createState() => _MoreToolsAdminScreenState();
}

class _MoreToolsAdminScreenState extends State<MoreToolsAdminScreen> {
  List<dynamic> _tools = [];
  Map<String, dynamic> _settings = {};
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  void _msg(String m) => ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(m)));

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final d = await ApiService.getMoreToolsAdmin();
      _tools = (d['tools'] as List?) ?? [];
      _settings = Map<String, dynamic>.from((d['settings'] as Map?) ?? {});
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
    if (mounted) setState(() => _loading = false);
  }

  Future<void> _editSettings() async {
    final limitCtrl = TextEditingController(text: '${_settings['dailyLimit'] ?? 1}');
    final keyCtrl = TextEditingController();
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Free Fire Info settings'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: limitCtrl,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: 'Checks per user per day'),
            ),
            TextField(
              controller: keyCtrl,
              decoration: InputDecoration(labelText: 'API key (current: ${_settings['apiKeyPreview'] ?? ''})', helperText: 'Leave empty to keep current'),
            ),
          ],
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Save')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.saveMoreToolSettings(dailyLimit: int.tryParse(limitCtrl.text.trim()), apiKey: keyCtrl.text.trim());
      _msg('Saved');
      _load();
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _addTool() async {
    final title = TextEditingController();
    final sub = TextEditingController();
    final link = TextEditingController();
    String icon = 'apps';
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setD) => AlertDialog(
          title: const Text('Add tool'),
          content: SingleChildScrollView(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                TextField(controller: title, decoration: const InputDecoration(labelText: 'Title')),
                TextField(controller: sub, decoration: const InputDecoration(labelText: 'Subtitle (optional)')),
                TextField(controller: link, decoration: const InputDecoration(labelText: 'Link URL (opens when tapped)')),
                const SizedBox(height: 8),
                DropdownButton<String>(
                  value: icon,
                  isExpanded: true,
                  items: const ['apps', 'sports_esports', 'diamond', 'search', 'shield', 'star']
                      .map((i) => DropdownMenuItem(value: i, child: Text(i)))
                      .toList(),
                  onChanged: (v) => setD(() => icon = v ?? 'apps'),
                ),
              ],
            ),
          ),
          actions: [
            TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
            ElevatedButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Add')),
          ],
        ),
      ),
    );
    if (ok != true || title.text.trim().isEmpty) return;
    try {
      await ApiService.addMoreTool(
        title: title.text.trim(),
        subtitle: sub.text.trim(),
        icon: icon,
        linkUrl: link.text.trim().isEmpty ? null : link.text.trim(),
      );
      _load();
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _toggle(dynamic id) async {
    try {
      await ApiService.toggleMoreTool(id);
      _load();
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  Future<void> _delete(Map t) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        title: const Text('Delete tool?'),
        content: Text('${t['title']}'),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (ok != true) return;
    try {
      await ApiService.deleteMoreTool(t['id']);
      _load();
    } catch (e) {
      _msg(e.toString().replaceFirst('Exception: ', ''));
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('More Tools')),
      floatingActionButton: FloatingActionButton(onPressed: _addTool, child: const Icon(Icons.add)),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView(
                padding: const EdgeInsets.all(12),
                children: [
                  Card(
                    child: ListTile(
                      leading: const Icon(Icons.tune),
                      title: const Text('Free Fire Info settings'),
                      subtitle: Text('Limit: ${_settings['dailyLimit'] ?? '-'} / user / day   |   Key: ${_settings['apiKeyPreview'] ?? ''}'),
                      trailing: const Icon(Icons.edit),
                      onTap: _editSettings,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._tools.map((t) {
                    final m = t as Map;
                    final builtIn = m['key'] == 'ff_info';
                    return Card(
                      child: ListTile(
                        title: Text('${m['title']}'),
                        subtitle: Text(builtIn ? 'Built-in' : ((m['linkUrl'] ?? '').toString().isEmpty ? 'Coming soon box' : '${m['linkUrl']}')),
                        trailing: Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Switch(value: m['isActive'] == true, onChanged: (_) => _toggle(m['id'])),
                            if (!builtIn) IconButton(icon: const Icon(Icons.delete_outline), onPressed: () => _delete(m)),
                          ],
                        ),
                      ),
                    );
                  }),
                ],
              ),
            ),
    );
  }
}

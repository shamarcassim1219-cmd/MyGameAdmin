import 'package:flutter/material.dart';
import '../main.dart';
import '../services/api_service.dart';

class TopupPackagesScreen extends StatefulWidget {
  final int gameId;
  final String gameName;
  const TopupPackagesScreen({super.key, required this.gameId, required this.gameName});

  @override
  State<TopupPackagesScreen> createState() => _TopupPackagesScreenState();
}

class _TopupPackagesScreenState extends State<TopupPackagesScreen> {
  List<dynamic> _packages = [];
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
      final list = await ApiService.getTopupPackages(widget.gameId);
      setState(() {
        _packages = list;
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
    final priceCtrl = TextEditingController(text: existing != null ? existing['price'].toString() : '');
    String category = existing?['category']?.toString() ?? 'diamonds';

    final saved = await showDialog<bool>(
      context: context,
      builder: (ctx) => StatefulBuilder(
        builder: (ctx, setDlg) => AlertDialog(
          backgroundColor: AppColors.surface,
          title: Text(existing == null ? 'Add Package' : 'Edit Package', style: const TextStyle(color: Colors.white)),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              TextField(
                controller: nameCtrl,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Package name', hintText: 'e.g. 100 Diamonds'),
              ),
              const SizedBox(height: 12),
              DropdownButtonFormField<String>(
                value: category,
                dropdownColor: AppColors.surface,
                style: const TextStyle(color: Colors.white),
                decoration: const InputDecoration(labelText: 'Category'),
                items: const [
                  DropdownMenuItem(value: 'diamonds', child: Text('Diamonds')),
                  DropdownMenuItem(value: 'weekly', child: Text('Weekly Membership')),
                  DropdownMenuItem(value: 'monthly', child: Text('Monthly Membership')),
                  DropdownMenuItem(value: 'other', child: Text('Other')),
                ],
                onChanged: (v) => setDlg(() => category = v ?? 'diamonds'),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: priceCtrl,
                style: const TextStyle(color: Colors.white),
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: 'Price (LKR)'),
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
    final price = double.tryParse(priceCtrl.text.trim());
    if (nameCtrl.text.trim().isEmpty || price == null) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(const SnackBar(content: Text('Enter a valid name and price')));
      return;
    }
    try {
      if (existing == null) {
        await ApiService.addTopupPackage(gameId: widget.gameId, name: nameCtrl.text.trim(), category: category, price: price);
      } else {
        await ApiService.updateTopupPackage(existing['id'], name: nameCtrl.text.trim(), category: category, price: price);
      }
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _toggle(Map p) async {
    try {
      await ApiService.toggleTopupPackage(p['id']);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _delete(Map p) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete this package?', style: TextStyle(color: Colors.white)),
        content: Text(p['name']?.toString() ?? '', style: const TextStyle(color: AppColors.hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete', style: TextStyle(color: Colors.redAccent))),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deleteTopupPackage(p['id']);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  String _categoryLabel(String c) {
    switch (c) {
      case 'weekly':
        return 'Weekly Membership';
      case 'monthly':
        return 'Monthly Membership';
      case 'diamonds':
        return 'Diamonds';
      default:
        return 'Other';
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: Text('${widget.gameName} — Packages')),
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
                  child: _packages.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No packages yet — tap + to add one', style: TextStyle(color: AppColors.hint)))])
                      : ListView.builder(
                          padding: const EdgeInsets.all(12),
                          itemCount: _packages.length,
                          itemBuilder: (context, i) {
                            final p = _packages[i];
                            final active = p['is_active'] == true || p['is_active'] == 1;
                            return Card(
                              color: AppColors.surface,
                              margin: const EdgeInsets.only(bottom: 10),
                              child: ListTile(
                                title: Text(p['name']?.toString() ?? '', style: TextStyle(color: active ? Colors.white : AppColors.hint, fontWeight: FontWeight.bold)),
                                subtitle: Text('${_categoryLabel(p['category']?.toString() ?? '')} · LKR ${p['price']}', style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                onTap: () => _showEditor(existing: p),
                                trailing: Row(
                                  mainAxisSize: MainAxisSize.min,
                                  children: [
                                    Switch(value: active, activeColor: AppColors.primary, onChanged: (_) => _toggle(p)),
                                    IconButton(icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 20), onPressed: () => _delete(p)),
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

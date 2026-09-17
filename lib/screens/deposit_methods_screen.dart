import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../services/api_service.dart';

class DepositMethodsScreen extends StatefulWidget {
  const DepositMethodsScreen({super.key});

  @override
  State<DepositMethodsScreen> createState() => _DepositMethodsScreenState();
}

class _DepositMethodsScreenState extends State<DepositMethodsScreen> {
  List<dynamic> _methods = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final methods = await ApiService.getDepositMethods();
      setState(() {
        _methods = methods;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _loading = false;
      });
    }
  }

  Future<void> _toggle(int id) async {
    try {
      await ApiService.toggleDepositMethod(id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _delete(int id) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Method', style: TextStyle(color: Colors.white)),
        content: const Text('Are you sure? This cannot be undone.', style: TextStyle(color: AppColors.hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: Colors.redAccent),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Delete'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    try {
      await ApiService.deleteDepositMethod(id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  void _openEditor({Map<String, dynamic>? existing}) {
    showDialog(
      context: context,
      builder: (ctx) => _MethodEditorDialog(existing: existing),
    ).then((changed) {
      if (changed == true) _load();
    });
  }

  Widget _typeIcon(String type) {
    switch (type) {
      case 'mobile_wallet':
        return const Icon(Icons.smartphone, color: AppColors.hint, size: 16);
      case 'crypto':
        return const Icon(Icons.currency_bitcoin, color: AppColors.hint, size: 16);
      default:
        return const Icon(Icons.account_balance, color: AppColors.hint, size: 16);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Deposit Methods')),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.primary,
        onPressed: () => _openEditor(),
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : _methods.isEmpty
                  ? const Center(child: Text('No deposit methods yet.\nTap + to add one.', textAlign: TextAlign.center, style: TextStyle(color: AppColors.hint)))
                  : RefreshIndicator(
                      onRefresh: _load,
                      color: AppColors.primary,
                      child: ListView.builder(
                        padding: const EdgeInsets.all(12),
                        itemCount: _methods.length,
                        itemBuilder: (context, i) {
                          final m = _methods[i];
                          final active = m['isActive'] == true;
                          return Container(
                            margin: const EdgeInsets.only(bottom: 10),
                            padding: const EdgeInsets.all(12),
                            decoration: BoxDecoration(
                              color: AppColors.surface,
                              borderRadius: BorderRadius.circular(12),
                              border: Border.all(color: AppColors.border),
                            ),
                            child: Row(
                              children: [
                                CircleAvatar(
                                  radius: 22,
                                  backgroundColor: AppColors.fieldFill,
                                  backgroundImage: m['iconUrl'] != null ? NetworkImage(m['iconUrl']) : null,
                                  child: m['iconUrl'] == null ? _typeIcon(m['methodType'] ?? 'bank') : null,
                                ),
                                const SizedBox(width: 12),
                                Expanded(
                                  child: Column(
                                    crossAxisAlignment: CrossAxisAlignment.start,
                                    children: [
                                      Text(m['displayName'] ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold)),
                                      const SizedBox(height: 2),
                                      Text(
                                        m['accountNumber'] ?? m['extraInfo'] ?? '',
                                        style: const TextStyle(color: AppColors.hint, fontSize: 12),
                                      ),
                                    ],
                                  ),
                                ),
                                Switch(
                                  value: active,
                                  activeColor: AppColors.primary,
                                  onChanged: (_) => _toggle(m['id']),
                                ),
                                PopupMenuButton<String>(
                                  color: AppColors.surface,
                                  icon: const Icon(Icons.more_vert, color: AppColors.hint, size: 18),
                                  onSelected: (v) {
                                    if (v == 'edit') _openEditor(existing: m);
                                    if (v == 'delete') _delete(m['id']);
                                  },
                                  itemBuilder: (ctx) => const [
                                    PopupMenuItem(value: 'edit', child: Text('Edit', style: TextStyle(color: Colors.white))),
                                    PopupMenuItem(value: 'delete', child: Text('Delete', style: TextStyle(color: Colors.redAccent))),
                                  ],
                                ),
                              ],
                            ),
                          );
                        },
                      ),
                    ),
    );
  }
}

class _MethodEditorDialog extends StatefulWidget {
  final Map<String, dynamic>? existing;
  const _MethodEditorDialog({this.existing});

  @override
  State<_MethodEditorDialog> createState() => _MethodEditorDialogState();
}

class _MethodEditorDialogState extends State<_MethodEditorDialog> {
  late String _type;
  final _nameCtrl = TextEditingController();
  final _accountNameCtrl = TextEditingController();
  final _accountNumberCtrl = TextEditingController();
  final _branchCtrl = TextEditingController();
  final _extraCtrl = TextEditingController();
  String? _iconUrl;
  XFile? _pickedIcon;
  bool _saving = false;
  String? _error;

  @override
  void initState() {
    super.initState();
    final e = widget.existing;
    _type = e?['methodType'] ?? 'bank';
    _nameCtrl.text = e?['displayName'] ?? '';
    _accountNameCtrl.text = e?['accountName'] ?? '';
    _accountNumberCtrl.text = e?['accountNumber'] ?? '';
    _branchCtrl.text = e?['branch'] ?? '';
    _extraCtrl.text = e?['extraInfo'] ?? '';
    _iconUrl = e?['iconUrl'];
  }

  Future<void> _pickIcon() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 80, maxWidth: 300);
    if (picked != null) setState(() => _pickedIcon = picked);
  }

  Future<void> _save() async {
    if (_nameCtrl.text.trim().isEmpty) {
      setState(() => _error = 'Display name is required');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      String? iconUrl = _iconUrl;
      if (_pickedIcon != null) {
        iconUrl = await ApiService.uploadImage(_pickedIcon!);
      }
      final body = {
        'methodType': _type,
        'displayName': _nameCtrl.text.trim(),
        'iconUrl': iconUrl,
        'accountName': _accountNameCtrl.text.trim(),
        'accountNumber': _accountNumberCtrl.text.trim(),
        'branch': _branchCtrl.text.trim(),
        'extraInfo': _extraCtrl.text.trim(),
      };
      if (widget.existing != null) {
        await ApiService.updateDepositMethod(widget.existing!['id'], body);
      } else {
        await ApiService.addDepositMethod(body);
      }
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _saving = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surface,
      title: Text(widget.existing != null ? 'Edit Method' : 'Add Method', style: const TextStyle(color: Colors.white)),
      content: SingleChildScrollView(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: GestureDetector(
                onTap: _pickIcon,
                child: CircleAvatar(
                  radius: 30,
                  backgroundColor: AppColors.fieldFill,
                  backgroundImage: _pickedIcon != null
                      ? null
                      : (_iconUrl != null ? NetworkImage(_iconUrl!) : null),
                  child: (_pickedIcon == null && _iconUrl == null)
                      ? const Icon(Icons.add_a_photo_outlined, color: AppColors.hint)
                      : null,
                ),
              ),
            ),
            const SizedBox(height: 14),
            DropdownButtonFormField<String>(
              value: _type,
              dropdownColor: AppColors.surface,
              decoration: const InputDecoration(labelText: 'Type'),
              items: const [
                DropdownMenuItem(value: 'bank', child: Text('Bank', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'mobile_wallet', child: Text('Mobile Wallet', style: TextStyle(color: Colors.white))),
                DropdownMenuItem(value: 'crypto', child: Text('Crypto', style: TextStyle(color: Colors.white))),
              ],
              onChanged: (v) => setState(() => _type = v ?? 'bank'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _nameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Display Name (e.g. Sampath Bank)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _accountNameCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Account Name'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _accountNumberCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Account / Wallet Number'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _branchCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Branch (bank only)'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _extraCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Extra Info (e.g. Binance ID note)'),
            ),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 12)),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('Cancel')),
        ElevatedButton(
          onPressed: _saving ? null : _save,
          child: _saving
              ? const SizedBox(height: 16, width: 16, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
              : const Text('Save'),
        ),
      ],
    );
  }
}

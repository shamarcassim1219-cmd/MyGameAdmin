import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';
import '../services/api_service.dart';

class PromotionsScreen extends StatefulWidget {
  const PromotionsScreen({super.key});

  @override
  State<PromotionsScreen> createState() => _PromotionsScreenState();
}

class _PromotionsScreenState extends State<PromotionsScreen> {
  List<dynamic> _promotions = [];
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
      final list = await ApiService.getAllPromotions();
      setState(() {
        _promotions = list;
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
      await ApiService.togglePromotion(id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _delete(int id) async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Delete Promotion?', style: TextStyle(color: Colors.white)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Delete')),
        ],
      ),
    );
    if (confirm != true) return;
    try {
      await ApiService.deletePromotion(id);
      _load();
    } catch (e) {
      if (mounted) ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(e.toString().replaceFirst('Exception: ', ''))));
    }
  }

  Future<void> _openCreateSheet() async {
    final created = await showModalBottomSheet<bool>(
      context: context,
      isScrollControlled: true,
      backgroundColor: AppColors.bg,
      builder: (_) => const _CreatePromotionSheet(),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Promotions')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateSheet,
        backgroundColor: AppColors.primary,
        child: const Icon(Icons.add, color: Colors.white),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator(color: AppColors.primary))
          : _error != null
              ? Center(child: Text(_error!, style: const TextStyle(color: Colors.redAccent)))
              : RefreshIndicator(
                  onRefresh: _load,
                  color: AppColors.primary,
                  child: _promotions.isEmpty
                      ? ListView(children: const [SizedBox(height: 120), Center(child: Text('No promotions yet — tap + to add one', style: TextStyle(color: AppColors.hint)))])
                      : ListView.builder(
                          padding: const EdgeInsets.only(bottom: 80),
                          itemCount: _promotions.length,
                          itemBuilder: (context, i) {
                            final p = _promotions[i];
                            final active = p['isActive'] == true;
                            final id = p['id'] is int ? p['id'] : int.parse(p['id'].toString());
                            return Card(
                              color: AppColors.surface,
                              margin: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                              child: Column(
                                crossAxisAlignment: CrossAxisAlignment.start,
                                children: [
                                  if (p['imageUrl'] != null && p['imageUrl'].toString().isNotEmpty)
                                    ClipRRect(
                                      borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
                                      child: Image.network(p['imageUrl'], height: 140, width: double.infinity, fit: BoxFit.cover,
                                          errorBuilder: (_, __, ___) => Container(height: 140, color: AppColors.fieldFill, child: const Icon(Icons.broken_image_outlined, color: AppColors.hint))),
                                    ),
                                  Padding(
                                    padding: const EdgeInsets.all(12),
                                    child: Column(
                                      crossAxisAlignment: CrossAxisAlignment.start,
                                      children: [
                                        Row(
                                          children: [
                                            Expanded(child: Text(p['title']?.toString() ?? '', style: const TextStyle(color: Colors.white, fontWeight: FontWeight.bold))),
                                            Switch(value: active, activeColor: AppColors.primary, onChanged: (_) => _toggle(id)),
                                          ],
                                        ),
                                        if (p['description'] != null && p['description'].toString().isNotEmpty)
                                          Padding(
                                            padding: const EdgeInsets.only(top: 4),
                                            child: Text(p['description'].toString(), style: const TextStyle(color: AppColors.hint, fontSize: 12)),
                                          ),
                                        const SizedBox(height: 8),
                                        Align(
                                          alignment: Alignment.centerRight,
                                          child: TextButton.icon(
                                            onPressed: () => _delete(id),
                                            icon: const Icon(Icons.delete_outline, color: Colors.redAccent, size: 18),
                                            label: const Text('Delete', style: TextStyle(color: Colors.redAccent)),
                                          ),
                                        ),
                                      ],
                                    ),
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

class _CreatePromotionSheet extends StatefulWidget {
  const _CreatePromotionSheet();

  @override
  State<_CreatePromotionSheet> createState() => _CreatePromotionSheetState();
}

class _CreatePromotionSheetState extends State<_CreatePromotionSheet> {
  final _titleCtrl = TextEditingController();
  final _descCtrl = TextEditingController();
  final _linkCtrl = TextEditingController();
  XFile? _pickedImage;
  bool _uploading = false;
  String? _error;

  Future<void> _pickImage() async {
    final picker = ImagePicker();
    final file = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
    if (file != null) setState(() => _pickedImage = file);
  }

  Future<void> _submit() async {
    final title = _titleCtrl.text.trim();
    if (title.isEmpty) {
      setState(() => _error = 'Title is required');
      return;
    }
    if (_pickedImage == null) {
      setState(() => _error = 'Please select an image');
      return;
    }
    setState(() {
      _uploading = true;
      _error = null;
    });
    try {
      final imageUrl = await ApiService.uploadImage(_pickedImage!);
      await ApiService.createPromotion(
        title,
        _descCtrl.text.trim(),
        imageUrl,
        _linkCtrl.text.trim().isEmpty ? null : _linkCtrl.text.trim(),
      );
      if (mounted) Navigator.pop(context, true);
    } catch (e) {
      setState(() => _error = e.toString().replaceFirst('Exception: ', ''));
    } finally {
      if (mounted) setState(() => _uploading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: EdgeInsets.only(bottom: MediaQuery.of(context).viewInsets.bottom, left: 16, right: 16, top: 16),
      child: SingleChildScrollView(
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('New Promotion', style: TextStyle(color: Colors.white, fontSize: 18, fontWeight: FontWeight.bold)),
            const SizedBox(height: 16),
            GestureDetector(
              onTap: _pickImage,
              child: Container(
                height: 140,
                width: double.infinity,
                decoration: BoxDecoration(color: AppColors.fieldFill, borderRadius: BorderRadius.circular(12), border: Border.all(color: AppColors.border)),
                child: _pickedImage == null
                    ? const Center(child: Icon(Icons.add_photo_alternate_outlined, color: AppColors.hint, size: 36))
                    : ClipRRect(
                        borderRadius: BorderRadius.circular(12),
                        child: Image.network(_pickedImage!.path, fit: BoxFit.cover),
                      ),
              ),
            ),
            const SizedBox(height: 16),
            TextField(controller: _titleCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Title')),
            const SizedBox(height: 12),
            TextField(controller: _descCtrl, style: const TextStyle(color: Colors.white), maxLines: 2, decoration: const InputDecoration(labelText: 'Description (optional)')),
            const SizedBox(height: 12),
            TextField(controller: _linkCtrl, style: const TextStyle(color: Colors.white), decoration: const InputDecoration(labelText: 'Link URL (optional)')),
            if (_error != null) ...[
              const SizedBox(height: 10),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            const SizedBox(height: 20),
            SizedBox(
              width: double.infinity,
              height: 50,
              child: ElevatedButton(
                onPressed: _uploading ? null : _submit,
                child: _uploading
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Text('Create Promotion'),
              ),
            ),
            const SizedBox(height: 24),
          ],
        ),
      ),
    );
  }
}

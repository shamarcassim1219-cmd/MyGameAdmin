import 'dart:io';
import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'dart:typed_data';
import '../widgets/simple_cropper.dart';
import '../main.dart';
import '../services/api_service.dart';

class BroadcastScreen extends StatefulWidget {
  const BroadcastScreen({super.key});

  @override
  State<BroadcastScreen> createState() => _BroadcastScreenState();
}

class _BroadcastScreenState extends State<BroadcastScreen> {
  final _titleCtrl = TextEditingController();
  final _bodyCtrl = TextEditingController();
  bool _sending = false;
  String? _resultMessage;
  String? _error;
  XFile? _image;

  @override
  void dispose() {
    _titleCtrl.dispose();
    _bodyCtrl.dispose();
    super.dispose();
  }

  Future<void> _pickImage() async {
    final picked = await ImagePicker().pickImage(source: ImageSource.gallery, imageQuality: 60, maxWidth: 1024);
    if (picked == null) return;
    final cropped = await _cropImage(picked);
    if (mounted) setState(() => _image = cropped);
  }

  Future<void> _recropImage() async {
    if (_image == null) return;
    final cropped = await _cropImage(_image!);
    if (mounted) setState(() => _image = cropped);
  }

  Future<XFile> _cropImage(XFile img) async {
    try {
      final bytes = await img.readAsBytes();
      if (!mounted) return img;
      final result = await Navigator.push<Uint8List>(
        context,
        MaterialPageRoute(builder: (_) => SimpleImageCropper(bytes: bytes, aspectRatio: 16 / 9), fullscreenDialog: true),
      );
      if (result == null) return img;
      return await saveCroppedImage(result, img.name);
    } catch (_) {
      return img;
    }
  }

  Future<void> _send() async {
    final title = _titleCtrl.text.trim();
    final body = _bodyCtrl.text.trim();
    if (title.isEmpty || body.isEmpty) {
      setState(() => _error = 'Title and message are both required');
      return;
    }

    final confirm = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppColors.surface,
        title: const Text('Send to all users?', style: TextStyle(color: Colors.white)),
        content: Text('"$title" will be sent as a push notification to every user.', style: const TextStyle(color: AppColors.hint)),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          TextButton(onPressed: () => Navigator.pop(ctx, true), child: const Text('Send')),
        ],
      ),
    );
    if (confirm != true) return;

    setState(() {
      _sending = true;
      _error = null;
      _resultMessage = null;
    });
    try {
      String? imageUrl;
      if (_image != null) imageUrl = await ApiService.uploadImage(_image!);
      final msg = await ApiService.sendBroadcast(title, body, imageUrl: imageUrl);
      setState(() {
        _resultMessage = msg;
        _sending = false;
        _image = null;
      });
      _titleCtrl.clear();
      _bodyCtrl.clear();
    } catch (e) {
      setState(() {
        _error = e.toString().replaceFirst('Exception: ', '');
        _sending = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.bg,
      appBar: AppBar(title: const Text('Notifications — Broadcast')),
      body: SingleChildScrollView(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text('Send a push notification to all users', style: TextStyle(color: AppColors.hint, fontSize: 13)),
            const SizedBox(height: 20),
            TextField(
              controller: _titleCtrl,
              style: const TextStyle(color: Colors.white),
              decoration: const InputDecoration(labelText: 'Title', hintText: 'e.g. New Feature Available'),
            ),
            const SizedBox(height: 16),
            TextField(
              controller: _bodyCtrl,
              style: const TextStyle(color: Colors.white),
              maxLines: 5,
              decoration: const InputDecoration(labelText: 'Message', hintText: 'Write your announcement here...'),
            ),
            const SizedBox(height: 16),
            if (_image != null)
              Stack(
                alignment: Alignment.topRight,
                children: [
                  GestureDetector(
                    onTap: _sending ? null : _recropImage,
                    child: ClipRRect(
                      borderRadius: BorderRadius.circular(10),
                      child: Image.file(File(_image!.path), width: double.infinity, height: 180, fit: BoxFit.cover),
                    ),
                  ),
                  Positioned(
                    left: 8, bottom: 8,
                    child: IconButton(
                      icon: const Icon(Icons.crop, color: Colors.white, size: 20),
                      style: IconButton.styleFrom(backgroundColor: Colors.black54),
                      onPressed: _sending ? null : _recropImage,
                    ),
                  ),
                  IconButton(
                    icon: const Icon(Icons.close, color: Colors.white),
                    style: IconButton.styleFrom(backgroundColor: Colors.black54),
                    onPressed: _sending ? null : () => setState(() => _image = null),
                  ),
                ],
              )
            else
              OutlinedButton.icon(
                onPressed: _sending ? null : _pickImage,
                icon: const Icon(Icons.image_outlined),
                label: const Text('Add image (optional)'),
              ),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.redAccent, fontSize: 13)),
            ],
            if (_resultMessage != null) ...[
              const SizedBox(height: 12),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(color: Colors.greenAccent.withOpacity(0.1), borderRadius: BorderRadius.circular(10)),
                child: Text(_resultMessage!, style: const TextStyle(color: Colors.greenAccent, fontSize: 13)),
              ),
            ],
            const SizedBox(height: 24),
            SizedBox(
              width: double.infinity,
              height: 52,
              child: ElevatedButton.icon(
                onPressed: _sending ? null : _send,
                icon: _sending
                    ? const SizedBox(height: 18, width: 18, child: CircularProgressIndicator(strokeWidth: 2, color: Colors.black))
                    : const Icon(Icons.campaign_outlined),
                label: Text(_sending ? 'Sending...' : 'Send to All Users'),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

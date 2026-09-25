import 'dart:io';
import 'dart:typed_data';
import 'dart:ui' as ui;
import 'package:flutter/material.dart';
import 'package:flutter/rendering.dart';
import 'package:image_picker/image_picker.dart';
import '../main.dart';

class SimpleImageCropper extends StatefulWidget {
  final Uint8List bytes;
  final double aspectRatio;
  const SimpleImageCropper({super.key, required this.bytes, this.aspectRatio = 1});

  @override
  State<SimpleImageCropper> createState() => _SimpleImageCropperState();
}

class _SimpleImageCropperState extends State<SimpleImageCropper> {
  final GlobalKey _boundaryKey = GlobalKey();
  bool _saving = false;

  Future<void> _done() async {
    if (_saving) return;
    setState(() => _saving = true);
    try {
      final renderObject = _boundaryKey.currentContext?.findRenderObject();
      if (renderObject is! RenderRepaintBoundary) throw Exception('not ready');
      const targetWidth = 1200.0;
      final pixelRatio = renderObject.size.width > 0 ? targetWidth / renderObject.size.width : 1.0;
      final image = await renderObject.toImage(pixelRatio: pixelRatio);
      final data = await image.toByteData(format: ui.ImageByteFormat.png);
      if (data == null) throw Exception('capture failed');
      if (mounted) Navigator.pop(context, data.buffer.asUint8List());
    } catch (e) {
      if (mounted) {
        setState(() => _saving = false);
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text('Could not crop: $e')));
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        foregroundColor: Colors.white,
        title: const Text('Adjust photo'),
        actions: [
          TextButton(
            onPressed: _saving ? null : () => Navigator.pop(context),
            child: const Text('Skip', style: TextStyle(color: Colors.white70)),
          ),
        ],
      ),
      body: Column(
        children: [
          const Padding(
            padding: EdgeInsets.fromLTRB(20, 12, 20, 4),
            child: Text(
              'Pinch to zoom and drag to position your photo inside the frame.',
              style: TextStyle(color: Colors.white70, fontSize: 13),
              textAlign: TextAlign.center,
            ),
          ),
          Expanded(
            child: Center(
              child: AspectRatio(
                aspectRatio: widget.aspectRatio,
                child: ClipRect(
                  child: RepaintBoundary(
                    key: _boundaryKey,
                    child: ColoredBox(
                      color: Colors.black,
                      child: InteractiveViewer(
                        minScale: 0.5,
                        maxScale: 4,
                        boundaryMargin: const EdgeInsets.all(400),
                        child: Image.memory(widget.bytes, fit: BoxFit.contain),
                      ),
                    ),
                  ),
                ),
              ),
            ),
          ),
          Padding(
            padding: const EdgeInsets.all(20),
            child: SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppColors.primary,
                  padding: const EdgeInsets.symmetric(vertical: 14),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
                ),
                onPressed: _saving ? null : _done,
                child: _saving
                    ? const SizedBox(
                        height: 20,
                        width: 20,
                        child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white),
                      )
                    : const Text('Use this crop', style: TextStyle(fontWeight: FontWeight.bold)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

Future<XFile> saveCroppedImage(Uint8List bytes, String originalName) async {
  final name = originalName.isEmpty ? 'crop.png' : originalName;
  final dir = Directory('${Directory.systemTemp.path}/cropped');
  if (!await dir.exists()) await dir.create(recursive: true);
  final dest = '${dir.path}/${DateTime.now().microsecondsSinceEpoch}_$name';
  await File(dest).writeAsBytes(bytes);
  return XFile(dest, name: name);
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({
    super.key,
    this.startFromGallery = false,
    this.title = '扫描箱贴二维码',
    this.allowGalleryImport = true,
    this.showBottomGalleryButton = true,
    this.showEndScanAction = false,
    this.endScanResult,
    this.minContinuousDetections = 1,
    this.validateResult,
  });

  final bool startFromGallery;
  final String title;
  final bool allowGalleryImport;
  final bool showBottomGalleryButton;
  final bool showEndScanAction;
  final String? endScanResult;
  final int minContinuousDetections;
  final bool Function(String value)? validateResult;

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen>
    with SingleTickerProviderStateMixin {
  static const double _scanBoxSize = 280;

  final MobileScannerController _controller = MobileScannerController(
    formats: const [BarcodeFormat.qrCode],
    detectionSpeed: DetectionSpeed.normal,
  );
  final ImagePicker _picker = ImagePicker();

  late final AnimationController _lineController;
  bool _handled = false;
  String? _lastRawValue;
  int _continuousHitCount = 0;

  @override
  void initState() {
    super.initState();
    _lineController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1500),
    )..repeat(reverse: true);

    if (widget.startFromGallery) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (widget.allowGalleryImport) {
          _pickFromGallery();
        }
      });
    }
  }

  @override
  void dispose() {
    _lineController.dispose();
    _controller.dispose();
    super.dispose();
  }

  void _onDetect(BarcodeCapture capture) {
    if (_handled || capture.barcodes.isEmpty) {
      return;
    }

    final values = capture.barcodes
        .map((e) => e.rawValue?.trim())
        .whereType<String>()
        .where((e) => e.isNotEmpty)
        .toList();
    if (values.isEmpty) {
      return;
    }

    final validator = widget.validateResult;
    final value = validator == null
        ? values.first
        : values.firstWhere(
            validator,
            orElse: () => '',
          );
    if (value.isEmpty) {
      return;
    }

    if (_lastRawValue == value) {
      _continuousHitCount += 1;
    } else {
      _lastRawValue = value;
      _continuousHitCount = 1;
    }
    if (_continuousHitCount < widget.minContinuousDetections) {
      return;
    }

    _handled = true;
    Navigator.of(context).pop(value);
  }

  Future<void> _pickFromGallery() async {
    if (_handled) {
      return;
    }

    final file = await _picker.pickImage(source: ImageSource.gallery);
    if (!mounted || file == null) {
      return;
    }

    final capture = await _controller.analyzeImage(file.path);
    if (!mounted) {
      return;
    }

    if (capture == null || capture.barcodes.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('图片中未识别到二维码')),
      );
      return;
    }

    final value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('识别结果为空')),
      );
      return;
    }

    _handled = true;
    Navigator.of(context).pop(value);
  }

  Widget _buildOverlay() {
    return IgnorePointer(
      child: Center(
        child: SizedBox(
          width: _scanBoxSize,
          height: _scanBoxSize,
          child: Stack(
            children: [
              Container(
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(20),
                  border: Border.all(color: const Color(0xFF6C63FF), width: 2),
                ),
              ),
              AnimatedBuilder(
                animation: _lineController,
                builder: (context, child) {
                  final top = _lineController.value * (_scanBoxSize - 4);
                  return Positioned(
                    left: 6,
                    right: 6,
                    top: top,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(99),
                        color: const Color(0xFF00CC99),
                        boxShadow: const [
                          BoxShadow(
                            color: Color(0x6600CC99),
                            blurRadius: 8,
                            spreadRadius: 1,
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ],
          ),
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.title),
        actions: [
          if (widget.allowGalleryImport)
            IconButton(
              tooltip: '本地图片识别',
              onPressed: _pickFromGallery,
              icon: const Icon(Icons.photo_library_outlined),
            ),
          if (widget.showEndScanAction)
            TextButton(
              onPressed: () => Navigator.of(context).pop(widget.endScanResult),
              child: const Text('结束扫描'),
            ),
        ],
      ),
      body: Stack(
        fit: StackFit.expand,
        children: [
          MobileScanner(
            controller: _controller,
            onDetect: _onDetect,
          ),
          _buildOverlay(),
          if (widget.allowGalleryImport && widget.showBottomGalleryButton)
            Positioned(
              left: 20,
              right: 20,
              bottom: 26,
              child: FilledButton.tonalIcon(
                onPressed: _pickFromGallery,
                icon: const Icon(Icons.image_outlined),
                label: const Text('从本地图片识别'),
              ),
            ),
        ],
      ),
    );
  }
}

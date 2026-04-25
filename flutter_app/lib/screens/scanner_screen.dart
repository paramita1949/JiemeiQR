import 'package:flutter/material.dart';
import 'package:mobile_scanner/mobile_scanner.dart';

class ScannerScreen extends StatefulWidget {
  const ScannerScreen({super.key});

  @override
  State<ScannerScreen> createState() => _ScannerScreenState();
}

class _ScannerScreenState extends State<ScannerScreen> {
  bool _handled = false;

  void _onDetect(BarcodeCapture capture) {
    if (_handled) {
      return;
    }

    if (capture.barcodes.isEmpty) {
      return;
    }
    final value = capture.barcodes.first.rawValue;
    if (value == null || value.isEmpty) {
      return;
    }

    _handled = true;
    Navigator.of(context).pop(value);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('扫描箱贴二维码'),
      ),
      body: MobileScanner(
        onDetect: _onDetect,
      ),
    );
  }
}

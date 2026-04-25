import 'package:flutter/material.dart';
import 'package:qrscan_flutter/screens/preview_screen.dart';
import 'package:qrscan_flutter/screens/scanner_screen.dart';
import 'package:qrscan_flutter/services/qr_parser.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  static const String _defaultCode = '00208540089567279FAYAUEZ32';

  Future<void> _startScan() async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    _openPreviewFromContent(result);
  }

  void _useDefault() {
    _openPreviewFromContent(_defaultCode);
  }

  void _openPreviewFromContent(String content) {
    final parsed = QrParser.parse(content);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('格式不匹配，请扫箱贴码')),
      );
      return;
    }

    final buildResult = QrParser.buildRecords(
      prefix: parsed.prefix,
      serialInt: parsed.serialInt,
      batch: parsed.batch,
      suffix: parsed.suffix,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          records: buildResult.records,
          scanIndex: buildResult.scanIndex,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final theme = Theme.of(context);
    return Scaffold(
      body: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                '箱贴二维码',
                style: theme.textTheme.headlineMedium?.copyWith(
                  fontWeight: FontWeight.bold,
                ),
              ),
              const SizedBox(height: 8),
              Text(
                '扫描箱贴码，自动生成序列预览',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _startScan,
                  child: const Text('开始扫描'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton(
                  onPressed: _useDefault,
                  child: const Text('跳过，使用默认配置'),
                ),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }
}

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
  static const List<int> _quickCounts = [10, 20, 50, 100];

  int _groupCount = 20;
  double _autoSlideSeconds = 1.0;
  bool _randomTail3 = false;

  Future<void> _startScan() async {
    await _openScannerAndPreview(startFromGallery: false);
  }

  Future<void> _startFromGallery() async {
    await _openScannerAndPreview(startFromGallery: true);
  }

  Future<void> _openScannerAndPreview({required bool startFromGallery}) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ScannerScreen(startFromGallery: startFromGallery),
      ),
    );

    if (!mounted || result == null) {
      return;
    }

    _openPreviewFromContent(result);
  }

  Future<void> _setGroupCount() async {
    final controller = TextEditingController(text: _groupCount.toString());
    final value = await showDialog<int>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('设置生成数量'),
          content: TextField(
            controller: controller,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: '每组张数（如 10、100）',
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final count = int.tryParse(controller.text.trim());
                if (count == null || count <= 0) {
                  return;
                }
                Navigator.of(context).pop(count);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (value == null) {
      return;
    }

    setState(() {
      _groupCount = value;
    });
  }

  Future<void> _setAutoSlideSeconds() async {
    final presets = <double>[0.5, 1.0, 2.0];
    final controller = TextEditingController(text: _autoSlideSeconds.toString());
    final value = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('设置自动滑动时间'),
          content: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Wrap(
                spacing: 8,
                children: presets
                    .map(
                      (item) => ActionChip(
                        label: Text('${item}s'),
                        onPressed: () => Navigator.of(context).pop(item),
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 12),
              TextField(
                controller: controller,
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(
                  labelText: '自定义秒数（例如 1.5）',
                ),
              ),
            ],
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('取消'),
            ),
            FilledButton(
              onPressed: () {
                final seconds = double.tryParse(controller.text.trim());
                if (seconds == null || seconds <= 0) {
                  return;
                }
                Navigator.of(context).pop(seconds);
              },
              child: const Text('确定'),
            ),
          ],
        );
      },
    );

    if (value == null) {
      return;
    }

    setState(() {
      _autoSlideSeconds = value;
    });
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
      serialSeed: parsed.serial,
      batch: parsed.batch,
      suffix: parsed.suffix,
      count: _groupCount,
      randomTail3: _randomTail3,
    );

    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          records: buildResult.records,
          scanIndex: buildResult.scanIndex,
          group: buildResult.group,
          initialAutoSlideSeconds: _autoSlideSeconds,
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
                '支持相机扫描与本地图片识别',
                style: theme.textTheme.bodyMedium?.copyWith(
                  color: Colors.white70,
                ),
              ),
              const SizedBox(height: 18),
              Text(
                '生成数量快捷设置',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                children: _quickCounts
                    .map(
                      (count) => ChoiceChip(
                        label: Text('$count'),
                        selected: _groupCount == count,
                        onSelected: (_) {
                          setState(() {
                            _groupCount = count;
                          });
                        },
                      ),
                    )
                    .toList(),
              ),
              const SizedBox(height: 10),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _setGroupCount,
                      child: Text('数量: $_groupCount 张'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton(
                      onPressed: _setAutoSlideSeconds,
                      child: Text('自动: ${_autoSlideSeconds}s'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: () {
                    setState(() {
                      _randomTail3 = !_randomTail3;
                    });
                  },
                  child: Text(_randomTail3 ? '随机模式: 开（末三位随机）' : '随机模式: 关（顺序递增）'),
                ),
              ),
              const SizedBox(height: 6),
              Text(
                '当前每组 $_groupCount 张，扫码后按此数量生成预览',
                style: theme.textTheme.bodySmall?.copyWith(color: Colors.white70),
              ),
              const Spacer(),
              SizedBox(
                width: double.infinity,
                child: FilledButton(
                  onPressed: _startScan,
                  child: const Text('开始扫描（相机）'),
                ),
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonal(
                  onPressed: _startFromGallery,
                  child: const Text('本地图片识别'),
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

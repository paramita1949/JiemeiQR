import 'package:flutter/material.dart';
import 'package:qrscan_flutter/features/qr/preview_screen.dart';
import 'package:qrscan_flutter/features/qr/scanner_screen.dart';
import 'package:qrscan_flutter/models/qr_record.dart';
import 'package:qrscan_flutter/services/qr_parser.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class QrEntryScreen extends StatefulWidget {
  const QrEntryScreen({super.key});

  @override
  State<QrEntryScreen> createState() => _QrEntryScreenState();
}

class _QrEntryScreenState extends State<QrEntryScreen> {
  final _manualContentController = TextEditingController();
  int _groupCount = 100;
  double _autoSlideSeconds = 1.0;
  bool _randomTailEnabled = true;
  int _randomTailDigits = 3;
  ParsedQr? _lastParsed;
  QrBuildResult? _lastBuildResult;

  @override
  void dispose() {
    _manualContentController.dispose();
    super.dispose();
  }

  Future<void> _startScan() => _openScannerAndPreview(startFromGallery: false);

  Future<void> _startFromGallery() =>
      _openScannerAndPreview(startFromGallery: true);

  Future<void> _openScannerAndPreview({required bool startFromGallery}) async {
    final result = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => ScannerScreen(startFromGallery: startFromGallery),
      ),
    );
    if (!mounted || result == null) {
      return;
    }
    _parseAndPreview(result);
  }

  void _parseAndPreview(String content) {
    final parsed = QrParser.parse(content);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('格式不匹配，请扫箱贴码')),
      );
      return;
    }
    setState(() => _lastParsed = parsed);
    _openPreview();
  }

  void _previewManualContent() {
    _parseAndPreview(_manualContentController.text.trim());
  }

  void _openPreview({int? startSerial}) {
    final parsed = _lastParsed;
    if (parsed == null) {
      return;
    }
    final buildResult = QrParser.buildRecords(
      prefix: parsed.prefix,
      serialSeed: parsed.serial,
      batch: parsed.batch,
      suffix: parsed.suffix,
      count: _groupCount,
      randomTailEnabled: _randomTailEnabled,
      randomTailDigits: _randomTailDigits,
      startSerial: startSerial,
    );
    setState(() => _lastBuildResult = buildResult);
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

  void _openNextGroup() {
    final lastGroup = _lastBuildResult?.group;
    if (lastGroup == null) {
      return;
    }
    final startSerial =
        _randomTailEnabled ? null : lastGroup.startSerial + lastGroup.count;
    _openPreview(startSerial: startSerial);
  }

  Future<void> _setGroupCount() async {
    final controller = TextEditingController(text: _groupCount.toString());
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置生成数量'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(labelText: '每组张数'),
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
      ),
    );
    if (value == null) {
      return;
    }
    setState(() {
      _groupCount = value;
      _lastBuildResult = null;
    });
  }

  Future<void> _setAutoSlideSeconds() async {
    final controller =
        TextEditingController(text: _autoSlideSeconds.toString());
    final value = await showDialog<double>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('设置自动滑动间隔'),
        content: TextField(
          controller: controller,
          keyboardType: const TextInputType.numberWithOptions(decimal: true),
          decoration: const InputDecoration(labelText: '秒数'),
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
      ),
    );
    if (value == null) {
      return;
    }
    setState(() => _autoSlideSeconds = value);
  }

  @override
  Widget build(BuildContext context) {
    final canGenerate = _lastParsed != null;
    final canContinue = _lastBuildResult != null;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageTitle(
                icon: Icons.qr_code_scanner_outlined,
                title: 'QR箱码生成',
                subtitle: '扫描后配置生成规则',
              ),
              const SizedBox(height: 12),
              _ScanCard(onScan: _startScan, onImportImage: _startFromGallery),
              const SizedBox(height: 12),
              _ManualQrCard(
                controller: _manualContentController,
                onPreview: _previewManualContent,
              ),
              const SizedBox(height: 12),
              _GenerateParamCard(
                groupCount: _groupCount,
                autoSlideSeconds: _autoSlideSeconds,
                randomTailEnabled: _randomTailEnabled,
                randomTailDigits: _randomTailDigits,
                onSetGroupCount: _setGroupCount,
                onSetAutoSlideSeconds: _setAutoSlideSeconds,
                onSetSequential: () => setState(() {
                  _randomTailEnabled = false;
                  _lastBuildResult = null;
                }),
                onSetRandom: () => setState(() {
                  _randomTailEnabled = true;
                  _lastBuildResult = null;
                }),
                onSetRandomDigits: (digits) => setState(() {
                  _randomTailEnabled = true;
                  _randomTailDigits = digits;
                  _lastBuildResult = null;
                }),
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: canGenerate ? () => _openPreview() : null,
                      icon: const Icon(Icons.play_arrow),
                      label: const Text('生成并预览'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.tonalIcon(
                      onPressed: canContinue ? _openNextGroup : null,
                      icon: const Icon(Icons.skip_next),
                      label: const Text('下一组继续'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              Text(
                _lastParsed == null ? '当前预览: 未扫描' : '当前预览: 1/$_groupCount',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                '提示: 请先扫描箱贴码或导入图片，再生成预览',
                style: TextStyle(color: Color(0xFF9A3412), fontSize: 11),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ManualQrCard extends StatelessWidget {
  const _ManualQrCard({
    required this.controller,
    required this.onPreview,
  });

  final TextEditingController controller;
  final VoidCallback onPreview;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      color: const Color(0xFFFFF7ED),
      children: [
        const _PanelTitle('手动输入箱码'),
        const SizedBox(height: 8),
        TextField(
          key: const Key('manualQrContentField'),
          controller: controller,
          textCapitalization: TextCapitalization.characters,
          decoration: const InputDecoration(
            labelText: '箱码内容',
            hintText: '00720680088454517EL3FJEZ31',
          ),
        ),
        const SizedBox(height: 10),
        SizedBox(
          width: double.infinity,
          child: FilledButton.icon(
            key: const Key('manualQrPreviewButton'),
            onPressed: onPreview,
            icon: const Icon(Icons.qr_code_2_outlined),
            label: const Text('生成二维码预览'),
          ),
        ),
      ],
    );
  }
}

class _ScanCard extends StatelessWidget {
  const _ScanCard({required this.onScan, required this.onImportImage});

  final VoidCallback onScan;
  final VoidCallback onImportImage;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      color: const Color(0xFFEAF7FF),
      children: [
        const _PanelTitle('扫码 / 本地图片识别'),
        const SizedBox(height: 4),
        const Text(
          '支持相机与本地图片导入',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 12),
        ),
        const SizedBox(height: 10),
        Row(
          children: [
            Expanded(
              child: FilledButton.icon(
                onPressed: onScan,
                icon: const Icon(Icons.photo_camera_outlined),
                label: const Text('开始扫码'),
              ),
            ),
            const SizedBox(width: 10),
            Expanded(
              child: FilledButton.tonalIcon(
                onPressed: onImportImage,
                icon: const Icon(Icons.photo_library_outlined),
                label: const Text('导入图片'),
              ),
            ),
          ],
        ),
      ],
    );
  }
}

class _GenerateParamCard extends StatelessWidget {
  const _GenerateParamCard({
    required this.groupCount,
    required this.autoSlideSeconds,
    required this.randomTailEnabled,
    required this.randomTailDigits,
    required this.onSetGroupCount,
    required this.onSetAutoSlideSeconds,
    required this.onSetSequential,
    required this.onSetRandom,
    required this.onSetRandomDigits,
  });

  final int groupCount;
  final double autoSlideSeconds;
  final bool randomTailEnabled;
  final int randomTailDigits;
  final VoidCallback onSetGroupCount;
  final VoidCallback onSetAutoSlideSeconds;
  final VoidCallback onSetSequential;
  final VoidCallback onSetRandom;
  final ValueChanged<int> onSetRandomDigits;

  @override
  Widget build(BuildContext context) {
    return _Panel(
      color: const Color(0xFFF3EEFF),
      children: [
        const _PanelTitle('生成参数'),
        const SizedBox(height: 6),
        Row(
          children: [
            Expanded(
              child: OutlinedButton(
                onPressed: onSetGroupCount,
                child: Text('数量: $groupCount'),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: OutlinedButton(
                onPressed: onSetAutoSlideSeconds,
                child: Text('自动滑动: ${autoSlideSeconds}s'),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Wrap(
          spacing: 8,
          runSpacing: 8,
          children: [
            ChoiceChip(
              label: const Text('顺序'),
              selected: !randomTailEnabled,
              onSelected: (_) => onSetSequential(),
            ),
            ChoiceChip(
              label: const Text('随机'),
              selected: randomTailEnabled,
              onSelected: (_) => onSetRandom(),
            ),
            ChoiceChip(
              label: const Text('末3位随机'),
              selected: randomTailEnabled && randomTailDigits == 3,
              onSelected: (_) => onSetRandomDigits(3),
            ),
            ChoiceChip(
              label: const Text('末4位随机'),
              selected: randomTailEnabled && randomTailDigits == 4,
              onSelected: (_) => onSetRandomDigits(4),
            ),
          ],
        ),
      ],
    );
  }
}

class _PanelTitle extends StatelessWidget {
  const _PanelTitle(this.text);

  final String text;

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: const TextStyle(
        color: AppTheme.textPrimary,
        fontSize: 14,
        fontWeight: FontWeight.w800,
      ),
    );
  }
}

class _Panel extends StatelessWidget {
  const _Panel({required this.color, required this.children});

  final Color color;
  final List<Widget> children;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: color,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: children,
      ),
    );
  }
}

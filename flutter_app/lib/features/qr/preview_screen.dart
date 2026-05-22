import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrscan_flutter/models/qr_record.dart';
import 'package:qrscan_flutter/services/qr_parser.dart';

abstract class QrSizeStore {
  Future<double?> loadQrSize();

  Future<void> saveQrSize(double size);
}

class FileQrSizeStore implements QrSizeStore {
  const FileQrSizeStore();

  static const double minSize = 160;
  static const double maxSize = 340;

  @override
  Future<double?> loadQrSize() async {
    final file = await _file();
    if (!await file.exists()) {
      return null;
    }
    final parsed = double.tryParse((await file.readAsString()).trim());
    return parsed == null ? null : _clampSize(parsed);
  }

  @override
  Future<void> saveQrSize(double size) async {
    final file = await _file();
    await file.writeAsString(_clampSize(size).round().toString());
  }

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/qr_preview_size.txt');
  }

  static double _clampSize(double value) =>
      value.clamp(minSize, maxSize).toDouble();
}

abstract class PreviewProgressStore {
  Future<int?> loadLastIndex(String key);

  Future<void> saveLastIndex(String key, int index);
}

class FilePreviewProgressStore implements PreviewProgressStore {
  const FilePreviewProgressStore();

  @override
  Future<int?> loadLastIndex(String key) async {
    final file = await _file();
    if (!await file.exists()) {
      return null;
    }
    final text = await file.readAsString();
    final map = jsonDecode(text);
    if (map is! Map<String, dynamic>) {
      return null;
    }
    final value = map[key];
    if (value is int) {
      return value;
    }
    return int.tryParse('$value');
  }

  @override
  Future<void> saveLastIndex(String key, int index) async {
    final file = await _file();
    Map<String, dynamic> map = <String, dynamic>{};
    if (await file.exists()) {
      final text = await file.readAsString();
      final parsed = jsonDecode(text);
      if (parsed is Map<String, dynamic>) {
        map = parsed;
      }
    }
    map[key] = index;
    await file.writeAsString(jsonEncode(map));
  }

  Future<File> _file() async {
    final directory = await getApplicationSupportDirectory();
    return File('${directory.path}/qr_preview_progress.json');
  }
}

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({
    super.key,
    required this.records,
    required this.scanIndex,
    required this.group,
    required this.initialAutoSlideSeconds,
    this.qrSizeStore,
    this.progressStore,
  });

  final List<QrRecord> records;
  final int scanIndex;
  final QrGroup group;
  final double initialAutoSlideSeconds;
  final QrSizeStore? qrSizeStore;
  final PreviewProgressStore? progressStore;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final PageController _pageController;
  late final QrSizeStore _qrSizeStore;
  late final PreviewProgressStore _progressStore;
  late final String _progressKey;

  late List<QrRecord> _records;
  late QrGroup _group;
  late int _scanIndex;
  late int _currentIndex;

  Timer? _autoSlideTimer;
  late double _autoSlideSeconds;
  double _qrSize = 260;
  bool _autoSliding = false;

  @override
  void initState() {
    super.initState();
    _records = List<QrRecord>.from(widget.records);
    _group = widget.group;
    _scanIndex = widget.scanIndex;
    _autoSlideSeconds = widget.initialAutoSlideSeconds;
    _qrSizeStore = widget.qrSizeStore ?? const FileQrSizeStore();
    _progressStore = widget.progressStore ?? const FilePreviewProgressStore();
    _progressKey =
        '${widget.group.prefix}|${widget.group.batch}|${widget.group.suffix}|${widget.group.startSerial}|${widget.group.count}';
    _currentIndex =
        _records.isEmpty ? 0 : _scanIndex.clamp(0, _records.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _loadQrSize();
    _loadProgress();
  }

  @override
  void dispose() {
    _saveProgress();
    _autoSlideTimer?.cancel();
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= _records.length) {
      return;
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  void _toggleAutoSlide() {
    if (_autoSliding) {
      _autoSlideTimer?.cancel();
      setState(() {
        _autoSliding = false;
      });
      return;
    }

    if (_records.length <= 1) {
      return;
    }

    final duration = Duration(milliseconds: (_autoSlideSeconds * 1000).round());
    _autoSlideTimer = Timer.periodic(duration, (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_currentIndex >= _records.length - 1) {
        timer.cancel();
        setState(() {
          _autoSliding = false;
        });
        return;
      }
      _goTo(_currentIndex + 1);
    });

    setState(() {
      _autoSliding = true;
    });
  }

  Future<void> _loadQrSize() async {
    final size = await _qrSizeStore.loadQrSize();
    if (!mounted || size == null) {
      return;
    }
    setState(() {
      _qrSize = FileQrSizeStore._clampSize(size);
    });
  }

  Future<void> _loadProgress() async {
    final index = await _progressStore.loadLastIndex(_progressKey);
    if (!mounted || index == null || _records.isEmpty) {
      return;
    }
    final safe = index.clamp(0, _records.length - 1);
    setState(() {
      _currentIndex = safe;
    });
    _pageController.jumpToPage(safe);
  }

  Future<void> _saveProgress() async {
    if (_records.isEmpty) {
      return;
    }
    await _progressStore.saveLastIndex(_progressKey, _currentIndex);
  }

  Future<void> _jumpToPage() async {
    if (_records.isEmpty) {
      return;
    }
    final controller =
        TextEditingController(text: (_currentIndex + 1).toString());
    final target = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('跳转到页码'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: InputDecoration(
            labelText: '输入 1 - ${_records.length}',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final value = int.tryParse(controller.text.trim());
              if (value == null) {
                return;
              }
              Navigator.of(context).pop(value);
            },
            child: const Text('跳转'),
          ),
        ],
      ),
    );
    if (target == null) {
      return;
    }
    final page = target.clamp(1, _records.length) - 1;
    _goTo(page);
  }

  Future<void> _editCurrentSerialTail() async {
    if (_records.isEmpty) {
      return;
    }
    final current = _records[_currentIndex];
    final serial = current.serial;
    if (serial.length != QrParser.serialLength) {
      return;
    }
    final head = serial.substring(0, serial.length - 4);
    final tailController = TextEditingController();
    String? errorText;
    final nextTail = await showModalBottomSheet<String>(
      context: context,
      isScrollControlled: true,
      useSafeArea: true,
      builder: (context) {
        return StatefulBuilder(
          builder: (context, setSheetState) {
            final bottomInset = MediaQuery.viewInsetsOf(context).bottom;
            return Padding(
              padding: EdgeInsets.fromLTRB(16, 12, 16, bottomInset + 16),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Text(
                    '修改流水号末4位',
                    style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800),
                  ),
                  const SizedBox(height: 6),
                  Text(
                    '前6位固定: $head',
                    style: const TextStyle(color: Colors.black54),
                  ),
                  const SizedBox(height: 2),
                  const Text(
                    '只需输入最后4位',
                    style: TextStyle(color: Colors.black45, fontSize: 12),
                  ),
                  const SizedBox(height: 12),
                  TextField(
                    controller: tailController,
                    autofocus: true,
                    keyboardType: TextInputType.number,
                    inputFormatters: [
                      FilteringTextInputFormatter.digitsOnly,
                      LengthLimitingTextInputFormatter(4),
                    ],
                    decoration: InputDecoration(
                      labelText: '末4位',
                      hintText: '例如 0905',
                      errorText: errorText,
                    ),
                  ),
                  const SizedBox(height: 12),
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () {
                        final tail = tailController.text.trim();
                        if (tail.length != 4) {
                          setSheetState(() => errorText = '请输入4位数字');
                          return;
                        }
                        Navigator.of(context).pop(tail);
                      },
                      child: const Text('应用到当前码'),
                    ),
                  ),
                ],
              ),
            );
          },
        );
      },
    );
    if (nextTail == null) {
      return;
    }
    final nextSerial = '$head$nextTail';
    if (_records.any((r) => r.serial == nextSerial)) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('该流水号已存在于当前组，请换一个末4位')),
      );
      return;
    }
    final nextContent =
        '${_group.prefix}$nextSerial${_group.batch}${_group.suffix}';
    setState(() {
      _records[_currentIndex] =
          QrRecord(content: nextContent, serial: nextSerial);
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: const Color(0xFFF5F7FB),
      appBar: AppBar(
        title: Text(
            '第 ${_records.isEmpty ? 0 : _currentIndex + 1} / ${_records.length} 张'),
        actions: [
          IconButton(
            tooltip: _autoSliding ? '停止自动滑动' : '开始自动滑动',
            onPressed: _toggleAutoSlide,
            icon: Icon(_autoSliding ? Icons.pause_circle : Icons.play_circle),
          ),
          IconButton(
            tooltip: '跳转页码',
            onPressed: _jumpToPage,
            icon: const Icon(Icons.pin_outlined),
          ),
        ],
      ),
      body: Column(
        children: [
          if (_records.isEmpty)
            const Expanded(
              child: Center(
                child: Text('没有可展示的记录'),
              ),
            )
          else
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: _records.length,
                onPageChanged: (value) {
                  setState(() {
                    _currentIndex = value;
                  });
                  _saveProgress();
                },
                itemBuilder: (context, index) {
                  final item = _records[index];
                  final isScanned = index == _scanIndex;
                  return Padding(
                    padding: const EdgeInsets.all(24),
                    child: SingleChildScrollView(
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Container(
                            padding: const EdgeInsets.all(16),
                            decoration: BoxDecoration(
                              borderRadius: BorderRadius.circular(20),
                              color: Colors.white,
                            ),
                            child: QrImageView(
                              data: item.content,
                              size: math.min(
                                _qrSize,
                                MediaQuery.sizeOf(context).shortestSide - 88,
                              ),
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Row(
                            mainAxisAlignment: MainAxisAlignment.center,
                            children: [
                              Flexible(
                                child: Text(
                                  item.serial,
                                  textAlign: TextAlign.center,
                                  style: const TextStyle(
                                    fontSize: 34,
                                    fontWeight: FontWeight.bold,
                                    letterSpacing: 3,
                                  ),
                                ),
                              ),
                              const SizedBox(width: 8),
                              IconButton.filledTonal(
                                key: const Key('editSerialTailButton'),
                                tooltip: '修改末4位',
                                onPressed: _editCurrentSerialTail,
                                icon: const Icon(Icons.edit_outlined),
                              ),
                            ],
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            item.content,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Color(0xFF22C55E),
                              fontSize: 14,
                            ),
                          ),
                          const SizedBox(height: 12),
                          if (isScanned)
                            Container(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 14,
                                vertical: 6,
                              ),
                              decoration: BoxDecoration(
                                borderRadius: BorderRadius.circular(999),
                                border:
                                    Border.all(color: const Color(0xFF6C63FF)),
                              ),
                              child: const Text('扫描号'),
                            ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 8, 16, 18),
            child: Row(
              children: [
                Expanded(
                  child: FilledButton.tonal(
                    onPressed: _currentIndex > 0
                        ? () => _goTo(_currentIndex - 1)
                        : null,
                    child: const Text('上一张'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: FilledButton(
                    onPressed: _currentIndex < _records.length - 1
                        ? () => _goTo(_currentIndex + 1)
                        : null,
                    child: const Text('下一张'),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

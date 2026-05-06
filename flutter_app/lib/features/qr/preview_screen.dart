import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
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

  void _setAutoSlideSecondsDirect(double seconds) {
    if (seconds <= 0) {
      return;
    }
    final wasRunning = _autoSliding;
    if (_autoSliding) {
      _toggleAutoSlide();
    }
    setState(() {
      _autoSlideSeconds = seconds;
    });
    if (wasRunning) {
      _toggleAutoSlide();
    }
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

  void _setQrSize(double size) {
    final next = FileQrSizeStore._clampSize(size);
    setState(() {
      _qrSize = next;
    });
    unawaited(_qrSizeStore.saveQrSize(next));
  }

  Future<void> _setAutoSlideSeconds() async {
    final presets = <double>[0.5, 1.0, 2.0];
    final controller =
        TextEditingController(text: _autoSlideSeconds.toString());
    final value = await showDialog<double>(
      context: context,
      builder: (context) {
        return AlertDialog(
          title: const Text('设置自动滑动间隔'),
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
                keyboardType:
                    const TextInputType.numberWithOptions(decimal: true),
                decoration: const InputDecoration(labelText: '自定义秒数'),
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

    final wasRunning = _autoSliding;
    if (_autoSliding) {
      _toggleAutoSlide();
    }

    setState(() {
      _autoSlideSeconds = value;
    });

    if (wasRunning) {
      _toggleAutoSlide();
    }
  }

  void _generateNextGroup() {
    final next = _group.randomTailEnabled
        ? QrParser.buildRecords(
            prefix: _group.prefix,
            serialSeed: _group.sourceSerial,
            batch: _group.batch,
            suffix: _group.suffix,
            count: _group.count,
            randomTailEnabled: true,
            randomTailDigits: _group.randomTailDigits,
          )
        : () {
            final nextStart = _group.startSerial + _group.count;
            return QrParser.buildRecords(
              prefix: _group.prefix,
              serialSeed: nextStart.toString().padLeft(10, '0'),
              batch: _group.batch,
              suffix: _group.suffix,
              count: _group.count,
              startSerial: nextStart,
            );
          }();

    _autoSlideTimer?.cancel();
    setState(() {
      _records = next.records;
      _group = next.group;
      _scanIndex = next.scanIndex;
      _currentIndex = 0;
      _autoSliding = false;
    });

    _pageController.jumpToPage(0);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(
            '第 ${_records.isEmpty ? 0 : _currentIndex + 1} / ${_records.length} 张'),
        actions: [
          IconButton(
            tooltip: '设置自动滑动',
            onPressed: _setAutoSlideSeconds,
            icon: const Icon(Icons.timer_outlined),
          ),
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
          Padding(
            padding: const EdgeInsets.fromLTRB(16, 10, 16, 0),
            child: Column(
              children: [
                Row(
                  children: [
                    Expanded(
                      child: Text(
                        '每组 ${_group.count} 张 | 自动 ${_autoSlideSeconds}s | ${_group.randomTailEnabled ? '末${_group.randomTailDigits}位随机' : '顺序递增'}',
                        style: const TextStyle(color: Colors.white70),
                      ),
                    ),
                    FilledButton.tonal(
                      onPressed: _generateNextGroup,
                      child: const Text('下一组'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Text(
                      '自动滑动',
                      style: TextStyle(
                        color: Colors.white70,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    const SizedBox(width: 8),
                    ...[0.5, 1.0, 2.0].map((value) {
                      final selected = (_autoSlideSeconds - value).abs() < 0.01;
                      return Padding(
                        padding: const EdgeInsets.only(right: 6),
                        child: ChoiceChip(
                          label: Text('${value}s'),
                          selected: selected,
                          onSelected: (_) => _setAutoSlideSecondsDirect(value),
                        ),
                      );
                    }),
                    const Spacer(),
                    FilledButton.tonalIcon(
                      onPressed: _toggleAutoSlide,
                      icon: Icon(
                        _autoSliding
                            ? Icons.pause_circle_outline
                            : Icons.play_circle_outline,
                      ),
                      label: Text(_autoSliding ? '暂停' : '继续'),
                    ),
                  ],
                ),
                const SizedBox(height: 8),
                const Align(
                  alignment: Alignment.centerLeft,
                  child: Text(
                    '继续时从当前页开始，不会回到第一张',
                    style: TextStyle(color: Colors.white54, fontSize: 12),
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  children: [
                    SizedBox(
                      width: 112,
                      child: Text(
                        '二维码大小 ${_qrSize.round()}',
                        style: const TextStyle(
                          color: Colors.white70,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    Expanded(
                      child: Slider(
                        key: const Key('qrSizeSlider'),
                        min: FileQrSizeStore.minSize,
                        max: FileQrSizeStore.maxSize,
                        divisions: 18,
                        value: _qrSize,
                        label: _qrSize.round().toString(),
                        onChanged: _setQrSize,
                      ),
                    ),
                  ],
                ),
              ],
            ),
          ),
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
                              size: _qrSize,
                              backgroundColor: Colors.white,
                            ),
                          ),
                          const SizedBox(height: 20),
                          Text(
                            item.serial,
                            style: const TextStyle(
                              fontSize: 30,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 2,
                            ),
                          ),
                          const SizedBox(height: 8),
                          SelectableText(
                            item.content,
                            textAlign: TextAlign.center,
                            style: const TextStyle(
                              color: Colors.greenAccent,
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

import 'dart:async';
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

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({
    super.key,
    required this.records,
    required this.scanIndex,
    required this.group,
    required this.initialAutoSlideSeconds,
    this.qrSizeStore,
  });

  final List<QrRecord> records;
  final int scanIndex;
  final QrGroup group;
  final double initialAutoSlideSeconds;
  final QrSizeStore? qrSizeStore;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final PageController _pageController;
  late final QrSizeStore _qrSizeStore;

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
    _currentIndex =
        _records.isEmpty ? 0 : _scanIndex.clamp(0, _records.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
    _loadQrSize();
  }

  @override
  void dispose() {
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

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrscan_flutter/models/qr_record.dart';
import 'package:qrscan_flutter/services/qr_parser.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({
    super.key,
    required this.records,
    required this.scanIndex,
    required this.group,
    required this.initialAutoSlideSeconds,
  });

  final List<QrRecord> records;
  final int scanIndex;
  final QrGroup group;
  final double initialAutoSlideSeconds;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final PageController _pageController;

  late List<QrRecord> _records;
  late QrGroup _group;
  late int _scanIndex;
  late int _currentIndex;

  Timer? _autoSlideTimer;
  late double _autoSlideSeconds;
  bool _autoSliding = false;

  @override
  void initState() {
    super.initState();
    _records = List<QrRecord>.from(widget.records);
    _group = widget.group;
    _scanIndex = widget.scanIndex;
    _autoSlideSeconds = widget.initialAutoSlideSeconds;
    _currentIndex = _records.isEmpty ? 0 : _scanIndex.clamp(0, _records.length - 1);
    _pageController = PageController(initialPage: _currentIndex);
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

  Future<void> _setAutoSlideSeconds() async {
    final presets = <double>[0.5, 1.0, 2.0];
    final controller = TextEditingController(text: _autoSlideSeconds.toString());
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
                keyboardType: const TextInputType.numberWithOptions(decimal: true),
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
    final nextStart = _group.startSerial + _group.count;
    final next = QrParser.buildRecords(
      prefix: _group.prefix,
      serialInt: nextStart,
      batch: _group.batch,
      suffix: _group.suffix,
      count: _group.count,
      startSerial: nextStart,
    );

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
        title: Text('第 ${_records.isEmpty ? 0 : _currentIndex + 1} / ${_records.length} 张'),
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
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    '每组 ${_group.count} 张 | 自动 ${_autoSlideSeconds}s',
                    style: const TextStyle(color: Colors.white70),
                  ),
                ),
                FilledButton.tonal(
                  onPressed: _generateNextGroup,
                  child: const Text('下一组'),
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
                            size: 260,
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
                              border: Border.all(color: const Color(0xFF6C63FF)),
                            ),
                            child: const Text('扫描号'),
                          ),
                      ],
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
                    onPressed: _currentIndex > 0 ? () => _goTo(_currentIndex - 1) : null,
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

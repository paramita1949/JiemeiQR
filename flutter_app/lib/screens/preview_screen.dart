import 'package:flutter/material.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrscan_flutter/models/qr_record.dart';

class PreviewScreen extends StatefulWidget {
  const PreviewScreen({
    super.key,
    required this.records,
    required this.scanIndex,
  });

  final List<QrRecord> records;
  final int scanIndex;

  @override
  State<PreviewScreen> createState() => _PreviewScreenState();
}

class _PreviewScreenState extends State<PreviewScreen> {
  late final PageController _pageController;
  late int _currentIndex;

  @override
  void initState() {
    super.initState();
    if (widget.records.isEmpty) {
      _currentIndex = 0;
    } else {
      _currentIndex = widget.scanIndex.clamp(0, widget.records.length - 1);
    }
    _pageController = PageController(initialPage: _currentIndex);
  }

  @override
  void dispose() {
    _pageController.dispose();
    super.dispose();
  }

  void _goTo(int index) {
    if (index < 0 || index >= widget.records.length) {
      return;
    }
    _pageController.animateToPage(
      index,
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOut,
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text('第 ${_currentIndex + 1} / ${widget.records.length} 张'),
      ),
      body: Column(
        children: [
          if (widget.records.isEmpty)
            const Expanded(
              child: Center(
                child: Text('没有可展示的记录'),
              ),
            )
          else
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                itemCount: widget.records.length,
                onPageChanged: (value) {
                  setState(() {
                    _currentIndex = value;
                  });
                },
                itemBuilder: (context, index) {
                  final item = widget.records[index];
                  final isScanned = index == widget.scanIndex;
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
                    onPressed: _currentIndex < widget.records.length - 1
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

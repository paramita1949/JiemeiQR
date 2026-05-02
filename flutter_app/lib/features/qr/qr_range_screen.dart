import 'dart:math';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/features/qr/preview_screen.dart';
import 'package:qrscan_flutter/features/qr/scanner_screen.dart';
import 'package:qrscan_flutter/models/qr_record.dart';
import 'package:qrscan_flutter/services/qr_board_ai_estimator.dart';
import 'package:qrscan_flutter/services/qr_parser.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class QrRangeScreen extends StatefulWidget {
  const QrRangeScreen({super.key, this.database});

  final AppDatabase? database;

  @override
  State<QrRangeScreen> createState() => _QrRangeScreenState();
}

class _QrRangeScreenState extends State<QrRangeScreen> {
  static const String _endScanSignal = '__END_RANGE_SCAN__';
  late final AppDatabase _database;
  late final ProductDao _productDao;
  late final bool _ownsDatabase;

  final List<ParsedQr> _scans = <ParsedQr>[];
  final bool _predicting = false;
  bool _autoStarted = false;
  bool _scanStageActive = true;
  bool _scanningNow = false;
  QrBoardRangeEstimate? _lastEstimate;
  String? _lastSerialTail3Range;
  String? _lastSerialTail4Range;
  int? _matchedBoxesPerBoard;
  QrBuildResult? _latestBuildResult;
  final ImagePicker _picker = ImagePicker();
  final MobileScannerController _galleryAnalyzeController =
      MobileScannerController();

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _productDao = ProductDao(_database);
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || _autoStarted) {
        return;
      }
      _autoStarted = true;
      _startContinuousScan();
    });
  }

  @override
  void dispose() {
    _galleryAnalyzeController.dispose();
    if (_ownsDatabase) {
      _database.close();
    }
    super.dispose();
  }

  Future<void> _startContinuousScan() async {
    if (!_scanStageActive || _scanningNow || !mounted) {
      return;
    }
    _scanningNow = true;
    final content = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(
          title: '箱码范围扫码',
          allowGalleryImport: false,
          showEndScanAction: true,
          endScanResult: _endScanSignal,
        ),
      ),
    );
    _scanningNow = false;
    if (!mounted || !_scanStageActive) {
      return;
    }
    if (content == null) {
      return;
    }
    if (content == _endScanSignal) {
      setState(() => _scanStageActive = false);
      return;
    }
    final parsed = QrParser.parse(content.trim());
    if (parsed == null) {
      _showMessage('格式不匹配，请扫箱贴码');
    } else if (!_accepts(parsed)) {
      _showMessage('仅支持同产品、同批号、同日期批次');
    } else {
      setState(() => _scans.add(parsed));
      if (_matchedBoxesPerBoard == null) {
        _loadMatchedBoxesPerBoard(parsed.batch);
      }
      _recomputeEstimate();
    }
    await Future<void>.delayed(const Duration(milliseconds: 180));
    if (mounted && _scanStageActive) {
      _startContinuousScan();
    }
  }

  bool _accepts(ParsedQr parsed) {
    if (_scans.isEmpty) {
      return true;
    }
    final first = _scans.first;
    return first.prefix == parsed.prefix &&
        first.batch == parsed.batch &&
        first.suffix == parsed.suffix;
  }

  void _showMessage(String message) {
    ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
  }

  Future<void> _importMultipleImagesAndParse() async {
    if (_predicting) {
      return;
    }
    final files = await _picker.pickMultiImage();
    if (!mounted || files.isEmpty) {
      return;
    }

    var accepted = 0;
    var rejected = 0;
    var invalid = 0;

    for (final file in files) {
      final capture = await _galleryAnalyzeController.analyzeImage(file.path);
      if (capture == null || capture.barcodes.isEmpty) {
        invalid += 1;
        continue;
      }

      final seen = <String>{};
      for (final barcode in capture.barcodes) {
        final raw = barcode.rawValue?.trim();
        if (raw == null || raw.isEmpty || !seen.add(raw)) {
          continue;
        }
        final parsed = QrParser.parse(raw);
        if (parsed == null) {
          invalid += 1;
          continue;
        }
        if (!_accepts(parsed)) {
          rejected += 1;
          continue;
        }
        _scans.add(parsed);
        accepted += 1;
      }
    }

    if (!mounted) {
      return;
    }
    setState(() {});

    if (_scans.isNotEmpty && _matchedBoxesPerBoard == null) {
      _loadMatchedBoxesPerBoard(_scans.first.batch);
    }
    _recomputeEstimate();
    _showMessage('批量解析完成：新增$accepted，拒收$rejected，无效$invalid');
  }

  Future<void> _loadMatchedBoxesPerBoard(String batch) async {
    final matched = await _productDao.findBoxesPerBoardByActualBatch(batch);
    if (!mounted || _scans.isEmpty || _scans.first.batch != batch) {
      return;
    }
    setState(() => _matchedBoxesPerBoard = matched);
    _recomputeEstimate();
  }

  Future<void> _handlePrimaryAction() async {
    if (_predicting) {
      return;
    }
    if (_scanStageActive) {
      setState(() => _scanStageActive = false);
      return;
    }

    if (_latestBuildResult != null) {
      _openPreview();
      return;
    }

    if (_scans.isEmpty || _scans.length < 2) {
      setState(() => _scanStageActive = true);
      _startContinuousScan();
      return;
    }

    setState(() {
      _scans.clear();
      _lastEstimate = null;
      _lastSerialTail3Range = null;
      _lastSerialTail4Range = null;
      _matchedBoxesPerBoard = null;
      _latestBuildResult = null;
      _scanStageActive = true;
    });
    _startContinuousScan();
  }

  String _primaryActionLabel() {
    if (_predicting) {
      return '推测中...';
    }
    if (_scanStageActive) {
      return '结束扫描';
    }
    if (_latestBuildResult != null) {
      return '生成预览';
    }
    if (_scans.isEmpty || _scans.length < 2) {
      return '继续扫描';
    }
    return '重新扫描';
  }

  void _recomputeEstimate() {
    final first = _scans.isEmpty ? null : _scans.first;
    final boxesPerBoard = _matchedBoxesPerBoard;
    if (first == null || boxesPerBoard == null) {
      return;
    }
    final serials = _scans.map((e) => e.serialInt).toSet().toList()..sort();
    if (serials.length < 2) {
      return;
    }
    try {
      final sample = min(6, serials.length);
      final estimate = QrBoardAiEstimator.estimateRange(
        boxesPerBoard: boxesPerBoard,
        topSerials: serials.take(sample).toList(),
        bottomSerials: serials.skip(serials.length - sample).toList(),
      );
      final result = QrParser.buildRecords(
        prefix: first.prefix,
        serialSeed: first.serial,
        batch: first.batch,
        suffix: first.suffix,
        count: boxesPerBoard,
        randomTailEnabled: false,
        startSerial: estimate.startSerial,
      );
      setState(() {
        _lastEstimate = estimate;
        _latestBuildResult = result;
        final startSerial = result.records.first.serial;
        final endSerial = result.records.last.serial;
        _lastSerialTail3Range =
            '${_tailOfSerial(startSerial, 3)} - ${_tailOfSerial(endSerial, 3)}';
        _lastSerialTail4Range =
            '${_tailOfSerial(startSerial, 4)} - ${_tailOfSerial(endSerial, 4)}';
      });
    } catch (_) {
      // keep scanning with existing last estimate if any
    }
  }

  void _openPreview() {
    final result = _latestBuildResult;
    if (result == null) {
      _showMessage('样本不足或未匹配到基础资料，暂无法生成预览');
      return;
    }
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => PreviewScreen(
          records: result.records,
          scanIndex: result.scanIndex,
          group: result.group,
          initialAutoSlideSeconds: 1.0,
        ),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final first = _scans.isEmpty ? null : _scans.first;
    final canPrimaryAction = !_predicting;
    return Scaffold(
      body: SafeArea(
        child: SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Padding(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const PageTitle(
                icon: Icons.qr_code_scanner_outlined,
                title: '箱码范围',
                subtitle: '连续扫码自动推测，结束后自动进入预览',
              ),
              const SizedBox(height: 12),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  key: const Key('rangePrimaryActionButton'),
                  onPressed: canPrimaryAction ? _handlePrimaryAction : null,
                  icon: Icon(
                    _scanStageActive
                        ? Icons.stop_circle_outlined
                        : Icons.auto_fix_high_outlined,
                  ),
                  label: Text(_primaryActionLabel()),
                ),
              ),
              if (_scanStageActive) ...[
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('rangeMultiImportButton'),
                    onPressed: _importMultipleImagesAndParse,
                    icon: const Icon(Icons.collections_outlined),
                    label: const Text('系统相册多选导入并解析'),
                  ),
                ),
              ],
              const SizedBox(height: 12),
              if (_matchedBoxesPerBoard != null)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Text(
                    '已匹配基础资料：每板 $_matchedBoxesPerBoard 箱',
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                )
              else
                const Text(
                  '扫描中将自动匹配基础资料每板箱数',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              const SizedBox(height: 8),
              Text(
                '已扫 ${_scans.length} 箱'
                '${first == null ? '' : ' | 批号 ${first.batch}'}'
                '${_scanStageActive ? ' | 连续扫描中' : ' | 扫描已结束'}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_lastEstimate != null) ...[
                const SizedBox(height: 8),
                const Text(
                  '范围已自动更新，点击“生成预览”进入二维码预览',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '流水号末3位范围：${_lastSerialTail3Range ?? "-"}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 4),
                Text(
                  '流水号末4位范围：${_lastSerialTail4Range ?? "-"}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
              if (_scans.isNotEmpty) ...[
                const SizedBox(height: 10),
                Wrap(
                  spacing: 6,
                  runSpacing: 6,
                  children: _scans.reversed.take(10).map((item) {
                    return Chip(
                      visualDensity: VisualDensity.compact,
                      label: Text(item.serial),
                    );
                  }).toList(),
                ),
              ],
            ],
          ),
        ),
      ),
      ),
    );
  }

  String _tailOfSerial(String serial, int digits) {
    if (serial.length <= digits) {
      return serial;
    }
    return serial.substring(serial.length - digits);
  }
}

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
  int? _rangeSpan;
  int _ignoredOutlierCount = 0;
  int? _matchedBoxesPerBoard;
  MatchedBaseInfo? _matchedBaseInfo;
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
        builder: (_) => ScannerScreen(
          title: '箱码范围扫码',
          allowGalleryImport: true,
          showBottomGalleryButton: false,
          showEndScanAction: false,
          minContinuousDetections: 1,
          validateResult: _acceptsDuringScan,
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
    final parsed = QrParser.parse(content.trim());
    if (parsed == null) {
      _showMessage('格式不匹配，请扫箱贴码');
    } else {
      _appendScan(parsed);
    }
  }

  bool _acceptsDuringScan(String value) {
    final parsed = QrParser.parse(value.trim());
    if (parsed == null) {
      return false;
    }
    if (_scans.isEmpty) {
      return true;
    }
    return _accepts(parsed);
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
    final matchedInfo = await _productDao.findMatchedBaseInfoByActualBatch(
      batch,
    );
    if (!mounted || _scans.isEmpty || _scans.first.batch != batch) {
      return;
    }
    setState(() {
      _matchedBaseInfo = matchedInfo;
      _matchedBoxesPerBoard = matchedInfo?.boxesPerBoard;
    });
    _recomputeEstimate();
  }

  Future<void> _handlePrimaryAction() async {
    if (_predicting) {
      return;
    }
    if (!_scanStageActive) {
      setState(() => _scanStageActive = true);
    }
    _startContinuousScan();
  }

  String _primaryActionLabel() {
    if (_predicting) {
      return '推测中...';
    }
    if (_scanningNow) {
      return '扫码中...';
    }
    if (_scans.isEmpty) {
      return '开始扫描';
    }
    if (_scanStageActive) {
      return '继续扫描';
    }
    return '继续补扫';
  }

  void _appendScan(ParsedQr parsed) {
    if (!_accepts(parsed)) {
      _showMessage('仅支持同产品、同批号、同日期批次');
      return;
    }
    setState(() => _scans.add(parsed));
    if (_matchedBoxesPerBoard == null) {
      _loadMatchedBoxesPerBoard(parsed.batch);
    }
    _recomputeEstimate();
  }

  void _recomputeEstimate() {
    final first = _scans.isEmpty ? null : _scans.first;
    final boxesPerBoard = _matchedBoxesPerBoard;
    if (first == null || boxesPerBoard == null) {
      return;
    }
    final stable = _selectStableSerials();
    if (stable.serials.length < 2) {
      setState(() {
        _ignoredOutlierCount = stable.ignoredCount;
        _lastEstimate = null;
        _latestBuildResult = null;
        _lastSerialTail3Range = null;
        _lastSerialTail4Range = null;
        _rangeSpan = null;
      });
      return;
    }
    try {
      final serials = stable.serials;
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
        _ignoredOutlierCount = stable.ignoredCount;
        _lastEstimate = estimate;
        _latestBuildResult = result;
        final startSerial = result.records.first.serial;
        final endSerial = result.records.last.serial;
        final startSerialInt = int.tryParse(startSerial) ?? 0;
        final endSerialInt = int.tryParse(endSerial) ?? 0;
        _lastSerialTail3Range =
            '${_tailOfSerial(startSerial, 3)} - ${_tailOfSerial(endSerial, 3)}';
        _lastSerialTail4Range =
            '${_tailOfSerial(startSerial, 4)} - ${_tailOfSerial(endSerial, 4)}';
        _rangeSpan = (endSerialInt - startSerialInt).abs();
      });
    } catch (_) {
      // keep scanning with existing last estimate if any
    }
  }

  _StableSerials _selectStableSerials() {
    final serials = _scans.map((e) => e.serialInt).toSet().toList()..sort();
    if (serials.length <= 1) {
      return _StableSerials(serials, 0);
    }

    const maxNeighborGap = 100;
    final clusters = <List<int>>[];
    var current = <int>[serials.first];
    for (var i = 1; i < serials.length; i++) {
      final value = serials[i];
      final prev = serials[i - 1];
      if ((value - prev).abs() <= maxNeighborGap) {
        current.add(value);
      } else {
        clusters.add(current);
        current = <int>[value];
      }
    }
    clusters.add(current);

    clusters.sort((a, b) {
      final byCount = b.length.compareTo(a.length);
      if (byCount != 0) {
        return byCount;
      }
      final aSpan = (a.last - a.first).abs();
      final bSpan = (b.last - b.first).abs();
      return aSpan.compareTo(bSpan);
    });

    final best = clusters.first;
    final ignored = serials.length - best.length;
    return _StableSerials(best, ignored);
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
                subtitle: '单次扫码后确认结果，手动继续',
              ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: FilledButton.icon(
                      key: const Key('rangePrimaryActionButton'),
                      onPressed: canPrimaryAction && !_scanningNow
                          ? _handlePrimaryAction
                          : null,
                      icon: Icon(
                        _scanStageActive
                            ? Icons.qr_code_scanner_outlined
                            : Icons.refresh_outlined,
                      ),
                      label: Text(_primaryActionLabel()),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: OutlinedButton.icon(
                      key: const Key('rangeMultiImportButton'),
                      onPressed: _scanStageActive
                          ? _importMultipleImagesAndParse
                          : null,
                      icon: const Icon(Icons.photo_library_outlined),
                      label: const Text('相册识别'),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: FilledButton.tonalIcon(
                  key: const Key('rangePreviewButton'),
                  onPressed: _latestBuildResult == null ? null : _openPreview,
                  icon: const Icon(Icons.grid_view_rounded),
                  label: const Text('生成预览'),
                ),
              ),
              const SizedBox(height: 12),
              if (_matchedBaseInfo != null)
                Container(
                  width: double.infinity,
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: const Color(0xFFEAF7FF),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      const Text(
                        '已匹配基础资料',
                        style: TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 8),
                      _buildInfoRow(
                        '产品编号',
                        _matchedBaseInfo!.productCode,
                      ),
                      _buildInfoRow('批号', _matchedBaseInfo!.actualBatch),
                      _buildInfoRow('日期', _matchedBaseInfo!.dateBatch),
                      _buildInfoRow('每板箱数', '${_matchedBaseInfo!.boxesPerBoard} 箱'),
                    ],
                  ),
                )
              else
                const Text(
                  '扫描后自动匹配基础资料',
                  style: TextStyle(color: AppTheme.textSecondary),
                ),
              const SizedBox(height: 8),
              Text(
                '已扫 ${_scans.length} 箱'
                '${first == null ? '' : ' | 批号 ${first.batch}'}'
                '${_scanningNow ? ' | 扫码中' : (_scanStageActive ? ' | 待继续扫描' : ' | 扫描已结束')}',
                style: const TextStyle(
                  color: AppTheme.textPrimary,
                  fontWeight: FontWeight.w800,
                ),
              ),
              if (_lastEstimate != null) ...[
                const SizedBox(height: 8),
                Text(
                  '范围跨度：${_rangeSpan ?? "-"}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                if (_ignoredOutlierCount > 0) ...[
                  const SizedBox(height: 4),
                  Text(
                    '已自动忽略偏差样本：$_ignoredOutlierCount',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
                const SizedBox(height: 4),
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

  Widget _buildInfoRow(String label, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 4),
      child: Row(
        children: [
          SizedBox(
            width: 86,
            child: Text(
              '$label：',
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Expanded(
            child: Text(
              value.isEmpty ? '-' : value,
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
        ],
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

class _StableSerials {
  const _StableSerials(this.serials, this.ignoredCount);

  final List<int> serials;
  final int ignoredCount;
}

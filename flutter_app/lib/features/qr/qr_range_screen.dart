import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:image_picker/image_picker.dart';
import 'package:mobile_scanner/mobile_scanner.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/data/daos/qr_range_history_dao.dart';
import 'package:qrscan_flutter/features/qr/preview_screen.dart';
import 'package:qrscan_flutter/features/qr/scanner_screen.dart';
import 'package:qrscan_flutter/models/qr_record.dart';
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
  late final QrRangeHistoryDao _historyDao;
  late final bool _ownsDatabase;

  final List<ParsedQr> _scans = <ParsedQr>[];
  final bool _predicting = false;
  bool _autoStarted = false;
  bool _scanStageActive = true;
  bool _scanningNow = false;
  String? _lastSerialTail3Range;
  String? _lastSerialTail4Range;
  int? _rangeSpan;
  int _ignoredOutlierCount = 0;
  Set<String> _ignoredSerials = <String>{};
  int? _matchedBoxesPerBoard;
  MatchedBaseInfo? _matchedBaseInfo;
  QrBuildResult? _latestBuildResult;
  String? _stableStartSerial;
  String? _stableEndSerial;
  final List<QrRangeHistoryEntry> _history = <QrRangeHistoryEntry>[];
  final ImagePicker _picker = ImagePicker();
  final MobileScannerController _galleryAnalyzeController =
      MobileScannerController();

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _productDao = ProductDao(_database);
    _historyDao = QrRangeHistoryDao(_database);
    _loadHistory();
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
      _closeIfInitialScanFailed();
      return;
    }
    final parsed = QrParser.parse(content.trim());
    if (parsed == null) {
      _closeIfInitialScanFailed();
      if (!mounted) {
        return;
      }
      _showMessage('格式不匹配，请扫箱贴码');
    } else {
      _appendScan(parsed);
    }
  }

  void _closeIfInitialScanFailed() {
    if (_scans.isNotEmpty) {
      return;
    }
    Navigator.of(context).pop();
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
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
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
    if (first == null) {
      return;
    }
    final stable = _selectStableSerials();
    if (stable.serials.length < 2) {
      setState(() {
        _ignoredOutlierCount = stable.ignoredCount;
        _ignoredSerials = stable.ignoredSerials;
        _latestBuildResult = null;
        _lastSerialTail3Range = null;
        _lastSerialTail4Range = null;
        _rangeSpan = null;
      });
      return;
    }
    try {
      final serials = stable.serials..sort();
      final startSerialInt = serials.first;
      final endSerialInt = serials.last;
      final generatedCount = endSerialInt - startSerialInt + 1;
      final result = QrParser.buildRecords(
        prefix: first.prefix,
        serialSeed: first.serial,
        batch: first.batch,
        suffix: first.suffix,
        count: generatedCount,
        randomTailEnabled: false,
        startSerial: startSerialInt,
      );
      setState(() {
        _ignoredOutlierCount = stable.ignoredCount;
        _ignoredSerials = stable.ignoredSerials;
        _latestBuildResult = result;
        final startSerial = result.records.first.serial;
        final endSerial = result.records.last.serial;
        _lastSerialTail3Range =
            '${_tailOfSerial(startSerial, 3)} - ${_tailOfSerial(endSerial, 3)}';
        _lastSerialTail4Range =
            '${_tailOfSerial(startSerial, 4)} - ${_tailOfSerial(endSerial, 4)}';
        _rangeSpan = (endSerialInt - startSerialInt).abs();
        _stableStartSerial = startSerial;
        _stableEndSerial = endSerial;
      });
    } catch (_) {
      // keep scanning with existing last estimate if any
    }
  }

  _StableSerials _selectStableSerials() {
    final serials = _scans.map((e) => e.serialInt).toSet().toList()..sort();
    if (serials.length <= 1) {
      return _StableSerials(serials, 0, const <String>{});
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
    final bestSet = best.toSet();
    final ignored = serials.where((e) => !bestSet.contains(e)).toList();
    final ignoredSerials = ignored
        .map((e) => e.toString().padLeft(QrParser.serialLength, '0'))
        .toSet();
    return _StableSerials(best, ignored.length, ignoredSerials);
  }

  void _openPreview() {
    final result = _latestBuildResult;
    if (result == null) {
      _showMessage('样本不足或未匹配到基础资料，暂无法生成预览');
      return;
    }
    _saveHistory(
      startSerial: result.records.first.serial,
      endSerial: result.records.last.serial,
      generatedCount: result.records.length,
    );
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

  Future<void> _openBulkPreviewDialog() async {
    final parsed = _scans.isEmpty ? null : _scans.first;
    if (parsed == null) {
      _showMessage('请先扫描至少1箱');
      return;
    }
    final startController =
        TextEditingController(text: _stableStartSerial ?? parsed.serial);
    final endController =
        TextEditingController(text: _stableEndSerial ?? parsed.serial);
    final range = await showDialog<({int start, int end})>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('批量预览生成'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: startController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '起始流水号(10位)'),
            ),
            const SizedBox(height: 8),
            TextField(
              controller: endController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(labelText: '结束流水号(10位)'),
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
              final start = int.tryParse(startController.text.trim());
              final end = int.tryParse(endController.text.trim());
              if (start == null || end == null || end < start) {
                return;
              }
              Navigator.of(context).pop((start: start, end: end));
            },
            child: const Text('生成'),
          ),
        ],
      ),
    );
    if (range == null) {
      return;
    }

    final count = range.end - range.start + 1;
    final result = QrParser.buildRecords(
      prefix: parsed.prefix,
      serialSeed: parsed.serial,
      batch: parsed.batch,
      suffix: parsed.suffix,
      count: count,
      randomTailEnabled: false,
      startSerial: range.start,
    );
    _saveHistory(
      startSerial: result.records.first.serial,
      endSerial: result.records.last.serial,
      generatedCount: result.records.length,
    );
    if (!mounted) {
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

  Future<void> _loadHistory() async {
    final rows = await _historyDao.latest(limit: 30);
    if (!mounted) {
      return;
    }
    setState(() {
      _history
        ..clear()
        ..addAll(rows);
    });
  }

  Future<void> _saveHistory({
    required String startSerial,
    required String endSerial,
    required int generatedCount,
  }) async {
    final base = _matchedBaseInfo;
    if (base == null) {
      return;
    }
    await _historyDao.insert(
      QrRangeHistoryEntry(
        productCode: base.productCode,
        actualBatch: base.actualBatch,
        dateBatch: base.dateBatch,
        startSerial: startSerial,
        endSerial: endSerial,
        generatedCount: generatedCount,
        ignoredCount: _ignoredOutlierCount,
        scannedCount: _scans.length,
        rawAnchorContent: _scans.isEmpty
            ? ''
            : '${_scans.first.prefix}${_scans.first.serial}${_scans.first.batch}${_scans.first.suffix}',
        scannedCodes: _scans
            .map(
              (e) => '${e.prefix}${e.serial}${e.batch}${e.suffix}',
            )
            .toList(),
        createdAt: DateTime.now(),
      ),
    );
    await _loadHistory();
  }

  Future<void> _deleteHistory(int id) async {
    await _historyDao.deleteById(id);
    await _loadHistory();
  }

  Future<void> _openRangeHistoryPreview(QrRangeHistoryEntry item) async {
    final raw = item.rawAnchorContent.trim();
    final parsed = QrParser.parse(raw);
    if (parsed == null) {
      _showMessage('历史记录缺少有效原始码，无法进入预览');
      return;
    }
    final start = int.tryParse(item.startSerial);
    final end = int.tryParse(item.endSerial);
    if (start == null || end == null || end < start) {
      return;
    }
    final count = end - start + 1;
    final result = QrParser.buildRecords(
      prefix: parsed.prefix,
      serialSeed: parsed.serial,
      batch: parsed.batch,
      suffix: parsed.suffix,
      count: count,
      randomTailEnabled: false,
      startSerial: start,
    );
    if (!mounted) {
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
                const SizedBox(height: 8),
                SizedBox(
                  width: double.infinity,
                  child: OutlinedButton.icon(
                    key: const Key('rangeBulkPreviewButton'),
                    onPressed: _scans.isEmpty ? null : _openBulkPreviewDialog,
                    icon: const Icon(Icons.view_carousel_outlined),
                    label: const Text('批量预览生成'),
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
                        _buildInfoRow(
                            '每板箱数', '${_matchedBaseInfo!.boxesPerBoard} 箱'),
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
                if (_latestBuildResult != null) ...[
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
                        color: Colors.red,
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
                      final ignored = _ignoredSerials.contains(item.serial);
                      return Chip(
                        visualDensity: VisualDensity.compact,
                        backgroundColor:
                            ignored ? const Color(0xFFFFEBEE) : null,
                        label: Text(item.serial),
                        labelStyle: TextStyle(
                          color: ignored ? Colors.red : AppTheme.textPrimary,
                          fontWeight:
                              ignored ? FontWeight.w700 : FontWeight.w500,
                        ),
                      );
                    }).toList(),
                  ),
                ],
                if (_history.isNotEmpty) ...[
                  const SizedBox(height: 16),
                  const Text(
                    '历史记录',
                    style: TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(height: 8),
                  ..._history.map((item) {
                    return Card(
                      margin: const EdgeInsets.only(bottom: 8),
                      child: ListTile(
                        onTap: () => _openRangeHistoryPreview(item),
                        dense: true,
                        title: Text(
                          '${item.productCode} | ${item.actualBatch} | ${item.startSerial}~${item.endSerial}',
                        ),
                        subtitle: Text(
                          '生成${item.generatedCount}张 | 扫描${item.scannedCount}箱 | 忽略${item.ignoredCount}',
                        ),
                        trailing: Wrap(
                          spacing: 2,
                          children: [
                            IconButton(
                              tooltip: '复制完整码',
                              onPressed: item.scannedCodes.isEmpty
                                  ? null
                                  : () {
                                      Clipboard.setData(
                                        ClipboardData(
                                          text: item.scannedCodes.join('\n'),
                                        ),
                                      );
                                      _showMessage('已复制完整码');
                                    },
                              icon: const Icon(Icons.copy_outlined),
                            ),
                            IconButton(
                              tooltip: '删除',
                              onPressed: item.id == null
                                  ? null
                                  : () => _deleteHistory(item.id!),
                              icon: const Icon(
                                Icons.delete_outline,
                                color: Colors.red,
                              ),
                            ),
                          ],
                        ),
                      ),
                    );
                  }),
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
  const _StableSerials(this.serials, this.ignoredCount, this.ignoredSerials);

  final List<int> serials;
  final int ignoredCount;
  final Set<String> ignoredSerials;
}

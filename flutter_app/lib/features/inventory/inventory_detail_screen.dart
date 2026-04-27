import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/base_info/base_info_edit_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/utils/board_calculator.dart';
import 'package:qrscan_flutter/shared/widgets/delete_confirm_dialog.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class InventoryDetailScreen extends StatefulWidget {
  const InventoryDetailScreen({
    super.key,
    this.database,
  });

  final AppDatabase? database;

  @override
  State<InventoryDetailScreen> createState() => _InventoryDetailScreenState();
}

class _InventoryDetailScreenState extends State<InventoryDetailScreen> {
  static const int _pageSize = 50;

  late final AppDatabase _database;
  late final ProductDao _productDao;
  late final StockDao _stockDao;
  late final bool _ownsDatabase;

  final _filterController = TextEditingController();
  _StockFilter _stockFilter = _StockFilter.inStock;
  List<InventoryDetailRow> _rows = const [];
  int _total = 0;
  int? _totalPieces;
  Map<String, InventoryGroupSummary> _groupSummaries = const {};
  List<String> _quickProductCodes = const [];
  final Set<String> _collapsedProductCodes = <String>{};
  bool _collapseInitialized = false;
  bool _loading = true;
  bool _loadingMore = false;
  int _queryVersion = 0;
  Timer? _filterDebounce;

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _productDao = ProductDao(_database);
    _stockDao = StockDao(_database);
    _refreshRows(refreshTotals: true);
  }

  @override
  void dispose() {
    _filterDebounce?.cancel();
    _filterController.dispose();
    if (_ownsDatabase) {
      _database.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 42),
          children: [
            Row(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Expanded(
                  child: PageTitle(
                    icon: Icons.inventory_2_outlined,
                    title: '库存明细',
                    subtitle: '批号库存、规格、备注',
                  ),
                ),
                FilledButton.icon(
                  onPressed: () {
                    Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => BaseInfoEditScreen(
                          database: _database,
                        ),
                      ),
                    );
                  },
                  icon: const Icon(Icons.add),
                  label: const Text('录入'),
                ),
              ],
            ),
            const SizedBox(height: 14),
            _TotalCard(totalPieces: _totalPieces),
            const SizedBox(height: 10),
            _FilterBar(
              controller: _filterController,
              selected: _stockFilter,
              quickProductCodes: _quickProductCodes,
              onTextChanged: _onFilterTextChanged,
              onFilterChanged: _onStockFilterChanged,
              onClearTap: () {
                _filterController.clear();
                _refreshRows();
              },
              onQuickProductTap: (code) {
                final current = _filterController.text.trim();
                final next = current == code ? '' : code;
                _filterController.text = next;
                if (next.isNotEmpty) {
                  _collapsedProductCodes.remove(code);
                }
                _refreshRows();
              },
            ),
            const SizedBox(height: 10),
            if (_loading)
              const Center(child: CircularProgressIndicator())
            else if (_rows.isEmpty)
              const _EmptyState()
            else
              ..._buildGroupedRows(_rows),
            if (!_loading && _rows.length < _total)
              Center(
                child: TextButton(
                  key: const Key('inventoryLoadMoreButton'),
                  onPressed: _loadingMore ? null : _loadMore,
                  child: Text(
                    _loadingMore ? '加载中...' : '加载更多（${_rows.length}/$_total）',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  Future<void> _refreshRows({bool refreshTotals = false}) async {
    final requestVersion = ++_queryVersion;
    setState(() {
      _loading = true;
      _loadingMore = false;
      _rows = const [];
      _total = 0;
    });
    final filter = _mapFilter(_stockFilter);
    final result = await _stockDao.inventoryDetailRowsPage(
      offset: 0,
      limit: _pageSize,
      queryText: _filterController.text,
      stockFilter: filter,
    );
    final groupSummaries = await _stockDao.inventoryGroupSummaries(
      queryText: _filterController.text,
      stockFilter: filter,
    );
    final shouldRefreshTotals = refreshTotals || _totalPieces == null;
    final totalPieces = shouldRefreshTotals
        ? await _stockDao.totalInventoryPieces()
        : _totalPieces;
    if (!mounted || requestVersion != _queryVersion) {
      return;
    }
    final sortedRows = _sortRowsByGroupRanking(result.rows, groupSummaries);
    final rankedCodes = groupSummaries.map((item) => item.productCode).toList();
    setState(() {
      _rows = sortedRows;
      _total = result.total;
      _totalPieces = totalPieces;
      _quickProductCodes = rankedCodes;
      _groupSummaries = {
        for (final summary in groupSummaries) summary.productCode: summary,
      };
      if (!_collapseInitialized) {
        _collapsedProductCodes.addAll(rankedCodes);
        _collapseInitialized = true;
      } else {
        for (final code in rankedCodes) {
          if (!_collapsedProductCodes.contains(code) &&
              !_rows.any((row) => row.product.code == code)) {
            _collapsedProductCodes.add(code);
          }
        }
      }
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loading || _loadingMore || _rows.length >= _total) {
      return;
    }
    setState(() => _loadingMore = true);
    final requestVersion = _queryVersion;
    final result = await _stockDao.inventoryDetailRowsPage(
      offset: _rows.length,
      limit: _pageSize,
      queryText: _filterController.text,
      stockFilter: _mapFilter(_stockFilter),
    );
    if (!mounted || requestVersion != _queryVersion) {
      return;
    }
    setState(() {
      final mergedRows = [..._rows, ...result.rows];
      _rows = _sortRowsByGroupRanking(
        mergedRows,
        _groupSummaries.values.toList(),
      );
      _total = result.total;
      _loadingMore = false;
    });
  }

  void _onFilterTextChanged(String _) {
    _filterDebounce?.cancel();
    _filterDebounce = Timer(const Duration(milliseconds: 220), () {
      if (!mounted) {
        return;
      }
      _refreshRows();
    });
  }

  void _onStockFilterChanged(_StockFilter filter) {
    setState(() => _stockFilter = filter);
    _refreshRows();
  }

  InventoryStockFilter _mapFilter(_StockFilter filter) {
    return switch (filter) {
      _StockFilter.all => InventoryStockFilter.all,
      _StockFilter.inStock => InventoryStockFilter.inStock,
      _StockFilter.zero => InventoryStockFilter.zero,
    };
  }

  Future<void> _editRemark(InventoryDetailRow row) async {
    final controller = TextEditingController(text: row.batch.remark ?? '');
    final remark = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('编辑备注'),
        content: TextField(
          key: const Key('inventoryRemarkField'),
          controller: controller,
          autofocus: true,
          maxLines: 3,
          decoration: const InputDecoration(
            labelText: '备注',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('保存'),
          ),
        ],
      ),
    );

    if (remark == null) {
      return;
    }
    await _productDao.updateBatchRemark(
      row.batch.id,
      remark.trim().isEmpty ? null : remark.trim(),
    );
    if (!mounted) {
      return;
    }
    await _refreshRows(refreshTotals: true);
  }

  Future<void> _editBaseInfo(InventoryDetailRow row) async {
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(
        builder: (_) => BaseInfoEditScreen(
          database: _database,
          editingBatchId: row.batch.id,
        ),
      ),
    );
    if (updated != true || !mounted) {
      return;
    }
    await _refreshRows(refreshTotals: true);
    if (!mounted) {
      return;
    }
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已更新基础资料')),
    );
  }

  Future<void> _deleteBatch(InventoryDetailRow row) async {
    final confirmed = await showDeleteConfirmDialog(
      context: context,
      title: '删除批号资料',
      message: '确认删除 ${row.product.code} · ${row.batch.actualBatch}？',
      riskLevel: DeleteRiskLevel.high,
    );
    if (!confirmed) {
      return;
    }
    try {
      final result = await _productDao.deleteBatchWithRelations(row.batch.id);
      if (!mounted) {
        return;
      }
      await _refreshRows(refreshTotals: true);
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(
            result.deletedProductId == null ? '已删除当前批号' : '已删除当前批号及产品',
          ),
        ),
      );
    } on BatchDeleteBlockedException catch (error) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(error.message)),
      );
    }
  }

  List<Widget> _buildGroupedRows(List<InventoryDetailRow> rows) {
    final widgets = <Widget>[];
    String? currentProductCode;
    var currentGroupCollapsed = false;
    for (final row in rows) {
      if (row.product.code != currentProductCode) {
        currentProductCode = row.product.code;
        final code = currentProductCode;
        final summary = _groupSummaries[code];
        currentGroupCollapsed = _collapsedProductCodes.contains(code);
        final collapsedAtBuild = currentGroupCollapsed;
        widgets.add(
          Padding(
            padding: const EdgeInsets.only(bottom: 8, top: 2),
            child: _ProductGroupHeader(
              productCode: code,
              summary: summary,
              collapsed: collapsedAtBuild,
              onTap: () {
                setState(() {
                  if (collapsedAtBuild) {
                    _collapsedProductCodes.remove(code);
                  } else {
                    _collapsedProductCodes.add(code);
                  }
                });
              },
            ),
          ),
        );
      }
      if (currentGroupCollapsed) {
        continue;
      }
      widgets.add(
        Padding(
          padding: const EdgeInsets.only(bottom: 10),
          child: _InventoryRowCard(
            row: row,
            onEditRemark: () => _editRemark(row),
            onEditBaseInfo: () => _editBaseInfo(row),
            onDeleteBatch: () => _deleteBatch(row),
          ),
        ),
      );
    }
    return widgets;
  }

  List<InventoryDetailRow> _sortRowsByGroupRanking(
    List<InventoryDetailRow> rows,
    List<InventoryGroupSummary> summaries,
  ) {
    if (rows.length <= 1) {
      return rows;
    }
    final rankByCode = <String, int>{};
    for (var index = 0; index < summaries.length; index += 1) {
      rankByCode[summaries[index].productCode] = index;
    }
    final sorted = [...rows];
    sorted.sort((a, b) {
      final rankA = rankByCode[a.product.code] ?? 1 << 20;
      final rankB = rankByCode[b.product.code] ?? 1 << 20;
      if (rankA != rankB) {
        return rankA.compareTo(rankB);
      }
      final dateA = _parseDate(a.batch.dateBatch);
      final dateB = _parseDate(b.batch.dateBatch);
      for (var i = 0; i < 3; i += 1) {
        final cmp = dateA[i].compareTo(dateB[i]);
        if (cmp != 0) {
          return cmp;
        }
      }
      return a.batch.actualBatch.compareTo(b.batch.actualBatch);
    });
    return sorted;
  }

  List<int> _parseDate(String dateText) {
    final parts = dateText.split('.');
    if (parts.length != 3) {
      return const [9999, 99, 99];
    }
    return [
      int.tryParse(parts[0]) ?? 9999,
      int.tryParse(parts[1]) ?? 99,
      int.tryParse(parts[2]) ?? 99,
    ];
  }
}

enum _StockFilter { all, inStock, zero }

class _TotalCard extends StatelessWidget {
  const _TotalCard({required this.totalPieces});

  final int? totalPieces;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '总库存',
            style: TextStyle(
              color: Color(0xFFDBEAFE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Text(
            totalPieces == null ? '-- 件' : '${_formatNumber(totalPieces!)} 件',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w800,
            ),
          ),
        ],
      ),
    );
  }
}

class _FilterBar extends StatelessWidget {
  const _FilterBar({
    required this.controller,
    required this.selected,
    required this.quickProductCodes,
    required this.onTextChanged,
    required this.onFilterChanged,
    required this.onQuickProductTap,
    required this.onClearTap,
  });

  final TextEditingController controller;
  final _StockFilter selected;
  final List<String> quickProductCodes;
  final ValueChanged<String> onTextChanged;
  final ValueChanged<_StockFilter> onFilterChanged;
  final ValueChanged<String> onQuickProductTap;
  final VoidCallback onClearTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        children: [
          TextField(
            controller: controller,
            onChanged: onTextChanged,
            decoration: InputDecoration(
              prefixIcon: const Icon(Icons.search),
              hintText: '筛选产品 / 批号',
              suffixIcon: controller.text.trim().isEmpty
                  ? null
                  : IconButton(
                      key: const Key('inventoryFilterClearButton'),
                      tooltip: '清空筛选',
                      onPressed: onClearTap,
                      icon: const Icon(Icons.close),
                    ),
              filled: true,
              fillColor: const Color(0xFFF7F9FC),
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          if (quickProductCodes.isNotEmpty) ...[
            const SizedBox(height: 10),
            SizedBox(
              height: 32,
              child: ListView.separated(
                scrollDirection: Axis.horizontal,
                itemCount: quickProductCodes.length,
                separatorBuilder: (_, __) => const SizedBox(width: 8),
                itemBuilder: (context, index) {
                  final code = quickProductCodes[index];
                  final selectedQuick = controller.text.trim() == code;
                  return GestureDetector(
                    onTap: () => onQuickProductTap(code),
                    child: Container(
                      key: Key('inventoryQuick-$code'),
                      padding: const EdgeInsets.symmetric(
                        horizontal: 10,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: selectedQuick
                            ? const Color(0xFFE5EDFF)
                            : const Color(0xFFF7F9FC),
                        borderRadius: BorderRadius.circular(999),
                        border: Border.all(
                          color: selectedQuick
                              ? const Color(0xFF2563EB)
                              : const Color(0xFFD5DDEB),
                        ),
                      ),
                      child: Text(
                        code,
                        style: TextStyle(
                          color: selectedQuick
                              ? const Color(0xFF1D4ED8)
                              : AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w800,
                        ),
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
          const SizedBox(height: 10),
          SegmentedButton<_StockFilter>(
            segments: const [
              ButtonSegment(value: _StockFilter.all, label: Text('全部')),
              ButtonSegment(value: _StockFilter.inStock, label: Text('有库存')),
              ButtonSegment(value: _StockFilter.zero, label: Text('零库存')),
            ],
            selected: {selected},
            onSelectionChanged: (value) => onFilterChanged(value.single),
            showSelectedIcon: false,
          ),
        ],
      ),
    );
  }
}

class _ProductGroupHeader extends StatelessWidget {
  const _ProductGroupHeader({
    required this.productCode,
    required this.summary,
    required this.collapsed,
    required this.onTap,
  });

  final String productCode;
  final InventoryGroupSummary? summary;
  final bool collapsed;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final totalPieces = summary?.totalPieces ?? 0;
    final totalBoxes = summary?.totalBoxes ?? 0;
    return InkWell(
      key: Key('inventory-group-$productCode'),
      onTap: onTap,
      borderRadius: BorderRadius.circular(10),
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 2, vertical: 4),
        child: Row(
          children: [
            Icon(
              collapsed ? Icons.chevron_right : Icons.expand_more,
              size: 17,
              color: AppTheme.textSecondary,
            ),
            const SizedBox(width: 2),
            Text(
              productCode,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_formatNumber(totalPieces)}件 · ${_formatNumber(totalBoxes)}箱',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _InventoryRowCard extends StatelessWidget {
  const _InventoryRowCard({
    required this.row,
    required this.onEditRemark,
    required this.onEditBaseInfo,
    required this.onDeleteBatch,
  });

  final InventoryDetailRow row;
  final VoidCallback onEditRemark;
  final VoidCallback onEditBaseInfo;
  final VoidCallback onDeleteBatch;

  @override
  Widget build(BuildContext context) {
    final boardText = BoardCalculator.format(
      boxes: row.currentBoxes,
      boxesPerBoard: row.batch.boxesPerBoard,
    );
    final statusColor =
        row.isZeroStock ? Colors.red.shade700 : Colors.green.shade700;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: row.isZeroStock ? const Color(0xFFFFF1F2) : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: row.isZeroStock ? const Color(0xFFFECACA) : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: [
                    Text(
                      '${row.product.code} · ${row.batch.actualBatch}',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                    Text(
                      row.batch.dateBatch,
                      style: const TextStyle(
                        color: Color(0xFFB91C1C),
                        fontSize: 17,
                        fontWeight: FontWeight.w800,
                      ),
                    ),
                  ],
                ),
              ),
              if (row.isZeroStock)
                _StatusPill(
                  text: '已空',
                  color: statusColor,
                ),
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(text: '${row.currentBoxes}箱'),
              _MetricChip(text: boardText),
              _MetricChip(
                text:
                    '${row.batch.boxesPerBoard}箱/板 · ${row.product.piecesPerBox}件/箱',
              ),
              _MetricChip(text: '库位 ${row.batch.location ?? '--'}'),
              if (row.batch.tsRequired)
                const _MetricChip(
                  text: 'TS',
                  textColor: Color(0xFFB91C1C),
                  backgroundColor: Color(0xFFFEE2E2),
                ),
              _MetricChip(
                text: row.batch.hasShipped ? '已发过' : '未发过',
                textColor: row.batch.hasShipped
                    ? const Color(0xFFB91C1C)
                    : AppTheme.primary,
                backgroundColor: row.batch.hasShipped
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFF3F6FB),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: Text(
                  row.batch.remark?.isNotEmpty == true
                      ? row.batch.remark!
                      : '暂无备注',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              IconButton(
                tooltip: '编辑资料',
                onPressed: onEditBaseInfo,
                icon: const Icon(Icons.edit_outlined),
              ),
              IconButton(
                tooltip: '编辑备注',
                onPressed: onEditRemark,
                icon: const Icon(Icons.edit_note_outlined),
              ),
              IconButton(
                tooltip: '删除批号',
                onPressed: onDeleteBatch,
                icon: const Icon(Icons.delete_outline),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _MetricChip extends StatelessWidget {
  const _MetricChip({
    required this.text,
    this.textColor = AppTheme.primary,
    this.backgroundColor = const Color(0xFFF3F6FB),
  });

  final String text;
  final Color textColor;
  final Color backgroundColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: textColor,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _StatusPill extends StatelessWidget {
  const _StatusPill({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _EmptyState extends StatelessWidget {
  const _EmptyState();

  @override
  Widget build(BuildContext context) {
    return const Padding(
      padding: EdgeInsets.symmetric(vertical: 48),
      child: Center(
        child: Text(
          '暂无库存资料',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
    );
  }
}

String _formatNumber(int value) {
  final text = value.toString();
  final buffer = StringBuffer();
  for (var i = 0; i < text.length; i += 1) {
    final reverseIndex = text.length - i;
    buffer.write(text[i]);
    if (reverseIndex > 1 && reverseIndex % 3 == 1) {
      buffer.write(',');
    }
  }
  return buffer.toString();
}

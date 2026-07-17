import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/base_info/base_info_edit_screen.dart';
import 'package:qrscan_flutter/features/inventory/stocktake_preview_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/utils/board_calculator.dart';
import 'package:qrscan_flutter/shared/utils/navigation_refresh.dart';
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
  Map<String, List<String>> _batchCodesByProductDate = const {};
  List<String> _quickProductCodes = const [];
  final Set<String> _collapsedProductCodes = <String>{};
  String? _selectedZeroProductCode;
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
            LayoutBuilder(
              builder: (context, constraints) {
                final compactActions = constraints.maxWidth < 560;
                return Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Expanded(
                      child: PageTitle(
                        icon: Icons.inventory_2_outlined,
                        title: '库存明细',
                        subtitle: '批号库存、规格、备注',
                      ),
                    ),
                    const SizedBox(width: 8),
                    if (compactActions) ...[
                      _HeaderActionButton(
                        key: const Key('inventoryStocktakeButton'),
                        label: '盘',
                        icon: Icons.fact_check_outlined,
                        primary: true,
                        compact: true,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StocktakePreviewScreen(
                              database: _database,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _HeaderActionButton(
                        label: '录入',
                        icon: Icons.playlist_add_rounded,
                        primary: false,
                        compact: true,
                        onPressed: () async {
                          await pushAndRefresh(
                            context,
                            route: MaterialPageRoute(
                              builder: (_) => BaseInfoEditScreen(
                                database: _database,
                              ),
                            ),
                            onRefresh: () => _refreshRows(refreshTotals: true),
                          );
                        },
                      ),
                    ] else ...[
                      _HeaderActionButton(
                        key: const Key('inventoryStocktakeButton'),
                        label: '盘',
                        icon: Icons.fact_check_outlined,
                        primary: true,
                        compact: false,
                        onPressed: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => StocktakePreviewScreen(
                              database: _database,
                            ),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      _HeaderActionButton(
                        label: '录入',
                        icon: Icons.playlist_add_rounded,
                        primary: false,
                        compact: false,
                        onPressed: () async {
                          await pushAndRefresh(
                            context,
                            route: MaterialPageRoute(
                              builder: (_) => BaseInfoEditScreen(
                                database: _database,
                              ),
                            ),
                            onRefresh: () => _refreshRows(refreshTotals: true),
                          );
                        },
                      ),
                    ],
                  ],
                );
              },
            ),
            const SizedBox(height: 14),
            _TotalCard(totalPieces: _totalPieces),
            const SizedBox(height: 10),
            _FilterBar(
              controller: _filterController,
              selected: _stockFilter,
              quickProductCodes: _quickProductCodes,
              showQuickProductCodes: _stockFilter != _StockFilter.zero,
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
            else if (_stockFilter == _StockFilter.zero)
              ..._buildZeroStockView(_rows)
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
    final batchCodesByProductDate = await _productDao.batchCodesByProductDate();
    final shouldRefreshTotals = refreshTotals || _totalPieces == null;
    final totalPieces = shouldRefreshTotals
        ? await _stockDao.totalInventoryPieces()
        : _totalPieces;
    if (!mounted || requestVersion != _queryVersion) {
      return;
    }
    final sortedRows = _sortRowsByGroupRanking(result.rows, groupSummaries);
    final rankedCodes = groupSummaries.map((item) => item.productCode).toList();
    var selectedZeroProductCode = _selectedZeroProductCode;
    if (_stockFilter == _StockFilter.zero) {
      if (rankedCodes.isEmpty) {
        selectedZeroProductCode = null;
      } else if (selectedZeroProductCode == null ||
          !rankedCodes.contains(selectedZeroProductCode)) {
        selectedZeroProductCode = rankedCodes.first;
      }
    } else {
      selectedZeroProductCode = null;
    }
    setState(() {
      _rows = sortedRows;
      _total = result.total;
      _totalPieces = totalPieces;
      _selectedZeroProductCode = selectedZeroProductCode;
      _quickProductCodes = rankedCodes;
      _batchCodesByProductDate = batchCodesByProductDate;
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
      _StockFilter.frozen => InventoryStockFilter.frozen,
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
    final duplicateDateKeys = _duplicateBatchDateKeys(_batchCodesByProductDate);
    final batchCodesByKey = _batchCodesByProductDate;
    final lowStockProductCodes =
        rows.where(_isLowStockRow).map((row) => row.product.code).toSet();
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
              hasLowStock: lowStockProductCodes.contains(code),
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
            highlightBatch: duplicateDateKeys
                .contains('${row.product.code}|${row.batch.dateBatch}'),
            batchCodeVariants:
                batchCodesByKey['${row.product.code}|${row.batch.dateBatch}'] ??
                    const <String>[],
            onEditRemark: () => _editRemark(row),
            onEditBaseInfo: () => _editBaseInfo(row),
            onDeleteBatch: () => _deleteBatch(row),
          ),
        ),
      );
    }
    return widgets;
  }

  List<Widget> _buildZeroStockView(List<InventoryDetailRow> rows) {
    final productCodes = _quickProductCodes;
    if (productCodes.isEmpty) {
      return const [_EmptyState()];
    }
    final selectedCode = _selectedZeroProductCode ?? productCodes.first;
    final selectedRows =
        rows.where((row) => row.product.code == selectedCode).toList();
    final duplicateDateKeys = _duplicateBatchDateKeys(_batchCodesByProductDate);
    final batchCodesByKey = _batchCodesByProductDate;
    return [
      _ZeroStockProductWall(
        productCodes: productCodes,
        selectedCode: selectedCode,
        onProductTap: (code) {
          setState(() => _selectedZeroProductCode = code);
        },
      ),
      const SizedBox(height: 10),
      _ZeroStockDetailPanel(
        key: Key('inventoryZeroDetail-$selectedCode'),
        productCode: selectedCode,
        rows: selectedRows,
        totalBatches: selectedRows.length,
        duplicateDateKeys: duplicateDateKeys,
        batchCodesByProductDate: batchCodesByKey,
        onEditRemark: _editRemark,
        onEditBaseInfo: _editBaseInfo,
        onDeleteBatch: _deleteBatch,
      ),
    ];
  }

  bool _isLowStockRow(InventoryDetailRow row) {
    return !row.isZeroStock &&
        row.availableBoxes < row.batch.boxesPerBoard * 10;
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

enum _StockFilter { all, inStock, zero, frozen }

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
    required this.showQuickProductCodes,
    required this.onTextChanged,
    required this.onFilterChanged,
    required this.onQuickProductTap,
    required this.onClearTap,
  });

  final TextEditingController controller;
  final _StockFilter selected;
  final List<String> quickProductCodes;
  final bool showQuickProductCodes;
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
          if (showQuickProductCodes && quickProductCodes.isNotEmpty) ...[
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
              ButtonSegment(value: _StockFilter.frozen, label: Text('有冻结')),
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

class _ZeroStockProductWall extends StatelessWidget {
  const _ZeroStockProductWall({
    required this.productCodes,
    required this.selectedCode,
    required this.onProductTap,
  });

  final List<String> productCodes;
  final String selectedCode;
  final ValueChanged<String> onProductTap;

  @override
  Widget build(BuildContext context) {
    return Container(
      key: const Key('inventoryZeroProductWall'),
      width: double.infinity,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${productCodes.length} 个零库存产品',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          const Text(
            '点击产品编号，下面直接展开该产品批号明细。',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          LayoutBuilder(
            builder: (context, constraints) {
              final itemWidth = (constraints.maxWidth - 16) / 3;
              return Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  for (final code in productCodes)
                    SizedBox(
                      width: itemWidth,
                      child: _ZeroStockProductTag(
                        code: code,
                        selected: code == selectedCode,
                        onTap: () => onProductTap(code),
                      ),
                    ),
                ],
              );
            },
          ),
        ],
      ),
    );
  }
}

class _ZeroStockProductTag extends StatelessWidget {
  const _ZeroStockProductTag({
    required this.code,
    required this.selected,
    required this.onTap,
  });

  final String code;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected ? const Color(0xFFEFF5FF) : Colors.white,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(13),
        side: BorderSide(
          color: selected ? const Color(0xFF8DB2FF) : const Color(0xFFD5DDEB),
          width: selected ? 1.4 : 1,
        ),
      ),
      child: InkWell(
        key: Key('inventoryZeroProduct-$code'),
        onTap: onTap,
        borderRadius: BorderRadius.circular(13),
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 11, horizontal: 6),
          child: Center(
            child: Text(
              code,
              maxLines: 1,
              overflow: TextOverflow.ellipsis,
              style: TextStyle(
                color:
                    selected ? const Color(0xFF0F4ED7) : AppTheme.textPrimary,
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _ZeroStockDetailPanel extends StatelessWidget {
  const _ZeroStockDetailPanel({
    super.key,
    required this.productCode,
    required this.rows,
    required this.totalBatches,
    required this.duplicateDateKeys,
    required this.batchCodesByProductDate,
    required this.onEditRemark,
    required this.onEditBaseInfo,
    required this.onDeleteBatch,
  });

  final String productCode;
  final List<InventoryDetailRow> rows;
  final int totalBatches;
  final Set<String> duplicateDateKeys;
  final Map<String, List<String>> batchCodesByProductDate;
  final ValueChanged<InventoryDetailRow> onEditRemark;
  final ValueChanged<InventoryDetailRow> onEditBaseInfo;
  final ValueChanged<InventoryDetailRow> onDeleteBatch;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      '$productCode · 批号明细',
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      '零库存，$totalBatches 条批号记录',
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              const _MetricChip(
                text: '可用 0箱',
                textColor: AppTheme.textSecondary,
              ),
            ],
          ),
          const SizedBox(height: 12),
          if (rows.isEmpty)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: 16),
              child: Text(
                '该产品批号还未加载，请点下方加载更多。',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  fontWeight: FontWeight.w700,
                ),
              ),
            )
          else
            ...rows.map(
              (row) {
                final key = '${row.product.code}|${row.batch.dateBatch}';
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _ZeroStockBatchTile(
                    row: row,
                    highlightBatch: duplicateDateKeys.contains(key),
                    batchCodeVariants:
                        batchCodesByProductDate[key] ?? const <String>[],
                    onEditRemark: () => onEditRemark(row),
                    onEditBaseInfo: () => onEditBaseInfo(row),
                    onDeleteBatch: () => onDeleteBatch(row),
                  ),
                );
              },
            ),
        ],
      ),
    );
  }
}

class _ZeroStockBatchTile extends StatelessWidget {
  const _ZeroStockBatchTile({
    required this.row,
    required this.highlightBatch,
    required this.batchCodeVariants,
    required this.onEditRemark,
    required this.onEditBaseInfo,
    required this.onDeleteBatch,
  });

  final InventoryDetailRow row;
  final bool highlightBatch;
  final List<String> batchCodeVariants;
  final VoidCallback onEditRemark;
  final VoidCallback onEditBaseInfo;
  final VoidCallback onDeleteBatch;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: const Color(0xFFFBFDFF),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 16,
                      fontWeight: FontWeight.w900,
                    ),
                    children: [
                      TextSpan(text: '${row.product.code} · '),
                      TextSpan(
                        children: _batchCodeSpans(
                          row.batch.actualBatch,
                          variants: batchCodeVariants,
                          highlightDifferences: highlightBatch,
                        ),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  '${row.batch.dateBatch} · 库位 ${row.batch.location ?? '--'}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  _zeroStockNote(row),
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 8),
          Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                tooltip: '编辑资料',
                visualDensity: VisualDensity.compact,
                onPressed: onEditBaseInfo,
                icon: const Icon(Icons.chevron_right_rounded),
              ),
              PopupMenuButton<String>(
                tooltip: '更多操作',
                onSelected: (value) {
                  if (value == 'remark') {
                    onEditRemark();
                  } else if (value == 'delete') {
                    onDeleteBatch();
                  }
                },
                itemBuilder: (context) => const [
                  PopupMenuItem(value: 'remark', child: Text('编辑备注')),
                  PopupMenuItem(value: 'delete', child: Text('删除批号')),
                ],
              ),
            ],
          ),
        ],
      ),
    );
  }

  String _zeroStockNote(InventoryDetailRow row) {
    if (row.frozenBoxes > 0) {
      return '冻结 ${row.frozenBoxes}箱';
    }
    final remark = row.batch.remark;
    if (remark != null && remark.isNotEmpty) {
      return remark;
    }
    return '已空';
  }
}

class _ProductGroupHeader extends StatelessWidget {
  const _ProductGroupHeader({
    required this.productCode,
    required this.summary,
    required this.collapsed,
    required this.hasLowStock,
    required this.onTap,
  });

  final String productCode;
  final InventoryGroupSummary? summary;
  final bool collapsed;
  final bool hasLowStock;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    final totalPieces = summary?.totalPieces ?? 0;
    final totalBoxes = summary?.totalBoxes ?? 0;
    final textColor =
        hasLowStock ? const Color(0xFFB91C1C) : AppTheme.textSecondary;
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
              color: textColor,
            ),
            const SizedBox(width: 2),
            Text(
              productCode,
              style: TextStyle(
                color: textColor,
                fontSize: 13,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                '${_formatNumber(totalPieces)}件 · ${_formatNumber(totalBoxes)}箱',
                style: TextStyle(
                  color: textColor,
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
    required this.highlightBatch,
    required this.batchCodeVariants,
    required this.onEditRemark,
    required this.onEditBaseInfo,
    required this.onDeleteBatch,
  });

  final InventoryDetailRow row;
  final bool highlightBatch;
  final List<String> batchCodeVariants;
  final VoidCallback onEditRemark;
  final VoidCallback onEditBaseInfo;
  final VoidCallback onDeleteBatch;

  @override
  Widget build(BuildContext context) {
    final boardText = BoardCalculator.format(
      boxes: row.availableBoxes,
      boxesPerBoard: row.batch.boxesPerBoard,
    );
    final lowStockThreshold = row.batch.boxesPerBoard * 10;
    final isLowStock =
        !row.isZeroStock && row.availableBoxes < lowStockThreshold;
    final statusColor = (row.isZeroStock || isLowStock)
        ? Colors.red.shade700
        : Colors.green.shade700;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: row.isZeroStock || isLowStock
            ? const Color(0xFFFFF1F2)
            : Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: row.isZeroStock || isLowStock
              ? const Color(0xFFFECACA)
              : Colors.transparent,
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Expanded(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    return SizedBox(
                      width: constraints.maxWidth,
                      child: FittedBox(
                        fit: BoxFit.scaleDown,
                        alignment: Alignment.centerLeft,
                        child: RichText(
                          maxLines: 1,
                          overflow: TextOverflow.visible,
                          text: TextSpan(
                            style: const TextStyle(
                              color: AppTheme.textPrimary,
                              fontSize: 17,
                              fontWeight: FontWeight.w800,
                            ),
                            children: [
                              TextSpan(text: '${row.product.code} · '),
                              TextSpan(
                                children: _batchCodeSpans(
                                  row.batch.actualBatch,
                                  variants: batchCodeVariants,
                                  highlightDifferences: highlightBatch,
                                ),
                              ),
                              TextSpan(
                                text: ' · ${row.batch.dateBatch}',
                                style: const TextStyle(
                                  color: Color(0xFFB91C1C),
                                  fontSize: 17,
                                  fontWeight: FontWeight.w800,
                                ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    );
                  },
                ),
              ),
              if (row.isZeroStock) ...[
                const SizedBox(width: 8),
                _StatusPill(
                  text: '已空',
                  color: statusColor,
                ),
              ],
            ],
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _MetricChip(
                text: '总数 ${row.totalPieces}',
                textColor: AppTheme.textPrimary,
              ),
              _MetricChip(
                text: '可用 ${row.availableBoxes}箱',
                textColor: isLowStock || row.isZeroStock
                    ? const Color(0xFFB91C1C)
                    : AppTheme.primary,
                backgroundColor: isLowStock || row.isZeroStock
                    ? const Color(0xFFFEE2E2)
                    : const Color(0xFFF3F6FB),
              ),
              if (row.reservedBoxes > 0)
                _MetricChip(
                  text: '占用 ${row.reservedBoxes}箱',
                  textColor: const Color(0xFF92400E),
                  backgroundColor: const Color(0xFFFFF7ED),
                ),
              if (row.frozenBoxes > 0)
                _MetricChip(
                  text: '冻结 ${row.frozenBoxes}箱',
                  textColor: const Color(0xFF92400E),
                  backgroundColor: const Color(0xFFFFF7ED),
                ),
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

class _HeaderActionButton extends StatelessWidget {
  const _HeaderActionButton({
    super.key,
    required this.label,
    required this.icon,
    required this.onPressed,
    required this.primary,
    required this.compact,
  });

  final String label;
  final IconData icon;
  final VoidCallback onPressed;
  final bool primary;
  final bool compact;

  @override
  Widget build(BuildContext context) {
    final foreground = primary ? Colors.white : const Color(0xFF1D4ED8);
    final backgroundTop =
        primary ? const Color(0xFF2D6BFF) : const Color(0xFFF1F6FF);
    final backgroundBottom =
        primary ? const Color(0xFF1D4ED8) : const Color(0xFFE4EEFF);
    final border = primary ? const Color(0xFF3B82F6) : const Color(0xFFC9DBFF);
    final shape = RoundedRectangleBorder(
      borderRadius: BorderRadius.circular(14),
      side: BorderSide(color: border, width: 1),
    );
    return DecoratedBox(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(14),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: primary ? 0.12 : 0.06),
            blurRadius: primary ? 18 : 12,
            offset: const Offset(0, 6),
          ),
          BoxShadow(
            color: primary
                ? Colors.white.withValues(alpha: 0.55)
                : Colors.white.withValues(alpha: 0.75),
            blurRadius: 2,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      child: Material(
        shape: shape,
        color: Colors.transparent,
        child: Ink(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(14),
            gradient: LinearGradient(
              colors: [backgroundTop, backgroundBottom],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: InkWell(
            onTap: onPressed,
            borderRadius: BorderRadius.circular(14),
            child: Padding(
              padding: EdgeInsets.symmetric(
                horizontal: compact ? 11 : 13,
                vertical: compact ? 8 : 9,
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(
                    icon,
                    size: compact ? 19 : 20,
                    color: foreground,
                  ),
                  SizedBox(width: compact ? 5 : 6),
                  Text(
                    label,
                    style: TextStyle(
                      color: foreground,
                      fontSize: compact ? 16 : 15,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}

Set<String> _duplicateBatchDateKeys(Map<String, List<String>> variants) {
  return variants.entries
      .where((entry) => entry.value.toSet().length > 1)
      .map((entry) => entry.key)
      .toSet();
}

List<InlineSpan> _batchCodeSpans(
  String code, {
  required List<String> variants,
  required bool highlightDifferences,
}) {
  if (!highlightDifferences || variants.length <= 1) {
    return [
      TextSpan(
        text: code,
        style: const TextStyle(color: AppTheme.textPrimary),
      ),
    ];
  }

  final unique = variants.toSet().toList()..sort();
  if (unique.length <= 1) {
    return [
      TextSpan(
        text: code,
        style: const TextStyle(color: AppTheme.textPrimary),
      ),
    ];
  }

  final maxLen =
      unique.map((item) => item.length).fold<int>(0, (a, b) => a > b ? a : b);
  final diffIndexes = <int>{};
  for (var i = 0; i < maxLen; i += 1) {
    final chars = unique.map((item) => i < item.length ? item[i] : '').toSet();
    if (chars.length > 1) {
      diffIndexes.add(i);
    }
  }

  final spans = <InlineSpan>[];
  for (var i = 0; i < code.length; i += 1) {
    spans.add(
      TextSpan(
        text: code[i],
        style: TextStyle(
          color: diffIndexes.contains(i)
              ? const Color(0xFFDC2626)
              : AppTheme.textPrimary,
        ),
      ),
    );
  }
  return spans;
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

import 'dart:async';
import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/stocktake_dao.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class StocktakePreviewScreen extends StatefulWidget {
  const StocktakePreviewScreen({
    super.key,
    this.database,
  });

  final AppDatabase? database;

  @override
  State<StocktakePreviewScreen> createState() => _StocktakePreviewScreenState();
}

class _StocktakePreviewScreenState extends State<StocktakePreviewScreen> {
  late final AppDatabase _database;
  late final bool _ownsDatabase;
  late final StocktakeDao _stocktakeDao;

  DateTime _selectedMonth = _defaultMonth();
  StocktakeSessionBundle? _bundle;
  List<_StocktakeHistorySummary> _recentHistory = const [];
  _LatestSessionSummary? _latestSummary;
  bool _loading = false;
  final Map<int, bool> _statsExpanded = <int, bool>{};
  final Map<int, List<_FloorCountEntry>> _floorEntries = <int, List<_FloorCountEntry>>{};
  final Map<int, int> _issueShortageBoxes = <int, int>{};

  @override
  void initState() {
    super.initState();
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _stocktakeDao = StocktakeDao(_database);
    _loadRecent();
  }

  @override
  void dispose() {
    if (_ownsDatabase) {
      _database.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final bundle = _bundle;
    final items = bundle?.items ?? const <StocktakeItemRecord>[];
    final isCompleted =
        bundle?.session.status == StocktakeSessionStatus.completed.index;
    final pending = items.where((e) => e.status == StocktakeItemStatus.pending.index).length;
    final checked = items.where((e) => e.status == StocktakeItemStatus.checked.index).length;
    final issue = items.where((e) => e.status == StocktakeItemStatus.issue.index).length;
    final diffIndexMap = _buildBatchDiffIndexMap(items);
    final showEditingArea = bundle != null;

    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 32),
          children: [
            const PageTitle(
              icon: Icons.fact_check_outlined,
              title: '盘库',
              subtitle: '简单记录，不改库存',
            ),
            const SizedBox(height: 12),
            if (showEditingArea) ...[
              _statsCard(total: items.length, pending: pending, checked: checked, issue: issue),
              const SizedBox(height: 10),
              if (items.isEmpty)
                _emptyResultCard()
              else
                ...items.map(
                  (item) => Padding(
                    padding: const EdgeInsets.only(bottom: 8),
                    child: _itemCard(
                      item,
                      readOnly: isCompleted,
                      diffIndexes: diffIndexMap[item.id] ?? const <int>{},
                    ),
                  ),
                ),
              const SizedBox(height: 12),
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: _loading || isCompleted ? null : _onAddProductPressed,
                      icon: const Icon(Icons.add_box_outlined),
                      label: const Text('新增产品'),
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: FilledButton.icon(
                      onPressed: _loading || isCompleted
                          ? null
                          : () async {
                              final messenger = ScaffoldMessenger.of(context);
                              await _stocktakeDao.completeSession(
                                sessionId: bundle.session.id,
                              );
                              if (!mounted) return;
                              messenger.showSnackBar(
                                const SnackBar(content: Text('盘库已确认')),
                              );
                              setState(() => _bundle = null);
                              await _loadRecent();
                            },
                      icon: const Icon(Icons.task_alt),
                      label: const Text('确认完成'),
                    ),
                  ),
                ],
              ),
            ] else ...[
              _monthBar(),
              const SizedBox(height: 10),
              _latestSummaryCard(),
            ],
            const SizedBox(height: 12),
            _recentCard(),
          ],
        ),
      ),
    );
  }

  Widget _monthBar() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: FittedBox(
                  fit: BoxFit.scaleDown,
                  alignment: Alignment.centerLeft,
                  child: Text(
                    _formatMonth(_selectedMonth),
                    maxLines: 1,
                    style: const TextStyle(
                      fontSize: 20,
                      fontWeight: FontWeight.w900,
                      color: AppTheme.textPrimary,
                    ),
                  ),
                ),
              ),
              IconButton(
                tooltip: '选择月份',
                onPressed: _loading ? null : _pickMonth,
                icon: const Icon(Icons.calendar_month_outlined),
              ),
              const SizedBox(width: 4),
              FilledButton.icon(
                onPressed: _loading ? null : _createSession,
                icon: const Icon(Icons.auto_awesome),
                label: Text(_loading ? '生成中' : '生成清单'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsCard({
    required int total,
    required int pending,
    required int checked,
    required int issue,
  }) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Row(
        children: [
          _metric('总数', '$total'),
          _metric('待盘', '$pending'),
          _metric('已盘', '$checked'),
          _metric('异常', '$issue'),
        ],
      ),
    );
  }

  Widget _metric(String label, String value) {
    return Expanded(
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }

  Widget _itemCard(
    StocktakeItemRecord item, {
    required bool readOnly,
    required Set<int> diffIndexes,
  }) {
    final status = StocktakeItemStatus.values[item.status];
    final isChecked = status == StocktakeItemStatus.checked;
    final isIssue = status == StocktakeItemStatus.issue;
    final accentColor = isIssue
        ? const Color(0xFFB91C1C)
        : (isChecked ? const Color(0xFF15803D) : AppTheme.textPrimary);
    final boardText = _formatBoard(item.currentBoxes, item.boxesPerBoard);
    final countedBoxes = _countedBoxes(item);
    final remainingBoxes = item.currentBoxes - countedBoxes;
    final entries = _floorEntries[item.id] ?? const <_FloorCountEntry>[];
    final countedText = _formatBoard(countedBoxes, item.boxesPerBoard);
    final remainText = _formatBoardSigned(remainingBoxes, item.boxesPerBoard);
    final isExpanded = _statsExpanded[item.id] ?? false;
    final showRedStat = countedBoxes > 0;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isIssue
            ? const Color(0xFFFEF2F2)
            : (isChecked ? const Color(0xFFF0FDF4) : Colors.white),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isIssue
              ? const Color(0xFFFCA5A5)
              : (isChecked ? const Color(0xFF22C55E) : Colors.transparent),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: RichText(
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  text: TextSpan(
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w800,
                      fontSize: 15,
                    ),
                    children: [
                      TextSpan(
                        text: '${item.productCode} · ',
                        style: TextStyle(color: accentColor),
                      ),
                      ..._batchCodeSpans(
                        item.batchCode,
                        diffIndexes,
                        baseColor: accentColor,
                      ),
                      TextSpan(
                        text: ' · ${item.dateBatch}',
                        style: TextStyle(color: accentColor),
                      ),
                    ],
                  ),
                ),
              ),
              if (!readOnly)
                IconButton(
                  tooltip: '删除条目',
                  onPressed: () => _deleteItem(item),
                  icon: const Icon(
                    Icons.delete_outline,
                    color: Color(0xFFDC2626),
                  ),
                ),
            ],
          ),
          const SizedBox(height: 6),
          Text(
            '当前库存 ${item.currentBoxes}箱（$boardText）',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 2),
          Text(
            '已统计 $countedText  ·  ${_remainingLabel(remainingBoxes)} $remainText',
            style: TextStyle(
              color: showRedStat ? const Color(0xFFB91C1C) : AppTheme.textSecondary,
              fontWeight: FontWeight.w800,
            ),
          ),
          if (status == StocktakeItemStatus.issue && (_issueShortageBoxes[item.id] ?? 0) > 0) ...[
            const SizedBox(height: 2),
            Text(
              '异常缺 ${_issueShortageBoxes[item.id]}箱',
              style: const TextStyle(
                color: Color(0xFFB91C1C),
                fontWeight: FontWeight.w800,
              ),
            ),
          ],
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: [
              _statusChip(item, StocktakeItemStatus.pending, '待盘', status == StocktakeItemStatus.pending),
              _statusChip(item, StocktakeItemStatus.checked, '已盘', status == StocktakeItemStatus.checked),
              _statusChip(item, StocktakeItemStatus.issue, '异常', status == StocktakeItemStatus.issue),
              ActionChip(
                label: const Text('备注'),
                onPressed: readOnly ? null : () => _editNote(item),
              ),
              ActionChip(
                avatar: const Icon(Icons.calculate_outlined, size: 16),
                label: Text(isExpanded ? '收起统计' : '统计'),
                onPressed: readOnly ? null : () => _toggleStats(item.id),
              ),
            ],
          ),
          if (isExpanded) ...[
            const SizedBox(height: 10),
            _statsEditor(
              item: item,
              entries: entries,
              readOnly: readOnly,
            ),
          ],
          if ((item.note ?? '').isNotEmpty) ...[
            const SizedBox(height: 8),
            Text(
              item.note!,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _statsEditor({
    required StocktakeItemRecord item,
    required List<_FloorCountEntry> entries,
    required bool readOnly,
  }) {
    final localEntries = entries.isEmpty ? <_FloorCountEntry>[const _FloorCountEntry()] : entries;
    if (entries.isEmpty) {
      _floorEntries[item.id] = localEntries;
    }
    final totalBoxes = _countedBoxes(item);
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFF),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          ...localEntries.asMap().entries.map(
            (entry) => Padding(
              padding: const EdgeInsets.only(bottom: 8),
              child: _statsRow(item: item, index: entry.key, entry: entry.value, readOnly: readOnly),
            ),
          ),
          Row(
            children: [
              TextButton.icon(
                onPressed: readOnly ? null : () => _addStatsEntry(item.id),
                icon: const Icon(Icons.add),
                label: const Text('增加条目'),
              ),
              const Spacer(),
              Text(
                '累计 ${_formatBoard(totalBoxes, item.boxesPerBoard)}',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontWeight: FontWeight.w800,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _statsRow({
    required StocktakeItemRecord item,
    required int index,
    required _FloorCountEntry entry,
    required bool readOnly,
  }) {
    return Row(
      children: [
        SizedBox(
          width: 76,
          child: DropdownButtonFormField<int>(
            initialValue: entry.floor,
            isExpanded: true,
            decoration: const InputDecoration(
              isDense: true,
              border: OutlineInputBorder(),
            ),
            items: const [1, 2, 3, 4]
                .map(
                  (floor) => DropdownMenuItem<int>(
                    value: floor,
                    child: Text('$floor楼'),
                  ),
                )
                .toList(),
            onChanged: readOnly ? null : (value) => _updateFloor(item.id, index, value ?? 1),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            initialValue: entry.boards == 0 ? '' : '${entry.boards}',
            keyboardType: TextInputType.number,
            enabled: !readOnly,
            decoration: const InputDecoration(
              labelText: '板数',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _updateBoards(item.id, index, int.tryParse(value) ?? 0),
          ),
        ),
        const SizedBox(width: 8),
        Expanded(
          child: TextFormField(
            initialValue: entry.boxes == 0 ? '' : '${entry.boxes}',
            keyboardType: TextInputType.number,
            enabled: !readOnly,
            decoration: const InputDecoration(
              labelText: '箱数',
              isDense: true,
              border: OutlineInputBorder(),
            ),
            onChanged: (value) => _updateBoxes(item.id, index, int.tryParse(value) ?? 0),
          ),
        ),
        IconButton(
          tooltip: '删除',
          onPressed: readOnly ? null : () => _removeStatsEntry(item.id, index),
          icon: const Icon(Icons.delete_outline),
        ),
      ],
    );
  }

  Widget _statusChip(
    StocktakeItemRecord item,
    StocktakeItemStatus target,
    String text,
    bool selected,
  ) {
    return ChoiceChip(
      selected: selected,
      label: Text(text),
      onSelected: (_) => _onStatusSelected(item, target),
    );
  }

  Widget _emptyResultCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        '本月无需要盘点的条目。',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
    );
  }

  Widget _recentCard() {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '盘库历史',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (_recentHistory.isEmpty)
            const Text(
              '暂无记录',
              style: TextStyle(color: AppTheme.textSecondary),
            )
          else
            ..._recentHistory.map(
              (summary) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: InkWell(
                  borderRadius: BorderRadius.circular(12),
                  onTap: () => _openSession(summary.session),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6),
                    child: Row(
                      children: [
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Row(
                                children: [
                                  Text(
                                    _formatShortDate(summary.date),
                                    style: const TextStyle(
                                      color: AppTheme.textPrimary,
                                      fontSize: 16,
                                      fontWeight: FontWeight.w900,
                                    ),
                                  ),
                                  const SizedBox(width: 8),
                                  _statusPill(summary.status),
                                ],
                              ),
                              const SizedBox(height: 4),
                              Text(
                                '${summary.total}项 · ${summary.pending}待盘 · ${summary.checked}已盘 · ${summary.issue}异常',
                                style: const TextStyle(
                                  color: AppTheme.textSecondary,
                                  fontWeight: FontWeight.w700,
                                ),
                              ),
                            ],
                          ),
                        ),
                        IconButton(
                          tooltip: '修改盘库日期',
                          onPressed: () => _editSessionDate(summary.session),
                          icon: const Icon(
                            Icons.edit_calendar_outlined,
                            size: 18,
                            color: AppTheme.primary,
                          ),
                        ),
                        IconButton(
                          tooltip: '删除盘库记录',
                          onPressed: () => _deleteSession(summary.session),
                          icon: const Icon(
                            Icons.delete_outline,
                            size: 18,
                            color: Color(0xFFB91C1C),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _pickMonth() async {
    final selected = await showDatePicker(
      context: context,
      initialDate: _selectedMonth,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '选择盘库月份',
    );
    if (selected == null) return;
    setState(() => _selectedMonth = DateTime(selected.year, selected.month, selected.day));
  }

  Future<void> _createSession() async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final bundle = await _stocktakeDao.createOrLoadSession(month: _selectedMonth);
      if (!mounted) return;
      setState(() {
        _bundle = bundle;
        _statsExpanded.clear();
      });
      _issueShortageBoxes.clear();
      await _hydrateFloorEntries(bundle);
      await _loadRecent();
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('生成失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _reloadBundle() async {
    final current = _bundle;
    if (current == null) return;
    final next = await _stocktakeDao.loadSession(current.session.id);
    if (!mounted) return;
    setState(() => _bundle = next);
    await _hydrateFloorEntries(next);
  }

  Future<void> _editNote(StocktakeItemRecord item) async {
    final controller = TextEditingController(text: item.note ?? '');
    final value = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('备注'),
        content: TextField(
          controller: controller,
          maxLines: 3,
          decoration: const InputDecoration(
            hintText: '写点记录',
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
    if (value == null) return;
    final status = StocktakeItemStatus.values[item.status];
    await _stocktakeDao.updateItem(itemId: item.id, status: status, note: value);
    await _reloadBundle();
  }

  Future<void> _loadRecent() async {
    final recent = await _stocktakeDao.listRecentSessions();
    _LatestSessionSummary? latest;
    final history = <_StocktakeHistorySummary>[];
    if (recent.isNotEmpty) {
      for (final session in recent) {
        final bundle = await _stocktakeDao.loadSession(session.id);
        final statsMap = await _stocktakeDao.loadFloorStatsForSession(session.id);
        final total = bundle.items.length;
        final pending = bundle.items.where((e) => e.status == StocktakeItemStatus.pending.index).length;
        final checked = bundle.items.where((e) => e.status == StocktakeItemStatus.checked.index).length;
        final issue = bundle.items.where((e) => e.status == StocktakeItemStatus.issue.index).length;
        final date = session.completedAt ?? session.createdAt;
        final summary = _StocktakeHistorySummary(
          session: session,
          date: date,
          status: session.status,
          total: total,
          pending: pending,
          checked: checked,
          issue: issue,
        );
        history.add(summary);
        latest ??= _LatestSessionSummary(
          status: session.status,
          date: date,
          issueItems: _latestIssueItems(bundle.items, statsMap),
        );
      }
      history.sort((a, b) => b.date.compareTo(a.date));
    }
    if (!mounted) return;
    setState(() {
      _recentHistory = history;
      _latestSummary = latest;
    });
  }

  Widget _latestSummaryCard() {
    final summary = _latestSummary;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: summary == null
          ? const Text(
              '暂无盘库记录',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            )
          : Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    const Expanded(
                      child: Text(
                        '最近异常',
                        style: TextStyle(
                          color: AppTheme.textPrimary,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ),
                    _statusPill(summary.status),
                  ],
                ),
                const SizedBox(height: 10),
                if (summary.issueItems.isEmpty)
                  Text(
                    '${_formatMonth(summary.date)} · 无异常记录',
                    style: const TextStyle(
                      color: AppTheme.textSecondary,
                      fontWeight: FontWeight.w800,
                    ),
                  )
                else
                  ...summary.issueItems.map(
                    (item) => Padding(
                      padding: const EdgeInsets.only(bottom: 8),
                      child: _issueSummary(item),
                    ),
                  ),
              ],
            ),
    );
  }

  Widget _issueSummary(_LatestIssueItem item) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFFEF2F2),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFFCA5A5)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.error_outline,
            color: Color(0xFFB91C1C),
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '${item.productCode} · ${item.batchCode}',
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w900,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  item.dateBatch,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: const Color(0xFFB91C1C),
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              item.shortageBoxes > 0 ? '缺${item.shortageBoxes}箱' : '未填数量',
              style: const TextStyle(
                color: Colors.white,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _statusPill(int status) {
    final completed = status == StocktakeSessionStatus.completed.index;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: completed ? const Color(0xFFEFF6FF) : const Color(0xFFFFF7ED),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        completed ? '已完成' : '草稿',
        style: TextStyle(
          color: completed ? AppTheme.primary : const Color(0xFFC2410C),
          fontSize: 12,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }

  List<_LatestIssueItem> _latestIssueItems(
    List<StocktakeItemRecord> items,
    Map<int, String> statsMap,
  ) {
    final result = <_LatestIssueItem>[];
    for (final item in items) {
      if (item.status != StocktakeItemStatus.issue.index) {
        continue;
      }
      final stats = _decodePersistedStats(statsMap[item.id] ?? '');
      result.add(
        _LatestIssueItem(
          productCode: item.productCode,
          batchCode: item.batchCode,
          dateBatch: item.dateBatch,
          shortageBoxes: stats.issueShortageBoxes,
        ),
      );
    }
    return result;
  }

  Future<void> _openSession(StocktakeSessionRecord session) async {
    final messenger = ScaffoldMessenger.of(context);
    setState(() => _loading = true);
    try {
      final bundle = await _stocktakeDao.loadSession(session.id);
      if (!mounted) return;
      final monthParts = session.monthKey.split('-');
      DateTime nextMonth = _selectedMonth;
      if (monthParts.length == 2) {
        final year = int.tryParse(monthParts[0]);
        final month = int.tryParse(monthParts[1]);
        if (year != null && month != null && month >= 1 && month <= 12) {
          nextMonth = DateTime(year, month);
        }
      }
      setState(() {
        _bundle = bundle;
        _selectedMonth = nextMonth;
        _statsExpanded.clear();
      });
      _issueShortageBoxes.clear();
      await _hydrateFloorEntries(bundle);
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('加载失败：$error')),
      );
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _deleteSession(StocktakeSessionRecord session) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除盘库记录'),
        content: Text('确认删除 ${session.monthKey} 记录？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _stocktakeDao.deleteSession(session.id);
    if (!mounted) return;
    if (_bundle?.session.id == session.id) {
      setState(() => _bundle = null);
    }
    await _loadRecent();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除盘库记录')),
    );
  }

  Future<void> _editSessionDate(StocktakeSessionRecord session) async {
    final initial = session.completedAt ?? session.createdAt;
    final selected = await showDatePicker(
      context: context,
      initialDate: initial,
      firstDate: DateTime(2020, 1, 1),
      lastDate: DateTime.now().add(const Duration(days: 365)),
      helpText: '修改盘库日期',
    );
    if (selected == null) return;
    await _stocktakeDao.updateSessionDate(
      sessionId: session.id,
      date: selected,
    );
    if (!mounted) return;
    await _loadRecent();
    if (!mounted) return;
    if (_bundle?.session.id == session.id) {
      await _reloadBundle();
    }
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('盘库日期已更新')),
    );
  }

  Future<void> _onAddProductPressed() async {
    final current = _bundle;
    if (current == null) return;
    final messenger = ScaffoldMessenger.of(context);
    try {
      final candidates = await _stocktakeDao.listCandidateBatches();
      if (!mounted) return;
      if (candidates.isEmpty) {
        messenger.showSnackBar(
          const SnackBar(content: Text('基础资料中没有可加入的在库批号')),
        );
        return;
      }
      final selectedBatchId = await _showAddProductDialog(candidates);
      if (selectedBatchId == null) return;
      final inserted = await _stocktakeDao.addItemToSession(
        sessionId: current.session.id,
        batchId: selectedBatchId,
      );
      if (!mounted) return;
      await _reloadBundle();
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text(inserted ? '已新增产品到盘库清单' : '该批号已在盘库清单中')),
      );
    } catch (error) {
      if (!mounted) return;
      messenger.showSnackBar(
        SnackBar(content: Text('新增失败：$error')),
      );
    }
  }

  Future<int?> _showAddProductDialog(List<StocktakeCandidateBatch> candidates) {
    final products = <_ProductOption>[];
    final byProduct = <int, List<StocktakeCandidateBatch>>{};
    for (final row in candidates) {
      byProduct.putIfAbsent(row.productId, () => <StocktakeCandidateBatch>[]).add(row);
    }
    byProduct.forEach((productId, rows) {
      rows.sort((a, b) {
        final byDate = _compareDateBatch(a.dateBatch, b.dateBatch);
        if (byDate != 0) return byDate;
        return a.batchCode.compareTo(b.batchCode);
      });
      final first = rows.first;
      products.add(
        _ProductOption(
          productId: productId,
          label: '${first.productCode} · ${first.productName}',
        ),
      );
    });
    products.sort((a, b) => a.label.compareTo(b.label));
    int selectedProductId = products.first.productId;
    int selectedBatchId = byProduct[selectedProductId]!.first.batchId;

    return showDialog<int>(
      context: context,
      builder: (context) => StatefulBuilder(
        builder: (context, setLocalState) {
          final batchOptions = byProduct[selectedProductId] ?? const <StocktakeCandidateBatch>[];
          if (batchOptions.where((e) => e.batchId == selectedBatchId).isEmpty && batchOptions.isNotEmpty) {
            selectedBatchId = batchOptions.first.batchId;
          }
          return AlertDialog(
            title: const Text('新增产品'),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                DropdownButtonFormField<int>(
                  initialValue: selectedProductId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '选择产品',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: products
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item.productId,
                          child: Text(item.label),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setLocalState(() {
                      selectedProductId = value;
                      final nextBatches = byProduct[selectedProductId] ?? const <StocktakeCandidateBatch>[];
                      if (nextBatches.isNotEmpty) {
                        selectedBatchId = nextBatches.first.batchId;
                      }
                    });
                  },
                ),
                const SizedBox(height: 12),
                DropdownButtonFormField<int>(
                  initialValue: selectedBatchId,
                  isExpanded: true,
                  decoration: const InputDecoration(
                    labelText: '选择批号（随产品自动切换）',
                    isDense: true,
                    border: OutlineInputBorder(),
                  ),
                  items: batchOptions
                      .map(
                        (item) => DropdownMenuItem<int>(
                          value: item.batchId,
                          child: Text(
                            '${item.batchCode} · ${item.dateBatch} · 当前${item.currentBoxes}箱',
                            overflow: TextOverflow.ellipsis,
                          ),
                        ),
                      )
                      .toList(),
                  onChanged: (value) {
                    if (value == null) return;
                    setLocalState(() => selectedBatchId = value);
                  },
                ),
              ],
            ),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('取消'),
              ),
              FilledButton(
                onPressed: () => Navigator.of(context).pop(selectedBatchId),
                child: const Text('加入清单'),
              ),
            ],
          );
        },
      ),
    );
  }

  void _toggleStats(int itemId) {
    setState(() {
      _statsExpanded[itemId] = !(_statsExpanded[itemId] ?? false);
      _floorEntries.putIfAbsent(itemId, () => <_FloorCountEntry>[const _FloorCountEntry()]);
    });
  }

  void _addStatsEntry(int itemId) {
    setState(() {
      final current = List<_FloorCountEntry>.from(_floorEntries[itemId] ?? const <_FloorCountEntry>[]);
      current.add(const _FloorCountEntry());
      _floorEntries[itemId] = current;
    });
    _persistFloorEntries(itemId);
  }

  void _removeStatsEntry(int itemId, int index) {
    setState(() {
      final current = List<_FloorCountEntry>.from(_floorEntries[itemId] ?? const <_FloorCountEntry>[]);
      if (index < 0 || index >= current.length) return;
      current.removeAt(index);
      if (current.isEmpty) {
        current.add(const _FloorCountEntry());
      }
      _floorEntries[itemId] = current;
    });
    _persistFloorEntries(itemId);
  }

  void _updateFloor(int itemId, int index, int floor) {
    setState(() {
      _updateEntry(itemId, index, (old) => old.copyWith(floor: floor));
    });
    _persistFloorEntries(itemId);
  }

  void _updateBoards(int itemId, int index, int boards) {
    setState(() {
      _updateEntry(itemId, index, (old) => old.copyWith(boards: boards < 0 ? 0 : boards));
    });
    _persistFloorEntries(itemId);
  }

  void _updateBoxes(int itemId, int index, int boxes) {
    setState(() {
      _updateEntry(itemId, index, (old) => old.copyWith(boxes: boxes < 0 ? 0 : boxes));
    });
    _persistFloorEntries(itemId);
  }

  void _updateEntry(int itemId, int index, _FloorCountEntry Function(_FloorCountEntry) updater) {
    final current = List<_FloorCountEntry>.from(_floorEntries[itemId] ?? const <_FloorCountEntry>[]);
    if (index < 0 || index >= current.length) return;
    current[index] = updater(current[index]);
    _floorEntries[itemId] = current;
  }

  int _countedBoxes(StocktakeItemRecord item) {
    final entries = _floorEntries[item.id] ?? const <_FloorCountEntry>[];
    return entries.fold<int>(
      0,
      (sum, entry) => sum + _toBoxes(entry, item.boxesPerBoard),
    );
  }

  Map<int, Set<int>> _buildBatchDiffIndexMap(List<StocktakeItemRecord> items) {
    final grouped = <String, List<StocktakeItemRecord>>{};
    for (final item in items) {
      final key = '${item.productCode}@@${item.dateBatch}';
      grouped.putIfAbsent(key, () => <StocktakeItemRecord>[]).add(item);
    }
    final result = <int, Set<int>>{};
    for (final group in grouped.values) {
      if (group.length <= 1) {
        for (final item in group) {
          result[item.id] = const <int>{};
        }
        continue;
      }
      final maxLen = group
          .map((item) => item.batchCode.length)
          .fold<int>(0, (a, b) => a > b ? a : b);
      final diffIndexes = <int>{};
      for (var i = 0; i < maxLen; i += 1) {
        String? first;
        var mismatch = false;
        for (final item in group) {
          final char = i < item.batchCode.length ? item.batchCode[i] : '';
          if (first == null) {
            first = char;
            continue;
          }
          if (char != first) {
            mismatch = true;
            break;
          }
        }
        if (mismatch) {
          diffIndexes.add(i);
        }
      }
      for (final item in group) {
        result[item.id] = diffIndexes;
      }
    }
    return result;
  }

  List<TextSpan> _batchCodeSpans(
    String batchCode,
    Set<int> diffIndexes, {
    required Color baseColor,
  }) {
    final spans = <TextSpan>[];
    for (var i = 0; i < batchCode.length; i += 1) {
      final highlight = diffIndexes.contains(i);
      spans.add(
        TextSpan(
          text: batchCode[i],
          style: highlight
              ? const TextStyle(
                  color: Color(0xFFDC2626),
                  fontWeight: FontWeight.w900,
                )
              : TextStyle(color: baseColor),
        ),
      );
    }
    return spans;
  }

  Future<void> _deleteItem(StocktakeItemRecord item) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除条目'),
        content: Text('确认删除 ${item.productCode} · ${item.batchCode} 吗？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (ok != true) return;
    await _stocktakeDao.deleteItem(item.id);
    _floorEntries.remove(item.id);
    _statsExpanded.remove(item.id);
    _issueShortageBoxes.remove(item.id);
    await _reloadBundle();
    if (!mounted) return;
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('已删除条目')),
    );
  }

  Future<void> _hydrateFloorEntries(StocktakeSessionBundle bundle) async {
    final statsMap = await _stocktakeDao.loadFloorStatsForSession(bundle.session.id);
    if (!mounted) return;
    final next = <int, List<_FloorCountEntry>>{};
    final shortage = <int, int>{};
    for (final item in bundle.items) {
      final json = statsMap[item.id];
      if (json == null || json.trim().isEmpty) {
        continue;
      }
      final parsed = _decodePersistedStats(json);
      if (parsed.entries.isNotEmpty) {
        next[item.id] = parsed.entries;
        if (parsed.issueShortageBoxes > 0) {
          shortage[item.id] = parsed.issueShortageBoxes;
        }
      }
    }
    setState(() {
      _floorEntries
        ..clear()
        ..addAll(next);
      _issueShortageBoxes
        ..clear()
        ..addAll(shortage);
    });
  }

  _PersistedStats _decodePersistedStats(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is List) {
        final entries = _decodeEntriesFromList(decoded);
        return _PersistedStats(entries: entries, issueShortageBoxes: 0);
      }
      if (decoded is! Map) {
        return const _PersistedStats(entries: <_FloorCountEntry>[], issueShortageBoxes: 0);
      }
      final entriesRaw = decoded['entries'];
      final entries = entriesRaw is List ? _decodeEntriesFromList(entriesRaw) : const <_FloorCountEntry>[];
      final shortage = _toInt(decoded['issueShortageBoxes']) ?? 0;
      return _PersistedStats(
        entries: entries,
        issueShortageBoxes: shortage < 0 ? 0 : shortage,
      );
    } catch (_) {
      return const _PersistedStats(entries: <_FloorCountEntry>[], issueShortageBoxes: 0);
    }
  }

  List<_FloorCountEntry> _decodeEntriesFromList(List<dynamic> list) {
    final result = <_FloorCountEntry>[];
    for (final row in list) {
      if (row is! Map) continue;
      final floor = _toInt(row['floor']) ?? 1;
      final boards = (_toInt(row['boards']) ?? 0).clamp(0, 1000000000);
      final boxes = (_toInt(row['boxes']) ?? 0).clamp(0, 1000000000);
      result.add(
        _FloorCountEntry(
          floor: floor < 1 || floor > 4 ? 1 : floor,
          boards: boards,
          boxes: boxes,
        ),
      );
    }
    return result;
  }
  int? _toInt(Object? value) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    if (value is String) return int.tryParse(value);
    return null;
  }

  void _persistFloorEntries(int itemId) {
    final entries = _floorEntries[itemId] ?? const <_FloorCountEntry>[];
    final payload = _encodeItemStats(itemId, entries);
    unawaited(
      _stocktakeDao.saveFloorStats(itemId: itemId, statsJson: payload),
    );
  }

  String _encodeItemStats(int itemId, List<_FloorCountEntry> entries) {
    final rows = entries
        .map(
          (entry) => <String, int>{
            'floor': entry.floor,
            'boards': entry.boards,
            'boxes': entry.boxes,
          },
        )
        .toList();
    return jsonEncode(
      <String, Object>{
        'entries': rows,
        'issueShortageBoxes': _issueShortageBoxes[itemId] ?? 0,
      },
    );
  }

  Future<void> _onStatusSelected(StocktakeItemRecord item, StocktakeItemStatus target) async {
    if (target == StocktakeItemStatus.issue) {
      final shortage = await _askIssueShortage(item.id);
      if (shortage == null) return;
      _issueShortageBoxes[item.id] = shortage;
      _persistFloorEntries(item.id);
    }
    await _stocktakeDao.updateItem(itemId: item.id, status: target, note: item.note);
    await _reloadBundle();
  }

  Future<int?> _askIssueShortage(int itemId) async {
    final controller = TextEditingController(
      text: (_issueShortageBoxes[itemId] ?? 0) > 0 ? '${_issueShortageBoxes[itemId]}' : '',
    );
    final value = await showDialog<int>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('异常数量'),
        content: TextField(
          controller: controller,
          keyboardType: TextInputType.number,
          decoration: const InputDecoration(
            hintText: '缺几箱',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () {
              final parsed = int.tryParse(controller.text.trim());
              if (parsed == null || parsed <= 0) {
                ScaffoldMessenger.of(context).showSnackBar(
                  const SnackBar(content: Text('请输入大于0的箱数')),
                );
                return;
              }
              Navigator.of(context).pop(parsed);
            },
            child: const Text('保存'),
          ),
        ],
      ),
    );
    return value;
  }
}

int _toBoxes(_FloorCountEntry entry, int boxesPerBoard) {
  final boardUnit = boxesPerBoard <= 0 ? 1 : boxesPerBoard;
  return (entry.boards * boardUnit) + entry.boxes;
}

class _FloorCountEntry {
  const _FloorCountEntry({
    this.floor = 1,
    this.boards = 0,
    this.boxes = 0,
  });

  final int floor;
  final int boards;
  final int boxes;

  _FloorCountEntry copyWith({
    int? floor,
    int? boards,
    int? boxes,
  }) {
    return _FloorCountEntry(
      floor: floor ?? this.floor,
      boards: boards ?? this.boards,
      boxes: boxes ?? this.boxes,
    );
  }
}

class _ProductOption {
  const _ProductOption({
    required this.productId,
    required this.label,
  });

  final int productId;
  final String label;
}

class _LatestSessionSummary {
  const _LatestSessionSummary({
    required this.status,
    required this.date,
    required this.issueItems,
  });

  final int status;
  final DateTime date;
  final List<_LatestIssueItem> issueItems;
}

class _StocktakeHistorySummary {
  const _StocktakeHistorySummary({
    required this.session,
    required this.date,
    required this.status,
    required this.total,
    required this.pending,
    required this.checked,
    required this.issue,
  });

  final StocktakeSessionRecord session;
  final DateTime date;
  final int status;
  final int total;
  final int pending;
  final int checked;
  final int issue;
}

class _LatestIssueItem {
  const _LatestIssueItem({
    required this.productCode,
    required this.batchCode,
    required this.dateBatch,
    required this.shortageBoxes,
  });

  final String productCode;
  final String batchCode;
  final String dateBatch;
  final int shortageBoxes;
}

class _PersistedStats {
  const _PersistedStats({
    required this.entries,
    required this.issueShortageBoxes,
  });

  final List<_FloorCountEntry> entries;
  final int issueShortageBoxes;
}

int _compareDateBatch(String left, String right) {
  final l = _parseDateBatch(left);
  final r = _parseDateBatch(right);
  if (l != null && r != null) {
    return l.compareTo(r);
  }
  if (l != null) return -1;
  if (r != null) return 1;
  return left.compareTo(right);
}

DateTime? _parseDateBatch(String value) {
  final parts = value.split('.');
  if (parts.length != 3) return null;
  final year = int.tryParse(parts[0]);
  final month = int.tryParse(parts[1]);
  final day = int.tryParse(parts[2]);
  if (year == null || month == null || day == null) return null;
  if (month < 1 || month > 12 || day < 1 || day > 31) return null;
  return DateTime(year, month, day);
}

String _formatMonth(DateTime month) {
  return '${month.year}年${month.month}月${month.day}日';
}

String _formatShortDate(DateTime date) {
  return '${date.year}年${date.month}月${date.day}日';
}

DateTime _defaultMonth() => DateTime.now();

String _formatBoard(int boxes, int boxesPerBoard) {
  if (boxesPerBoard <= 0) {
    return '$boxes箱';
  }
  final board = boxes ~/ boxesPerBoard;
  final remain = boxes % boxesPerBoard;
  if (board <= 0) {
    return '$boxes箱';
  }
  if (remain == 0) {
    return '$board板';
  }
  return '$board板+$remain箱';
}

String _formatBoardSigned(int boxes, int boxesPerBoard) {
  if (boxes == 0) {
    return '0箱';
  }
  final isNegative = boxes < 0;
  final content = _formatBoard(boxes.abs(), boxesPerBoard);
  return isNegative ? '-$content' : content;
}

String _remainingLabel(int remainingBoxes) {
  if (remainingBoxes > 0) {
    return '还需盘';
  }
  if (remainingBoxes < 0) {
    return '超盘';
  }
  return '盘平';
}

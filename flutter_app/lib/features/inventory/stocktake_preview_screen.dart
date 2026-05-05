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
  List<StocktakeSessionRecord> _recentSessions = const [];
  bool _loading = false;
  final Map<int, bool> _statsExpanded = <int, bool>{};
  final Map<int, List<_FloorCountEntry>> _floorEntries = <int, List<_FloorCountEntry>>{};

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
            _monthBar(),
            const SizedBox(height: 10),
            _statsCard(total: items.length, pending: pending, checked: checked, issue: issue),
            const SizedBox(height: 10),
            if (bundle == null)
              _emptyCard()
            else if (items.isEmpty)
              _emptyResultCard()
            else
              ...items.map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: _itemCard(item, readOnly: isCompleted),
                ),
              ),
            const SizedBox(height: 12),
            FilledButton.icon(
              onPressed: bundle == null || _loading || isCompleted
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
      child: Row(
        children: [
          Expanded(
            child: Text(
              _formatMonth(_selectedMonth),
              style: const TextStyle(
                fontSize: 20,
                fontWeight: FontWeight.w900,
                color: AppTheme.textPrimary,
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

  Widget _itemCard(StocktakeItemRecord item, {required bool readOnly}) {
    final status = StocktakeItemStatus.values[item.status];
    final boardText = _formatBoard(item.currentBoxes, item.boxesPerBoard);
    final countedBoxes = _countedBoxes(item);
    final remainingBoxes = item.currentBoxes - countedBoxes;
    final entries = _floorEntries[item.id] ?? const <_FloorCountEntry>[];
    final countedText = _formatBoard(countedBoxes, item.boxesPerBoard);
    final remainText = _formatBoardSigned(remainingBoxes, item.boxesPerBoard);
    final isExpanded = _statsExpanded[item.id] ?? false;
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '${item.productCode} · ${item.batchCode} · ${item.dateBatch}',
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
              fontSize: 15,
            ),
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
            style: const TextStyle(
              color: Color(0xFFB91C1C),
              fontWeight: FontWeight.w800,
            ),
          ),
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
      onSelected: (_) async {
        await _stocktakeDao.updateItem(itemId: item.id, status: target, note: item.note);
        await _reloadBundle();
      },
    );
  }

  Widget _emptyCard() {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
      ),
      child: const Text(
        '先选择月份，再点“生成清单”。',
        style: TextStyle(
          color: AppTheme.textSecondary,
          fontWeight: FontWeight.w700,
        ),
      ),
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
            '最近盘库',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 8),
          if (_recentSessions.isEmpty)
            const Text(
              '暂无记录',
              style: TextStyle(color: AppTheme.textSecondary),
            )
          else
            ..._recentSessions.map(
              (session) => Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${session.monthKey} · ${session.status == StocktakeSessionStatus.completed.index ? '已完成' : '草稿'}',
                        style: const TextStyle(
                          color: AppTheme.textSecondary,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ),
                    IconButton(
                      tooltip: '删除盘库记录',
                      onPressed: () => _deleteSession(session),
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
          const SizedBox(height: 4),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: _recentSessions
                .map(
                  (session) => ActionChip(
                    label: Text(
                      '${session.monthKey} ${session.status == StocktakeSessionStatus.completed.index ? '已完成' : '草稿'}',
                    ),
                    onPressed: () => _openSession(session),
                  ),
                )
                .toList(),
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
    setState(() => _selectedMonth = DateTime(selected.year, selected.month));
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
        _floorEntries.clear();
      });
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
    if (!mounted) return;
    setState(() => _recentSessions = recent);
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
        _floorEntries.clear();
      });
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
  }

  void _updateFloor(int itemId, int index, int floor) {
    setState(() {
      _updateEntry(itemId, index, (old) => old.copyWith(floor: floor));
    });
  }

  void _updateBoards(int itemId, int index, int boards) {
    setState(() {
      _updateEntry(itemId, index, (old) => old.copyWith(boards: boards < 0 ? 0 : boards));
    });
  }

  void _updateBoxes(int itemId, int index, int boxes) {
    setState(() {
      _updateEntry(itemId, index, (old) => old.copyWith(boxes: boxes < 0 ? 0 : boxes));
    });
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

String _formatMonth(DateTime month) {
  return '${month.year}年${month.month}月';
}

DateTime _defaultMonth() {
  final now = DateTime.now();
  final current = DateTime(now.year, now.month);
  return DateTime(current.year, current.month - 1);
}

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

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
            '当前库存 $boardText',
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
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
            ],
          ),
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
                child: Text(
                  '${session.monthKey} · ${session.status == StocktakeSessionStatus.completed.index ? '已完成' : '草稿'}',
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontWeight: FontWeight.w700,
                  ),
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
    setState(() => _loading = true);
    final bundle = await _stocktakeDao.createOrLoadSession(month: _selectedMonth);
    if (!mounted) return;
    setState(() {
      _bundle = bundle;
      _loading = false;
    });
    await _loadRecent();
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
    setState(() => _loading = true);
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
      _loading = false;
    });
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
    return '$remain箱';
  }
  if (remain == 0) {
    return '$board板';
  }
  return '$board板+$remain箱';
}

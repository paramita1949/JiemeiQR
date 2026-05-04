import 'package:flutter/material.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class StocktakePreviewScreen extends StatelessWidget {
  const StocktakePreviewScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 42),
          children: const [
            PageTitle(
              icon: Icons.fact_check_outlined,
              title: '盘库任务',
              subtitle: '仅记录盘点笔记，不修改真实库存',
            ),
            SizedBox(height: 14),
            _MonthCard(),
            SizedBox(height: 10),
            _RuleCard(),
            SizedBox(height: 10),
            _ProgressCard(),
            SizedBox(height: 10),
            _ProductChecklistCard(),
            SizedBox(height: 10),
            _ConfirmCard(),
          ],
        ),
      ),
    );
  }
}

class _MonthCard extends StatelessWidget {
  const _MonthCard();

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFF1D4ED8), Color(0xFF2563EB)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        ),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '盘库月份',
            style: TextStyle(
              color: Color(0xFFDBEAFE),
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '2026 年 4 月',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              OutlinedButton.icon(
                onPressed: null,
                icon: const Icon(Icons.calendar_month_outlined),
                label: const Text('切换月份'),
                style: OutlinedButton.styleFrom(
                  foregroundColor: Colors.white,
                  side: const BorderSide(color: Color(0xFFBFDBFE)),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          const Text(
            '建议：每月 1-5 日盘点上月库存',
            style: TextStyle(
              color: Color(0xFFEFF6FF),
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _RuleCard extends StatelessWidget {
  const _RuleCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: '自动提炼规则',
      child: Column(
        children: const [
          _RuleRow(label: '发过货', value: '是'),
          _RuleRow(label: '当前库存', value: '不为 0'),
          _RuleRow(label: '库存有变化', value: '当前 ≠ 初始'),
          _RuleRow(label: '预计待盘条目', value: '14 条'),
        ],
      ),
    );
  }
}

class _ProgressCard extends StatelessWidget {
  const _ProgressCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: '盘点进度',
      trailing: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
        decoration: BoxDecoration(
          color: const Color(0xFFEFF6FF),
          borderRadius: BorderRadius.circular(999),
        ),
        child: const Text(
          '5 / 14',
          style: TextStyle(
            color: AppTheme.primary,
            fontWeight: FontWeight.w800,
          ),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          ClipRRect(
            borderRadius: BorderRadius.circular(999),
            child: const LinearProgressIndicator(
              value: 0.36,
              minHeight: 10,
              backgroundColor: Color(0xFFE5E7EB),
              color: Color(0xFF2563EB),
            ),
          ),
          const SizedBox(height: 8),
          const Text(
            '已核对 4 条 · 异常 1 条 · 待复核 9 条',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductChecklistCard extends StatelessWidget {
  const _ProductChecklistCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: '产品盘点清单（预览）',
      child: Column(
        children: const [
          _ProductRow(
            productCode: '72067',
            batchCode: 'FCHBMHEZ',
            delta: '-20 箱',
            status: '已核对',
            color: Color(0xFF166534),
            background: Color(0xFFDCFCE7),
          ),
          SizedBox(height: 8),
          _ProductRow(
            productCode: '20380',
            batchCode: 'ELMAXEZ',
            delta: '-50 箱',
            status: '异常',
            color: Color(0xFFB91C1C),
            background: Color(0xFFFEE2E2),
          ),
          SizedBox(height: 8),
          _ProductRow(
            productCode: '20148',
            batchCode: 'FBAADEZ',
            delta: '-10 箱',
            status: '待复核',
            color: Color(0xFF92400E),
            background: Color(0xFFFFF7ED),
          ),
        ],
      ),
    );
  }
}

class _ConfirmCard extends StatelessWidget {
  const _ConfirmCard();

  @override
  Widget build(BuildContext context) {
    return _CardShell(
      title: '盘后确认',
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: double.infinity,
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: const Color(0xFFE2E8F0)),
            ),
            child: const Text(
              '本页为 UI 预览：确认后只生成盘库笔记，不修改库存。',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.save_alt_outlined),
                  label: const Text('保存草稿'),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: FilledButton.icon(
                  onPressed: null,
                  icon: const Icon(Icons.task_alt),
                  label: const Text('确认完成'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

class _CardShell extends StatelessWidget {
  const _CardShell({
    required this.title,
    required this.child,
    this.trailing,
  });

  final String title;
  final Widget child;
  final Widget? trailing;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              if (trailing != null) trailing!,
            ],
          ),
          const SizedBox(height: 10),
          child,
        ],
      ),
    );
  }
}

class _RuleRow extends StatelessWidget {
  const _RuleRow({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 5),
      child: Row(
        children: [
          Expanded(
            child: Text(
              label,
              style: const TextStyle(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _ProductRow extends StatelessWidget {
  const _ProductRow({
    required this.productCode,
    required this.batchCode,
    required this.delta,
    required this.status,
    required this.color,
    required this.background,
  });

  final String productCode;
  final String batchCode;
  final String delta;
  final String status;
  final Color color;
  final Color background;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(10),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: const Color(0xFFE2E8F0)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              '$productCode · $batchCode · 变化 $delta',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.w800,
              ),
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(999),
            ),
            child: Text(
              status,
              style: TextStyle(
                color: color,
                fontWeight: FontWeight.w900,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

import 'dart:async';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/base_info/base_info_edit_screen.dart';
import 'package:qrscan_flutter/features/calendar/outbound_calendar_screen.dart';
import 'package:qrscan_flutter/features/inventory/inventory_detail_screen.dart';
import 'package:qrscan_flutter/features/orders/order_list_screen.dart';
import 'package:qrscan_flutter/features/orders/ocr/ai_config_screen.dart';
import 'package:qrscan_flutter/features/qr/qr_entry_screen.dart';
import 'package:qrscan_flutter/features/transfer/lan_transfer_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/utils/navigation_refresh.dart';
import 'package:qrscan_flutter/shared/widgets/action_card.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.database,
    this.refreshToken = 0,
    this.onPrepareImport,
    this.onImportCompleted,
  });

  final AppDatabase? database;
  final int refreshToken;
  final Future<void> Function()? onPrepareImport;
  final DatabaseReloadCallback? onImportCompleted;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late AppDatabase _database;
  late bool _ownsDatabase;
  _HomeStats? _stats;
  bool _loadingStats = true;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    unawaited(_refreshStats());
  }

  @override
  void didUpdateWidget(covariant HomeScreen oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.database != widget.database) {
      if (_ownsDatabase) {
        unawaited(_database.close());
      }
      _ownsDatabase = widget.database == null;
      _database = widget.database ?? AppDatabase();
      setState(() => _loadingStats = true);
      unawaited(_refreshStats());
      return;
    }
    if (oldWidget.refreshToken != widget.refreshToken) {
      unawaited(_refreshStats());
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    if (_ownsDatabase) {
      _database.close();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshStats());
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: RefreshIndicator(
          onRefresh: _refreshStats,
          child: ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.all(18),
            children: [
              const PageTitle(
                icon: Icons.warehouse_outlined,
                title: '洁美',
                subtitle: '浙江仓订单与库存工作台',
              ),
              const SizedBox(height: 10),
              _InventoryStatsSection(
                stats: _stats,
                loading: _loadingStats,
              ),
              const SizedBox(height: 10),
              Text(
                '常用功能',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              const SizedBox(height: 9),
              _ActionGrid(
                onOpenAction: (title) => _openHomeAction(context, title),
              ),
              const SizedBox(height: 8),
            ],
          ),
        ),
      ),
    );
  }

  Future<void> _openHomeAction(BuildContext context, String title) async {
    if (title == 'QR箱码') {
      await pushAndRefresh(
        context,
        route: MaterialPageRoute(builder: (_) => const QrEntryScreen()),
        onRefresh: () => unawaited(_refreshStats()),
      );
      return;
    }
    if (title == '基础资料') {
      await pushAndRefresh(
        context,
        route: MaterialPageRoute(
          builder: (_) => BaseInfoEditScreen(database: database),
        ),
        onRefresh: () => unawaited(_refreshStats()),
      );
      return;
    }
    if (title == '库存明细') {
      await pushAndRefresh(
        context,
        route: MaterialPageRoute(
          builder: (_) => InventoryDetailScreen(database: database),
        ),
        onRefresh: () => unawaited(_refreshStats()),
      );
      return;
    }
    if (title == '订单信息') {
      await pushAndRefresh(
        context,
        route: MaterialPageRoute(
          builder: (_) => OrderListScreen(database: database),
        ),
        onRefresh: () => unawaited(_refreshStats()),
      );
      return;
    }
    if (title == '出库日历') {
      await pushAndRefresh(
        context,
        route: MaterialPageRoute(
          builder: (_) => OutboundCalendarScreen(database: database),
        ),
        onRefresh: () => unawaited(_refreshStats()),
      );
      return;
    }
    if (title == '数据备份') {
      await pushAndRefresh(
        context,
        route: MaterialPageRoute(
          builder: (_) => LanTransferScreen(
            onPrepareImport: widget.onPrepareImport,
            onImportCompleted: widget.onImportCompleted,
          ),
        ),
        onRefresh: () => unawaited(_refreshStats()),
      );
      return;
    }
    if (title == 'AI配置') {
      await pushAndRefresh(
        context,
        route: MaterialPageRoute(
          builder: (_) => const AiConfigScreen(),
        ),
        onRefresh: () => unawaited(_refreshStats()),
      );
      return;
    }
  }

  AppDatabase get database => _database;

  Future<_HomeStats> _loadStats() async {
    final stockDao = StockDao(_database);
    final totalPieces = await stockDao.totalInventoryPieces();
    final projectedPieces = await stockDao.projectedInventoryPieces();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final yesterday = todayStart.subtract(const Duration(days: 1));
    final yesterdayStart =
        DateTime(yesterday.year, yesterday.month, yesterday.day);
    final yesterdayEnd =
        DateTime(yesterday.year, yesterday.month, yesterday.day, 23, 59, 59);
    final countsRow = await _database.customSelect(
      '''
      SELECT
        SUM(CASE WHEN status != ? THEN 1 ELSE 0 END) AS pending_count,
        SUM(CASE WHEN order_date BETWEEN ? AND ? THEN 1 ELSE 0 END) AS today_count,
        SUM(CASE WHEN order_date BETWEEN ? AND ? THEN 1 ELSE 0 END) AS yesterday_count
      FROM orders
      ''',
      variables: [
        Variable.withInt(OrderStatus.done.index),
        Variable.withDateTime(todayStart),
        Variable.withDateTime(todayEnd),
        Variable.withDateTime(yesterdayStart),
        Variable.withDateTime(yesterdayEnd),
      ],
    ).getSingleOrNull();
    final countsData = countsRow?.data ?? const <String, Object?>{};
    final pendingOrders = (countsData['pending_count'] as int?) ?? 0;
    final todayOrders = (countsData['today_count'] as int?) ?? 0;
    final yesterdayOrders = (countsData['yesterday_count'] as int?) ?? 0;
    final outboundRow = await _database.customSelect(
      '''
      SELECT COALESCE(SUM(boxes), 0) AS outbound_boxes
      FROM stock_movements
      WHERE type = ?
        AND movement_date BETWEEN ? AND ?
      ''',
      variables: [
        Variable.withInt(StockMovementType.orderOut.index),
        Variable.withDateTime(todayStart),
        Variable.withDateTime(todayEnd),
      ],
    ).getSingleOrNull();
    final outboundBoxes = (outboundRow?.data['outbound_boxes'] as int?) ?? 0;

    return _HomeStats(
      totalPieces: totalPieces,
      projectedPieces: projectedPieces,
      todayOrders: todayOrders,
      yesterdayOrders: yesterdayOrders,
      pendingOrders: pendingOrders,
      outboundBoxes: outboundBoxes,
    );
  }

  Future<void> _refreshStats() async {
    try {
      final stats = await _loadStats();
      if (!mounted) {
        return;
      }
      setState(() {
        _stats = stats;
        _loadingStats = false;
      });
    } catch (error) {
      debugPrint('home refresh failed: $error');
      if (!mounted) {
        return;
      }
      setState(() {
        _loadingStats = false;
      });
    }
  }
}

class _InventoryStatsSection extends StatelessWidget {
  const _InventoryStatsSection({
    required this.stats,
    required this.loading,
  });

  final _HomeStats? stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    final totalText = stats == null ? '--' : _formatNumber(stats!.totalPieces);
    final projectedText =
        stats == null ? '--' : _formatNumber(stats!.projectedPieces);
    final todayText = loading || stats == null ? '--' : '${stats!.todayOrders}';
    final yesterdayText =
        loading || stats == null ? '--' : '${stats!.yesterdayOrders}';
    final pendingText =
        loading || stats == null ? '--' : '${stats!.pendingOrders}';
    final outboundText = loading || stats == null || stats!.outboundBoxes == 0
        ? null
        : '库存变化 -${stats!.outboundBoxes}箱';

    return Column(
      children: [
        Row(
          children: [
            Expanded(
              child: _InventoryStatCard(
                title: '实时库存',
                value: totalText,
                icon: Icons.inventory_2_outlined,
                titleColor: const Color(0xFFEAF1FF),
                valueColor: Colors.white,
                backgroundColor: const Color(0xFF1D68F2),
              ),
            ),
            const SizedBox(width: 8),
            Expanded(
              child: _InventoryStatCard(
                title: '在途货物',
                value: projectedText,
                icon: Icons.local_shipping_outlined,
                titleColor: const Color(0xFF7C2D12),
                valueColor: const Color(0xFF7C2D12),
                backgroundColor: const Color(0xFFF7C488),
                subValue: outboundText,
                subValueColor: const Color(0xFFA04018),
              ),
            ),
          ],
        ),
        const SizedBox(height: 8),
        Container(
          width: double.infinity,
          height: 60,
          padding: const EdgeInsets.all(6),
          decoration: BoxDecoration(
            color: Colors.white,
            borderRadius: BorderRadius.circular(10),
            border: Border.all(color: const Color(0xFFE2E8F0)),
          ),
          child: Row(
            children: [
              Expanded(
                child: _OrderCountChip(
                  label: '今日订单',
                  value: '$todayText 单',
                  valueColor: AppTheme.primary,
                  backgroundColor: const Color(0xFFEEF4FF),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OrderCountChip(
                  label: '昨日订单',
                  value: '$yesterdayText 单',
                  valueColor: AppTheme.textPrimary,
                  backgroundColor: const Color(0xFFF8FAFC),
                ),
              ),
              const SizedBox(width: 8),
              Expanded(
                child: _OrderCountChip(
                  label: '未完成',
                  value: '$pendingText 单',
                  valueColor: const Color(0xFFEA580C),
                  labelColor: const Color(0xFF9A3412),
                  backgroundColor: const Color(0xFFFFF7ED),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _InventoryStatCard extends StatelessWidget {
  const _InventoryStatCard({
    required this.title,
    required this.value,
    required this.icon,
    required this.titleColor,
    required this.valueColor,
    required this.backgroundColor,
    this.subValue,
    this.subValueColor = const Color(0xFF64748B),
  });

  final String title;
  final String value;
  final IconData icon;
  final Color titleColor;
  final Color valueColor;
  final Color backgroundColor;
  final String? subValue;
  final Color subValueColor;
  static const double _subLineHeight = 14;

  @override
  Widget build(BuildContext context) {
    return Container(
      height: 84,
      padding: const EdgeInsets.all(8),
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(10),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(
                title,
                style: TextStyle(
                  color: titleColor,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                ),
              ),
              Icon(
                icon,
                size: 14,
                color: titleColor,
              ),
            ],
          ),
          const SizedBox(height: 2),
          Expanded(
            child: Align(
              alignment: Alignment.bottomLeft,
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  Text(
                    value,
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: valueColor,
                      fontSize: 21,
                      fontWeight: FontWeight.w900,
                      height: 1.0,
                    ),
                  ),
                  const SizedBox(height: 3),
                  SizedBox(
                    height: _subLineHeight,
                    child: subValue == null
                        ? null
                        : Text(
                            subValue!,
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: TextStyle(
                              color: subValueColor,
                              fontSize: 11,
                              fontWeight: FontWeight.w800,
                            ),
                          ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _OrderCountChip extends StatelessWidget {
  const _OrderCountChip({
    required this.label,
    required this.value,
    required this.valueColor,
    required this.backgroundColor,
    this.labelColor = const Color(0xFF64748B),
  });

  final String label;
  final String value;
  final Color valueColor;
  final Color backgroundColor;
  final Color labelColor;

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: backgroundColor,
        borderRadius: BorderRadius.circular(8),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text(
            label,
            style: TextStyle(
              color: labelColor,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 1),
          Text(
            value,
            style: TextStyle(
              color: valueColor,
              fontSize: 15,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _HomeStats {
  const _HomeStats({
    required this.totalPieces,
    required this.projectedPieces,
    required this.todayOrders,
    required this.yesterdayOrders,
    required this.pendingOrders,
    required this.outboundBoxes,
  });

  final int totalPieces;
  final int projectedPieces;
  final int todayOrders;
  final int yesterdayOrders;
  final int pendingOrders;
  final int outboundBoxes;
}

class _ActionGrid extends StatelessWidget {
  const _ActionGrid({
    required this.onOpenAction,
  });

  final Future<void> Function(String) onOpenAction;

  @override
  Widget build(BuildContext context) {
    const actions = <_HomeAction>[
      _HomeAction(
        icon: Icons.qr_code_scanner_outlined,
        title: 'QR箱码',
        subtitle: '批量预览与自动滚动',
        color: Color(0xFFEEF4FF),
      ),
      _HomeAction(
        icon: Icons.receipt_long_outlined,
        title: '订单信息',
        subtitle: '运单状态与产品明细',
        color: Color(0xFFF3EEFF),
      ),
      _HomeAction(
        icon: Icons.calendar_month_outlined,
        title: '出库日历',
        subtitle: '按日期回看库存',
        color: Color(0xFFECFDF3),
      ),
      _HomeAction(
        icon: Icons.inventory_2_outlined,
        title: '库存明细',
        subtitle: '批号库存与备注',
        color: Color(0xFFFFF4E8),
      ),
      _HomeAction(
        icon: Icons.backup_outlined,
        title: '数据备份',
        subtitle: '备份 / 迁移 / 重置',
        color: Color(0xFFEAF7FF),
      ),
      _HomeAction(
        icon: Icons.edit_document,
        title: '基础资料',
        subtitle: '产品/批号/规格/库位',
        color: Color(0xFFEEF2FF),
      ),
      _HomeAction(
        icon: Icons.tune_outlined,
        title: 'AI配置',
        subtitle: 'Gemini / 腾讯OCR',
        color: Color(0xFFF0FDF4),
      ),
    ];

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      itemCount: actions.length,
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: 2,
        crossAxisSpacing: 10,
        mainAxisSpacing: 9,
        mainAxisExtent: 96,
      ),
      itemBuilder: (context, index) {
        final action = actions[index];
        return ActionCard(
          icon: action.icon,
          title: action.title,
          subtitle: action.subtitle,
          backgroundColor: action.color,
          onTap: () => unawaited(onOpenAction(action.title)),
        );
      },
    );
  }
}

class _HomeAction {
  const _HomeAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
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

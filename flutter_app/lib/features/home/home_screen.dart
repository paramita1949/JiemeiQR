import 'dart:async';

import 'package:flutter/material.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/data_change_notifier.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/base_info/base_info_edit_screen.dart';
import 'package:qrscan_flutter/features/calendar/outbound_calendar_screen.dart';
import 'package:qrscan_flutter/features/inventory/inventory_detail_screen.dart';
import 'package:qrscan_flutter/features/orders/order_list_screen.dart';
import 'package:qrscan_flutter/features/qr/qr_entry_screen.dart';
import 'package:qrscan_flutter/features/transfer/lan_transfer_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/widgets/action_card.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({
    super.key,
    this.database,
    this.onPrepareImport,
    this.onImportCompleted,
  });

  final AppDatabase? database;
  final Future<void> Function()? onPrepareImport;
  final Future<void> Function()? onImportCompleted;

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> with WidgetsBindingObserver {
  late final AppDatabase _database;
  late final bool _ownsDatabase;
  _HomeStats? _stats;
  bool _loadingStats = true;
  StreamSubscription<DataChangeKind>? _changeSubscription;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    _refreshStats();
    _changeSubscription = DataChangeNotifier.instance.stream.listen((_) {
      if (!mounted) {
        return;
      }
      unawaited(_refreshStats());
    });
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _changeSubscription?.cancel();
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
              _InventorySummaryCard(
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
      await Navigator.of(context).push(
        MaterialPageRoute(builder: (_) => const QrEntryScreen()),
      );
      if (mounted) {
        unawaited(_refreshStats());
      }
      return;
    }
    if (title == '基础资料') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => BaseInfoEditScreen(database: database),
        ),
      );
      if (mounted) {
        unawaited(_refreshStats());
      }
      return;
    }
    if (title == '库存明细') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => InventoryDetailScreen(database: database),
        ),
      );
      if (mounted) {
        unawaited(_refreshStats());
      }
      return;
    }
    if (title == '订单信息') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OrderListScreen(database: database),
        ),
      );
      if (mounted) {
        unawaited(_refreshStats());
      }
      return;
    }
    if (title == '出库日历') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => OutboundCalendarScreen(database: database),
        ),
      );
      if (mounted) {
        unawaited(_refreshStats());
      }
      return;
    }
    if (title == '局域网迁移') {
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => LanTransferScreen(
            onPrepareImport: widget.onPrepareImport,
            onImportCompleted: widget.onImportCompleted,
          ),
        ),
      );
      if (mounted) {
        unawaited(_refreshStats());
      }
      return;
    }
  }

  AppDatabase get database => _database;

  Future<_HomeStats> _loadStats() async {
    final stockDao = StockDao(_database);
    final totalPieces = await stockDao.totalInventoryPieces();
    final today = DateTime.now();
    final todayStart = DateTime(today.year, today.month, today.day);
    final todayEnd = DateTime(today.year, today.month, today.day, 23, 59, 59);
    final countsRow = await _database.customSelect(
      '''
      SELECT
        COUNT(*) AS total_count,
        SUM(CASE WHEN status = ? THEN 1 ELSE 0 END) AS pending_count,
        SUM(CASE WHEN created_at BETWEEN ? AND ? THEN 1 ELSE 0 END) AS today_new_count
      FROM orders
      ''',
      variables: [
        Variable.withInt(OrderStatus.pending.index),
        Variable.withDateTime(todayStart),
        Variable.withDateTime(todayEnd),
      ],
    ).getSingleOrNull();
    final countsData = countsRow?.data ?? const <String, Object?>{};
    final totalOrders = (countsData['total_count'] as int?) ?? 0;
    final pendingOrders = (countsData['pending_count'] as int?) ?? 0;
    final todayNew = (countsData['today_new_count'] as int?) ?? 0;

    return _HomeStats(
      totalPieces: totalPieces,
      totalOrders: totalOrders,
      todayNewOrders: todayNew,
      pendingOrders: pendingOrders,
    );
  }

  Future<void> _refreshStats() async {
    final stats = await _loadStats();
    if (!mounted) {
      return;
    }
    setState(() {
      _stats = stats;
      _loadingStats = false;
    });
  }
}

class _InventorySummaryCard extends StatelessWidget {
  const _InventorySummaryCard({
    required this.stats,
    required this.loading,
  });

  final _HomeStats? stats;
  final bool loading;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.primary,
        borderRadius: BorderRadius.circular(20),
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
          const SizedBox(height: 7),
          Text(
            stats == null ? '-- 件' : '${_formatNumber(stats!.totalPieces)} 件',
            style: const TextStyle(
              color: Colors.white,
              fontSize: 31,
              fontWeight: FontWeight.w800,
            ),
          ),
          const SizedBox(height: 7),
          Text(
            loading || stats == null
                ? '总订单 -- 单 · 今日新增 -- 单 · 未完成 -- 单'
                : '总订单 ${stats!.totalOrders} 单 · 今日新增 ${stats!.todayNewOrders} 单 · 未完成 ${stats!.pendingOrders} 单',
            style: const TextStyle(
              color: Color(0xFFDBEAFE),
              fontSize: 12,
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
    required this.totalOrders,
    required this.todayNewOrders,
    required this.pendingOrders,
  });

  final int totalPieces;
  final int totalOrders;
  final int todayNewOrders;
  final int pendingOrders;
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
        icon: Icons.sync_alt_outlined,
        title: '局域网迁移',
        subtitle: '发送 / 接收数据库',
        color: Color(0xFFEAF7FF),
      ),
      _HomeAction(
        icon: Icons.edit_document,
        title: '基础资料',
        subtitle: '产品/批号/规格/库位',
        color: Color(0xFFEEF2FF),
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

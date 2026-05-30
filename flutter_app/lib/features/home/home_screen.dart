import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:drift/drift.dart' hide Column;
import 'package:package_info_plus/package_info_plus.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/stock_dao.dart';
import 'package:qrscan_flutter/features/attendance/attendance_geofence_reminder_service.dart';
import 'package:qrscan_flutter/features/attendance/attendance_precheckin_guard_service.dart';
import 'package:qrscan_flutter/features/attendance/attendance_screen.dart';
import 'package:qrscan_flutter/features/base_info/base_info_edit_screen.dart';
import 'package:qrscan_flutter/features/calendar/outbound_calendar_screen.dart';
import 'package:qrscan_flutter/features/inventory/inventory_detail_screen.dart';
import 'package:qrscan_flutter/features/orders/order_list_screen.dart';
import 'package:qrscan_flutter/features/orders/ocr/ai_config_screen.dart';
import 'package:qrscan_flutter/features/qr/qr_entry_screen.dart';
import 'package:qrscan_flutter/features/transfer/backup_import_intent_service.dart';
import 'package:qrscan_flutter/features/transfer/backup_service.dart';
import 'package:qrscan_flutter/features/transfer/lan_transfer_screen.dart';
import 'package:qrscan_flutter/features/update/app_update_service.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';
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
  static const _importExtensions = [
    '.jiemei',
    '.sqlite',
    '.zip',
    '.attendance.json',
  ];
  late AppDatabase _database;
  late bool _ownsDatabase;
  final BackupService _backupService =
      const BackupService(databaseFileName: 'jiemei.sqlite');
  final BackupImportIntentService _backupImportIntentService =
      const BackupImportIntentService();
  final AppUpdateService _appUpdateService = const AppUpdateService();
  _HomeStats? _stats;
  bool _loadingStats = true;
  bool _handlingIntentImport = false;
  bool _notiHintShownInSession = false;
  Timer? _precheckinGuardTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _ownsDatabase = widget.database == null;
    _database = widget.database ?? AppDatabase();
    unawaited(_refreshStats());
    unawaited(_runAutoBackupCheck());
    unawaited(_consumePendingImportIntent());
    unawaited(_runAttendanceReminderCheck());
    unawaited(_runPrecheckinGuard(forForeground: true));
    unawaited(_ensureNotificationPermissionHint());
    _startPrecheckinGuardTimer();
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
    _precheckinGuardTimer?.cancel();
    if (_ownsDatabase) {
      _database.close();
    }
    super.dispose();
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      unawaited(_refreshStats());
      unawaited(_runAutoBackupCheck());
      unawaited(_consumePendingImportIntent());
      unawaited(_runAttendanceReminderCheck());
      unawaited(_runPrecheckinGuard(forForeground: true));
      unawaited(_ensureNotificationPermissionHint());
      _startPrecheckinGuardTimer();
    } else if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive) {
      unawaited(_runPrecheckinGuard(forForeground: false));
      _precheckinGuardTimer?.cancel();
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
              Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Expanded(
                    child: PageTitle(
                      icon: Icons.warehouse_outlined,
                      title: '洁美',
                      subtitle: '浙江仓订单与库存工作台',
                    ),
                  ),
                  IconButton.filledTonal(
                    tooltip: '日志面板',
                    onPressed: _openDebugLogPanel,
                    icon: const Icon(Icons.bug_report_outlined),
                  ),
                ],
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
        route: MaterialPageRoute(
            builder: (_) => QrEntryScreen(database: database)),
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
      await _openBackupScreen();
      return;
    }
    if (title == 'AI识别') {
      DebugEventLog.add('AI_OCR', 'open ai_config_screen');
      await pushAndRefresh(
        context,
        route: MaterialPageRoute(
          builder: (_) => const AiConfigScreen(),
        ),
        onRefresh: () => unawaited(_refreshStats()),
      );
      return;
    }
    if (title == '考勤签到') {
      await pushAndRefresh(
        context,
        route: MaterialPageRoute(
          builder: (_) => AttendanceScreen(database: database),
        ),
        onRefresh: () => unawaited(_refreshStats()),
      );
      return;
    }
  }

  Future<void> _openBackupScreen({String? initialImportPath}) async {
    if (!mounted) {
      return;
    }
    await pushAndRefresh(
      context,
      route: MaterialPageRoute(
        builder: (_) => LanTransferScreen(
          initialImportPath: initialImportPath,
          onPrepareImport: widget.onPrepareImport,
          onImportCompleted: widget.onImportCompleted,
        ),
      ),
      onRefresh: () => unawaited(_refreshStats()),
    );
  }

  Future<void> _consumePendingImportIntent() async {
    if (!mounted || _handlingIntentImport) {
      return;
    }
    _handlingIntentImport = true;
    try {
      final path = await _backupImportIntentService.consumePendingImportPath();
      if (!mounted || path == null || !_isSupportedImportPath(path)) {
        return;
      }
      if (_isAttendanceBackupPath(path)) {
        await pushAndRefresh(
          context,
          route: MaterialPageRoute(
            builder: (_) => AttendanceScreen(
              database: database,
              initialImportPath: path,
            ),
          ),
          onRefresh: () => unawaited(_refreshStats()),
        );
      } else {
        await _openBackupScreen(initialImportPath: path);
      }
    } catch (_) {
      // Swallow intent read errors to avoid interrupting normal home flows.
    } finally {
      _handlingIntentImport = false;
    }
  }

  bool _isSupportedImportPath(String path) {
    final normalized = path.toLowerCase();
    return _importExtensions.any(normalized.endsWith);
  }

  bool _isAttendanceBackupPath(String path) {
    final lower = path.toLowerCase();
    return lower.endsWith('.attendance.json');
  }

  AppDatabase get database => _database;

  Future<void> _runAutoBackupCheck() async {
    try {
      await _backupService.runAutoBackupIfDue();
    } catch (_) {
      // Ignore auto backup errors on home lifecycle hooks.
    }
  }

  Future<void> _runAttendanceReminderCheck() async {
    try {
      await AttendanceGeofenceReminderService.checkAndMaybeNotify(
        database: _database,
      );
    } catch (_) {
      // Keep home resilient when location/notification fails on some devices.
    }
  }

  void _startPrecheckinGuardTimer() {
    _precheckinGuardTimer?.cancel();
    _precheckinGuardTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      unawaited(_runPrecheckinGuard(forForeground: true));
    });
  }

  Future<void> _runPrecheckinGuard({required bool forForeground}) async {
    try {
      final decision = await AttendancePrecheckinGuardService.evaluate(
        database: _database,
      );
      if (!decision.shouldRemind) return;

      if (forForeground) {
        if (!AttendancePrecheckinGuardService.shouldShowDialog(
            decision.dayKey)) {
          return;
        }
        if (!mounted) return;
        DebugEventLog.add('PRECHECKIN', 'show foreground dialog');
        await showDialog<void>(
          context: context,
          builder: (_) => AlertDialog(
            title: const Text('上班临近提醒'),
            content: const Text('距离上班时间不足3分钟，且你还未签到。'),
            actions: [
              TextButton(
                onPressed: () => Navigator.of(context).pop(),
                child: const Text('知道了'),
              ),
              FilledButton(
                onPressed: () async {
                  Navigator.of(context).pop();
                  await pushAndRefresh(
                    context,
                    route: MaterialPageRoute(
                      builder: (_) => AttendanceScreen(database: database),
                    ),
                    onRefresh: () => unawaited(_refreshStats()),
                  );
                },
                child: const Text('去签到'),
              ),
            ],
          ),
        );
      } else {
        if (!AttendancePrecheckinGuardService.shouldSendNotification(
            decision.dayKey)) {
          return;
        }
        DebugEventLog.add('PRECHECKIN', 'show lockscreen notification');
        await AttendanceGeofenceReminderService.showPrecheckinNotification();
      }
    } catch (e) {
      DebugEventLog.add('PRECHECKIN', 'guard failed: $e');
    }
  }

  Future<void> _ensureNotificationPermissionHint() async {
    if (!mounted || _notiHintShownInSession) return;
    try {
      final state =
          await AttendanceGeofenceReminderService.ensureSystemPermissions(
        requestIfNeeded: false,
      );
      if (!mounted || state.notificationGranted) return;
      _notiHintShownInSession = true;
      final enable = await showDialog<bool>(
        context: context,
        builder: (_) => AlertDialog(
          title: const Text('开启通知权限'),
          content: const Text('未开启通知权限，围栏签到提醒与锁屏提醒将无法正常弹出。'),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('稍后'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('立即开启'),
            ),
          ],
        ),
      );
      if (enable == true) {
        await AttendanceGeofenceReminderService.ensureSystemPermissions(
          requestIfNeeded: true,
        );
      }
    } catch (_) {
      // Ignore permission hint failures to keep home flow resilient.
    }
  }

  Future<_HomeStats> _loadStats() async {
    final stockDao = StockDao(_database);
    final totalPieces = await stockDao.totalInventoryPieces();
    final nonRestrictedPieces = await stockDao.nonRestrictedInventoryPieces();
    final frozenBoxes = await stockDao.totalFrozenBoxes();
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
      nonRestrictedPieces: nonRestrictedPieces,
      frozenBoxes: frozenBoxes,
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

  Future<void> _openDebugLogPanel() async {
    final report = await _buildDebugReport();
    if (!mounted) {
      return;
    }
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      showDragHandle: true,
      builder: (context) => _DebugLogSheet(
        report: report,
        onCheckUpdate: _checkForUpdateFromLogPanel,
        onCopy: () async {
          await Clipboard.setData(ClipboardData(text: report.rawText));
          if (!context.mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('日志已复制')),
          );
        },
      ),
    );
  }

  Future<void> _checkForUpdateFromLogPanel() async {
    var progress = 0.0;
    StateSetter? progressSetState;
    var blockingDialogOpen = false;

    void showMessage(String message) {
      if (!mounted) {
        return;
      }
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(message)),
      );
    }

    void closeBlockingDialog() {
      if (!mounted || !blockingDialogOpen) {
        return;
      }
      Navigator.of(context, rootNavigator: true).pop();
      blockingDialogOpen = false;
    }

    try {
      blockingDialogOpen = true;
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            progressSetState = setState;
            return const AlertDialog(
              title: Text('正在检查更新'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [Text('正在连接 GitHub Release...')],
              ),
            );
          },
        ),
      ));
      final info = await _appUpdateService.checkLatest();
      if (!mounted) {
        return;
      }
      closeBlockingDialog();
      if (!info.hasUpdate) {
        showMessage('当前已经是最新版本：${info.currentVersion}');
        return;
      }
      final shouldDownload = await showDialog<bool>(
        context: context,
        builder: (context) => AlertDialog(
          title: Text('发现新版本 ${info.latestVersion}'),
          content: SingleChildScrollView(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('当前版本：${info.currentVersion}'),
                const SizedBox(height: 8),
                if (info.releaseNotes.trim().isNotEmpty)
                  Text(info.releaseNotes.trim()),
              ],
            ),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(false),
              child: const Text('稍后'),
            ),
            FilledButton(
              onPressed: () => Navigator.of(context).pop(true),
              child: const Text('下载并安装'),
            ),
          ],
        ),
      );
      if (shouldDownload != true || !mounted) {
        return;
      }
      progress = 0.0;
      progressSetState = null;
      blockingDialogOpen = true;
      unawaited(showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (context) => StatefulBuilder(
          builder: (context, setState) {
            progressSetState = setState;
            return AlertDialog(
              title: const Text('正在下载更新'),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  LinearProgressIndicator(value: progress),
                  const SizedBox(height: 10),
                  Text('下载进度 ${(progress * 100).round()}%'),
                ],
              ),
            );
          },
        ),
      ));
      final apk = await _appUpdateService.downloadApk(
        info,
        onProgress: (value) {
          progress = value.clamp(0.0, 1.0).toDouble();
          progressSetState?.call(() {});
        },
      );
      if (!mounted) {
        return;
      }
      closeBlockingDialog();
      await _appUpdateService.installApk(apk);
      showMessage('安装界面已打开，请按系统提示完成更新');
    } on AppUpdateException catch (error) {
      closeBlockingDialog();
      showMessage(error.message);
    } on PlatformException catch (error) {
      closeBlockingDialog();
      showMessage(error.message ?? '无法打开安装界面');
    } catch (error) {
      closeBlockingDialog();
      showMessage('更新失败：$error');
    }
  }

  Future<_DebugLogReport> _buildDebugReport() async {
    final buffer = StringBuffer();
    String dbStatus = '正常';
    var appVersion = '读取失败';
    buffer.writeln('time=${DateTime.now().toIso8601String()}');
    try {
      final packageInfo = await PackageInfo.fromPlatform();
      appVersion = packageInfo.version;
      final buildNumber = packageInfo.buildNumber.trim();
      if (buildNumber.isNotEmpty) {
        appVersion = '$appVersion+$buildNumber';
      }
      buffer.writeln('app_version=$appVersion');
    } catch (error) {
      buffer.writeln('app_version_error=$error');
    }
    buffer.writeln('schema=${_database.schemaVersion}');
    try {
      final userVersionRow =
          await _database.customSelect('PRAGMA user_version;').getSingle();
      buffer.writeln(
          'sqlite_user_version=${userVersionRow.data['user_version']}');
    } catch (error) {
      dbStatus = '异常（数据库连接失败）';
      buffer.writeln('sqlite_user_version_error=$error');
    }
    final orderCount = await _safeTableCount('orders', buffer);
    final orderItemCount = await _safeTableCount('order_items', buffer);
    final batchCount = await _safeTableCount('batches', buffer);
    final movementCount = await _safeTableCount('stock_movements', buffer);

    buffer.writeln('--- recent_debug_events ---');
    final events = DebugEventLog.dump();
    const aiKeywords = <String>[
      '[AI_OCR]',
      'ocr',
      '识别',
      'gemini',
      'modelscope',
      'prompt',
    ];
    final filtered = events.where((e) {
      final lower = e.toLowerCase();
      for (final keyword in aiKeywords) {
        if (keyword.startsWith('[')) {
          if (e.contains(keyword)) return true;
        } else if (lower.contains(keyword)) {
          return true;
        }
      }
      return false;
    }).toList();
    if (filtered.isEmpty) {
      buffer.writeln('recent_debug_events=empty');
    } else {
      for (final e in filtered) {
        buffer.writeln(e);
      }
    }
    return _DebugLogReport(
      appVersion: appVersion,
      dbStatus: dbStatus,
      sqliteSchemaVersion: _database.schemaVersion,
      orderCount: orderCount,
      orderItemCount: orderItemCount,
      batchCount: batchCount,
      movementCount: movementCount,
      readableEvents: _humanReadableEvents(filtered),
      rawText: buffer.toString(),
    );
  }

  Future<int?> _safeTableCount(String table, StringBuffer buffer) async {
    try {
      final row = await _database
          .customSelect('SELECT COUNT(*) AS c FROM $table;')
          .getSingle();
      final count = row.data['c'] as int?;
      buffer.writeln('table_count_$table=${count ?? 0}');
      return count;
    } catch (error) {
      buffer.writeln('table_count_${table}_error=$error');
      return null;
    }
  }

  List<String> _humanReadableEvents(List<String> events) {
    if (events.isEmpty) {
      return const <String>[];
    }
    final readable = <String>[];
    for (final event in events.reversed.take(12)) {
      final normalized = event.toLowerCase();
      if (normalized.contains('failed') || normalized.contains('error')) {
        readable.add('系统操作失败：$event');
      } else if (normalized.contains('show foreground dialog')) {
        readable.add('已弹出前台提醒：$event');
      } else if (normalized.contains('show lockscreen notification')) {
        readable.add('已触发锁屏通知：$event');
      } else if (normalized.contains('permission')) {
        readable.add('权限相关状态：$event');
      } else {
        readable.add('系统记录：$event');
      }
    }
    return readable;
  }
}

class _DebugLogReport {
  const _DebugLogReport({
    required this.appVersion,
    required this.dbStatus,
    required this.sqliteSchemaVersion,
    required this.orderCount,
    required this.orderItemCount,
    required this.batchCount,
    required this.movementCount,
    required this.readableEvents,
    required this.rawText,
  });

  final String appVersion;
  final String dbStatus;
  final int sqliteSchemaVersion;
  final int? orderCount;
  final int? orderItemCount;
  final int? batchCount;
  final int? movementCount;
  final List<String> readableEvents;
  final String rawText;
}

class _DebugLogSheet extends StatelessWidget {
  const _DebugLogSheet({
    required this.report,
    required this.onCheckUpdate,
    required this.onCopy,
  });

  final _DebugLogReport report;
  final VoidCallback onCheckUpdate;
  final VoidCallback onCopy;

  @override
  Widget build(BuildContext context) {
    final media = MediaQuery.of(context);
    return SafeArea(
      child: Padding(
        padding: EdgeInsets.only(
          left: 16,
          right: 16,
          top: 6,
          bottom: media.viewInsets.bottom + 16,
        ),
        child: ConstrainedBox(
          constraints: BoxConstraints(maxHeight: media.size.height * 0.82),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                '可视化日志',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              const Text(
                '当前仅显示 AI 识别日志；定位/打卡相关日志已暂时屏蔽。',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              _DebugStatusCard(
                label: '当前版本',
                value: report.appVersion,
              ),
              const SizedBox(height: 8),
              _DebugStatusCard(
                label: '数据库状态',
                value: report.dbStatus,
              ),
              const SizedBox(height: 8),
              _DebugStatusCard(
                label: '数据库版本',
                value: 'schema v${report.sqliteSchemaVersion}',
              ),
              const SizedBox(height: 8),
              Wrap(
                spacing: 8,
                runSpacing: 8,
                children: [
                  _DebugMetricChip(
                      label: '订单', value: _countText(report.orderCount)),
                  _DebugMetricChip(
                      label: '订单明细', value: _countText(report.orderItemCount)),
                  _DebugMetricChip(
                      label: '批号', value: _countText(report.batchCount)),
                  _DebugMetricChip(
                      label: '库存流水', value: _countText(report.movementCount)),
                ],
              ),
              const SizedBox(height: 12),
              const Text(
                '最近 AI 识别记录',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 14,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 8),
              Expanded(
                child: report.readableEvents.isEmpty
                    ? const Center(
                        child: Text(
                          '暂无 AI 识别日志',
                          style: TextStyle(
                            color: AppTheme.textSecondary,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      )
                    : ListView.separated(
                        itemCount: report.readableEvents.length,
                        itemBuilder: (context, index) => Container(
                          padding: const EdgeInsets.all(10),
                          decoration: BoxDecoration(
                            color: const Color(0xFFF8FAFC),
                            borderRadius: BorderRadius.circular(10),
                            border: Border.all(color: const Color(0xFFE5E7EB)),
                          ),
                          child: Text(
                            report.readableEvents[index],
                            style: const TextStyle(
                              color: AppTheme.textSecondary,
                              fontSize: 12,
                              fontWeight: FontWeight.w700,
                            ),
                          ),
                        ),
                        separatorBuilder: (_, __) => const SizedBox(height: 8),
                      ),
              ),
              const SizedBox(height: 10),
              SizedBox(
                width: double.infinity,
                child: FilledButton.icon(
                  onPressed: onCheckUpdate,
                  icon: const Icon(Icons.system_update_alt_rounded),
                  label: const Text('检查更新'),
                ),
              ),
              const SizedBox(height: 8),
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: onCopy,
                  icon: const Icon(Icons.copy_all_rounded),
                  label: const Text('一键复制完整日志'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  String _countText(int? value) => value == null ? '读取失败' : '$value 条';
}

class _DebugStatusCard extends StatelessWidget {
  const _DebugStatusCard({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          Text(
            label,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w800,
            ),
          ),
          const Spacer(),
          Text(
            value,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 13,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _DebugMetricChip extends StatelessWidget {
  const _DebugMetricChip({
    required this.label,
    required this.value,
  });

  final String label;
  final String value;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        '$label: $value',
        style: const TextStyle(
          color: AppTheme.textSecondary,
          fontSize: 12,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
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
    final nonRestrictedText =
        stats == null ? '--' : _formatNumber(stats!.nonRestrictedPieces);
    final projectedText =
        stats == null ? '--' : _formatNumber(stats!.projectedPieces);
    final frozenText = loading || stats == null
        ? null
        : '冻结箱数 ${_formatNumber(stats!.frozenBoxes)}箱';
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
        LayoutBuilder(
          builder: (context, constraints) {
            final cardWidth = (constraints.maxWidth - 8) / 2;
            return SingleChildScrollView(
              key: const Key('homeInventoryStatsCarousel'),
              scrollDirection: Axis.horizontal,
              physics: const BouncingScrollPhysics(),
              child: Row(
                children: [
                  SizedBox(
                    width: cardWidth,
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
                  SizedBox(
                    width: cardWidth,
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
                  const SizedBox(width: 8),
                  SizedBox(
                    width: cardWidth,
                    child: _InventoryStatCard(
                      title: '非限制库存',
                      value: nonRestrictedText,
                      icon: Icons.lock_open_outlined,
                      titleColor: const Color(0xFF064E3B),
                      valueColor: const Color(0xFF064E3B),
                      backgroundColor: const Color(0xFFDDF8EC),
                      subValue: frozenText,
                      subValueColor: const Color(0xFF047857),
                    ),
                  ),
                ],
              ),
            );
          },
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
    required this.nonRestrictedPieces,
    required this.frozenBoxes,
    required this.projectedPieces,
    required this.todayOrders,
    required this.yesterdayOrders,
    required this.pendingOrders,
    required this.outboundBoxes,
  });

  final int totalPieces;
  final int nonRestrictedPieces;
  final int frozenBoxes;
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
        title: 'AI识别',
        subtitle: 'AI智能填单',
        color: Color(0xFFF0FDF4),
      ),
      _HomeAction(
        icon: Icons.fact_check_outlined,
        title: '考勤签到',
        subtitle: '签到 / 统计 / 围栏',
        color: Color(0xFFEFF6FF),
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

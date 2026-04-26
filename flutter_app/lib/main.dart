import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/seed/embedded_stock_seed_service.dart';
import 'package:qrscan_flutter/data/data_change_notifier.dart';
import 'package:qrscan_flutter/features/home/home_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/utils/startup_trace.dart';

void main() {
  WidgetsFlutterBinding.ensureInitialized();
  StartupTrace.mark('main() start');
  runApp(const QrScanApp());
  StartupTrace.mark('runApp completed');
}

class QrScanApp extends StatefulWidget {
  const QrScanApp({
    super.key,
    this.database,
  });

  final AppDatabase? database;

  @override
  State<QrScanApp> createState() => _QrScanAppState();
}

class _QrScanAppState extends State<QrScanApp> {
  late AppDatabase _database;
  int _databaseVersion = 0;

  @override
  void initState() {
    super.initState();
    StartupTrace.mark('QrScanApp.initState');
    _database = widget.database ?? AppDatabase();
    StartupTrace.mark('AppDatabase allocated');
    if (widget.database == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        StartupTrace.mark('first frame callback -> start seed check');
        unawaited(_seedInBackground());
      });
    }
  }

  @override
  void dispose() {
    if (widget.database == null) {
      _database.close();
    }
    super.dispose();
  }

  Future<void> _seedInBackground() async {
    try {
      final seeded = await StartupTrace.time(
        'EmbeddedStockSeedService.seedIfDatabaseEmpty',
        () => EmbeddedStockSeedService(_database).seedIfDatabaseEmpty(),
      );
      if (!mounted || !seeded) {
        StartupTrace.mark('seed skipped or widget disposed');
        return;
      }
      StartupTrace.mark('seed applied -> emit data change only (no app rebuild)');
      DataChangeNotifier.instance.emit(DataChangeKind.baseInfo);
    } catch (error) {
      StartupTrace.mark('seed failed: $error');
    }
  }

  @override
  Widget build(BuildContext context) {
    StartupTrace.mark('QrScanApp.build');
    return MaterialApp(
      title: '洁美',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
      locale: const Locale('zh', 'CN'),
      supportedLocales: const [
        Locale('zh', 'CN'),
        Locale('en', 'US'),
      ],
      localizationsDelegates: const [
        GlobalMaterialLocalizations.delegate,
        GlobalWidgetsLocalizations.delegate,
        GlobalCupertinoLocalizations.delegate,
      ],
      home: HomeScreen(
        key: ValueKey(_databaseVersion),
        database: _database,
        onPrepareImport: _prepareImport,
        onImportCompleted: _importCompleted,
      ),
    );
  }

  Future<void> _prepareImport() async {
    if (widget.database != null) {
      return;
    }
    StartupTrace.mark('prepare import -> close database');
    await _database.close();
  }

  Future<void> _importCompleted() async {
    if (widget.database != null) {
      return;
    }
    StartupTrace.mark('import completed -> recreate database');
    _database = AppDatabase();
    await StartupTrace.time(
      'seed after importCompleted',
      () => EmbeddedStockSeedService(_database).seedIfDatabaseEmpty(),
    );
    if (!mounted) {
      return;
    }
    setState(() => _databaseVersion += 1);
  }
}

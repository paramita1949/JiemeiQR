import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_localizations/flutter_localizations.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/seed/embedded_stock_seed_service.dart';
import 'package:qrscan_flutter/features/home/home_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';

void main() {
  runApp(const QrScanApp());
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
  bool _bootReady = false;

  @override
  void initState() {
    super.initState();
    _database = widget.database ?? AppDatabase();
    unawaited(_bootstrap());
  }

  @override
  void dispose() {
    if (widget.database == null) {
      _database.close();
    }
    super.dispose();
  }

  Future<void> _bootstrap() async {
    await Future.wait([
      Future<void>.delayed(const Duration(milliseconds: 420)),
      _warmUpDatabase(),
    ]);
    if (!mounted) {
      return;
    }
    setState(() => _bootReady = true);
    if (widget.database == null) {
      unawaited(_seedInBackground());
    }
  }

  Future<void> _warmUpDatabase() async {
    await _database.customSelect('SELECT 1;').getSingleOrNull();
  }

  Future<void> _seedInBackground() async {
    final seeded =
        await EmbeddedStockSeedService(_database).seedIfDatabaseEmpty();
    if (!mounted || !seeded) {
      return;
    }
    setState(() => _databaseVersion += 1);
  }

  @override
  Widget build(BuildContext context) {
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
      home: _bootReady
          ? HomeScreen(
              key: ValueKey(_databaseVersion),
              database: _database,
              onPrepareImport: _prepareImport,
              onImportCompleted: _importCompleted,
            )
          : const _AppBootScreen(),
    );
  }

  Future<void> _prepareImport() async {
    if (widget.database != null) {
      return;
    }
    await _database.close();
  }

  Future<void> _importCompleted() async {
    if (widget.database != null) {
      return;
    }
    _database = AppDatabase();
    await EmbeddedStockSeedService(_database).seedIfDatabaseEmpty();
    if (!mounted) {
      return;
    }
    setState(() => _databaseVersion += 1);
  }
}

class _AppBootScreen extends StatelessWidget {
  const _AppBootScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      backgroundColor: Color(0xFFF5F8FF),
      body: Center(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            CircularProgressIndicator(strokeWidth: 2.4),
            SizedBox(height: 14),
            Text(
              '正在加载洁美…',
              style: TextStyle(
                color: Color(0xFF475569),
                fontSize: 14,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

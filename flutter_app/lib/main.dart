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

  @override
  void initState() {
    super.initState();
    _database = widget.database ?? AppDatabase();
    if (widget.database == null) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
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
      final seeded =
          await EmbeddedStockSeedService(_database).seedIfDatabaseEmpty();
      if (!mounted || !seeded) {
        return;
      }
      setState(() => _databaseVersion += 1);
    } catch (error) {
      debugPrint('seed failed: $error');
    }
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
      home: HomeScreen(
        database: _database,
        refreshToken: _databaseVersion,
        onPrepareImport: _prepareImport,
        onImportCompleted: _importCompleted,
      ),
    );
  }

  Future<void> _prepareImport() async {
    if (widget.database != null) {
      return;
    }
    await _database.close();
  }

  Future<void> _importCompleted({bool seedIfEmpty = false}) async {
    if (widget.database != null) {
      return;
    }
    _database = AppDatabase();
    if (seedIfEmpty) {
      await EmbeddedStockSeedService(_database).seedIfDatabaseEmpty();
    }
    if (!mounted) {
      return;
    }
    setState(() => _databaseVersion += 1);
  }
}

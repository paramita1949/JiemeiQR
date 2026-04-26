import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
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
  }

  @override
  void dispose() {
    if (widget.database == null) {
      _database.close();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      title: '洁美',
      debugShowCheckedModeBanner: false,
      theme: AppTheme.light(),
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
    await _database.close();
  }

  Future<void> _importCompleted() async {
    if (widget.database != null) {
      return;
    }
    _database = AppDatabase();
    if (!mounted) {
      return;
    }
    setState(() => _databaseVersion += 1);
  }
}

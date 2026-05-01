import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:archive/archive.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:sqflite/sqflite.dart' show getDatabasesPath;
import 'package:sqlite3/sqlite3.dart' as sqlite;

typedef DocumentsDirectoryProvider = Future<Directory> Function();
typedef DatabaseDirectoryProvider = Future<Directory> Function();
typedef NowProvider = DateTime Function();
typedef RandomIntProvider = int Function(int max);

enum BackupReason {
  manual('manual'),
  autoDaily('auto_daily'),
  autoWeekly('auto_weekly'),
  beforeReset('before_reset'),
  beforeImport('before_import'),
  beforeRestore('before_restore');

  const BackupReason(this.value);
  final String value;
}

enum BackupSchedule {
  off('off'),
  daily('daily'),
  weekly('weekly');

  const BackupSchedule(this.value);
  final String value;

  static BackupSchedule fromValue(String? value) {
    return BackupSchedule.values.firstWhere(
      (item) => item.value == value,
      orElse: () => BackupSchedule.off,
    );
  }
}

class BackupService {
  const BackupService({
    required this.databaseFileName,
    this.documentsDirectoryProvider,
    this.databaseDirectoryProvider,
    this.nowProvider,
    this.randomIntProvider,
  });

  final String databaseFileName;
  final DocumentsDirectoryProvider? documentsDirectoryProvider;
  final DatabaseDirectoryProvider? databaseDirectoryProvider;
  final NowProvider? nowProvider;
  final RandomIntProvider? randomIntProvider;
  static const int maxSnapshotCount = 90;
  static const String aiConfigFileName = 'ai_ocr_config.json';
  static const Duration dailyAutoBackupInterval = Duration(hours: 24);
  static const Duration weeklyAutoBackupInterval = Duration(days: 7);

  BackupDraft createLocalBackupDraft() {
    final now = (nowProvider ?? DateTime.now)();
    final stamp = _fileStamp(now);
    return BackupDraft(
      databasePath: databaseFileName,
      fileName: 'jiemei-backup-$stamp.sqlite',
      note: '本地备份入口保留在数据备份页面，避免与首页入口重复。',
    );
  }

  Future<BackupResult> createLocalBackup({
    BackupReason reason = BackupReason.manual,
  }) async {
    final now = (nowProvider ?? DateTime.now)();
    final documentsDir = await _documentsDirectory();
    final source = await _databaseFile();
    if (!await source.exists()) {
      throw BackupSourceMissingException(source.path);
    }

    final backupDir = Directory(p.join(documentsDir.path, 'backups'));
    if (!await backupDir.exists()) {
      await backupDir.create(recursive: true);
    }

    final stamp = _fileStamp(now);
    final backupFileName = 'jiemei-backup-$stamp.sqlite';
    final backupFile = File(p.join(backupDir.path, backupFileName));
    await source.copy(backupFile.path);
    final aiConfigSource = await _aiConfigFile();
    final aiConfigBackupPath = p.join(
      backupDir.path,
      'jiemei-backup-$stamp.$aiConfigFileName',
    );
    String? copiedAiConfigPath;
    if (await aiConfigSource.exists()) {
      final copied = await aiConfigSource.copy(aiConfigBackupPath);
      copiedAiConfigPath = copied.path;
    }

    final infoFileName = 'jiemei-backup-$stamp.backup_info.json';
    final infoFile = File(p.join(backupDir.path, infoFileName));
    await infoFile.writeAsString(
      jsonEncode({
        'createdAt': now.toIso8601String(),
        'databaseFileName': databaseFileName,
        'sourceDatabasePath': source.path,
        'backupDatabasePath': backupFile.path,
        'backupAiConfigPath': copiedAiConfigPath,
        'reason': reason.value,
      }),
    );

    final result = BackupResult(
      fileName: backupFileName,
      filePath: backupFile.path,
      infoPath: infoFile.path,
      note: '备份已生成，可用于数据备份接收端导入。',
    );
    await _pruneBackupsByCount(maxCount: maxSnapshotCount);
    return result;
  }

  Future<List<BackupSnapshot>> listLocalBackups() async {
    final documentsDir = await _documentsDirectory();
    final backupDir = Directory(p.join(documentsDir.path, 'backups'));
    if (!await backupDir.exists()) {
      return const [];
    }

    final snapshots = <BackupSnapshot>[];
    await for (final entity in backupDir.list()) {
      if (entity is! File || p.extension(entity.path) != '.sqlite') {
        continue;
      }
      final stat = await entity.stat();
      final fileName = p.basename(entity.path);
      final infoPath = p.setExtension(entity.path, '.backup_info.json');
      final infoFile = File(infoPath);
      DateTime createdAt = stat.modified;
      var reason = BackupReason.manual;
      if (await infoFile.exists()) {
        try {
          final content = jsonDecode(await infoFile.readAsString());
          if (content is Map<String, dynamic>) {
            final parsed =
                DateTime.tryParse(content['createdAt'] as String? ?? '');
            if (parsed != null) {
              createdAt = parsed;
            }
            reason = BackupReason.values.firstWhere(
              (item) => item.value == (content['reason'] as String? ?? ''),
              orElse: () => BackupReason.manual,
            );
          }
        } catch (_) {
          // A damaged metadata file should not hide a valid backup snapshot.
        }
      }
      snapshots.add(
        BackupSnapshot(
          fileName: fileName,
          filePath: entity.path,
          infoPath: await infoFile.exists() ? infoFile.path : null,
          createdAt: createdAt,
          sizeBytes: stat.size,
          reason: reason,
        ),
      );
    }
    snapshots.sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return snapshots;
  }

  Future<ImportResult> restoreBackupSnapshot(String backupPath) {
    final aiConfigPath = p.join(
      p.dirname(backupPath),
      '${p.basenameWithoutExtension(backupPath)}.$aiConfigFileName',
    );
    return importDatabaseFromPath(
      backupPath,
      incomingAiConfigPath: aiConfigPath,
    );
  }

  Future<void> deleteBackupSnapshot(String backupPath) async {
    final backupFile = File(backupPath);
    if (await backupFile.exists()) {
      await backupFile.delete();
    }
    final infoFile = File(p.setExtension(backupPath, '.backup_info.json'));
    if (await infoFile.exists()) {
      await infoFile.delete();
    }
  }

  Future<int> cleanupBackupsByCount({int keepLatest = 30}) async {
    return _pruneBackupsByCount(maxCount: keepLatest);
  }

  Future<BackupSchedule> getBackupSchedule() async {
    final file = await _backupSettingsFile();
    if (!await file.exists()) {
      return BackupSchedule.off;
    }
    try {
      final content = jsonDecode(await file.readAsString());
      if (content is Map<String, dynamic>) {
        return BackupSchedule.fromValue(content['schedule'] as String?);
      }
    } catch (_) {}
    return BackupSchedule.off;
  }

  Future<void> setBackupSchedule(BackupSchedule schedule) async {
    final file = await _backupSettingsFile();
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    DateTime? lastAutoBackupAt;
    if (await file.exists()) {
      try {
        final previous = jsonDecode(await file.readAsString());
        if (previous is Map<String, dynamic>) {
          lastAutoBackupAt =
              DateTime.tryParse(previous['lastAutoBackupAt'] as String? ?? '');
        }
      } catch (_) {}
    }
    await file.writeAsString(
      jsonEncode({
        'schedule': schedule.value,
        'lastAutoBackupAt': lastAutoBackupAt?.toIso8601String(),
      }),
    );
  }

  Future<BackupResult?> runAutoBackupIfDue() async {
    final file = await _backupSettingsFile();
    final schedule = await getBackupSchedule();
    if (schedule == BackupSchedule.off) {
      return null;
    }

    DateTime? lastAutoBackupAt;
    if (await file.exists()) {
      try {
        final content = jsonDecode(await file.readAsString());
        if (content is Map<String, dynamic>) {
          lastAutoBackupAt =
              DateTime.tryParse(content['lastAutoBackupAt'] as String? ?? '');
        }
      } catch (_) {}
    }

    final now = (nowProvider ?? DateTime.now)();
    final due = switch (schedule) {
      BackupSchedule.daily => lastAutoBackupAt == null ||
          now.difference(lastAutoBackupAt) >= dailyAutoBackupInterval,
      BackupSchedule.weekly => lastAutoBackupAt == null ||
          now.difference(lastAutoBackupAt) >= weeklyAutoBackupInterval,
      BackupSchedule.off => false,
    };
    if (!due) {
      return null;
    }

    final result = await createLocalBackup(
      reason: schedule == BackupSchedule.daily
          ? BackupReason.autoDaily
          : BackupReason.autoWeekly,
    );
    if (!await file.parent.exists()) {
      await file.parent.create(recursive: true);
    }
    await file.writeAsString(
      jsonEncode({
        'schedule': schedule.value,
        'lastAutoBackupAt': now.toIso8601String(),
      }),
    );
    return result;
  }

  Future<SendPackageResult> createSendPackage() async {
    final now = (nowProvider ?? DateTime.now)();
    final documentsDir = await _documentsDirectory();
    final source = await _databaseFile();
    if (!await source.exists()) {
      throw BackupSourceMissingException(source.path);
    }

    final stamp = _fileStamp(now);
    final sendDir = Directory(p.join(documentsDir.path, 'transfers', stamp));
    if (!await sendDir.exists()) {
      await sendDir.create(recursive: true);
    }

    final packageDb = File(p.join(sendDir.path, databaseFileName));
    await source.copy(packageDb.path);
    String? aiConfigPackagePath;
    final aiConfig = await _aiConfigFile();
    if (await aiConfig.exists()) {
      final aiConfigFile =
          await aiConfig.copy(p.join(sendDir.path, aiConfigFileName));
      aiConfigPackagePath = aiConfigFile.path;
    }

    final pairingCode = _generatePairingCode();
    final manifest = {
      'type': 'jiemei-transfer',
      'createdAt': now.toIso8601String(),
      'databaseFileName': databaseFileName,
      'databasePath': packageDb.path,
      'aiConfigPath': aiConfigPackagePath,
      'pairingCode': pairingCode,
    };
    final manifestFile = File(p.join(sendDir.path, 'transfer_manifest.json'));
    await manifestFile.writeAsString(jsonEncode(manifest));

    return SendPackageResult(
      packageDirectoryPath: sendDir.path,
      databaseFilePath: packageDb.path,
      manifestPath: manifestFile.path,
      pairingCode: pairingCode,
    );
  }

  Future<SharePackageResult> createSharePackage({String? snapshotPath}) async {
    final now = (nowProvider ?? DateTime.now)();
    final documentsDir = await _documentsDirectory();
    final source =
        snapshotPath == null ? await _databaseFile() : File(snapshotPath);
    if (!await source.exists()) {
      throw BackupSourceMissingException(source.path);
    }

    final stamp = _fileStamp(now);
    final shareDir = Directory(p.join(documentsDir.path, 'shares'));
    if (!await shareDir.exists()) {
      await shareDir.create(recursive: true);
    }

    final fileName = 'jiemei-backup-$stamp.jiemei';
    final packageFile = File(p.join(shareDir.path, fileName));
    final databaseBytes = await source.readAsBytes();
    final manifestBytes = utf8.encode(
      jsonEncode({
        'type': 'jiemei-backup-share',
        'version': 1,
        'createdAt': now.toIso8601String(),
        'databaseFileName': databaseFileName,
        'sourceFileName': p.basename(source.path),
      }),
    );

    final archive = Archive()
      ..addFile(
          ArchiveFile('manifest.json', manifestBytes.length, manifestBytes))
      ..addFile(
          ArchiveFile(databaseFileName, databaseBytes.length, databaseBytes));
    final aiConfig = await _aiConfigFile();
    if (await aiConfig.exists()) {
      final aiConfigBytes = await aiConfig.readAsBytes();
      archive.addFile(
        ArchiveFile(aiConfigFileName, aiConfigBytes.length, aiConfigBytes),
      );
    }
    final encoded = ZipEncoder().encode(archive);
    await packageFile.writeAsBytes(encoded, flush: true);

    return SharePackageResult(
      fileName: fileName,
      filePath: packageFile.path,
      createdAt: now,
    );
  }

  Future<ImportResult> importSharedBackupPackage(String incomingPath) async {
    if (p.extension(incomingPath).toLowerCase() == '.sqlite') {
      return importDatabaseFromPath(incomingPath);
    }

    final incoming = File(incomingPath);
    if (!await incoming.exists()) {
      throw ImportSourceMissingException(incomingPath);
    }

    late final Archive archive;
    try {
      archive = ZipDecoder().decodeBytes(await incoming.readAsBytes());
    } on Object {
      throw InvalidImportDatabaseException(incomingPath);
    }

    ArchiveFile? manifestFile;
    ArchiveFile? databaseFile;
    ArchiveFile? aiConfigArchiveFile;
    for (final file in archive.files) {
      if (file.name == 'manifest.json') {
        manifestFile = file;
      } else if (p.basename(file.name) == databaseFileName) {
        databaseFile = file;
      } else if (p.basename(file.name) == aiConfigFileName) {
        aiConfigArchiveFile = file;
      }
    }
    if (manifestFile == null || databaseFile == null) {
      throw InvalidImportDatabaseException(incomingPath);
    }

    try {
      final manifest = jsonDecode(
        utf8.decode(_archiveContentBytes(manifestFile)),
      );
      if (manifest is! Map<String, dynamic> ||
          manifest['type'] != 'jiemei-backup-share') {
        throw const FormatException('invalid manifest');
      }
    } on Object {
      throw InvalidImportDatabaseException(incomingPath);
    }

    final tempDir = Directory(p.join(
      (await _documentsDirectory()).path,
      'imports',
      _fileStamp((nowProvider ?? DateTime.now)()),
    ));
    if (!await tempDir.exists()) {
      await tempDir.create(recursive: true);
    }
    final extractedDatabase = File(p.join(tempDir.path, databaseFileName));
    await extractedDatabase.writeAsBytes(
      _archiveContentBytes(databaseFile),
      flush: true,
    );
    String? extractedAiConfigPath;
    if (aiConfigArchiveFile != null) {
      final extractedAiConfig = File(p.join(tempDir.path, aiConfigFileName));
      await extractedAiConfig.writeAsBytes(
        _archiveContentBytes(aiConfigArchiveFile),
        flush: true,
      );
      extractedAiConfigPath = extractedAiConfig.path;
    }

    final result = await importDatabaseFromPath(
      extractedDatabase.path,
      incomingAiConfigPath: extractedAiConfigPath,
    );
    return ImportResult(
      importedFromPath: incomingPath,
      backupFilePath: result.backupFilePath,
      backupFileName: result.backupFileName,
    );
  }

  Future<ImportResult> importDatabaseFromPath(
    String incomingPath, {
    String? incomingAiConfigPath,
  }) async {
    final incoming = await _resolveIncomingFile(incomingPath);
    if (incoming == null) {
      throw ImportSourceMissingException(incomingPath);
    }
    final content = await incoming.openRead(0, 16).fold<List<int>>(
      <int>[],
      (all, chunk) => all..addAll(chunk),
    );
    final header = ascii.decode(content, allowInvalid: true);
    if (!header.startsWith('SQLite format 3')) {
      throw InvalidImportDatabaseException(incomingPath);
    }

    final target = await _databaseFile();
    if (!await target.exists()) {
      throw BackupSourceMissingException(target.path);
    }

    final backup = await createLocalBackup(reason: BackupReason.beforeImport);
    try {
      _overwriteBusinessTables(target: target, incoming: incoming);
      await _restoreAiConfigFromPath(incomingAiConfigPath);
      return ImportResult(
        importedFromPath: incomingPath,
        backupFilePath: backup.filePath,
        backupFileName: backup.fileName,
      );
    } on Object catch (error) {
      throw ImportDatabaseFailedException(error);
    }
  }

  Future<ResetDatabaseResult> resetDatabase() async {
    final now = (nowProvider ?? DateTime.now)();
    final target = await _databaseFile();
    if (!await target.exists()) {
      throw BackupSourceMissingException(target.path);
    }

    final backup = await createLocalBackup(reason: BackupReason.beforeReset);
    _clearBusinessTables(target);
    final sidecars = <String>[
      '${target.path}-wal',
      '${target.path}-shm',
      '${target.path}-journal',
    ];
    for (final sidecar in sidecars) {
      final file = File(sidecar);
      if (await file.exists()) {
        await file.delete();
      }
    }

    return ResetDatabaseResult(
      backupFileName: backup.fileName,
      resetAt: now,
    );
  }

  void _clearBusinessTables(File target) {
    final db = sqlite.sqlite3.open(target.path);
    try {
      db.execute('PRAGMA foreign_keys = OFF;');
      db.execute('BEGIN IMMEDIATE;');
      try {
        _deleteBusinessRows(db, schema: 'main');
        db.execute('COMMIT;');
      } on Object {
        db.execute('ROLLBACK;');
        rethrow;
      } finally {
        db.execute('PRAGMA foreign_keys = ON;');
      }
      db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    } finally {
      db.close();
    }
  }

  void _overwriteBusinessTables({
    required File target,
    required File incoming,
  }) {
    final db = sqlite.sqlite3.open(target.path);
    try {
      db.execute(
          "ATTACH DATABASE '${_escapeSqlString(incoming.path)}' AS incoming;");
      db.execute('PRAGMA foreign_keys = OFF;');
      db.execute('BEGIN IMMEDIATE;');
      try {
        _deleteBusinessRows(db, schema: 'main');
        _copyBusinessRows(db);
        db.execute('COMMIT;');
      } on Object {
        db.execute('ROLLBACK;');
        rethrow;
      } finally {
        db.execute('PRAGMA foreign_keys = ON;');
        db.execute('DETACH DATABASE incoming;');
      }
      db.execute('PRAGMA wal_checkpoint(TRUNCATE);');
    } finally {
      db.close();
    }
  }

  void _deleteBusinessRows(sqlite.Database db, {required String schema}) {
    for (final table in _businessTables.reversed) {
      db.execute('DELETE FROM $schema.$table;');
    }
    db.execute(
      "DELETE FROM $schema.sqlite_sequence WHERE name IN (${_businessTables.map((table) => "'$table'").join(', ')});",
    );
  }

  void _copyBusinessRows(sqlite.Database db) {
    for (final table in _businessTables) {
      final columns = _businessTableColumns[table]!;
      db.execute(
        'INSERT INTO main.$table (${columns.join(', ')}) '
        'SELECT ${columns.join(', ')} FROM incoming.$table;',
      );
    }
    db.execute(
      "DELETE FROM main.sqlite_sequence WHERE name IN (${_businessTables.map((table) => "'$table'").join(', ')});",
    );
    for (final table in _businessTables) {
      db.execute(
        'INSERT OR REPLACE INTO main.sqlite_sequence(name, seq) '
        "SELECT '$table', COALESCE(MAX(id), 0) FROM main.$table;",
      );
    }
  }

  String _escapeSqlString(String value) => value.replaceAll("'", "''");

  String _fileStamp(DateTime value) {
    String pad2(int n) => n.toString().padLeft(2, '0');
    return '${value.year}${pad2(value.month)}${pad2(value.day)}-${pad2(value.hour)}${pad2(value.minute)}${pad2(value.second)}';
  }

  String _generatePairingCode() {
    final random = randomIntProvider ?? Random().nextInt;
    final code = random(1000000);
    return code.toString().padLeft(6, '0');
  }

  Future<Directory> _documentsDirectory() {
    final provider = documentsDirectoryProvider;
    if (provider != null) {
      return provider();
    }
    return getApplicationDocumentsDirectory();
  }

  Future<Directory> _databaseDirectory() async {
    final provider = databaseDirectoryProvider;
    if (provider != null) {
      return provider();
    }
    // Tests inject only the documents directory. Keep that behavior there,
    // while Android/iOS production uses sqflite's actual database folder.
    if (documentsDirectoryProvider != null) {
      return documentsDirectoryProvider!();
    }
    if (Platform.isAndroid || Platform.isIOS) {
      return Directory(await getDatabasesPath());
    }
    return _documentsDirectory();
  }

  Future<File> _databaseFile() async {
    final databaseDir = await _databaseDirectory();
    return File(p.join(databaseDir.path, databaseFileName));
  }

  Future<File> _backupSettingsFile() async {
    final documentsDir = await _documentsDirectory();
    return File(p.join(documentsDir.path, 'backups', '.backup_settings.json'));
  }

  Future<File> _aiConfigFile() async {
    final documentsDir = await _documentsDirectory();
    return File(p.join(documentsDir.path, aiConfigFileName));
  }

  Future<void> _restoreAiConfigFromPath(String? incomingAiConfigPath) async {
    final path = incomingAiConfigPath?.trim();
    if (path == null || path.isEmpty) {
      return;
    }
    final incoming = File(path);
    if (!await incoming.exists()) {
      return;
    }
    final target = await _aiConfigFile();
    await target.parent.create(recursive: true);
    await incoming.copy(target.path);
  }

  Future<int> _pruneBackupsByCount({required int maxCount}) async {
    if (maxCount < 1) {
      return 0;
    }
    final snapshots = await listLocalBackups();
    if (snapshots.length <= maxCount) {
      return 0;
    }
    var deleted = 0;
    for (final snapshot in snapshots.skip(maxCount)) {
      await deleteBackupSnapshot(snapshot.filePath);
      deleted += 1;
    }
    return deleted;
  }

  Future<File?> _resolveIncomingFile(String incomingPath) async {
    final incomingFile = File(incomingPath);
    if (await incomingFile.exists()) {
      if (p.basename(incomingPath) == 'transfer_manifest.json') {
        final content = jsonDecode(await incomingFile.readAsString());
        if (content is Map<String, dynamic>) {
          final dbPath = content['databasePath'] as String?;
          if (dbPath != null && dbPath.isNotEmpty) {
            final dbFile = File(dbPath);
            if (await dbFile.exists()) {
              return dbFile;
            }
          }
        }
        return null;
      }
      return incomingFile;
    }

    final incomingDir = Directory(incomingPath);
    if (!await incomingDir.exists()) {
      return null;
    }
    final manifestFile =
        File(p.join(incomingDir.path, 'transfer_manifest.json'));
    if (await manifestFile.exists()) {
      final content = jsonDecode(await manifestFile.readAsString());
      if (content is Map<String, dynamic>) {
        final dbPath = content['databasePath'] as String?;
        if (dbPath != null && dbPath.isNotEmpty) {
          final dbFile = File(dbPath);
          if (await dbFile.exists()) {
            return dbFile;
          }
        }
      }
    }
    final dbInDir = File(p.join(incomingDir.path, databaseFileName));
    if (await dbInDir.exists()) {
      return dbInDir;
    }
    return null;
  }

  List<int> _archiveContentBytes(ArchiveFile file) => file.content;
}

const _businessTables = <String>[
  'products',
  'batches',
  'orders',
  'order_items',
  'stock_movements',
];

const _businessTableColumns = <String, List<String>>{
  'products': [
    'id',
    'code',
    'name',
    'boxes_per_board',
    'pieces_per_box',
    'created_at',
    'updated_at',
  ],
  'batches': [
    'id',
    'product_id',
    'actual_batch',
    'date_batch',
    'initial_boxes',
    'boxes_per_board',
    'stacking_pattern',
    'location',
    'has_shipped',
    'ts_required',
    'remark',
    'created_at',
    'updated_at',
  ],
  'orders': [
    'id',
    'waybill_no',
    'merchant_name',
    'order_date',
    'status',
    'remark',
    'created_at',
    'updated_at',
  ],
  'order_items': [
    'id',
    'order_id',
    'product_id',
    'batch_id',
    'boxes',
    'boxes_per_board',
    'pieces_per_box',
    'created_at',
  ],
  'stock_movements': [
    'id',
    'batch_id',
    'order_id',
    'movement_date',
    'type',
    'boxes',
    'remark',
    'created_at',
  ],
};

class BackupDraft {
  const BackupDraft({
    required this.databasePath,
    required this.fileName,
    required this.note,
  });

  final String databasePath;
  final String fileName;
  final String note;
}

class BackupResult {
  const BackupResult({
    required this.fileName,
    required this.filePath,
    required this.infoPath,
    required this.note,
  });

  final String fileName;
  final String filePath;
  final String infoPath;
  final String note;
}

class BackupSnapshot {
  const BackupSnapshot({
    required this.fileName,
    required this.filePath,
    required this.createdAt,
    required this.sizeBytes,
    required this.reason,
    this.infoPath,
  });

  final String fileName;
  final String filePath;
  final String? infoPath;
  final DateTime createdAt;
  final int sizeBytes;
  final BackupReason reason;
}

class BackupSourceMissingException implements Exception {
  const BackupSourceMissingException(this.sourcePath);

  final String sourcePath;

  @override
  String toString() => 'BackupSourceMissingException(sourcePath: $sourcePath)';
}

class SendPackageResult {
  const SendPackageResult({
    required this.packageDirectoryPath,
    required this.databaseFilePath,
    required this.manifestPath,
    required this.pairingCode,
  });

  final String packageDirectoryPath;
  final String databaseFilePath;
  final String manifestPath;
  final String pairingCode;
}

class SharePackageResult {
  const SharePackageResult({
    required this.fileName,
    required this.filePath,
    required this.createdAt,
  });

  final String fileName;
  final String filePath;
  final DateTime createdAt;
}

class ImportSourceMissingException implements Exception {
  const ImportSourceMissingException(this.sourcePath);

  final String sourcePath;

  @override
  String toString() => 'ImportSourceMissingException(sourcePath: $sourcePath)';
}

class InvalidImportDatabaseException implements Exception {
  const InvalidImportDatabaseException(this.sourcePath);

  final String sourcePath;

  @override
  String toString() =>
      'InvalidImportDatabaseException(sourcePath: $sourcePath)';
}

class ImportDatabaseFailedException implements Exception {
  const ImportDatabaseFailedException(this.error);

  final Object error;

  @override
  String toString() => 'ImportDatabaseFailedException(error: $error)';
}

class ImportResult {
  const ImportResult({
    required this.importedFromPath,
    required this.backupFilePath,
    required this.backupFileName,
  });

  final String importedFromPath;
  final String backupFilePath;
  final String backupFileName;
}

class ResetDatabaseResult {
  const ResetDatabaseResult({
    required this.backupFileName,
    required this.resetAt,
  });

  final String backupFileName;
  final DateTime resetAt;
}

import 'dart:convert';
import 'dart:io';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef DocumentsDirectoryProvider = Future<Directory> Function();
typedef NowProvider = DateTime Function();
typedef RandomIntProvider = int Function(int max);

class BackupService {
  const BackupService({
    required this.databaseFileName,
    this.documentsDirectoryProvider,
    this.nowProvider,
    this.randomIntProvider,
  });

  final String databaseFileName;
  final DocumentsDirectoryProvider? documentsDirectoryProvider;
  final NowProvider? nowProvider;
  final RandomIntProvider? randomIntProvider;

  BackupDraft createLocalBackupDraft() {
    final now = (nowProvider ?? DateTime.now)();
    final stamp = _fileStamp(now);
    return BackupDraft(
      databasePath: databaseFileName,
      fileName: 'jiemei-backup-$stamp.sqlite',
      note: '本地备份入口保留在局域网迁移页面，避免与首页入口重复。',
    );
  }

  Future<BackupResult> createLocalBackup() async {
    final now = (nowProvider ?? DateTime.now)();
    final documentsDir = await (documentsDirectoryProvider ??
        getApplicationDocumentsDirectory)();
    final source = File(p.join(documentsDir.path, databaseFileName));
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

    final infoFileName = 'jiemei-backup-$stamp.backup_info.json';
    final infoFile = File(p.join(backupDir.path, infoFileName));
    await infoFile.writeAsString(
      jsonEncode({
        'createdAt': now.toIso8601String(),
        'databaseFileName': databaseFileName,
        'sourceDatabasePath': source.path,
        'backupDatabasePath': backupFile.path,
      }),
    );

    return BackupResult(
      fileName: backupFileName,
      filePath: backupFile.path,
      infoPath: infoFile.path,
      note: '备份已生成，可用于局域网迁移接收端导入。',
    );
  }

  Future<SendPackageResult> createSendPackage() async {
    final now = (nowProvider ?? DateTime.now)();
    final documentsDir = await (documentsDirectoryProvider ??
        getApplicationDocumentsDirectory)();
    final source = File(p.join(documentsDir.path, databaseFileName));
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

    final pairingCode = _generatePairingCode();
    final manifest = {
      'type': 'jiemei-transfer',
      'createdAt': now.toIso8601String(),
      'databaseFileName': databaseFileName,
      'databasePath': packageDb.path,
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

  Future<ImportResult> importDatabaseFromPath(String incomingPath) async {
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

    final documentsDir = await (documentsDirectoryProvider ??
        getApplicationDocumentsDirectory)();
    final target = File(p.join(documentsDir.path, databaseFileName));
    if (!await target.exists()) {
      throw BackupSourceMissingException(target.path);
    }

    final backup = await createLocalBackup();
    final tempImport = File('${target.path}.importing');
    try {
      if (await tempImport.exists()) {
        await tempImport.delete();
      }
      await incoming.copy(tempImport.path);
      await target.delete();
      await tempImport.rename(target.path);
      return ImportResult(
        importedFromPath: incomingPath,
        backupFilePath: backup.filePath,
        backupFileName: backup.fileName,
      );
    } on FileSystemException catch (error) {
      throw ImportDatabaseFailedException(error);
    }
  }

  Future<ResetDatabaseResult> resetDatabase() async {
    final now = (nowProvider ?? DateTime.now)();
    final documentsDir = await (documentsDirectoryProvider ??
        getApplicationDocumentsDirectory)();
    final target = File(p.join(documentsDir.path, databaseFileName));
    if (!await target.exists()) {
      throw BackupSourceMissingException(target.path);
    }

    final backup = await createLocalBackup();
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
    await target.delete();

    return ResetDatabaseResult(
      backupFileName: backup.fileName,
      resetAt: now,
    );
  }

  String _fileStamp(DateTime value) {
    String pad2(int n) => n.toString().padLeft(2, '0');
    return '${value.year}${pad2(value.month)}${pad2(value.day)}-${pad2(value.hour)}${pad2(value.minute)}${pad2(value.second)}';
  }

  String _generatePairingCode() {
    final random = randomIntProvider ?? Random().nextInt;
    final code = random(1000000);
    return code.toString().padLeft(6, '0');
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
}

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

  final FileSystemException error;

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

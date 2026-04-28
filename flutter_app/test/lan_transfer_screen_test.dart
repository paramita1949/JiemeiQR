import 'dart:convert';
import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/features/transfer/backup_service.dart';
import 'package:qrscan_flutter/features/transfer/lan_transfer_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

class _ResetOnlyBackupService extends BackupService {
  _ResetOnlyBackupService() : super(databaseFileName: 'jiemei.sqlite');

  bool resetCalled = false;

  @override
  Future<ResetDatabaseResult> resetDatabase() async {
    resetCalled = true;
    return ResetDatabaseResult(
      backupFileName: 'test-backup.sqlite',
      resetAt: DateTime(2026, 4, 28),
    );
  }

  @override
  Future<List<BackupSnapshot>> listLocalBackups() async => const [];
}

Future<void> _createBusinessDatabase(
  File file, {
  required String productCode,
}) async {
  final database = AppDatabase.forTesting(NativeDatabase(file));
  try {
    await database.into(database.products).insert(
          ProductsCompanion.insert(
            code: productCode,
            name: '测试产品$productCode',
            boxesPerBoard: 40,
            piecesPerBox: 30,
          ),
        );
  } finally {
    await database.close();
  }
}

List<String> _productCodes(File file) {
  final db = sqlite.sqlite3.open(file.path);
  try {
    return db
        .select('SELECT code FROM products ORDER BY code')
        .map((row) => row['code'] as String)
        .toList();
  } finally {
    db.close();
  }
}

Future<void> _overwriteProducts(
  File file, {
  required String productCode,
}) async {
  final database = AppDatabase.forTesting(NativeDatabase(file));
  try {
    await database.delete(database.products).go();
    await database.into(database.products).insert(
          ProductsCompanion.insert(
            code: productCode,
            name: '测试产品$productCode',
            boxesPerBoard: 40,
            piecesPerBox: 30,
          ),
        );
  } finally {
    await database.close();
  }
}

void main() {
  test('backup service creates local backup and metadata file', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('jiemei-backup-test-');
    final sourceFile = File('${tempDir.path}/jiemei.sqlite');
    await sourceFile.writeAsString('sqlite-bytes');
    final service = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => tempDir,
      nowProvider: () => DateTime(2026, 4, 26, 9, 30, 15),
    );

    final draft = service.createLocalBackupDraft();
    final result = await service.createLocalBackup();

    expect(draft.databasePath, 'jiemei.sqlite');
    expect(draft.fileName, 'jiemei-backup-20260426-093015.sqlite');
    expect(draft.note, contains('数据备份'));

    final backupFile = File(result.filePath);
    final metadataFile = File(result.infoPath);
    expect(await backupFile.exists(), isTrue);
    expect(await metadataFile.exists(), isTrue);
    expect(await backupFile.readAsString(), 'sqlite-bytes');

    final metadata =
        jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;
    expect(metadata['databaseFileName'], 'jiemei.sqlite');
    expect(metadata['backupDatabasePath'], result.filePath);
  });

  test('backup service lists snapshots by date and restores selected snapshot',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('jiemei-restore-test-');
    final currentDb = File('${tempDir.path}/jiemei.sqlite');
    await _createBusinessDatabase(currentDb, productCode: 'CURRENT');
    var now = DateTime(2026, 4, 26, 8, 0, 0);
    final service = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => tempDir,
      nowProvider: () => now,
    );

    final older = await service.createLocalBackup();
    await _overwriteProducts(currentDb, productCode: 'NEWER');
    now = DateTime(2026, 4, 26, 9, 0, 0);
    final newer = await service.createLocalBackup();
    await _overwriteProducts(currentDb, productCode: 'ACTIVE');

    final snapshots = await service.listLocalBackups();

    expect(snapshots.map((snapshot) => snapshot.fileName), [
      newer.fileName,
      older.fileName,
    ]);

    final restore = await service.restoreBackupSnapshot(older.filePath);

    expect(restore.backupFileName, isNotEmpty);
    expect(_productCodes(currentDb), ['CURRENT']);
  });

  test('backup service reads source database from database directory',
      () async {
    final documentsDir =
        await Directory.systemTemp.createTemp('jiemei-docs-test-');
    final databaseDir =
        await Directory.systemTemp.createTemp('jiemei-db-test-');
    final sourceFile = File(p.join(databaseDir.path, 'jiemei.sqlite'));
    await sourceFile.writeAsString('sqlite-from-db-dir');
    final service = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => documentsDir,
      databaseDirectoryProvider: () async => databaseDir,
      nowProvider: () => DateTime(2026, 4, 26, 9, 45, 0),
    );

    final result = await service.createLocalBackup();

    final backupFile = File(result.filePath);
    final metadataFile = File(result.infoPath);
    expect(await backupFile.readAsString(), 'sqlite-from-db-dir');
    expect(result.filePath, contains(documentsDir.path));
    final metadata =
        jsonDecode(await metadataFile.readAsString()) as Map<String, dynamic>;
    expect(
      p.equals(metadata['sourceDatabasePath'] as String, sourceFile.path),
      isTrue,
    );
  });

  test('backup service creates send package with manifest and pairing code',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('jiemei-send-test-');
    final sourceFile = File('${tempDir.path}/jiemei.sqlite');
    await sourceFile.writeAsString('sqlite-source');

    final service = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => tempDir,
      nowProvider: () => DateTime(2026, 4, 26, 11, 0, 0),
      randomIntProvider: (_) => 123456,
    );

    final result = await service.createSendPackage();
    final dbFile = File(result.databaseFilePath);
    final manifestFile = File(result.manifestPath);
    expect(result.pairingCode, '123456');
    expect(await dbFile.exists(), isTrue);
    expect(await dbFile.readAsString(), 'sqlite-source');
    expect(await manifestFile.exists(), isTrue);
    final manifest =
        jsonDecode(await manifestFile.readAsString()) as Map<String, dynamic>;
    expect(manifest['type'], 'jiemei-transfer');
    expect(manifest['pairingCode'], '123456');
  });

  test('backup service imports database with sql overwrite, not file replace',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('jiemei-import-test-');
    final currentDb = File('${tempDir.path}/jiemei.sqlite');
    final incomingDb = File('${tempDir.path}/incoming.sqlite');
    await _createBusinessDatabase(currentDb, productCode: 'OLD');
    await _createBusinessDatabase(incomingDb, productCode: 'NEW');

    final currentSqlite = sqlite.sqlite3.open(currentDb.path);
    currentSqlite.execute('CREATE TABLE local_marker (value TEXT NOT NULL);');
    currentSqlite.execute("INSERT INTO local_marker VALUES ('keep-me');");
    currentSqlite.close();

    final service = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => tempDir,
      nowProvider: () => DateTime(2026, 4, 26, 10, 0, 0),
    );

    final result = await service.importDatabaseFromPath(incomingDb.path);

    expect(_productCodes(currentDb), ['NEW']);
    expect(File(result.backupFilePath).existsSync(), isTrue);
    expect(result.importedFromPath, incomingDb.path);

    final afterImport = sqlite.sqlite3.open(currentDb.path);
    try {
      final marker = afterImport.select('SELECT value FROM local_marker');
      expect(marker.single['value'], 'keep-me');
    } finally {
      afterImport.close();
    }
  });

  test('backup service rejects invalid import source', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('jiemei-import-invalid-test-');
    final currentDb = File('${tempDir.path}/jiemei.sqlite');
    final invalidIncoming = File('${tempDir.path}/incoming.sqlite');
    await currentDb.writeAsString('current-db');
    await invalidIncoming.writeAsString('not-a-sqlite-file');

    final service = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => tempDir,
    );

    expect(
      () => service.importDatabaseFromPath(invalidIncoming.path),
      throwsA(isA<InvalidImportDatabaseException>()),
    );
    expect(await currentDb.readAsString(), 'current-db');
  });

  test('backup service resets database with sql clear and keeps database file',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('jiemei-reset-test-');
    final db = File('${tempDir.path}/jiemei.sqlite');
    final wal = File('${tempDir.path}/jiemei.sqlite-wal');
    final shm = File('${tempDir.path}/jiemei.sqlite-shm');
    await _createBusinessDatabase(db, productCode: '72067');
    await wal.writeAsString('wal');
    await shm.writeAsString('shm');

    final service = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => tempDir,
      nowProvider: () => DateTime(2026, 4, 26, 12, 0, 0),
    );

    final result = await service.resetDatabase();

    expect(result.backupFileName, 'jiemei-backup-20260426-120000.sqlite');
    expect(await db.exists(), isTrue);
    expect(_productCodes(db), isEmpty);
    expect(await wal.exists(), isFalse);
    expect(await shm.exists(), isFalse);
  });

  testWidgets('shows simple send and receive entry points', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const LanTransferScreen(),
      ),
    );

    expect(find.text('数据备份'), findsWidgets);
    expect(find.text('发送'), findsOneWidget);
    expect(find.text('接收'), findsOneWidget);
    expect(find.text('本地备份'), findsOneWidget);
    expect(find.textContaining('发送地址'), findsNothing);
  });

  testWidgets('reset database reopens without seeding embedded stock',
      (tester) async {
    final backupService = _ResetOnlyBackupService();
    var prepareCalled = false;
    bool? requestedSeedIfEmpty;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: Builder(
          builder: (context) => FilledButton(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => LanTransferScreen(
                  backupService: backupService,
                  onPrepareImport: () async => prepareCalled = true,
                  onImportCompleted: ({bool seedIfEmpty = true}) async {
                    requestedSeedIfEmpty = seedIfEmpty;
                  },
                ),
              ),
            ),
            child: const Text('打开数据备份'),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开数据备份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重置数据库'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认重置'));
    await tester.pumpAndSettle();

    expect(prepareCalled, isTrue);
    expect(backupService.resetCalled, isTrue);
    expect(requestedSeedIfEmpty, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });
}

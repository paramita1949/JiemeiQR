import 'dart:convert';
import 'dart:io';
import 'dart:async';

import 'package:archive/archive.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:path/path.dart' as p;
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/features/transfer/backup_service.dart';
import 'package:qrscan_flutter/features/transfer/lan_transfer_screen.dart';
import 'package:qrscan_flutter/features/transfer/lan_transfer_service.dart';
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

class _NoopBackupService extends BackupService {
  const _NoopBackupService() : super(databaseFileName: 'jiemei.sqlite');

  @override
  Future<BackupSchedule> getBackupSchedule() async => BackupSchedule.off;

  @override
  Future<BackupResult?> runAutoBackupIfDue() async => null;

  @override
  Future<List<BackupSnapshot>> listLocalBackups() async => const [];
}

class _ShareImportBackupService extends BackupService {
  _ShareImportBackupService()
      : super(
          databaseFileName: 'jiemei.sqlite',
          nowProvider: () => DateTime(2026, 4, 30, 17, 0, 0),
        );

  int createSharePackageCalls = 0;
  String? sharedSnapshotPath;
  String? importedPackagePath;

  final snapshot = BackupSnapshot(
    fileName: 'jiemei-backup-20260430-160000.sqlite',
    filePath: 'C:/tmp/jiemei-backup-20260430-160000.sqlite',
    createdAt: DateTime(2026, 4, 30, 16, 0, 0),
    sizeBytes: 1024,
    reason: BackupReason.manual,
  );

  @override
  Future<BackupSchedule> getBackupSchedule() async => BackupSchedule.off;

  @override
  Future<BackupResult?> runAutoBackupIfDue() async => null;

  @override
  Future<List<BackupSnapshot>> listLocalBackups() async => [snapshot];

  @override
  Future<SharePackageResult> createSharePackage({String? snapshotPath}) async {
    createSharePackageCalls += 1;
    sharedSnapshotPath = snapshotPath;
    return SharePackageResult(
      fileName: 'jiemei-backup-20260430-170000.jiemei',
      filePath: 'C:/tmp/jiemei-backup-20260430-170000.jiemei',
      createdAt: DateTime(2026, 4, 30, 17, 0, 0),
    );
  }

  @override
  Future<ImportResult> importSharedBackupPackage(String incomingPath) async {
    importedPackagePath = incomingPath;
    return const ImportResult(
      importedFromPath: 'C:/tmp/incoming.jiemei',
      backupFilePath: 'C:/tmp/protected.sqlite',
      backupFileName: 'protected.sqlite',
    );
  }
}

class _ImmediateReceiveLanTransferService extends LanTransferService {
  _ImmediateReceiveLanTransferService()
      : super(backupService: const _NoopBackupService());

  @override
  Future<ReceiveResult> receiveByPairingCode(
    String pairingCode, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    return const ReceiveResult(
      importedFromPath: 'incoming.sqlite',
      backupFileName: 'received-backup.sqlite',
    );
  }
}

class _NearbyReceiveLanTransferService extends LanTransferService {
  _NearbyReceiveLanTransferService()
      : super(backupService: const _NoopBackupService());

  DiscoveryAnnouncement? selectedSender;

  @override
  Future<List<DiscoveryAnnouncement>> discoverSenders({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    return [
      DiscoveryAnnouncement(
        baseUri: Uri(scheme: 'http', host: '192.168.1.8', port: 54022),
        sessionId: 'session-1',
        deviceId: 'device-1',
        deviceName: '仓库手机',
        platform: 'android',
      ),
    ];
  }

  @override
  Future<ReceiveResult> receiveFromDiscoveredSender(
    DiscoveryAnnouncement sender, {
    String? receiverName,
    Duration approvalTimeout = const Duration(seconds: 60),
    Duration approvalPollInterval = const Duration(milliseconds: 500),
  }) async {
    selectedSender = sender;
    return const ReceiveResult(
      importedFromPath: 'incoming.sqlite',
      backupFileName: 'nearby-backup.sqlite',
    );
  }
}

class _FakeSendLanTransferService extends LanTransferService {
  _FakeSendLanTransferService()
      : super(backupService: const _NoopBackupService());

  bool _active = false;

  @override
  bool get hasActiveSendSession => _active;

  @override
  Future<SendSession> startSendSession() async {
    _active = true;
    return SendSession(
      pairingCode: '123456',
      baseUri: Uri(scheme: 'http', host: '127.0.0.1', port: 54022),
      baseUris: [Uri(scheme: 'http', host: '127.0.0.1', port: 54022)],
      packageDirectoryPath: '/tmp',
      manifestPath: '/tmp/manifest',
      databaseFilePath: '/tmp/jiemei.sqlite',
      connectionCode: 'JM:mock',
      sessionId: 'session-1',
      deviceId: 'device-1',
    );
  }

  @override
  Future<void> stopSendSession() async {
    _active = false;
  }
}

class _ConfirmingSendLanTransferService extends _FakeSendLanTransferService {
  final StreamController<TransferRequest> _requests =
      StreamController<TransferRequest>.broadcast();
  String? approvedRequestId;
  String? rejectedRequestId;

  @override
  Stream<TransferRequest> get transferRequests => _requests.stream;

  void emitRequest() {
    _requests.add(
      TransferRequest(
        id: 'request-1',
        receiverDeviceId: 'receiver-1',
        receiverName: '仓库手机B',
        requestedAt: DateTime(2026, 4, 29, 9, 0),
      ),
    );
  }

  @override
  Future<bool> approveTransferRequest(String requestId) async {
    approvedRequestId = requestId;
    return true;
  }

  @override
  Future<bool> rejectTransferRequest(String requestId) async {
    rejectedRequestId = requestId;
    return true;
  }
}

class _RejectingNearbyReceiveLanTransferService
    extends _NearbyReceiveLanTransferService {
  @override
  Future<ReceiveResult> receiveFromDiscoveredSender(
    DiscoveryAnnouncement sender, {
    String? receiverName,
    Duration approvalTimeout = const Duration(seconds: 60),
    Duration approvalPollInterval = const Duration(milliseconds: 500),
  }) async {
    throw const TransferRequestRejectedException('request rejected');
  }
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
    expect(metadata['reason'], BackupReason.manual.value);
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
    expect(snapshots.first.reason, BackupReason.manual);

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

  test('backup service creates share package with manifest and sqlite snapshot',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('jiemei-share-test-');
    final sourceFile = File('${tempDir.path}/jiemei.sqlite');
    await _createBusinessDatabase(sourceFile, productCode: 'SHARE');

    final service = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => tempDir,
      nowProvider: () => DateTime(2026, 4, 30, 15, 20, 0),
    );

    final package = await service.createSharePackage();

    expect(package.fileName, 'jiemei-backup-20260430-152000.jiemei');
    expect(await File(package.filePath).exists(), isTrue);

    final archive = ZipDecoder().decodeBytes(
      await File(package.filePath).readAsBytes(),
    );
    final names = archive.files.map((file) => file.name).toSet();
    expect(names, contains('manifest.json'));
    expect(names, contains('jiemei.sqlite'));

    final manifestFile =
        archive.files.singleWhere((file) => file.name == 'manifest.json');
    final manifest = jsonDecode(
      utf8.decode(manifestFile.content as List<int>),
    ) as Map<String, dynamic>;
    expect(manifest['type'], 'jiemei-backup-share');
    expect(manifest['databaseFileName'], 'jiemei.sqlite');
    expect(manifest['createdAt'], '2026-04-30T15:20:00.000');
  });

  test('backup service imports shared package through protected restore',
      () async {
    final senderDir =
        await Directory.systemTemp.createTemp('jiemei-share-sender-');
    final senderDb = File('${senderDir.path}/jiemei.sqlite');
    await _createBusinessDatabase(senderDb, productCode: 'FROM_SHARE');
    final senderService = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => senderDir,
      nowProvider: () => DateTime(2026, 4, 30, 15, 30, 0),
    );
    final package = await senderService.createSharePackage();

    final receiverDir =
        await Directory.systemTemp.createTemp('jiemei-share-receiver-');
    final receiverDb = File('${receiverDir.path}/jiemei.sqlite');
    await _createBusinessDatabase(receiverDb, productCode: 'CURRENT');
    final receiverService = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => receiverDir,
      nowProvider: () => DateTime(2026, 4, 30, 16, 0, 0),
    );

    final result =
        await receiverService.importSharedBackupPackage(package.filePath);

    expect(_productCodes(receiverDb), ['FROM_SHARE']);
    expect(result.importedFromPath, package.filePath);
    expect(await File(result.backupFilePath).exists(), isTrue);
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

  test('backup service auto backup respects daily schedule', () async {
    final tempDir = await Directory.systemTemp.createTemp('jiemei-auto-test-');
    final db = File('${tempDir.path}/jiemei.sqlite');
    await _createBusinessDatabase(db, productCode: '72067');
    var now = DateTime(2026, 4, 26, 9, 0, 0);
    final service = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => tempDir,
      nowProvider: () => now,
    );

    await service.setBackupSchedule(BackupSchedule.daily);
    final first = await service.runAutoBackupIfDue();
    final second = await service.runAutoBackupIfDue();
    now = DateTime(2026, 4, 27, 10, 0, 0);
    final third = await service.runAutoBackupIfDue();

    expect(first, isNotNull);
    expect(second, isNull);
    expect(third, isNotNull);
    final snapshots = await service.listLocalBackups();
    expect(
      snapshots.where((item) => item.reason == BackupReason.autoDaily).length,
      2,
    );
  });

  test('backup service deletes snapshot and cleans old backups', () async {
    final tempDir =
        await Directory.systemTemp.createTemp('jiemei-cleanup-test-');
    final db = File('${tempDir.path}/jiemei.sqlite');
    await _createBusinessDatabase(db, productCode: '72067');
    var now = DateTime(2026, 4, 26, 9, 0, 0);
    final service = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => tempDir,
      nowProvider: () => now,
    );

    final a = await service.createLocalBackup();
    now = DateTime(2026, 4, 26, 10, 0, 0);
    await service.createLocalBackup();
    now = DateTime(2026, 4, 26, 11, 0, 0);
    await service.createLocalBackup();

    await service.deleteBackupSnapshot(a.filePath);
    final afterDelete = await service.listLocalBackups();
    expect(afterDelete.length, 2);

    final deleted = await service.cleanupBackupsByCount(keepLatest: 1);
    final afterCleanup = await service.listLocalBackups();
    expect(deleted, 1);
    expect(afterCleanup.length, 1);
  });

  testWidgets('shows simple send and receive entry points', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const LanTransferScreen(),
      ),
    );

    expect(find.text('数据备份'), findsWidgets);
    expect(find.text('快照恢复 + 局域网互传'), findsNothing);
    expect(find.text('发送'), findsOneWidget);
    expect(find.text('接收'), findsOneWidget);
    expect(find.text('生成二维码'), findsNothing);
    expect(find.text('本地备份'), findsNothing);
    expect(find.text('传到电脑'), findsNothing);
    expect(find.text('自动备份'), findsOneWidget);
    expect(find.text('每天一次'), findsOneWidget);
    expect(find.text('每周一次'), findsOneWidget);
    expect(find.textContaining('发送地址'), findsNothing);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets('backup panel uses refined advanced action layout',
      (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LanTransferScreen(
          backupService: _ShareImportBackupService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('生成并分享'), findsNothing);
    expect(find.text('高级操作'), findsNothing);
    expect(find.text('生成备份'), findsOneWidget);
    expect(find.text('导入备份'), findsOneWidget);
    expect(find.text('清理备份'), findsOneWidget);
    expect(find.text('重置数据'), findsOneWidget);
    expect(find.textContaining('.jiemei / .sqlite'), findsOneWidget);
    expect(find.textContaining('保留最近30个'), findsOneWidget);
    expect(find.textContaining('重置前自动备份'), findsOneWidget);
  });

  testWidgets('shares selected snapshot and imports selected backup file',
      (tester) async {
    final backupService = _ShareImportBackupService();
    String? sharedPath;
    var reloadCalled = false;

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LanTransferScreen(
          backupService: backupService,
          shareFile: (path, fileName) async => sharedPath = path,
          pickImportFile: () async => 'C:/tmp/incoming.jiemei',
          onImportCompleted: ({bool seedIfEmpty = true}) async {
            reloadCalled = true;
          },
        ),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('分享'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -480));
    await tester.pumpAndSettle();
    await tester.tap(find.text('分享'));
    await tester.pumpAndSettle();
    expect(
      backupService.sharedSnapshotPath,
      'C:/tmp/jiemei-backup-20260430-160000.sqlite',
    );
    expect(sharedPath, 'C:/tmp/jiemei-backup-20260430-170000.jiemei');

    expect(find.text('导入备份'), findsOneWidget);
    await tester.drag(find.byType(ListView), const Offset(0, -160));
    await tester.pumpAndSettle();
    await tester.tap(find.text('导入备份'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认导入'));
    await tester.pumpAndSettle();

    expect(backupService.importedPackagePath, 'C:/tmp/incoming.jiemei');
    expect(reloadCalled, isTrue);
  });

  testWidgets('backup snapshot time stays on one line on narrow phones',
      (tester) async {
    tester.view.physicalSize = const Size(432, 936);
    tester.view.devicePixelRatio = 1;
    addTearDown(tester.view.resetPhysicalSize);
    addTearDown(tester.view.resetDevicePixelRatio);

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LanTransferScreen(
          backupService: _ShareImportBackupService(),
          lanTransferService: _FakeSendLanTransferService(),
        ),
      ),
    );
    await tester.pumpAndSettle();

    final snapshotTime = tester.widget<Text>(
      find.text('2026.4.30 16:00'),
    );
    expect(snapshotTime.maxLines, 1);
    expect(snapshotTime.softWrap, isFalse);
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
    await tester.drag(find.byType(ListView), const Offset(0, -220));
    await tester.pumpAndSettle();
    await tester.tap(find.text('重置数据'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('确认重置'));
    await tester.pumpAndSettle();

    expect(prepareCalled, isTrue);
    expect(backupService.resetCalled, isTrue);
    expect(requestedSeedIfEmpty, isFalse);
    await tester.pumpWidget(const SizedBox.shrink());
  });

  testWidgets('receive finishes without rebuilding active transfer route',
      (tester) async {
    var rootVersion = 0;

    await tester.pumpWidget(
      StatefulBuilder(
        builder: (context, setRootState) => MaterialApp(
          theme: AppTheme.light(),
          home: Scaffold(
            body: Builder(
              builder: (context) => FilledButton(
                onPressed: () => Navigator.of(context).push(
                  MaterialPageRoute(
                    builder: (_) => LanTransferScreen(
                      backupService: const _NoopBackupService(),
                      lanTransferService: _ImmediateReceiveLanTransferService(),
                      onPrepareImport: () async {},
                      onImportCompleted: ({bool seedIfEmpty = true}) async {
                        setRootState(() => rootVersion += 1);
                      },
                    ),
                  ),
                ),
                child: Text('打开数据备份 $rootVersion'),
              ),
            ),
          ),
        ),
      ),
    );

    await tester.tap(find.text('打开数据备份 0'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('接收'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('输入6位配对码'));
    await tester.pumpAndSettle();
    final fields = find.byType(TextField);
    expect(fields, findsNWidgets(6));
    await tester.enterText(fields.at(0), '1');
    await tester.enterText(fields.at(1), '2');
    await tester.enterText(fields.at(2), '3');
    await tester.enterText(fields.at(3), '4');
    await tester.enterText(fields.at(4), '5');
    await tester.enterText(fields.at(5), '6');
    await tester.pumpAndSettle();

    expect(tester.takeException(), isNull);
    expect(find.text('接收完成'), findsOneWidget);
  });

  testWidgets('receive lists nearby devices before fallback pairing code',
      (tester) async {
    final lanTransferService = _NearbyReceiveLanTransferService();

    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LanTransferScreen(
          backupService: const _NoopBackupService(),
          lanTransferService: lanTransferService,
          onPrepareImport: () async {},
          onImportCompleted: ({bool seedIfEmpty = true}) async {},
        ),
      ),
    );

    await tester.tap(find.text('接收'));
    await tester.pumpAndSettle();

    expect(find.text('发现附近设备'), findsOneWidget);
    expect(find.text('仓库手机'), findsOneWidget);
    expect(find.text('扫码接收'), findsOneWidget);
    expect(find.text('输入6位配对码'), findsOneWidget);

    await tester.tap(find.text('仓库手机'));
    await tester.pumpAndSettle();

    expect(lanTransferService.selectedSender?.deviceName, '仓库手机');
    expect(find.text('接收完成'), findsOneWidget);
  });

  testWidgets('send panel keeps status text minimal with fallback pairing code',
      (tester) async {
    final lanTransferService = _FakeSendLanTransferService();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LanTransferScreen(
          backupService: const _NoopBackupService(),
          lanTransferService: lanTransferService,
        ),
      ),
    );

    await tester.tap(find.text('发送'));
    await tester.pump();

    expect(find.text('等待附近设备接收'), findsNothing);
    expect(find.text('接收端会自动发现本机，也可用配对码兜底'), findsNothing);
    expect(find.text('等待接收端输入并连接...'), findsNothing);
    expect(find.text('123456'), findsOneWidget);
    expect(find.text('复制二维码内容'), findsNothing);
    expect(find.byType(TextField), findsNothing);
    await tester.tap(find.text('停止'));
    await tester.pump(const Duration(milliseconds: 300));
    expect(find.text('发送已停止'), findsNothing);
  });

  testWidgets('sender confirms nearby receive request', (tester) async {
    final lanTransferService = _ConfirmingSendLanTransferService();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LanTransferScreen(
          backupService: const _NoopBackupService(),
          lanTransferService: lanTransferService,
        ),
      ),
    );

    await tester.tap(find.text('发送'));
    await tester.pump();
    lanTransferService.emitRequest();
    await tester.pump();

    expect(find.text('接收请求'), findsOneWidget);
    expect(find.textContaining('仓库手机B'), findsOneWidget);
    await tester.tap(find.text('允许'));
    await tester.pump();

    expect(lanTransferService.approvedRequestId, 'request-1');
  });

  testWidgets('nearby receive shows sender rejection explicitly',
      (tester) async {
    final lanTransferService = _RejectingNearbyReceiveLanTransferService();
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: LanTransferScreen(
          backupService: const _NoopBackupService(),
          lanTransferService: lanTransferService,
          onPrepareImport: () async {},
          onImportCompleted: ({bool seedIfEmpty = true}) async {},
        ),
      ),
    );

    await tester.tap(find.text('接收'));
    await tester.pumpAndSettle();
    await tester.tap(find.text('仓库手机'));
    await tester.pumpAndSettle();

    expect(find.text('对方已拒绝'), findsWidgets);
  });
}

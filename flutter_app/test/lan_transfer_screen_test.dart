import 'dart:convert';
import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/features/transfer/backup_service.dart';
import 'package:qrscan_flutter/features/transfer/lan_transfer_screen.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';

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
    expect(draft.note, contains('局域网迁移'));

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

  test('backup service imports database with auto backup before replace',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('jiemei-import-test-');
    final currentDb = File('${tempDir.path}/jiemei.sqlite');
    final incomingDb = File('${tempDir.path}/incoming.sqlite');
    await currentDb.writeAsString('current-db');
    await incomingDb.writeAsString('SQLite format 3\x00incoming-db');

    final service = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => tempDir,
      nowProvider: () => DateTime(2026, 4, 26, 10, 0, 0),
    );

    final result = await service.importDatabaseFromPath(incomingDb.path);

    expect(await currentDb.readAsString(), 'SQLite format 3\x00incoming-db');
    expect(File(result.backupFilePath).existsSync(), isTrue);
    expect(File(result.backupFilePath).readAsStringSync(), 'current-db');
    expect(result.importedFromPath, incomingDb.path);
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

  testWidgets('shows send receive and backup boundary', (tester) async {
    await tester.pumpWidget(
      MaterialApp(
        theme: AppTheme.light(),
        home: const LanTransferScreen(),
      ),
    );

    expect(find.text('局域网迁移'), findsWidgets);
    expect(find.text('发送数据库'), findsOneWidget);
    expect(find.text('接收数据库'), findsOneWidget);
    expect(find.text('本地备份'), findsOneWidget);
    expect(find.text('备份/导入只在此页面处理'), findsOneWidget);
    expect(find.textContaining('自动备份当前数据库'), findsWidgets);
  });
}

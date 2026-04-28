import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/features/transfer/backup_service.dart';
import 'package:qrscan_flutter/features/transfer/lan_transfer_service.dart';

void main() {
  test('connection code round-trip parse', () {
    final service = LanTransferService(
      backupService: const BackupService(databaseFileName: 'jiemei.sqlite'),
    );
    final code = service.buildConnectionCode(
      baseUrl: 'http://127.0.0.1:12345',
      pairingCode: '778899',
    );
    final parsed = service.parseConnectionCode(code);
    expect(parsed.baseUrl, 'http://127.0.0.1:12345');
    expect(parsed.pairingCode, '778899');
  });

  test('discovery announcement round-trip parse', () {
    final service = LanTransferService(
      backupService: const BackupService(databaseFileName: 'jiemei.sqlite'),
    );
    final message = service.buildDiscoveryAnnouncement(
      baseUrl: 'http://192.168.1.8:54021',
    );

    final parsed = service.parseDiscoveryAnnouncement(message);

    expect(parsed.baseUri, Uri.parse('http://192.168.1.8:54021'));
    expect(message, isNot(contains('778899')));
  });

  test('connection code can receive database without manual address', () async {
    final senderDir =
        await Directory.systemTemp.createTemp('jiemei-qr-sender-');
    final receiverDir =
        await Directory.systemTemp.createTemp('jiemei-qr-receiver-');

    final senderDb = File('${senderDir.path}/jiemei.sqlite');
    final receiverDb = File('${receiverDir.path}/jiemei.sqlite');
    await senderDb.writeAsString('SQLite format 3\x00sender-db');
    await receiverDb.writeAsString('SQLite format 3\x00receiver-db');

    final senderService = LanTransferService(
      backupService: BackupService(
        databaseFileName: 'jiemei.sqlite',
        documentsDirectoryProvider: () async => senderDir,
        randomIntProvider: (_) => 456789,
      ),
      hostProvider: () async => '127.0.0.1',
      bindAddress: InternetAddress.loopbackIPv4,
    );
    final receiverService = LanTransferService(
      backupService: BackupService(
        databaseFileName: 'jiemei.sqlite',
        documentsDirectoryProvider: () async => receiverDir,
      ),
      tempDirectoryProvider: () async => receiverDir,
    );

    final session = await senderService.startSendSession();
    final result = await receiverService.receiveFromConnectionCode(
      session.connectionCode,
    );

    expect(result.backupFileName, isNotEmpty);
    expect(await receiverDb.readAsString(), 'SQLite format 3\x00sender-db');

    await senderService.stopSendSession();
  });

  test('lan transfer service sends and receives database with backup',
      () async {
    final senderDir =
        await Directory.systemTemp.createTemp('jiemei-lan-sender-');
    final receiverDir =
        await Directory.systemTemp.createTemp('jiemei-lan-receiver-');

    final senderDb = File('${senderDir.path}/jiemei.sqlite');
    final receiverDb = File('${receiverDir.path}/jiemei.sqlite');
    await senderDb.writeAsString('SQLite format 3\x00sender-db');
    await receiverDb.writeAsString('SQLite format 3\x00receiver-db');

    final senderBackupService = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => senderDir,
      randomIntProvider: (_) => 345678,
    );
    final receiverBackupService = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => receiverDir,
    );

    final senderService = LanTransferService(
      backupService: senderBackupService,
      hostProvider: () async => '127.0.0.1',
      bindAddress: InternetAddress.loopbackIPv4,
    );
    final receiverService = LanTransferService(
      backupService: receiverBackupService,
      tempDirectoryProvider: () async => receiverDir,
    );

    final session = await senderService.startSendSession();
    final receiveResult = await receiverService.receiveFromSender(
      baseUri: session.baseUri,
      pairingCode: session.pairingCode,
    );

    expect(await receiverDb.readAsString(), 'SQLite format 3\x00sender-db');
    final backupFile =
        File('${receiverDir.path}/backups/${receiveResult.backupFileName}');
    expect(await backupFile.exists(), isTrue);
    expect(await backupFile.readAsString(), 'SQLite format 3\x00receiver-db');

    await senderService.stopSendSession();
  });

  test('lan transfer rejects wrong pairing code', () async {
    final senderDir =
        await Directory.systemTemp.createTemp('jiemei-lan-reject-sender-');
    final receiverDir =
        await Directory.systemTemp.createTemp('jiemei-lan-reject-receiver-');

    final senderDb = File('${senderDir.path}/jiemei.sqlite');
    final receiverDb = File('${receiverDir.path}/jiemei.sqlite');
    await senderDb.writeAsString('SQLite format 3\x00sender-db');
    await receiverDb.writeAsString('SQLite format 3\x00receiver-db');

    final senderBackupService = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => senderDir,
      randomIntProvider: (_) => 112233,
    );
    final receiverBackupService = BackupService(
      databaseFileName: 'jiemei.sqlite',
      documentsDirectoryProvider: () async => receiverDir,
    );

    final senderService = LanTransferService(
      backupService: senderBackupService,
      hostProvider: () async => '127.0.0.1',
      bindAddress: InternetAddress.loopbackIPv4,
    );
    final receiverService = LanTransferService(
      backupService: receiverBackupService,
      tempDirectoryProvider: () async => receiverDir,
    );
    final session = await senderService.startSendSession();

    await expectLater(
      receiverService.receiveFromSender(
        baseUri: session.baseUri,
        pairingCode: '000000',
      ),
      throwsA(isA<PairingCodeRejectedException>()),
    );

    await senderService.stopSendSession();
    expect(await receiverDb.readAsString(), 'SQLite format 3\x00receiver-db');
  });
}

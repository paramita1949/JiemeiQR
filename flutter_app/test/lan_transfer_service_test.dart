import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/features/transfer/backup_service.dart';
import 'package:qrscan_flutter/features/transfer/lan_transfer_service.dart';
import 'package:sqlite3/sqlite3.dart' as sqlite;

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

  test('discovery announcement includes public device details only', () {
    final service = LanTransferService(
      backupService: const BackupService(databaseFileName: 'jiemei.sqlite'),
    );
    final message = service.buildDiscoveryAnnouncement(
      baseUrl: 'http://192.168.1.8:54021',
      sessionId: 'session-1',
      deviceId: 'device-1',
      deviceName: '仓库手机',
      platform: 'android',
    );

    final parsed = service.parseDiscoveryAnnouncement(message);

    expect(parsed.baseUri, Uri.parse('http://192.168.1.8:54021'));
    expect(parsed.sessionId, 'session-1');
    expect(parsed.deviceId, 'device-1');
    expect(parsed.deviceName, '仓库手机');
    expect(parsed.platform, 'android');
    expect(message, isNot(contains('778899')));
  });

  test('discovery announcement keeps multiple endpoint candidates', () {
    final service = LanTransferService(
      backupService: const BackupService(databaseFileName: 'jiemei.sqlite'),
    );
    final message = service.buildDiscoveryAnnouncement(
      baseUrl: 'http://10.8.0.4:54021',
      baseUrls: const [
        'http://10.8.0.4:54021',
        'http://192.168.1.8:54021',
      ],
      sessionId: 'session-1',
      deviceId: 'device-1',
      deviceName: '仓库手机',
      platform: 'android',
    );

    final parsed = service.parseDiscoveryAnnouncement(message);

    expect(parsed.baseUri, Uri.parse('http://10.8.0.4:54021'));
    expect(parsed.baseUris, [
      Uri.parse('http://10.8.0.4:54021'),
      Uri.parse('http://192.168.1.8:54021'),
    ]);
  });

  test('connection code can receive database without manual address', () async {
    final senderDir =
        await Directory.systemTemp.createTemp('jiemei-qr-sender-');
    final receiverDir =
        await Directory.systemTemp.createTemp('jiemei-qr-receiver-');

    final senderDb = File('${senderDir.path}/jiemei.sqlite');
    final receiverDb = File('${receiverDir.path}/jiemei.sqlite');
    await _createBusinessDatabase(senderDb, productCode: 'SENDER');
    await _createBusinessDatabase(receiverDb, productCode: 'RECEIVER');

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
    expect(_productCodes(receiverDb), ['SENDER']);

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
    await _createBusinessDatabase(senderDb, productCode: 'SENDER');
    await _createBusinessDatabase(receiverDb, productCode: 'RECEIVER');

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

    expect(_productCodes(receiverDb), ['SENDER']);
    final backupFile =
        File('${receiverDir.path}/backups/${receiveResult.backupFileName}');
    expect(await backupFile.exists(), isTrue);
    expect(_productCodes(backupFile), ['RECEIVER']);
    expect(senderService.hasActiveSendSession, isFalse);

    await senderService.stopSendSession();
  });

  test(
      'lan transfer service receives from discovered sender without code input',
      () async {
    final senderDir =
        await Directory.systemTemp.createTemp('jiemei-nearby-sender-');
    final receiverDir =
        await Directory.systemTemp.createTemp('jiemei-nearby-receiver-');

    final senderDb = File('${senderDir.path}/jiemei.sqlite');
    final receiverDb = File('${receiverDir.path}/jiemei.sqlite');
    await _createBusinessDatabase(senderDb, productCode: 'SENDER');
    await _createBusinessDatabase(receiverDb, productCode: 'RECEIVER');

    final senderService = LanTransferService(
      backupService: BackupService(
        databaseFileName: 'jiemei.sqlite',
        documentsDirectoryProvider: () async => senderDir,
        randomIntProvider: (_) => 234567,
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
    final requestFuture = senderService.transferRequests.first;
    final receiveFuture = receiverService.receiveFromDiscoveredSender(
      DiscoveryAnnouncement(
        baseUri: session.baseUri,
        sessionId: session.sessionId,
        deviceId: session.deviceId,
        deviceName: '仓库手机',
        platform: 'android',
      ),
      receiverName: '接收手机',
      approvalPollInterval: const Duration(milliseconds: 20),
    );
    final request = await requestFuture;
    expect(request.receiverName, '接收手机');
    await senderService.approveTransferRequest(request.id);
    final receiveResult = await receiveFuture;

    expect(_productCodes(receiverDb), ['SENDER']);
    expect(receiveResult.backupFileName, isNotEmpty);

    await senderService.stopSendSession();
  });

  test('discovered sender tries reachable candidate when first endpoint fails',
      () async {
    final senderDir =
        await Directory.systemTemp.createTemp('jiemei-candidates-sender-');
    final receiverDir =
        await Directory.systemTemp.createTemp('jiemei-candidates-receiver-');

    final senderDb = File('${senderDir.path}/jiemei.sqlite');
    final receiverDb = File('${receiverDir.path}/jiemei.sqlite');
    await _createBusinessDatabase(senderDb, productCode: 'SENDER');
    await _createBusinessDatabase(receiverDb, productCode: 'RECEIVER');

    final senderService = LanTransferService(
      backupService: BackupService(
        databaseFileName: 'jiemei.sqlite',
        documentsDirectoryProvider: () async => senderDir,
        randomIntProvider: (_) => 236789,
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
    final requestFuture = senderService.transferRequests.first;
    final receiveFuture = receiverService.receiveFromDiscoveredSender(
      DiscoveryAnnouncement(
        baseUri: Uri.parse('http://127.0.0.1:1'),
        baseUris: [Uri.parse('http://127.0.0.1:1'), session.baseUri],
        sessionId: session.sessionId,
        deviceId: session.deviceId,
        deviceName: '仓库手机',
        platform: 'android',
      ),
      receiverName: '接收手机',
      approvalPollInterval: const Duration(milliseconds: 20),
    );
    final request = await requestFuture;
    await senderService.approveTransferRequest(request.id);
    final receiveResult = await receiveFuture;

    expect(_productCodes(receiverDb), ['SENDER']);
    expect(receiveResult.backupFileName, isNotEmpty);

    await senderService.stopSendSession();
  });

  test('discovered sender receive fails when sender rejects request', () async {
    final senderDir =
        await Directory.systemTemp.createTemp('jiemei-reject-nearby-sender-');
    final receiverDir =
        await Directory.systemTemp.createTemp('jiemei-reject-nearby-receiver-');

    final senderDb = File('${senderDir.path}/jiemei.sqlite');
    final receiverDb = File('${receiverDir.path}/jiemei.sqlite');
    await _createBusinessDatabase(senderDb, productCode: 'SENDER');
    await _createBusinessDatabase(receiverDb, productCode: 'RECEIVER');

    final senderService = LanTransferService(
      backupService: BackupService(
        databaseFileName: 'jiemei.sqlite',
        documentsDirectoryProvider: () async => senderDir,
        randomIntProvider: (_) => 345123,
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
    final requestFuture = senderService.transferRequests.first;
    final receiveFuture = receiverService.receiveFromDiscoveredSender(
      DiscoveryAnnouncement(
        baseUri: session.baseUri,
        sessionId: session.sessionId,
        deviceId: session.deviceId,
        deviceName: '仓库手机',
        platform: 'android',
      ),
      receiverName: '接收手机',
      approvalPollInterval: const Duration(milliseconds: 20),
    );
    final request = await requestFuture;
    await senderService.rejectTransferRequest(request.id);

    await expectLater(
      receiveFuture,
      throwsA(isA<TransferRequestRejectedException>()),
    );
    expect(_productCodes(receiverDb), ['RECEIVER']);

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

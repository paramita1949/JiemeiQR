import 'dart:convert';
import 'dart:io';
import 'dart:async';
import 'dart:math';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'backup_service.dart';

typedef HttpClientFactory = HttpClient Function();
typedef TempDirectoryProvider = Future<Directory> Function();
typedef HostProvider = Future<String> Function();

class LanTransferService {
  static const int defaultDiscoveryPort = 54022;

  LanTransferService({
    required BackupService backupService,
    HttpClientFactory? httpClientFactory,
    TempDirectoryProvider? tempDirectoryProvider,
    HostProvider? hostProvider,
    InternetAddress? bindAddress,
    int discoveryPort = defaultDiscoveryPort,
    InternetAddress? discoveryAddress,
  })  : _backupService = backupService,
        _httpClientFactory = httpClientFactory ?? HttpClient.new,
        _tempDirectoryProvider = tempDirectoryProvider ?? getTemporaryDirectory,
        _hostProvider = hostProvider,
        _bindAddress = bindAddress ?? InternetAddress.anyIPv4,
        _discoveryPort = discoveryPort,
        _discoveryAddress =
            discoveryAddress ?? InternetAddress('255.255.255.255');

  final BackupService _backupService;
  final HttpClientFactory _httpClientFactory;
  final TempDirectoryProvider _tempDirectoryProvider;
  final HostProvider? _hostProvider;
  final InternetAddress _bindAddress;
  final int _discoveryPort;
  final InternetAddress _discoveryAddress;
  HttpServer? _server;
  SendSession? _session;
  RawDatagramSocket? _discoverySocket;
  Timer? _discoveryTimer;
  bool _databaseDelivered = false;
  final String _deviceId = _randomToken(12);
  final StreamController<TransferRequest> _transferRequestsController =
      StreamController<TransferRequest>.broadcast();
  final Map<String, _PendingTransferRequest> _pendingTransferRequests = {};

  bool get hasActiveSendSession => _session != null;
  Stream<TransferRequest> get transferRequests =>
      _transferRequestsController.stream;

  Future<SendSession> startSendSession() async {
    if (_session != null) {
      return _session!;
    }
    _databaseDelivered = false;
    final sendPackage = await _backupService.createSendPackage();
    final server = await HttpServer.bind(_bindAddress, 0);
    _server = server;

    final localHost = await (_hostProvider ?? _preferredLocalHost)();
    final baseUri = Uri.parse('http://$localHost:${server.port}');
    final sessionId = _randomToken(12);
    final connectionCode = buildConnectionCode(
      baseUrl: baseUri.toString(),
      pairingCode: sendPackage.pairingCode,
    );
    final session = SendSession(
      pairingCode: sendPackage.pairingCode,
      baseUri: baseUri,
      packageDirectoryPath: sendPackage.packageDirectoryPath,
      manifestPath: sendPackage.manifestPath,
      databaseFilePath: sendPackage.databaseFilePath,
      connectionCode: connectionCode,
      sessionId: sessionId,
      deviceId: _deviceId,
    );
    _session = session;

    server.listen((request) async {
      try {
        await _handleRequest(request, session);
      } catch (_) {
        request.response.statusCode = HttpStatus.internalServerError;
        await request.response.close();
      }
    });
    await _startDiscoveryBroadcast(session);
    return session;
  }

  Future<void> stopSendSession() async {
    _session = null;
    _databaseDelivered = false;
    _discoveryTimer?.cancel();
    _discoveryTimer = null;
    _discoverySocket?.close();
    _discoverySocket = null;
    _pendingTransferRequests.clear();
    final server = _server;
    _server = null;
    await server?.close(force: true);
  }

  Future<ReceiveResult> receiveFromConnectionCode(String connectionCode) {
    final parsed = parseConnectionCode(connectionCode);
    return receiveFromSender(
      baseUri: Uri.parse(parsed.baseUrl),
      pairingCode: parsed.pairingCode,
    );
  }

  Future<ReceiveResult> receiveByPairingCode(
    String pairingCode, {
    Duration timeout = const Duration(seconds: 4),
  }) async {
    final announcements = await discoverSenders(timeout: timeout);
    for (final announcement in announcements) {
      try {
        return await receiveFromSender(
          baseUri: announcement.baseUri,
          pairingCode: pairingCode,
        );
      } on PairingCodeRejectedException {
        // Try the next discovered sender.
      } on SenderUnavailableException {
        // Sender may have closed while discovery was still visible.
      }
    }
    throw const SenderUnavailableException('no sender matched pairing code');
  }

  Future<ReceiveResult> receiveFromDiscoveredSender(
    DiscoveryAnnouncement sender, {
    String? receiverName,
    Duration approvalTimeout = const Duration(seconds: 60),
    Duration approvalPollInterval = const Duration(milliseconds: 500),
  }) async {
    final grantToken = await _requestTransferApproval(
      sender,
      receiverName: receiverName ?? Platform.localHostname,
      approvalTimeout: approvalTimeout,
      approvalPollInterval: approvalPollInterval,
    );
    return receiveFromSenderWithToken(
      baseUri: sender.baseUri,
      transferToken: grantToken,
    );
  }

  Future<bool> approveTransferRequest(String requestId) async {
    final pending = _pendingTransferRequests[requestId];
    if (pending == null) {
      return false;
    }
    pending.status = TransferRequestStatus.approved;
    pending.grantToken = _randomToken(18);
    return true;
  }

  Future<bool> rejectTransferRequest(String requestId) async {
    final pending = _pendingTransferRequests[requestId];
    if (pending == null) {
      return false;
    }
    pending.status = TransferRequestStatus.rejected;
    return true;
  }

  Future<List<DiscoveryAnnouncement>> discoverSenders({
    Duration timeout = const Duration(seconds: 3),
  }) async {
    late final RawDatagramSocket socket;
    if (Platform.isWindows) {
      socket = await RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
      );
    } else {
      try {
        socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          _discoveryPort,
          reuseAddress: true,
          reusePort: true,
        );
      } on Object {
        socket = await RawDatagramSocket.bind(
          InternetAddress.anyIPv4,
          _discoveryPort,
          reuseAddress: true,
        );
      }
    }
    final found = <String, DiscoveryAnnouncement>{};
    final completer = Completer<List<DiscoveryAnnouncement>>();
    late final StreamSubscription<RawSocketEvent> subscription;
    Timer? timer;
    void finish() {
      if (completer.isCompleted) {
        return;
      }
      timer?.cancel();
      subscription.cancel();
      socket.close();
      completer.complete(found.values.toList(growable: false));
    }

    subscription = socket.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }
      Datagram? datagram;
      while ((datagram = socket.receive()) != null) {
        try {
          final text = utf8.decode(datagram!.data);
          final announcement = parseDiscoveryAnnouncement(text);
          found[announcement.baseUri.toString()] = announcement;
        } on Object {
          // Ignore unrelated UDP traffic on the same network.
        }
      }
    });
    socket.broadcastEnabled = true;
    final probe = buildDiscoveryProbe(
      deviceId: _deviceId,
      deviceName: Platform.localHostname,
      platform: Platform.operatingSystem,
    );
    socket.send(utf8.encode(probe), _discoveryAddress, _discoveryPort);
    timer = Timer(timeout, finish);
    return completer.future;
  }

  Future<ReceiveResult> receiveFromSender({
    required Uri baseUri,
    required String pairingCode,
  }) async {
    final client = _httpClientFactory();
    try {
      final manifestResponse = await _getWithPairingCode(
        client: client,
        uri: baseUri.resolve('/manifest'),
        pairingCode: pairingCode,
      );
      final manifestBody = await utf8.decodeStream(manifestResponse);
      final manifest = _parseManifest(manifestBody);
      final databasePath = manifest['databasePath'] as String?;
      if (databasePath == null || databasePath.isEmpty) {
        throw const InvalidSenderManifestException('databasePath missing');
      }
      final dbFileName = p.basename(databasePath);
      final dbResponse = await _getWithPairingCode(
        client: client,
        uri: baseUri.resolve('/database/$dbFileName'),
        pairingCode: pairingCode,
      );
      final incomingPath = await _saveIncomingFile(dbResponse, dbFileName);
      final importResult = await _backupService.importDatabaseFromPath(
        incomingPath,
      );
      return ReceiveResult(
        importedFromPath: incomingPath,
        backupFileName: importResult.backupFileName,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<ReceiveResult> receiveFromSenderWithToken({
    required Uri baseUri,
    required String transferToken,
  }) async {
    final client = _httpClientFactory();
    try {
      final manifestResponse = await _getWithTransferToken(
        client: client,
        uri: baseUri.resolve('/manifest'),
        transferToken: transferToken,
      );
      final manifestBody = await utf8.decodeStream(manifestResponse);
      final manifest = _parseManifest(manifestBody);
      final databasePath = manifest['databasePath'] as String?;
      if (databasePath == null || databasePath.isEmpty) {
        throw const InvalidSenderManifestException('databasePath missing');
      }
      final dbFileName = p.basename(databasePath);
      final dbResponse = await _getWithTransferToken(
        client: client,
        uri: baseUri.resolve('/database/$dbFileName'),
        transferToken: transferToken,
      );
      final incomingPath = await _saveIncomingFile(dbResponse, dbFileName);
      final importResult = await _backupService.importDatabaseFromPath(
        incomingPath,
      );
      return ReceiveResult(
        importedFromPath: incomingPath,
        backupFileName: importResult.backupFileName,
      );
    } finally {
      client.close(force: true);
    }
  }

  Future<HttpClientResponse> _getWithPairingCode({
    required HttpClient client,
    required Uri uri,
    required String pairingCode,
  }) async {
    HttpClientRequest request;
    try {
      request = await client.getUrl(uri);
    } on SocketException catch (error) {
      throw SenderUnavailableException(error.toString());
    }
    request.headers.set('x-pairing-code', pairingCode);
    final response = await request.close();
    if (response.statusCode == HttpStatus.forbidden) {
      throw const PairingCodeRejectedException();
    }
    if (response.statusCode != HttpStatus.ok) {
      throw DatabaseDownloadFailedException(
        'status=${response.statusCode}, uri=$uri',
      );
    }
    return response;
  }

  Future<HttpClientResponse> _getWithTransferToken({
    required HttpClient client,
    required Uri uri,
    required String transferToken,
  }) async {
    HttpClientRequest request;
    try {
      request = await client.getUrl(uri);
    } on SocketException catch (error) {
      throw SenderUnavailableException(error.toString());
    }
    request.headers.set('x-transfer-token', transferToken);
    final response = await request.close();
    if (response.statusCode == HttpStatus.forbidden) {
      throw const TransferRequestRejectedException('transfer token rejected');
    }
    if (response.statusCode != HttpStatus.ok) {
      throw DatabaseDownloadFailedException(
        'status=${response.statusCode}, uri=$uri',
      );
    }
    return response;
  }

  Future<String> _requestTransferApproval(
    DiscoveryAnnouncement sender, {
    required String receiverName,
    required Duration approvalTimeout,
    required Duration approvalPollInterval,
  }) async {
    final client = _httpClientFactory();
    final requestId = _randomToken(12);
    try {
      HttpClientRequest request;
      try {
        request = await client.postUrl(
          sender.baseUri.resolve('/transfer/request'),
        );
      } on SocketException catch (error) {
        throw SenderUnavailableException(error.toString());
      }
      final payload = utf8.encode(
        jsonEncode({
          'requestId': requestId,
          'sessionId': sender.sessionId,
          'receiverDeviceId': _deviceId,
          'receiverName': receiverName,
        }),
      );
      request.headers.contentType = ContentType.json;
      request.headers.contentLength = payload.length;
      request.add(payload);
      final response = await request.close();
      if (response.statusCode != HttpStatus.accepted) {
        throw DatabaseDownloadFailedException(
          'status=${response.statusCode}, uri=${sender.baseUri}',
        );
      }

      final deadline = DateTime.now().add(approvalTimeout);
      while (DateTime.now().isBefore(deadline)) {
        final statusRequest = await client.getUrl(
          sender.baseUri.resolve('/transfer/request/$requestId'),
        );
        final statusResponse = await statusRequest.close();
        if (statusResponse.statusCode == HttpStatus.notFound) {
          throw const SenderUnavailableException('transfer request missing');
        }
        if (statusResponse.statusCode != HttpStatus.ok) {
          throw DatabaseDownloadFailedException(
            'status=${statusResponse.statusCode}, uri=${sender.baseUri}',
          );
        }
        final body = await utf8.decodeStream(statusResponse);
        final dynamic parsed = jsonDecode(body);
        if (parsed is! Map<String, dynamic>) {
          throw const InvalidSenderManifestException(
            'transfer request status invalid',
          );
        }
        final status = parsed['status'] as String?;
        if (status == TransferRequestStatus.approved.name) {
          final grantToken = parsed['grantToken'] as String?;
          if (grantToken == null || grantToken.isEmpty) {
            throw const InvalidSenderManifestException('grantToken missing');
          }
          return grantToken;
        }
        if (status == TransferRequestStatus.rejected.name) {
          throw const TransferRequestRejectedException('request rejected');
        }
        if (status == TransferRequestStatus.expired.name) {
          throw const TransferRequestExpiredException('request expired');
        }
        await Future<void>.delayed(approvalPollInterval);
      }
      throw const TransferRequestExpiredException('request timed out');
    } finally {
      client.close(force: true);
    }
  }

  Future<void> _handleRequest(HttpRequest request, SendSession session) async {
    final path = request.uri.path;
    if (request.method == 'POST' && path == '/transfer/request') {
      await _handleTransferRequest(request, session);
      return;
    }
    if (request.method == 'GET' && path.startsWith('/transfer/request/')) {
      await _handleTransferRequestStatus(request);
      return;
    }

    final code = request.headers.value('x-pairing-code');
    final token = request.headers.value('x-transfer-token');
    if (code != session.pairingCode && !_isApprovedTransferToken(token)) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }

    if (path == '/manifest') {
      request.response.headers.contentType = ContentType.json;
      await request.response.addStream(File(session.manifestPath).openRead());
      await request.response.close();
      return;
    }
    if (path.startsWith('/database/')) {
      final fileName = p.basename(path);
      final fullPath = p.join(session.packageDirectoryPath, fileName);
      final file = File(fullPath);
      if (!await file.exists()) {
        request.response.statusCode = HttpStatus.notFound;
        await request.response.close();
        return;
      }
      request.response.headers.contentType = ContentType.binary;
      await request.response.addStream(file.openRead());
      await request.response.close();
      if (!_databaseDelivered) {
        _databaseDelivered = true;
        unawaited(stopSendSession());
      }
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
  }

  Future<void> _handleTransferRequest(
    HttpRequest request,
    SendSession session,
  ) async {
    final body = await utf8.decodeStream(request);
    final dynamic parsed = jsonDecode(body);
    if (parsed is! Map<String, dynamic>) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    if (parsed['sessionId'] != session.sessionId) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }
    final requestId = parsed['requestId'] as String?;
    final receiverDeviceId = parsed['receiverDeviceId'] as String?;
    final receiverName = parsed['receiverName'] as String?;
    if (requestId == null ||
        requestId.isEmpty ||
        receiverDeviceId == null ||
        receiverDeviceId.isEmpty ||
        receiverName == null ||
        receiverName.isEmpty) {
      request.response.statusCode = HttpStatus.badRequest;
      await request.response.close();
      return;
    }
    final transferRequest = TransferRequest(
      id: requestId,
      receiverDeviceId: receiverDeviceId,
      receiverName: receiverName,
      requestedAt: DateTime.now(),
    );
    _pendingTransferRequests[requestId] = _PendingTransferRequest(
      request: transferRequest,
    );
    _transferRequestsController.add(transferRequest);
    await _writeJson(request.response, HttpStatus.accepted, {
      'requestId': requestId,
      'status': TransferRequestStatus.pending.name,
    });
  }

  Future<void> _handleTransferRequestStatus(HttpRequest request) async {
    final requestId = request.uri.pathSegments.last;
    final pending = _pendingTransferRequests[requestId];
    if (pending == null) {
      request.response.statusCode = HttpStatus.notFound;
      await request.response.close();
      return;
    }
    await _writeJson(request.response, HttpStatus.ok, {
      'requestId': requestId,
      'status': pending.status.name,
      if (pending.grantToken != null) 'grantToken': pending.grantToken,
    });
  }

  bool _isApprovedTransferToken(String? token) {
    if (token == null || token.isEmpty) {
      return false;
    }
    return _pendingTransferRequests.values.any(
      (pending) =>
          pending.status == TransferRequestStatus.approved &&
          pending.grantToken == token,
    );
  }

  Future<void> _writeJson(
    HttpResponse response,
    int statusCode,
    Map<String, Object?> body,
  ) async {
    final data = utf8.encode(jsonEncode(body));
    response.statusCode = statusCode;
    response.headers.contentType = ContentType.json;
    response.headers.contentLength = data.length;
    response.add(data);
    await response.close();
  }

  Map<String, dynamic> _parseManifest(String body) {
    final dynamic parsed = jsonDecode(body);
    if (parsed is! Map<String, dynamic>) {
      throw const InvalidSenderManifestException('manifest must be object');
    }
    if (parsed['type'] != 'jiemei-transfer') {
      throw const InvalidSenderManifestException('manifest type mismatch');
    }
    return parsed;
  }

  Future<String> _saveIncomingFile(
    HttpClientResponse response,
    String dbFileName,
  ) async {
    final dir = await _tempDirectoryProvider();
    final file = File(
      p.join(
        dir.path,
        'incoming-${DateTime.now().microsecondsSinceEpoch}-$dbFileName',
      ),
    );
    final sink = file.openWrite();
    await response.forEach(sink.add);
    await sink.flush();
    await sink.close();
    return file.path;
  }

  Future<String> _preferredLocalHost() async {
    try {
      final interfaces = await NetworkInterface.list(
        includeLoopback: false,
        type: InternetAddressType.IPv4,
      );
      for (final interface in interfaces) {
        for (final address in interface.addresses) {
          if (!address.isLoopback) {
            return address.address;
          }
        }
      }
    } catch (_) {
      // fallback to loopback
    }
    return '127.0.0.1';
  }

  Future<void> _startDiscoveryBroadcast(SendSession session) async {
    final socket = await _bindDiscoverySocket();
    socket.broadcastEnabled = true;
    _discoverySocket = socket;
    void send() {
      final message = buildDiscoveryAnnouncement(
        baseUrl: session.baseUri.toString(),
        sessionId: session.sessionId,
        deviceId: session.deviceId,
        deviceName: Platform.localHostname,
        platform: Platform.operatingSystem,
      );
      socket.send(utf8.encode(message), _discoveryAddress, _discoveryPort);
    }

    socket.listen((event) {
      if (event != RawSocketEvent.read) {
        return;
      }
      Datagram? datagram;
      while ((datagram = socket.receive()) != null) {
        try {
          final text = utf8.decode(datagram!.data);
          if (isDiscoveryProbe(text)) {
            final message = buildDiscoveryAnnouncement(
              baseUrl: session.baseUri.toString(),
              sessionId: session.sessionId,
              deviceId: session.deviceId,
              deviceName: Platform.localHostname,
              platform: Platform.operatingSystem,
            );
            socket.send(utf8.encode(message), datagram.address, datagram.port);
          }
        } on Object {
          // Ignore unrelated UDP traffic.
        }
      }
    });
    send();
    _discoveryTimer = Timer.periodic(const Duration(seconds: 1), (_) => send());
  }

  Future<RawDatagramSocket> _bindDiscoverySocket() {
    if (Platform.isWindows) {
      return RawDatagramSocket.bind(
        InternetAddress.anyIPv4,
        _discoveryPort,
        reuseAddress: true,
      );
    }
    return RawDatagramSocket.bind(
      InternetAddress.anyIPv4,
      _discoveryPort,
      reuseAddress: true,
      reusePort: true,
    );
  }

  String buildDiscoveryProbe({
    required String deviceId,
    required String deviceName,
    required String platform,
  }) {
    return jsonEncode({
      'type': 'jiemei-transfer-probe',
      'version': 2,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
    });
  }

  bool isDiscoveryProbe(String text) {
    final dynamic payload = jsonDecode(text);
    return payload is Map<String, dynamic> &&
        payload['type'] == 'jiemei-transfer-probe';
  }

  String buildDiscoveryAnnouncement({
    required String baseUrl,
    required String sessionId,
    required String deviceId,
    required String deviceName,
    required String platform,
  }) {
    return jsonEncode({
      'type': 'jiemei-transfer-advertisement',
      'version': 2,
      'baseUrl': baseUrl,
      'sessionId': sessionId,
      'deviceId': deviceId,
      'deviceName': deviceName,
      'platform': platform,
    });
  }

  DiscoveryAnnouncement parseDiscoveryAnnouncement(String text) {
    final dynamic payload = jsonDecode(text);
    if (payload is! Map<String, dynamic>) {
      throw const DiscoveryAnnouncementParseException('payload invalid');
    }
    if (payload['type'] != 'jiemei-transfer-advertisement') {
      throw const DiscoveryAnnouncementParseException('type mismatch');
    }
    final baseUrl = payload['baseUrl'] as String?;
    if (baseUrl == null || baseUrl.isEmpty) {
      throw const DiscoveryAnnouncementParseException('payload missing fields');
    }
    final sessionId = payload['sessionId'] as String?;
    final deviceId = payload['deviceId'] as String?;
    final deviceName = payload['deviceName'] as String?;
    final platform = payload['platform'] as String?;
    if (sessionId == null ||
        sessionId.isEmpty ||
        deviceId == null ||
        deviceId.isEmpty ||
        deviceName == null ||
        deviceName.isEmpty ||
        platform == null ||
        platform.isEmpty) {
      throw const DiscoveryAnnouncementParseException('payload missing fields');
    }
    final baseUri = Uri.tryParse(baseUrl);
    if (baseUri == null || !baseUri.hasAuthority) {
      throw const DiscoveryAnnouncementParseException('baseUrl invalid');
    }
    return DiscoveryAnnouncement(
      baseUri: baseUri,
      sessionId: sessionId,
      deviceId: deviceId,
      deviceName: deviceName,
      platform: platform,
    );
  }

  String buildConnectionCode({
    required String baseUrl,
    required String pairingCode,
  }) {
    final payload = jsonEncode({
      'baseUrl': baseUrl,
      'pairingCode': pairingCode,
    });
    final encoded = base64UrlEncode(utf8.encode(payload));
    return 'JM:$encoded';
  }

  ParsedConnectionCode parseConnectionCode(String text) {
    final trimmed = text.trim();
    if (!trimmed.startsWith('JM:')) {
      throw const ConnectionCodeParseException('prefix mismatch');
    }
    final encoded = trimmed.substring(3);
    try {
      final decoded = utf8.decode(base64Url.decode(encoded));
      final dynamic payload = jsonDecode(decoded);
      if (payload is! Map<String, dynamic>) {
        throw const ConnectionCodeParseException('payload invalid');
      }
      final baseUrl = payload['baseUrl'] as String?;
      final pairingCode = payload['pairingCode'] as String?;
      if (baseUrl == null ||
          baseUrl.isEmpty ||
          pairingCode == null ||
          pairingCode.isEmpty) {
        throw const ConnectionCodeParseException('payload missing fields');
      }
      return ParsedConnectionCode(
        baseUrl: baseUrl,
        pairingCode: pairingCode,
      );
    } on FormatException {
      throw const ConnectionCodeParseException('base64 invalid');
    }
  }
}

class SendSession {
  const SendSession({
    required this.pairingCode,
    required this.baseUri,
    required this.packageDirectoryPath,
    required this.manifestPath,
    required this.databaseFilePath,
    required this.connectionCode,
    required this.sessionId,
    required this.deviceId,
  });

  final String pairingCode;
  final Uri baseUri;
  final String packageDirectoryPath;
  final String manifestPath;
  final String databaseFilePath;
  final String connectionCode;
  final String sessionId;
  final String deviceId;
}

class ReceiveResult {
  const ReceiveResult({
    required this.importedFromPath,
    required this.backupFileName,
  });

  final String importedFromPath;
  final String backupFileName;
}

class SenderUnavailableException implements Exception {
  const SenderUnavailableException(this.message);

  final String message;
}

class PairingCodeRejectedException implements Exception {
  const PairingCodeRejectedException();
}

class TransferRequestRejectedException implements Exception {
  const TransferRequestRejectedException(this.message);

  final String message;
}

class TransferRequestExpiredException implements Exception {
  const TransferRequestExpiredException(this.message);

  final String message;
}

class InvalidSenderManifestException implements Exception {
  const InvalidSenderManifestException(this.message);

  final String message;
}

class DatabaseDownloadFailedException implements Exception {
  const DatabaseDownloadFailedException(this.message);

  final String message;
}

class ConnectionCodeParseException implements Exception {
  const ConnectionCodeParseException(this.message);

  final String message;
}

class DiscoveryAnnouncementParseException implements Exception {
  const DiscoveryAnnouncementParseException(this.message);

  final String message;
}

class ParsedConnectionCode {
  const ParsedConnectionCode({
    required this.baseUrl,
    required this.pairingCode,
  });

  final String baseUrl;
  final String pairingCode;
}

class DiscoveryAnnouncement {
  const DiscoveryAnnouncement({
    required this.baseUri,
    required this.sessionId,
    required this.deviceId,
    required this.deviceName,
    required this.platform,
  });

  final Uri baseUri;
  final String sessionId;
  final String deviceId;
  final String deviceName;
  final String platform;
}

enum TransferRequestStatus {
  pending,
  approved,
  rejected,
  expired,
}

class TransferRequest {
  const TransferRequest({
    required this.id,
    required this.receiverDeviceId,
    required this.receiverName,
    required this.requestedAt,
  });

  final String id;
  final String receiverDeviceId;
  final String receiverName;
  final DateTime requestedAt;
}

class _PendingTransferRequest {
  _PendingTransferRequest({
    required this.request,
  });

  final TransferRequest request;
  TransferRequestStatus status = TransferRequestStatus.pending;
  String? grantToken;
}

String _randomToken(int length) {
  const alphabet =
      'abcdefghijklmnopqrstuvwxyzABCDEFGHIJKLMNOPQRSTUVWXYZ0123456789';
  final random = Random.secure();
  return List.generate(
    length,
    (_) => alphabet[random.nextInt(alphabet.length)],
  ).join();
}

import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

import 'backup_service.dart';

typedef HttpClientFactory = HttpClient Function();
typedef TempDirectoryProvider = Future<Directory> Function();
typedef HostProvider = Future<String> Function();

class LanTransferService {
  LanTransferService({
    required BackupService backupService,
    HttpClientFactory? httpClientFactory,
    TempDirectoryProvider? tempDirectoryProvider,
    HostProvider? hostProvider,
    InternetAddress? bindAddress,
  })  : _backupService = backupService,
        _httpClientFactory = httpClientFactory ?? HttpClient.new,
        _tempDirectoryProvider = tempDirectoryProvider ?? getTemporaryDirectory,
        _hostProvider = hostProvider,
        _bindAddress = bindAddress ?? InternetAddress.anyIPv4;

  final BackupService _backupService;
  final HttpClientFactory _httpClientFactory;
  final TempDirectoryProvider _tempDirectoryProvider;
  final HostProvider? _hostProvider;
  final InternetAddress _bindAddress;
  HttpServer? _server;
  SendSession? _session;

  Future<SendSession> startSendSession() async {
    if (_session != null) {
      return _session!;
    }
    final sendPackage = await _backupService.createSendPackage();
    final server = await HttpServer.bind(_bindAddress, 0);
    _server = server;

    final localHost = await (_hostProvider ?? _preferredLocalHost)();
    final baseUri = Uri.parse('http://$localHost:${server.port}');
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
    return session;
  }

  Future<void> stopSendSession() async {
    _session = null;
    final server = _server;
    _server = null;
    await server?.close(force: true);
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

  Future<void> _handleRequest(HttpRequest request, SendSession session) async {
    final code = request.headers.value('x-pairing-code');
    if (code != session.pairingCode) {
      request.response.statusCode = HttpStatus.forbidden;
      await request.response.close();
      return;
    }

    final path = request.uri.path;
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
      return;
    }

    request.response.statusCode = HttpStatus.notFound;
    await request.response.close();
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
  });

  final String pairingCode;
  final Uri baseUri;
  final String packageDirectoryPath;
  final String manifestPath;
  final String databaseFilePath;
  final String connectionCode;
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

class ParsedConnectionCode {
  const ParsedConnectionCode({
    required this.baseUrl,
    required this.pairingCode,
  });

  final String baseUrl;
  final String pairingCode;
}

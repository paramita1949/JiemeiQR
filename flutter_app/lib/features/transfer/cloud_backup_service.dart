import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

typedef CloudDocumentsDirectoryProvider = Future<Directory> Function();
typedef CloudNowProvider = DateTime Function();

enum CloudBackupRole {
  admin,
  viewer;

  static CloudBackupRole fromValue(String? value) {
    return value == 'admin' ? CloudBackupRole.admin : CloudBackupRole.viewer;
  }
}

class CloudBackupSession {
  const CloudBackupSession({
    required this.email,
    required this.role,
    required this.accessToken,
    this.refreshToken,
  });

  final String email;
  final CloudBackupRole role;
  final String accessToken;
  final String? refreshToken;

  bool get canUpload => role == CloudBackupRole.admin;

  Map<String, Object?> toJson() => {
        'email': email,
        'role': role.name,
        'accessToken': accessToken,
        'refreshToken': refreshToken,
      };

  factory CloudBackupSession.fromJson(Map<String, Object?> json) {
    return CloudBackupSession(
      email: json['email']?.toString() ?? '',
      role: CloudBackupRole.fromValue(json['role']?.toString()),
      accessToken: json['accessToken']?.toString() ?? '',
      refreshToken: json['refreshToken']?.toString(),
    );
  }
}

class CloudBackupRemoteBackup {
  const CloudBackupRemoteBackup({
    required this.objectPath,
    required this.fileName,
    required this.createdAt,
    this.sizeBytes,
  });

  final String objectPath;
  final String fileName;
  final DateTime createdAt;
  final int? sizeBytes;
}

abstract class CloudBackupApi {
  Future<CloudBackupSession> signIn({
    required String email,
    required String password,
  });

  Future<void> uploadPackage({
    required CloudBackupSession session,
    required File packageFile,
    String? objectPath,
  });

  Future<List<int>> downloadPackage({
    required CloudBackupSession session,
    String? objectPath,
  });

  Future<List<CloudBackupRemoteBackup>> listBackups({
    required CloudBackupSession session,
    int limit = 5,
  });

  Future<void> deleteBackups({
    required CloudBackupSession session,
    required List<String> objectPaths,
  });
}

class SupabaseCloudBackupApi implements CloudBackupApi {
  SupabaseCloudBackupApi({
    this.projectUrl = defaultProjectUrl,
    this.publishableKey = defaultPublishableKey,
    this.bucketName = defaultBucketName,
    this.objectPath = defaultObjectPath,
    HttpClient? httpClient,
  }) : _httpClient = httpClient;

  static const defaultProjectUrl = 'https://usduvwrbhwtodfcghcqh.supabase.co';
  static const defaultPublishableKey =
      'sb_publishable_581VpBamFopYkBPDviXeRQ_i6P9OpN3';
  static const defaultBucketName = 'qrscan-backups';
  static const defaultObjectPath = 'latest/jiemei-backup.jiemei';

  final String projectUrl;
  final String publishableKey;
  final String bucketName;
  final String objectPath;
  final HttpClient? _httpClient;

  @override
  Future<CloudBackupSession> signIn({
    required String email,
    required String password,
  }) async {
    final response = await _sendJson(
      method: 'POST',
      path: '/auth/v1/token',
      query: {'grant_type': 'password'},
      headers: {'apikey': publishableKey},
      body: {'email': email.trim(), 'password': password},
    );
    final user = response['user'];
    final metadata = user is Map ? user['app_metadata'] : null;
    final role = metadata is Map
        ? CloudBackupRole.fromValue(metadata['app_role']?.toString())
        : CloudBackupRole.viewer;
    return CloudBackupSession(
      email: email.trim(),
      role: role,
      accessToken: response['access_token']?.toString() ?? '',
      refreshToken: response['refresh_token']?.toString(),
    );
  }

  @override
  Future<void> uploadPackage({
    required CloudBackupSession session,
    required File packageFile,
    String? objectPath,
  }) async {
    final targetPath = objectPath ?? this.objectPath;
    final uri = _uri('/storage/v1/object/$bucketName/$targetPath', {
      'upsert': 'true',
    });
    final client = _httpClient ?? HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer ${session.accessToken}')
        ..set('apikey', publishableKey)
        ..set(HttpHeaders.contentTypeHeader, 'application/octet-stream');
      request.add(await packageFile.readAsBytes());
      final response = await request.close();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CloudBackupRequestException(
          statusCode: response.statusCode,
          message: await response.transform(utf8.decoder).join(),
        );
      }
    } finally {
      if (_httpClient == null) {
        client.close(force: true);
      }
    }
  }

  @override
  Future<List<int>> downloadPackage({
    required CloudBackupSession session,
    String? objectPath,
  }) async {
    final targetPath = objectPath ?? this.objectPath;
    final uri =
        _uri('/storage/v1/object/authenticated/$bucketName/$targetPath');
    final client = _httpClient ?? HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer ${session.accessToken}')
        ..set('apikey', publishableKey);
      final response = await request.close();
      final bytes = await response.fold<List<int>>(
        <int>[],
        (all, chunk) => all..addAll(chunk),
      );
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CloudBackupRequestException(
          statusCode: response.statusCode,
          message: utf8.decode(bytes, allowMalformed: true),
        );
      }
      return bytes;
    } finally {
      if (_httpClient == null) {
        client.close(force: true);
      }
    }
  }

  @override
  Future<List<CloudBackupRemoteBackup>> listBackups({
    required CloudBackupSession session,
    int limit = 5,
  }) async {
    final response = await _sendJsonList(
      method: 'POST',
      path: '/storage/v1/object/list/$bucketName',
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
        'apikey': publishableKey,
      },
      body: {
        'prefix': 'history',
        'limit': limit + 5,
        'sortBy': {'column': 'name', 'order': 'desc'},
      },
    );
    final backups = response
        .whereType<Map>()
        .map(_remoteBackupFromJson)
        .whereType<CloudBackupRemoteBackup>()
        .toList()
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    return backups.take(limit).toList();
  }

  @override
  Future<void> deleteBackups({
    required CloudBackupSession session,
    required List<String> objectPaths,
  }) async {
    if (objectPaths.isEmpty) {
      return;
    }
    await _sendJsonList(
      method: 'DELETE',
      path: '/storage/v1/object/$bucketName',
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
        'apikey': publishableKey,
      },
      body: {'prefixes': objectPaths},
    );
  }

  Future<Map<String, Object?>> _sendJson({
    required String method,
    required String path,
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    Map<String, Object?>? body,
  }) async {
    final client = _httpClient ?? HttpClient();
    try {
      final request = await client.openUrl(method, _uri(path, query));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      headers.forEach(request.headers.set);
      if (body != null) {
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CloudBackupRequestException(
          statusCode: response.statusCode,
          message: text,
        );
      }
      final decoded = jsonDecode(text);
      return decoded is Map<String, Object?> ? decoded : <String, Object?>{};
    } finally {
      if (_httpClient == null) {
        client.close(force: true);
      }
    }
  }

  Future<List<Object?>> _sendJsonList({
    required String method,
    required String path,
    Map<String, String> query = const {},
    Map<String, String> headers = const {},
    Map<String, Object?>? body,
  }) async {
    final client = _httpClient ?? HttpClient();
    try {
      final request = await client.openUrl(method, _uri(path, query));
      request.headers.set(HttpHeaders.contentTypeHeader, 'application/json');
      headers.forEach(request.headers.set);
      if (body != null) {
        request.write(jsonEncode(body));
      }
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw CloudBackupRequestException(
          statusCode: response.statusCode,
          message: text,
        );
      }
      final decoded = jsonDecode(text);
      return decoded is List ? decoded.cast<Object?>() : const <Object?>[];
    } finally {
      if (_httpClient == null) {
        client.close(force: true);
      }
    }
  }

  CloudBackupRemoteBackup? _remoteBackupFromJson(Map json) {
    final rawName = json['name']?.toString();
    if (rawName == null || rawName.isEmpty) {
      return null;
    }
    final fileName = p.basename(rawName);
    final objectPath = rawName.startsWith('history/')
        ? rawName
        : p.posix.join('history', rawName);
    final createdAt = DateTime.tryParse(
          json['created_at']?.toString() ??
              json['updated_at']?.toString() ??
              '',
        ) ??
        _createdAtFromHistoryFileName(fileName) ??
        DateTime.fromMillisecondsSinceEpoch(0);
    final metadata = json['metadata'];
    final rawSize = metadata is Map ? metadata['size'] : null;
    final sizeBytes = rawSize is int ? rawSize : int.tryParse('$rawSize');
    return CloudBackupRemoteBackup(
      objectPath: objectPath,
      fileName: fileName,
      createdAt: createdAt,
      sizeBytes: sizeBytes,
    );
  }

  Uri _uri(String path, [Map<String, String> query = const {}]) {
    final base = Uri.parse(projectUrl);
    return base.replace(
        path: path, queryParameters: query.isEmpty ? null : query);
  }

  DateTime? _createdAtFromHistoryFileName(String fileName) {
    final match = RegExp(r'^(\d{8})-(\d{6})-').firstMatch(fileName);
    if (match == null) {
      return null;
    }
    final date = match.group(1)!;
    final time = match.group(2)!;
    return DateTime(
      int.parse(date.substring(0, 4)),
      int.parse(date.substring(4, 6)),
      int.parse(date.substring(6, 8)),
      int.parse(time.substring(0, 2)),
      int.parse(time.substring(2, 4)),
      int.parse(time.substring(4, 6)),
    );
  }
}

class CloudBackupService {
  CloudBackupService({
    required this.api,
    this.documentsDirectoryProvider,
    this.nowProvider,
  });

  final CloudBackupApi api;
  final CloudDocumentsDirectoryProvider? documentsDirectoryProvider;
  final CloudNowProvider? nowProvider;

  Future<CloudBackupSession?> loadSavedSession() async {
    final file = await _sessionFile();
    if (!await file.exists()) {
      return null;
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, Object?>) {
        final session = CloudBackupSession.fromJson(decoded);
        if (session.email.isNotEmpty && session.accessToken.isNotEmpty) {
          return session;
        }
      }
    } catch (_) {}
    return null;
  }

  Future<CloudBackupSession> signIn({
    required String email,
    required String password,
  }) async {
    final session = await api.signIn(email: email, password: password);
    await _saveSession(session);
    return session;
  }

  Future<void> signOut() async {
    final file = await _sessionFile();
    if (await file.exists()) {
      await file.delete();
    }
  }

  Future<void> uploadPackage({
    required CloudBackupSession session,
    required File packageFile,
  }) async {
    if (!session.canUpload) {
      throw const CloudBackupPermissionException();
    }
    await api.uploadPackage(
      session: session,
      packageFile: packageFile,
      objectPath: SupabaseCloudBackupApi.defaultObjectPath,
    );
    await api.uploadPackage(
      session: session,
      packageFile: packageFile,
      objectPath: _historyObjectPath((nowProvider ?? DateTime.now)()),
    );
    await _pruneHistory(session);
  }

  Future<File> downloadPackage({
    required CloudBackupSession session,
    CloudBackupRemoteBackup? backup,
  }) async {
    final bytes = await api.downloadPackage(
      session: session,
      objectPath: backup?.objectPath,
    );
    final documentsDir = await _documentsDirectory();
    final cloudDir = Directory(p.join(documentsDir.path, 'cloud_backups'));
    await cloudDir.create(recursive: true);
    final stamp = _fileStamp((nowProvider ?? DateTime.now)());
    final file = File(p.join(cloudDir.path, 'jiemei-cloud-$stamp.jiemei'));
    await file.writeAsBytes(bytes, flush: true);
    return file;
  }

  Future<List<CloudBackupRemoteBackup>> listBackups({
    required CloudBackupSession session,
    int limit = 5,
  }) {
    return api.listBackups(session: session, limit: limit);
  }

  Future<void> _saveSession(CloudBackupSession session) async {
    final file = await _sessionFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(session.toJson()));
  }

  Future<File> _sessionFile() async {
    final documentsDir = await _documentsDirectory();
    return File(p.join(documentsDir.path, 'cloud_backups', 'session.json'));
  }

  Future<Directory> _documentsDirectory() {
    final provider = documentsDirectoryProvider;
    if (provider != null) {
      return provider();
    }
    return getApplicationDocumentsDirectory();
  }

  String _fileStamp(DateTime value) {
    String pad2(int n) => n.toString().padLeft(2, '0');
    return '${value.year}${pad2(value.month)}${pad2(value.day)}-'
        '${pad2(value.hour)}${pad2(value.minute)}${pad2(value.second)}';
  }

  String _historyObjectPath(DateTime value) =>
      'history/${_fileStamp(value)}-jiemei-backup.jiemei';

  Future<void> _pruneHistory(CloudBackupSession session) async {
    final backups = await api.listBackups(session: session, limit: 100);
    if (backups.length <= 5) {
      return;
    }
    final sorted = [...backups]
      ..sort((a, b) => b.createdAt.compareTo(a.createdAt));
    await api.deleteBackups(
      session: session,
      objectPaths: sorted.skip(5).map((backup) => backup.objectPath).toList(),
    );
  }
}

class CloudBackupPermissionException implements Exception {
  const CloudBackupPermissionException();
}

class CloudBackupRequestException implements Exception {
  const CloudBackupRequestException({
    required this.statusCode,
    required this.message,
  });

  final int statusCode;
  final String message;

  @override
  String toString() =>
      'CloudBackupRequestException(statusCode: $statusCode, message: $message)';
}

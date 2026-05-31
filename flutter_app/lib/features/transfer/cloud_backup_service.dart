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

class CloudManagedAccount {
  const CloudManagedAccount({
    required this.email,
    required this.role,
    this.id,
  });

  final String email;
  final CloudBackupRole role;
  final String? id;

  factory CloudManagedAccount.fromJson(Map<String, Object?> json) {
    return CloudManagedAccount(
      email: json['email']?.toString() ?? '',
      role: CloudBackupRole.fromValue(json['role']?.toString()),
      id: json['id']?.toString(),
    );
  }
}

abstract class CloudBackupApi {
  String get sessionScope;

  Future<CloudBackupSession> signIn({
    required String email,
    required String password,
  });

  Future<CloudBackupSession> refreshSession({
    required CloudBackupSession session,
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

  Future<List<CloudManagedAccount>> listAccounts({
    required CloudBackupSession session,
  });

  Future<void> createAccount({
    required CloudBackupSession session,
    required String email,
    required String password,
    required CloudBackupRole role,
  });

  Future<void> updateAccountPassword({
    required CloudBackupSession session,
    required String email,
    required String password,
  });

  Future<void> deleteAccount({
    required CloudBackupSession session,
    required String email,
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

  static const defaultProjectUrl = 'https://zqszqeawedogbuydwfdv.supabase.co';
  static const defaultPublishableKey =
      'sb_publishable_t8bFXn5R3E4MCaMegvxEhw_3YW7ZOtV';
  static const defaultBucketName = 'qrscan-backups';
  static const defaultObjectPath = 'latest/jiemei-backup.jiemei';
  static const accountManagerFunction = 'qrscan-account-admin';

  final String projectUrl;
  final String publishableKey;
  final String bucketName;
  final String objectPath;
  final HttpClient? _httpClient;

  @override
  String get sessionScope => '$projectUrl|$publishableKey';

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
  Future<CloudBackupSession> refreshSession({
    required CloudBackupSession session,
  }) async {
    final refreshToken = session.refreshToken;
    if (refreshToken == null || refreshToken.isEmpty) {
      return session;
    }
    final response = await _sendJson(
      method: 'POST',
      path: '/auth/v1/token',
      query: {'grant_type': 'refresh_token'},
      headers: {'apikey': publishableKey},
      body: {'refresh_token': refreshToken},
    );
    final user = response['user'];
    final metadata = user is Map ? user['app_metadata'] : null;
    final role = metadata is Map
        ? CloudBackupRole.fromValue(metadata['app_role']?.toString())
        : session.role;
    return CloudBackupSession(
      email: session.email,
      role: role,
      accessToken: response['access_token']?.toString() ?? session.accessToken,
      refreshToken: response['refresh_token']?.toString() ?? refreshToken,
    );
  }

  @override
  Future<void> uploadPackage({
    required CloudBackupSession session,
    required File packageFile,
    String? objectPath,
  }) async {
    final targetPath = objectPath ?? this.objectPath;
    final uri = _uri('/storage/v1/object/$bucketName/$targetPath');
    final client = _httpClient ?? HttpClient();
    try {
      final request = await client.postUrl(uri);
      request.headers
        ..set(HttpHeaders.authorizationHeader, 'Bearer ${session.accessToken}')
        ..set('apikey', publishableKey)
        ..set('x-upsert', 'true')
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

  @override
  Future<List<CloudManagedAccount>> listAccounts({
    required CloudBackupSession session,
  }) async {
    final response = await _sendFunctionJson(
      session: session,
      body: {'action': 'list'},
    );
    final accounts = response['accounts'];
    if (accounts is! List) {
      return const [];
    }
    return accounts
        .whereType<Map>()
        .map((item) => CloudManagedAccount.fromJson(item.cast()))
        .where((account) => account.email.isNotEmpty)
        .toList();
  }

  @override
  Future<void> createAccount({
    required CloudBackupSession session,
    required String email,
    required String password,
    required CloudBackupRole role,
  }) async {
    await _sendFunctionJson(
      session: session,
      body: {
        'action': 'create',
        'email': email.trim(),
        'password': password,
        'role': role.name,
      },
    );
  }

  @override
  Future<void> updateAccountPassword({
    required CloudBackupSession session,
    required String email,
    required String password,
  }) async {
    await _sendFunctionJson(
      session: session,
      body: {
        'action': 'updatePassword',
        'email': email.trim(),
        'password': password,
      },
    );
  }

  @override
  Future<void> deleteAccount({
    required CloudBackupSession session,
    required String email,
  }) async {
    await _sendFunctionJson(
      session: session,
      body: {
        'action': 'delete',
        'email': email.trim(),
      },
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

  Future<Map<String, Object?>> _sendFunctionJson({
    required CloudBackupSession session,
    required Map<String, Object?> body,
  }) {
    return _sendJson(
      method: 'POST',
      path: '/functions/v1/$accountManagerFunction',
      headers: {
        HttpHeaders.authorizationHeader: 'Bearer ${session.accessToken}',
        'apikey': publishableKey,
      },
      body: body,
    );
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
        if (decoded['sessionScope'] != api.sessionScope) {
          await file.delete();
          return null;
        }
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
    await _withFreshSession(session, (freshSession) async {
      await api.uploadPackage(
        session: freshSession,
        packageFile: packageFile,
        objectPath: SupabaseCloudBackupApi.defaultObjectPath,
      );
      await api.uploadPackage(
        session: freshSession,
        packageFile: packageFile,
        objectPath: _historyObjectPath((nowProvider ?? DateTime.now)()),
      );
      await _pruneHistory(freshSession);
    });
  }

  Future<File> downloadPackage({
    required CloudBackupSession session,
    CloudBackupRemoteBackup? backup,
  }) async {
    final bytes = await _withFreshSession(
      session,
      (freshSession) => api.downloadPackage(
        session: freshSession,
        objectPath: backup?.objectPath,
      ),
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
  }) async {
    final backups = await _withFreshSession(
      session,
      (freshSession) => api.listBackups(session: freshSession, limit: limit),
    );
    if (backups.isNotEmpty) {
      return backups;
    }
    try {
      await _withFreshSession(
        session,
        (freshSession) => api.downloadPackage(
          session: freshSession,
          objectPath: SupabaseCloudBackupApi.defaultObjectPath,
        ),
      );
      return [
        CloudBackupRemoteBackup(
          objectPath: SupabaseCloudBackupApi.defaultObjectPath,
          fileName: p.basename(SupabaseCloudBackupApi.defaultObjectPath),
          createdAt: (nowProvider ?? DateTime.now)(),
        ),
      ];
    } on CloudBackupRequestException catch (error) {
      if (error.statusCode == 404) {
        return const [];
      }
      rethrow;
    }
  }

  Future<void> uploadAttendanceBackup({
    required CloudBackupSession session,
    required String accountKey,
    required String jsonText,
  }) async {
    final documentsDir = await _documentsDirectory();
    final cloudDir = Directory(p.join(documentsDir.path, 'cloud_backups'));
    await cloudDir.create(recursive: true);
    final file = File(
      p.join(
        cloudDir.path,
        'attendance-${_safeAccountPath(accountKey)}-${_fileStamp((nowProvider ?? DateTime.now)())}.json',
      ),
    );
    await file.writeAsString(jsonText, flush: true);
    await _withFreshSession(
      session,
      (freshSession) => api.uploadPackage(
        session: freshSession,
        packageFile: file,
        objectPath: attendanceObjectPath(accountKey),
      ),
    );
  }

  Future<List<CloudManagedAccount>> listAccounts({
    required CloudBackupSession session,
  }) {
    return _withFreshSession(
      session,
      (freshSession) => api.listAccounts(session: freshSession),
    );
  }

  Future<void> createAccount({
    required CloudBackupSession session,
    required String email,
    required String password,
    required CloudBackupRole role,
  }) {
    return _withFreshSession(
      session,
      (freshSession) => api.createAccount(
        session: freshSession,
        email: email,
        password: password,
        role: role,
      ),
    );
  }

  Future<void> updateAccountPassword({
    required CloudBackupSession session,
    required String email,
    required String password,
  }) {
    return _withFreshSession(
      session,
      (freshSession) => api.updateAccountPassword(
        session: freshSession,
        email: email,
        password: password,
      ),
    );
  }

  Future<void> deleteAccount({
    required CloudBackupSession session,
    required String email,
  }) {
    return _withFreshSession(
      session,
      (freshSession) => api.deleteAccount(
        session: freshSession,
        email: email,
      ),
    );
  }

  Future<String> downloadAttendanceBackup({
    required CloudBackupSession session,
    required String accountKey,
  }) async {
    final bytes = await _withFreshSession(
      session,
      (freshSession) => api.downloadPackage(
        session: freshSession,
        objectPath: attendanceObjectPath(accountKey),
      ),
    );
    return utf8.decode(bytes, allowMalformed: true);
  }

  Future<void> _saveSession(CloudBackupSession session) async {
    final file = await _sessionFile();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode({
      ...session.toJson(),
      'sessionScope': api.sessionScope,
    }));
  }

  Future<T> _withFreshSession<T>(
    CloudBackupSession session,
    Future<T> Function(CloudBackupSession session) action,
  ) async {
    final freshSession = await _refreshIfExpired(session);
    try {
      return await action(freshSession);
    } on CloudBackupRequestException catch (error) {
      if (!_looksLikeExpiredToken(error) || freshSession.refreshToken == null) {
        rethrow;
      }
      final refreshed = await api.refreshSession(session: freshSession);
      await _saveSession(refreshed);
      return action(refreshed);
    }
  }

  Future<CloudBackupSession> _refreshIfExpired(
    CloudBackupSession session,
  ) async {
    final expiresAt = _jwtExpiresAt(session.accessToken);
    if (expiresAt == null || session.refreshToken == null) {
      return session;
    }
    final now = (nowProvider ?? DateTime.now)().toUtc();
    if (expiresAt.isAfter(now.add(const Duration(minutes: 2)))) {
      return session;
    }
    final refreshed = await api.refreshSession(session: session);
    await _saveSession(refreshed);
    return refreshed;
  }

  DateTime? _jwtExpiresAt(String token) {
    final parts = token.split('.');
    if (parts.length != 3) {
      return null;
    }
    try {
      final payload =
          utf8.decode(base64Url.decode(base64Url.normalize(parts[1])));
      final decoded = jsonDecode(payload);
      if (decoded is! Map) {
        return null;
      }
      final rawExp = decoded['exp'];
      final exp = rawExp is int ? rawExp : int.tryParse('$rawExp');
      if (exp == null) {
        return null;
      }
      return DateTime.fromMillisecondsSinceEpoch(exp * 1000, isUtc: true);
    } catch (_) {
      return null;
    }
  }

  bool _looksLikeExpiredToken(CloudBackupRequestException error) {
    final message = error.message.toLowerCase();
    return message.contains('exp') ||
        message.contains('jwt') ||
        message.contains('expired');
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

  static String attendanceObjectPath(String accountKey) =>
      'attendance/${_safeAccountPath(accountKey)}/latest.attendance.json';

  static String _safeAccountPath(String accountKey) {
    final normalized = accountKey.trim().toLowerCase();
    final effective = normalized.isEmpty ? 'local' : normalized;
    return Uri.encodeComponent(effective);
  }

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

  String get debugMessage {
    final normalized = _compactMessage(message);
    if (_looksLikeInvalidLogin(normalized)) {
      return '账号或密码错误，请重新输入';
    }
    final hint = normalized.toLowerCase().contains('exp')
        ? '。可能是云账号登录已过期，请退出云账号后重新登录'
        : '';
    return 'HTTP $statusCode：$normalized$hint';
  }

  @override
  String toString() =>
      'CloudBackupRequestException(statusCode: $statusCode, message: $message)';

  static String _compactMessage(String value) {
    try {
      final decoded = jsonDecode(value);
      if (decoded is Map) {
        final innerMessage = decoded['message']?.toString();
        final error = decoded['error']?.toString();
        final status = decoded['statusCode']?.toString();
        return [
          if (status != null) 'status=$status',
          if (error != null) 'error=$error',
          if (innerMessage != null) innerMessage,
        ].join(' · ');
      }
    } catch (_) {}
    return value.trim().isEmpty ? '无返回内容' : value.trim();
  }

  static bool _looksLikeInvalidLogin(String value) {
    final lower = value.toLowerCase();
    return lower.contains('invalid login credentials') ||
        lower.contains('invalid_grant') ||
        lower.contains('email not confirmed');
  }
}

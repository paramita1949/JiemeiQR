import 'dart:async';
import 'dart:convert';
import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:flutter/services.dart';
import 'package:package_info_plus/package_info_plus.dart';
import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AppUpdateInfo {
  const AppUpdateInfo({
    required this.currentVersion,
    required this.latestVersion,
    required this.releaseName,
    required this.releaseNotes,
    required this.apkUrl,
    required this.apkName,
    required this.hasUpdate,
  });

  final String currentVersion;
  final String latestVersion;
  final String releaseName;
  final String releaseNotes;
  final String apkUrl;
  final String apkName;
  final bool hasUpdate;
}

class AppUpdateService {
  const AppUpdateService({
    this.owner = 'paramita1949',
    this.repo = 'JiemeiQR',
  });

  final String owner;
  final String repo;

  static const _channel = MethodChannel('com.jiemei.hualushui/app_update');

  Future<AppUpdateInfo> checkLatest() async {
    final packageInfo = await PackageInfo.fromPlatform();
    final currentVersion = packageInfo.version.trim();
    final uri = Uri.https(
      'api.github.com',
      '/repos/$owner/$repo/releases/latest',
    );
    final response = await _getJson(uri);
    final latestVersion = _normalizeVersion(
      response['tag_name']?.toString().trim().isNotEmpty == true
          ? response['tag_name'].toString()
          : response['name']?.toString() ?? '',
    );
    final assets = response['assets'];
    final apkAsset = assets is List
        ? assets.cast<Object?>().whereType<Map<String, Object?>>().firstWhere(
              (asset) =>
                  (asset['name']?.toString().toLowerCase().endsWith('.apk') ??
                      false) &&
                  (asset['browser_download_url']?.toString().isNotEmpty ??
                      false),
              orElse: () => const <String, Object?>{},
            )
        : const <String, Object?>{};

    return AppUpdateInfo(
      currentVersion: currentVersion,
      latestVersion: latestVersion,
      releaseName: response['name']?.toString() ?? latestVersion,
      releaseNotes: response['body']?.toString() ?? '',
      apkUrl: apkAsset['browser_download_url']?.toString() ?? '',
      apkName: apkAsset['name']?.toString() ?? 'jiemei-update.apk',
      hasUpdate: _compareVersions(latestVersion, currentVersion) > 0 &&
          (apkAsset['browser_download_url']?.toString().isNotEmpty ?? false),
    );
  }

  Future<File> downloadApk(
    AppUpdateInfo info, {
    ValueChanged<double>? onProgress,
  }) async {
    final directory = await getTemporaryDirectory();
    final updatesDir = Directory(p.join(directory.path, 'updates'));
    if (!await updatesDir.exists()) {
      await updatesDir.create(recursive: true);
    }
    final fileName = info.apkName.endsWith('.apk')
        ? info.apkName
        : 'jiemei-${info.latestVersion}.apk';
    final file = File(p.join(updatesDir.path, fileName));
    AppUpdateException? lastError;
    final candidates = appUpdateDownloadUris(info.apkUrl);
    final uris = await _prioritizeDownloadUris(candidates);

    for (final uri in uris) {
      try {
        return await _downloadApkFromUri(uri, file, onProgress: onProgress);
      } on AppUpdateException catch (error) {
        lastError = error;
      }
    }

    throw lastError ?? const AppUpdateException('下载失败：没有可用下载线路');
  }

  Future<void> installApk(File apkFile) async {
    await _channel.invokeMethod<void>('installApk', {
      'path': apkFile.path,
    });
  }

  Future<Map<String, Object?>> _getJson(Uri uri) async {
    final client = HttpClient();
    try {
      final request = await client.getUrl(uri);
      request.headers.set(
        HttpHeaders.acceptHeader,
        'application/vnd.github+json',
      );
      request.headers.set(HttpHeaders.userAgentHeader, 'JiemeiQR-Updater');
      final response = await request.close();
      final text = await response.transform(utf8.decoder).join();
      if (response.statusCode < 200 || response.statusCode >= 300) {
        throw AppUpdateException('检查失败：HTTP ${response.statusCode}');
      }
      final decoded = jsonDecode(text);
      if (decoded is! Map<String, Object?>) {
        throw const AppUpdateException('更新信息格式无效');
      }
      return decoded;
    } on AppUpdateException {
      rethrow;
    } catch (error) {
      throw AppUpdateException('检查更新失败：$error');
    } finally {
      client.close(force: true);
    }
  }
}

Future<File> _downloadApkFromUri(
  Uri uri,
  File file, {
  ValueChanged<double>? onProgress,
}) async {
  final client = HttpClient()..connectionTimeout = _downloadConnectTimeout;
  try {
    final request = await client.getUrl(uri).timeout(_downloadConnectTimeout);
    request.headers.set(HttpHeaders.userAgentHeader, 'JiemeiQR-Updater');
    final response = await request.close().timeout(_downloadConnectTimeout);
    if (response.statusCode == HttpStatus.partialContent) {
      throw const AppUpdateException('下载失败：下载线路只返回了部分安装包');
    }
    if (response.statusCode != HttpStatus.ok) {
      throw AppUpdateException('下载失败：HTTP ${response.statusCode}');
    }
    final sink = file.openWrite();
    var received = 0;
    final total = response.contentLength;
    try {
      await for (final chunk in response.timeout(_downloadIdleTimeout)) {
        received += chunk.length;
        sink.add(chunk);
        if (total > 0) {
          onProgress?.call(received / total);
        }
      }
    } finally {
      await sink.close();
    }
    if (total > 0 && received != total) {
      await _deleteIncompleteApk(file);
      throw AppUpdateException('下载失败：安装包不完整（$received/$total）');
    }
    if (!await _hasApkZipHeader(file)) {
      await _deleteIncompleteApk(file);
      throw const AppUpdateException('下载失败：安装包格式无效');
    }
    onProgress?.call(1);
    return file;
  } on AppUpdateException {
    rethrow;
  } catch (error) {
    throw AppUpdateException('下载失败：$error');
  } finally {
    client.close(force: true);
  }
}

@visibleForTesting
Future<File> downloadAppUpdateApkFromUriForTesting(
  Uri uri,
  File file, {
  ValueChanged<double>? onProgress,
}) {
  return _downloadApkFromUri(uri, file, onProgress: onProgress);
}

Future<void> _deleteIncompleteApk(File file) async {
  try {
    if (await file.exists()) {
      await file.delete();
    }
  } catch (_) {
    // Best-effort cleanup. The caller still receives the download failure.
  }
}

Future<bool> _hasApkZipHeader(File file) async {
  final stream = file.openRead(0, 4);
  final bytes = <int>[];
  await for (final chunk in stream) {
    bytes.addAll(chunk);
  }
  return bytes.length >= 4 &&
      bytes[0] == 0x50 &&
      bytes[1] == 0x4B &&
      bytes[2] == 0x03 &&
      bytes[3] == 0x04;
}

class AppUpdateException implements Exception {
  const AppUpdateException(this.message);

  final String message;

  @override
  String toString() => message;
}

String _normalizeVersion(String value) {
  final match = RegExp(r'(\d+(?:\.\d+){1,3})').firstMatch(value);
  return match?.group(1) ?? value.replaceFirst(RegExp(r'^[vV]'), '').trim();
}

int _compareVersions(String a, String b) {
  final left = _versionParts(a);
  final right = _versionParts(b);
  final length = left.length > right.length ? left.length : right.length;
  for (var index = 0; index < length; index += 1) {
    final diff = (index < left.length ? left[index] : 0) -
        (index < right.length ? right[index] : 0);
    if (diff != 0) {
      return diff;
    }
  }
  return 0;
}

List<int> _versionParts(String version) {
  return _normalizeVersion(version)
      .split(RegExp(r'[^0-9]+'))
      .where((part) => part.isNotEmpty)
      .map((part) => int.tryParse(part) ?? 0)
      .toList(growable: false);
}

List<Uri> appUpdateDownloadUris(String officialUrl) {
  final normalized = officialUrl.trim();
  if (normalized.isEmpty) {
    return const [];
  }
  return [
    normalized,
    for (final proxy in _githubDownloadProxyPrefixes) '$proxy$normalized',
  ].map(Uri.parse).toList(growable: false);
}

typedef AppUpdateDownloadProbe = Future<void> Function(Uri uri);

Future<Uri> chooseFastestAppUpdateDownloadUri(
  List<Uri> uris, {
  AppUpdateDownloadProbe probe = _probeDownloadUri,
}) async {
  if (uris.isEmpty) {
    throw const AppUpdateException('下载失败：没有可用下载线路');
  }
  if (uris.length == 1) {
    return uris.first;
  }

  final completer = Completer<Uri>();
  var pending = uris.length;
  Object? lastError;

  for (final uri in uris) {
    unawaited(() async {
      try {
        await probe(uri).timeout(_downloadProbeTimeout);
        if (!completer.isCompleted) {
          completer.complete(uri);
        }
      } catch (error) {
        lastError = error;
      } finally {
        pending -= 1;
        if (pending == 0 && !completer.isCompleted) {
          completer.completeError(
            lastError ?? const AppUpdateException('下载失败：没有可用下载线路'),
          );
        }
      }
    }());
  }

  return completer.future;
}

Future<List<Uri>> _prioritizeDownloadUris(List<Uri> uris) async {
  if (uris.length <= 1) {
    return uris;
  }
  try {
    final fastest = await chooseFastestAppUpdateDownloadUri(uris);
    return [
      fastest,
      for (final uri in uris)
        if (uri != fastest) uri,
    ];
  } on Object {
    return uris;
  }
}

Future<void> _probeDownloadUri(Uri uri) async {
  final client = HttpClient()..connectionTimeout = _downloadConnectTimeout;
  try {
    final request = await client.getUrl(uri).timeout(_downloadConnectTimeout);
    request.headers.set(HttpHeaders.userAgentHeader, 'JiemeiQR-Updater');
    request.headers.set(HttpHeaders.rangeHeader, 'bytes=0-65535');
    final response = await request.close().timeout(_downloadProbeTimeout);
    if (response.statusCode < 200 || response.statusCode >= 300) {
      throw AppUpdateException('下载失败：HTTP ${response.statusCode}');
    }
    var received = 0;
    await for (final chunk in response.timeout(_downloadProbeTimeout)) {
      received += chunk.length;
      if (received >= _downloadProbeBytes) {
        break;
      }
    }
    if (received == 0) {
      throw const AppUpdateException('下载失败：下载线路没有返回数据');
    }
  } finally {
    client.close(force: true);
  }
}

const _downloadConnectTimeout = Duration(seconds: 6);
const _downloadProbeTimeout = Duration(seconds: 8);
const _downloadIdleTimeout = Duration(seconds: 12);
const _downloadProbeBytes = 64 * 1024;

const _githubDownloadProxyPrefixes = [
  'https://gh-proxy.com/',
  'https://github.akams.cn/',
  'https://v6.gh-proxy.org/',
  'https://ghproxy.net/',
  'https://ghproxy.site/',
  'https://ghproxy.vip/',
  'https://githubproxy.cc/',
  'https://gh-fast.com/',
  'https://ghpull.com/',
  'https://mirror.ghproxy.com/',
  'https://ghfast.top/',
  'https://gh.llkk.cc/',
];

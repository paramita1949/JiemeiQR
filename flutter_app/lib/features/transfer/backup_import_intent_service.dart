import 'package:flutter/services.dart';

class BackupImportIntentService {
  const BackupImportIntentService();

  static const MethodChannel _channel = MethodChannel(
    'com.jiemei.hualushui/backup_import',
  );

  Future<String?> consumePendingImportPath() async {
    final value =
        await _channel.invokeMethod<String>('consumePendingImportPath');
    final path = value?.trim();
    if (path == null || path.isEmpty) {
      return null;
    }
    return path;
  }
}

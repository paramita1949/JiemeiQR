import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';

/// 考勤通知专用的有界JSONL日志，后台动作和重启后也可读取，不保存邮箱或令牌。
class AttendanceNotificationLog {
  AttendanceNotificationLog._();

  static Future<void> _pending = Future.value();
  static const fileName = 'attendance_notification_diagnostics.jsonl';

  static String accountId(String account) =>
      sha256.convert(utf8.encode(account)).toString().substring(0, 8);

  static Future<File> _file() async =>
      File('${(await getApplicationDocumentsDirectory()).path}/$fileName');

  /// 写日志失败不得阻止排期或签到。单个isolate串行写入，文件大小受限。
  static Future<void> write(String event,
      [Map<String, Object?> data = const {}]) {
    final now = DateTime.now();
    final line = jsonEncode({
      'time': now.toIso8601String(),
      'offsetMinutes': now.timeZoneOffset.inMinutes,
      'event': event,
      ...data
    });
    DebugEventLog.add('CHECKOUT_DIAG', line);
    _pending = _pending.then((_) async {
      try {
        final file = await _file();
        if (await file.exists() && await file.length() > 128 * 1024) {
          final lines = await file.readAsLines();
          await file.writeAsString(
              '${lines.skip(lines.length > 100 ? lines.length - 100 : 0).join('\n')}\n');
        }
        await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
      } catch (error) {
        DebugEventLog.add('CHECKOUT_DIAG', 'persistent_log_failed: $error');
      }
    });
    return _pending;
  }

  /// 提供可复制的最近200条记录；不存在时返回明确空状态。
  static Future<String> readReport() async {
    await _pending;
    try {
      final file = await _file();
      if (!await file.exists()) return '暂无通知日志，请先点击“测试下班通知”。';
      final lines = await file.readAsLines();
      return lines.skip(lines.length > 200 ? lines.length - 200 : 0).join('\n');
    } catch (error) {
      return '读取通知日志失败：$error';
    }
  }
}

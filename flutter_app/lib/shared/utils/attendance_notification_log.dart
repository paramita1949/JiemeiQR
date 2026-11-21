import 'dart:convert';
import 'dart:io';

import 'package:crypto/crypto.dart';
import 'package:path_provider/path_provider.dart';
import 'package:qrscan_flutter/shared/utils/debug_event_log.dart';

/// 下班提醒的有界关键日志；持久化短字段，复制时只提供中文摘要。
class AttendanceNotificationLog {
  AttendanceNotificationLog._();

  static Future<void> _pending = Future.value();
  static const fileName = 'attendance_notification_diagnostics.jsonl';
  static final Map<String, String> _lastState = {};
  static String? _lastFile;
  static const _events = {
    'initialize_returned',
    'initialize_failed',
    'schedule_decision',
    'schedule_input',
    'schedule_begin',
    'schedule_returned',
    'schedule_failed',
    'cancel_returned',
    'system_state',
    'due_check',
    'response_received',
    'checkout_result',
    'checkout_rejected',
    'action_rejected',
    'action_failed'
  };
  static const _fields = {
    'stage',
    'due',
    'recordId',
    'notificationId',
    'mode',
    'error',
    'reason',
    'enabled',
    'workEnd',
    'openRecordCount',
    'changed',
    'id',
    'action',
    'responseType',
    'status',
    'observedAt',
    'appVersion',
    'permission',
    'exactAlarmAllowed',
    'channels',
    'pending',
    'active',
    'initialized'
  };

  static String accountId(String account) =>
      sha256.convert(utf8.encode(account)).toString().substring(0, 8);

  static Future<File> _file() async =>
      File('${(await getApplicationDocumentsDirectory()).path}/$fileName');

  /// 写日志失败不得阻止排期或签到。单个isolate串行写入，文件大小受限。
  static Future<void> write(String event,
      [Map<String, Object?> data = const {}]) {
    if (!_events.contains(event)) return Future.value();
    final now = DateTime.now();
    final short = <String, Object?>{
      for (final entry in data.entries)
        if (_fields.contains(entry.key))
          entry.key: entry.value is String &&
                  (entry.key == 'error' ||
                      (entry.value as String).startsWith('query_failed:'))
              ? briefError(entry.value.toString())
              : entry.value
    };
    final line =
        jsonEncode({'time': now.toIso8601String(), 'event': event, ...short});
    _pending = _pending.then((_) async {
      try {
        final file = await _file();
        if (_lastFile != file.path) {
          _lastState.clear();
          _lastFile = file.path;
        }
        if (event == 'system_state' ||
            event == 'due_check' ||
            event == 'schedule_decision') {
          final key = '$event:${short['stage'] ?? ''}';
          final signature = jsonEncode({
            for (final entry in short.entries)
              if (entry.key != 'observedAt') entry.key: entry.value
          });
          if (_lastState[key] == signature) return;
          _lastState[key] = signature;
        }
        if (await file.exists() && await file.length() > 128 * 1024) {
          final lines = await file.readAsLines();
          await file.writeAsString(
              '${lines.skip(lines.length > 100 ? lines.length - 100 : 0).join('\n')}\n');
        }
        await file.writeAsString('$line\n', mode: FileMode.append, flush: true);
        DebugEventLog.add('CHECKOUT_DIAG', line);
      } catch (error) {
        DebugEventLog.add('CHECKOUT_DIAG', 'persistent_log_failed: $error');
      }
    });
    return _pending;
  }

  /// 保留原始短JSONL供验证读取；不作为界面的复制内容。
  static Future<String> readRawReport() async {
    await _pending;
    try {
      final file = await _file();
      if (!await file.exists()) return '';
      final lines = await file.readAsLines();
      return lines.skip(lines.length > 200 ? lines.length - 200 : 0).join('\n');
    } catch (error) {
      return '读取通知日志失败：${briefError('$error')}';
    }
  }

  /// 错误只保留代码/首行信息，兼容旧版包含原生堆栈的错误字符串。
  static String briefError(String error) {
    final match =
        RegExp(r'PlatformException\(([^,]+),\s*([^,\n]+)').firstMatch(error);
    final text = (match == null
            ? error.replaceFirst('query_failed: ', '').split('\n').first
            : '${match.group(1)}: ${match.group(2)}')
        .replaceAll('\r', '')
        .trim();
    return text.length > 90 ? '${text.substring(0, 90)}…' : text;
  }

  static String _time(Object? value, {bool date = false}) {
    final ts = DateTime.tryParse('$value');
    if (ts == null) return '未知';
    String two(int n) => n.toString().padLeft(2, '0');
    return '${date ? '${two(ts.month)}-${two(ts.day)} ' : ''}'
        '${two(ts.hour)}:${two(ts.minute)}:${two(ts.second)}';
  }

  static String _flag(Object? value) => value == true
      ? '开'
      : value == false
          ? '关'
          : '未知';

  static String? _message(Map<String, dynamic> e) {
    switch (e['event']) {
      case 'schedule_input':
        return e['due'] == null ? null : '目标下班：${_time(e['due'], date: true)}';
      case 'schedule_begin':
        return '开始安排（${e['mode'] == 'exactAllowWhileIdle' ? '精确' : '非精确，可能延迟'}）';
      case 'schedule_returned':
        return '安排成功（不是弹窗确认）';
      case 'cancel_returned':
        return '旧提醒取消成功';
      case 'system_state':
        final channels = e['channels'];
        final importance =
            channels is List && channels.isNotEmpty && channels.first is Map
                ? (channels.first as Map)['importance']
                : null;
        String count(Object? list) => list is List
            ? list
                .where((n) => n is Map && n['id'] == 20261120)
                .length
                .toString()
            : '查询失败';
        return '权限${_flag(e['permission'])}；精确闹钟${_flag(e['exactAlarmAllowed'])}；'
            '渠道${importance ?? '未建/未知'}；待发送${count(e['pending'])}；通知栏${count(e['active'])}';
      case 'due_check':
        final status = switch (e['status']) {
          'active' => '通知栏有下班提醒（横幅需目测）',
          'pending' => '待系统发送，可能延迟',
          'not_visible' => '当前无提醒，可能已清除，不能判断是否曾弹出',
          _ => '系统状态查询失败'
        };
        return '到点检查：$status';
      case 'schedule_decision':
        return switch (e['reason']) {
          'reminder_disabled' => '未安排：提醒已关闭',
          'no_open_record' => '未安排：没有未签退的上班记录',
          'outside_future_window_or_past_due' => '未安排：时间已过或不在有效范围',
          _ => null
        };
      case 'response_received':
        return e['action'] == 'attendance_checkout_now'
            ? '收到下班签到按钮操作'
            : '收到通知点击（不自动签到）';
      case 'checkout_result':
        return e['changed'] == true ? '下班签到成功' : '未修改签到（重复/校验拒绝）';
      case 'checkout_rejected':
      case 'action_rejected':
        return '签到拒绝：${briefError('${e['reason']}')}';
      case 'initialize_failed':
      case 'schedule_failed':
      case 'action_failed':
        return '操作失败：${briefError('${e['error']}')}';
      default:
        return null;
    }
  }

  /// 最近12条关键中文记录，兼容旧文件；没有堆栈、测试通知或账号数据。
  static Future<String> readReport() async {
    final raw = await readRawReport();
    if (raw.startsWith('读取通知日志失败')) return raw;
    final rows = <String>[];
    String? version;
    String? due;
    for (final line in const LineSplitter().convert(raw)) {
      try {
        final e = jsonDecode(line) as Map<String, dynamic>;
        if (e['event'] == 'system_state' && e['appVersion'] is String) {
          version = e['appVersion'] as String;
        }
        if (e['due'] is String) due = e['due'] as String;
        final message = _message(e);
        if (message == null) continue;
        final row = '${_time(e['observedAt'] ?? e['time'])} $message';
        if (rows.isEmpty || rows.last != row) rows.add(row);
      } catch (_) {
        // Ignore legacy/unparseable lines without exposing their raw payload.
      }
    }
    final recent = rows.skip(rows.length > 12 ? rows.length - 12 : 0).toList();
    final header = '下班提醒日志${version == null ? '' : ' v$version'}\n'
        '目标：${due == null ? '未安排' : _time(due, date: true)}（秒数00）';
    const note = '检查时间是观测时间，不是横幅弹出时间；后台需返回首页后抓取。';
    String report() =>
        '$header\n${recent.isEmpty ? '暂无关键日志，请设置未来下班时间并开启提醒。' : recent.join('\n')}\n$note';
    while (recent.length > 1 && report().length > 1500) {
      recent.removeAt(0);
    }
    return report();
  }
}

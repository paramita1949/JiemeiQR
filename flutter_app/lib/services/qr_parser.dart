import 'package:qrscan_flutter/models/qr_record.dart';

class QrParser {
  static const int serialLength = 10;
  static const int batchLength = 7;
  static const int suffixLength = 2;
  static const int defaultCount = 20;

  static ParsedQr? parse(String content) {
    const tailLength = batchLength + suffixLength;
    const variableLength = serialLength + tailLength;
    if (content.length < variableLength + 1) {
      return null;
    }

    final suffix = content.substring(content.length - suffixLength);
    final batch = content.substring(
      content.length - tailLength,
      content.length - suffixLength,
    );
    final serial = content.substring(
      content.length - variableLength,
      content.length - tailLength,
    );
    final prefix = content.substring(0, content.length - variableLength);

    final serialInt = int.tryParse(serial);
    if (serialInt == null) {
      return null;
    }

    return ParsedQr(
      prefix: prefix,
      serial: serial,
      serialInt: serialInt,
      batch: batch,
      suffix: suffix,
    );
  }

  static QrBuildResult buildRecords({
    required String prefix,
    required int serialInt,
    required String batch,
    required String suffix,
    int count = defaultCount,
    int? startSerial,
  }) {
    final start = startSerial ?? serialInt;

    var scanIndex = 0;
    final records = <QrRecord>[];

    for (var i = 0; i < count; i++) {
      final value = start + i;
      final serial = value.toString().padLeft(serialLength, '0');
      final content = '$prefix$serial$batch$suffix';
      records.add(QrRecord(content: content, serial: serial));

      if (value == serialInt) {
        scanIndex = i;
      }
    }

    if (startSerial != null) {
      scanIndex = 0;
    }

    return QrBuildResult(
      records: records,
      scanIndex: scanIndex,
      group: QrGroup(
        prefix: prefix,
        batch: batch,
        suffix: suffix,
        startSerial: start,
        count: count,
      ),
    );
  }

}

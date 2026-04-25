import 'dart:math';

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
    required String serialSeed,
    required String batch,
    required String suffix,
    int count = defaultCount,
    int? startSerial,
    bool randomTailEnabled = false,
    int randomTailDigits = 3,
    Random? random,
  }) {
    if (count <= 0) {
      throw ArgumentError.value(count, 'count', 'count must be > 0');
    }

    final serialInt = int.tryParse(serialSeed);
    if (serialInt == null || serialSeed.length != serialLength) {
      throw ArgumentError.value(
        serialSeed,
        'serialSeed',
        'serialSeed must be 10-digit numeric string',
      );
    }

    late final List<QrRecord> records;
    late final int resolvedStart;

    if (randomTailEnabled) {
      if (randomTailDigits <= 0 || randomTailDigits >= serialLength) {
        throw ArgumentError.value(
          randomTailDigits,
          'randomTailDigits',
          'randomTailDigits must be in range 1..9',
        );
      }

      final combinations = pow(10, randomTailDigits).toInt();
      if (count > combinations) {
        throw ArgumentError.value(
          count,
          'count',
          'random tail mode supports up to $combinations records for $randomTailDigits digits',
        );
      }

      final rng = random ?? Random();
      final serialHead = serialSeed.substring(0, serialLength - randomTailDigits);
      final pool = List<int>.generate(combinations, (i) => i)..shuffle(rng);

      records = List<QrRecord>.generate(count, (index) {
        final tail = pool[index].toString().padLeft(randomTailDigits, '0');
        final serial = '$serialHead$tail';
        return QrRecord(content: '$prefix$serial$batch$suffix', serial: serial);
      });
      resolvedStart = serialInt;
    } else {
      final start = startSerial ?? serialInt;
      resolvedStart = start;
      records = List<QrRecord>.generate(count, (index) {
        final value = start + index;
        final serial = value.toString().padLeft(serialLength, '0');
        return QrRecord(content: '$prefix$serial$batch$suffix', serial: serial);
      });
    }

    return QrBuildResult(
      records: records,
      scanIndex: 0,
      group: QrGroup(
        prefix: prefix,
        batch: batch,
        suffix: suffix,
        sourceSerial: serialSeed,
        startSerial: resolvedStart,
        count: count,
        randomTailEnabled: randomTailEnabled,
        randomTailDigits: randomTailDigits,
      ),
    );
  }
}

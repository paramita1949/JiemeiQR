import 'dart:math';

import 'package:qrscan_flutter/models/qr_record.dart';

class QrParser {
  static const int serialLength = 10;
  static const int batchLength = 7;
  static const int suffixLength = 2;
  static const int defaultCount = 20;

  static String ensureLeading00(String content) {
    final trimmed = content.trim();
    return trimmed.startsWith('00') ? trimmed : '00$trimmed';
  }

  static ParsedQr? parse(String content) {
    final normalizedContent = ensureLeading00(content);
    const tailLength = batchLength + suffixLength;
    const variableLength = serialLength + tailLength;
    if (normalizedContent.length < variableLength + 1) {
      return null;
    }

    final suffix = normalizedContent.substring(
      normalizedContent.length - suffixLength,
    );
    final batch = normalizedContent.substring(
      normalizedContent.length - tailLength,
      normalizedContent.length - suffixLength,
    );
    final serial = normalizedContent.substring(
      normalizedContent.length - variableLength,
      normalizedContent.length - tailLength,
    );
    final prefix = normalizedContent.substring(
      0,
      normalizedContent.length - variableLength,
    );

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

    final normalizedPrefix = prefix.startsWith('00') ? prefix : '00$prefix';
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
      final serialHead =
          serialSeed.substring(0, serialLength - randomTailDigits);
      final seedTail = int.parse(
        serialSeed.substring(serialLength - randomTailDigits),
      );
      final pool = List<int>.generate(combinations, (i) => i)
        ..remove(seedTail)
        ..shuffle(rng);

      final seededRecord = QrRecord(
        content: '$normalizedPrefix$serialSeed$batch$suffix',
        serial: serialSeed,
      );
      if (count == 1) {
        records = <QrRecord>[seededRecord];
      } else {
        final randomRecords = List<QrRecord>.generate(count - 1, (index) {
          final tail = pool[index].toString().padLeft(randomTailDigits, '0');
          final serial = '$serialHead$tail';
          return QrRecord(
            content: '$normalizedPrefix$serial$batch$suffix',
            serial: serial,
          );
        });
        records = <QrRecord>[seededRecord, ...randomRecords];
      }
      resolvedStart = serialInt;
    } else {
      final start = startSerial ?? serialInt;
      resolvedStart = start;
      records = List<QrRecord>.generate(count, (index) {
        final value = start + index;
        final serial = value.toString().padLeft(serialLength, '0');
        return QrRecord(
          content: '$normalizedPrefix$serial$batch$suffix',
          serial: serial,
        );
      });
    }

    return QrBuildResult(
      records: records,
      scanIndex: 0,
      group: QrGroup(
        prefix: normalizedPrefix,
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

import 'dart:math';

import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/services/qr_parser.dart';

void main() {
  group('QrParser.parse', () {
    test('parses a valid box label QR content', () {
      const input = '00208540089567279FAYAUEZ32';

      final parsed = QrParser.parse(input);

      expect(parsed, isNotNull);
      expect(parsed!.prefix, '0020854');
      expect(parsed.serial, '0089567279');
      expect(parsed.serialInt, 89567279);
      expect(parsed.batch, 'FAYAUEZ');
      expect(parsed.suffix, '32');
    });

    test('returns null for invalid serial section', () {
      const input = '0020854ABCDEFGHIJFAYAUEZ32';

      final parsed = QrParser.parse(input);

      expect(parsed, isNull);
    });

    test('returns null for too short content', () {
      const input = '12345';

      final parsed = QrParser.parse(input);

      expect(parsed, isNull);
    });
  });

  group('QrParser.buildRecords', () {
    test('creates records starting from scanned serial', () {
      final result = QrParser.buildRecords(
        prefix: '0020854',
        serialSeed: '0000000100',
        batch: 'FAYAUEZ',
        suffix: '32',
      );

      expect(result.records, hasLength(20));
      expect(result.scanIndex, 0);
      expect(result.group.count, 20);
      expect(result.group.startSerial, 100);
      expect(result.records.first.serial, '0000000100');
      expect(result.records[result.scanIndex].serial, '0000000100');
      expect(result.records.last.serial, '0000000119');
    });

    test('supports explicit start serial for next group generation', () {
      final result = QrParser.buildRecords(
        prefix: '0020854',
        serialSeed: '0000000500',
        batch: 'FAYAUEZ',
        suffix: '32',
        count: 10,
        startSerial: 500,
      );

      expect(result.records, hasLength(10));
      expect(result.group.startSerial, 500);
      expect(result.scanIndex, 0);
      expect(result.records.first.serial, '0000000500');
      expect(result.records.last.serial, '0000000509');
    });

    test('random mode only randomizes last three digits', () {
      final result = QrParser.buildRecords(
        prefix: '0020854',
        serialSeed: '0089567279',
        batch: 'FAYAUEZ',
        suffix: '32',
        count: 10,
        randomTail3: true,
        random: Random(42),
      );

      expect(result.records, hasLength(10));
      expect(result.group.randomTail3, isTrue);
      final serials = result.records.map((e) => e.serial).toList();
      for (final serial in serials) {
        expect(serial.startsWith('0089567'), isTrue);
      }
      expect(serials.toSet().length, serials.length);
    });
  });
}

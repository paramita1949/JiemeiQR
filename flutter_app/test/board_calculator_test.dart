import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/shared/utils/board_calculator.dart';

void main() {
  group('BoardCalculator.format', () {
    test('formats exact board count', () {
      expect(BoardCalculator.format(boxes: 160, boxesPerBoard: 40), '4板');
    });

    test('formats board count with remaining boxes', () {
      expect(BoardCalculator.format(boxes: 3477, boxesPerBoard: 40), '86板+37箱');
    });

    test('formats boxes only when less than one board', () {
      expect(BoardCalculator.format(boxes: 8, boxesPerBoard: 40), '8箱');
    });

    test('formats zero boxes', () {
      expect(BoardCalculator.format(boxes: 0, boxesPerBoard: 40), '0箱');
    });

    test('rejects invalid boxes per board', () {
      expect(
        () => BoardCalculator.format(boxes: 10, boxesPerBoard: 0),
        throwsArgumentError,
      );
    });
  });
}

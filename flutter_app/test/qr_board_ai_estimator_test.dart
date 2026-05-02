import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/services/qr_board_ai_estimator.dart';

void main() {
  group('QrBoardAiEstimator', () {
    test('estimates full board range from top and bottom samples', () {
      final result = QrBoardAiEstimator.estimateRange(
        boxesPerBoard: 35,
        topSerials: const [1000, 1001, 1002, 1003],
        bottomSerials: const [1031, 1032, 1033, 1034],
      );

      expect(result.startSerial, 1000);
      expect(result.endSerial, 1034);
      expect(result.step, 1);
      expect(result.confidence, greaterThan(0.9));
    });

    test('supports board size 50 and sparse samples', () {
      final result = QrBoardAiEstimator.estimateRange(
        boxesPerBoard: 50,
        topSerials: const [2000, 2001, 2002],
        bottomSerials: const [2047, 2048, 2049],
      );

      expect(result.startSerial, 2000);
      expect(result.endSerial, 2049);
      expect(result.step, 1);
    });

    test('throws when sample count is too small', () {
      expect(
        () => QrBoardAiEstimator.estimateRange(
          boxesPerBoard: 35,
          topSerials: const [1000],
          bottomSerials: const [1034],
        ),
        throwsArgumentError,
      );
    });
  });
}

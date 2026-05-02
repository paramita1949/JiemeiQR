class QrBoardRangeEstimate {
  const QrBoardRangeEstimate({
    required this.startSerial,
    required this.endSerial,
    required this.step,
    required this.confidence,
  });

  final int startSerial;
  final int endSerial;
  final int step;
  final double confidence;
}

class QrBoardAiEstimator {
  const QrBoardAiEstimator._();

  static QrBoardRangeEstimate estimateRange({
    required int boxesPerBoard,
    required List<int> topSerials,
    required List<int> bottomSerials,
  }) {
    if (boxesPerBoard <= 0) {
      throw ArgumentError.value(
        boxesPerBoard,
        'boxesPerBoard',
        'boxesPerBoard must be > 0',
      );
    }
    if (topSerials.length + bottomSerials.length < 4) {
      throw ArgumentError.value(
        topSerials.length + bottomSerials.length,
        'samples',
        'at least 4 samples are required',
      );
    }
    final sortedTop = [...topSerials]..sort();
    final sortedBottom = [...bottomSerials]..sort();
    if (sortedTop.isEmpty || sortedBottom.isEmpty) {
      throw ArgumentError('top and bottom samples are both required');
    }

    final topSpan = sortedTop.length > 1 ? sortedTop.last - sortedTop.first : 0;
    final bottomSpan =
        sortedBottom.length > 1 ? sortedBottom.last - sortedBottom.first : 0;
    final topStep = _bestStep(sortedTop);
    final bottomStep = _bestStep(sortedBottom);
    final step = topStep > 0 && bottomStep > 0
        ? (topStep + bottomStep) ~/ 2
        : (topStep > 0 ? topStep : (bottomStep > 0 ? bottomStep : 1));

    final startSerial = sortedTop.first;
    final endSerial = startSerial + (boxesPerBoard - 1) * step;
    final expectedBottomStart = endSerial - (sortedBottom.length - 1) * step;
    final bottomDelta = (expectedBottomStart - sortedBottom.first).abs();

    final continuityPenalty = (topSpan + bottomSpan) == 0 ? 0.0 : 0.04;
    final bottomPenalty = bottomDelta == 0 ? 0.0 : (bottomDelta * 0.02);
    final confidence = (1.0 - continuityPenalty - bottomPenalty).clamp(0.0, 1.0);

    return QrBoardRangeEstimate(
      startSerial: startSerial,
      endSerial: endSerial,
      step: step <= 0 ? 1 : step,
      confidence: confidence,
    );
  }

  static int _bestStep(List<int> values) {
    if (values.length < 2) {
      return 1;
    }
    final diffs = <int>[];
    for (var i = 1; i < values.length; i++) {
      final diff = values[i] - values[i - 1];
      if (diff > 0) {
        diffs.add(diff);
      }
    }
    if (diffs.isEmpty) {
      return 1;
    }
    diffs.sort();
    return diffs[diffs.length ~/ 2];
  }

}

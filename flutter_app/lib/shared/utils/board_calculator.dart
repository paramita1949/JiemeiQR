class BoardCalculator {
  const BoardCalculator._();

  static String format({
    required int boxes,
    required int boxesPerBoard,
  }) {
    if (boxesPerBoard <= 0) {
      throw ArgumentError.value(
        boxesPerBoard,
        'boxesPerBoard',
        'boxesPerBoard must be greater than 0',
      );
    }
    if (boxes < 0) {
      throw ArgumentError.value(boxes, 'boxes', 'boxes must not be negative');
    }

    final boards = boxes ~/ boxesPerBoard;
    final remainingBoxes = boxes % boxesPerBoard;

    if (boards == 0) {
      return '$remainingBoxes箱';
    }
    if (remainingBoxes == 0) {
      return '$boards板';
    }
    return '$boards板+$remainingBoxes箱';
  }
}

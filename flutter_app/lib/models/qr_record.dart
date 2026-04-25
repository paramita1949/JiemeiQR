class QrRecord {
  const QrRecord({
    required this.content,
    required this.serial,
  });

  final String content;
  final String serial;
}

class ParsedQr {
  const ParsedQr({
    required this.prefix,
    required this.serial,
    required this.serialInt,
    required this.batch,
    required this.suffix,
  });

  final String prefix;
  final String serial;
  final int serialInt;
  final String batch;
  final String suffix;
}

class QrBuildResult {
  const QrBuildResult({
    required this.records,
    required this.scanIndex,
    required this.group,
  });

  final List<QrRecord> records;
  final int scanIndex;
  final QrGroup group;
}

class QrGroup {
  const QrGroup({
    required this.prefix,
    required this.batch,
    required this.suffix,
    required this.sourceSerial,
    required this.startSerial,
    required this.count,
    required this.randomTail3,
  });

  final String prefix;
  final String batch;
  final String suffix;
  final String sourceSerial;
  final int startSerial;
  final int count;
  final bool randomTail3;
}

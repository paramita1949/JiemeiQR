String resolveMerchantNameFromHistory({
  required String recognizedName,
  required Iterable<String> historyNames,
}) {
  final original = recognizedName.trim();
  if (original.isEmpty) {
    return '';
  }
  final normalizedRecognized = _normalizeMerchantName(original);
  if (normalizedRecognized.isEmpty) {
    return original;
  }

  final matches = <_MerchantMatch>[];
  for (final historyName in historyNames) {
    final candidate = historyName.trim();
    if (candidate.isEmpty) {
      continue;
    }
    final normalizedCandidate = _normalizeMerchantName(candidate);
    if (normalizedCandidate.isEmpty) {
      continue;
    }
    if (normalizedRecognized == normalizedCandidate) {
      matches.add(_MerchantMatch(candidate, normalizedCandidate.length + 1000));
      continue;
    }
    if (normalizedRecognized.contains(normalizedCandidate) ||
        normalizedCandidate.contains(normalizedRecognized)) {
      matches.add(_MerchantMatch(candidate, normalizedCandidate.length));
    }
  }

  if (matches.isEmpty) {
    return original;
  }
  matches.sort((a, b) => b.score.compareTo(a.score));
  if (matches.length > 1 && matches[0].score == matches[1].score) {
    return original;
  }
  return matches.first.name;
}

String _normalizeMerchantName(String value) {
  var text = value
      .toUpperCase()
      .replaceAll(RegExp(r'[\s　\(\)（）【】\[\]<>《》,，.。:：;；\-_/\\]'), '');
  const suffixes = [
    '有限责任公司',
    '股份有限公司',
    '有限公司',
    '商贸公司',
    '贸易公司',
    '经销商',
    '客户',
    '公司',
    '商贸',
    '贸易',
  ];
  var changed = true;
  while (changed) {
    changed = false;
    for (final suffix in suffixes) {
      if (text.endsWith(suffix) && text.length > suffix.length) {
        text = text.substring(0, text.length - suffix.length);
        changed = true;
      }
    }
  }
  return text;
}

class _MerchantMatch {
  const _MerchantMatch(this.name, this.score);

  final String name;
  final int score;
}

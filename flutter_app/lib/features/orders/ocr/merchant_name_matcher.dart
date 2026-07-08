import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';

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

    final shortHistoryName = normalizedCandidate.length >= 2 &&
        normalizedCandidate.length <= 3 &&
        normalizedRecognized.startsWith(normalizedCandidate);
    if (shortHistoryName) {
      matches.add(_MerchantMatch(candidate, normalizedCandidate.length + 100));
      continue;
    }

    final shorterLength =
        normalizedRecognized.length < normalizedCandidate.length
            ? normalizedRecognized.length
            : normalizedCandidate.length;
    final longerLength =
        normalizedRecognized.length > normalizedCandidate.length
            ? normalizedRecognized.length
            : normalizedCandidate.length;
    final coverage = shorterLength / longerLength;
    if ((normalizedRecognized.contains(normalizedCandidate) ||
            normalizedCandidate.contains(normalizedRecognized)) &&
        shorterLength >= 4 &&
        coverage >= 0.55) {
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

WaybillOcrDraft applyMerchantHistoryMatch(
  WaybillOcrDraft draft,
  Iterable<String> historyNames,
) {
  if (historyNames.isEmpty) {
    return draft;
  }
  final rawName = draft.rawMerchantName.trim();
  final recognizedNames = <String>[
    if (rawName.isNotEmpty) rawName,
    if (draft.merchantName.trim().isNotEmpty) draft.merchantName.trim(),
  ];
  for (final recognizedName in recognizedNames) {
    final matched = resolveMerchantNameFromHistory(
      recognizedName: recognizedName,
      historyNames: historyNames,
    );
    if (matched.trim().isEmpty || matched == recognizedName) {
      continue;
    }
    return WaybillOcrDraft(
      waybillNo: draft.waybillNo,
      merchantName: matched,
      rawMerchantName: rawName.isEmpty ? recognizedName : rawName,
      matchedHistoryMerchant: matched,
      merchantConfidence: 'high',
      merchantMatchReason: '历史商家简称匹配',
      orderDateText: draft.orderDateText,
      rows: draft.rows,
      totalBoxes: draft.totalBoxes,
      warnings: draft.warnings,
    );
  }
  return draft;
}

String _normalizeMerchantName(String value) {
  var text = value
      .toUpperCase()
      .replaceAll(RegExp(r'[（(][^）)]*[）)]'), '')
      .replaceFirst(RegExp(r'二级.*$'), '')
      .replaceAll(RegExp(r'[\s　【】\[\]<>《》,，.。:：;；\-_/\\]'), '');
  text = _stripAdministrativePrefix(text);
  const suffixes = [
    '有限责任公司',
    '股份有限公司',
    '贸易发展有限公司',
    '日用品有限公司',
    '日用品商行',
    '日用品经营部',
    '化妆品经营部',
    '有限公司',
    '商贸公司',
    '贸易公司',
    '个体工商户',
    '经销商',
    '经营部',
    '批发部',
    '商行',
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
        text = _stripAdministrativePrefix(text);
        changed = true;
      }
    }
  }
  return text;
}

String _stripAdministrativePrefix(String value) {
  var text = value.trim();
  var changed = true;
  while (changed) {
    changed = false;
    final markedPrefix = RegExp(
      r'^[\u4e00-\u9fa5]{2,8}(省|市|县|区|镇|乡|街道|街)',
    ).firstMatch(text);
    if (markedPrefix != null && text.length > markedPrefix.end + 1) {
      text = text.substring(markedPrefix.end);
      changed = true;
      continue;
    }
    for (final prefix in _administrativePrefixes) {
      if (text.startsWith(prefix) && text.length > prefix.length + 1) {
        text = text.substring(prefix.length);
        changed = true;
        break;
      }
    }
  }
  return text;
}

const _administrativePrefixes = [
  '黑龙江省',
  '内蒙古',
  '浙江省',
  '上海市',
  '北京市',
  '天津市',
  '重庆市',
  '杭州市',
  '宁波市',
  '温州市',
  '嘉兴市',
  '湖州市',
  '绍兴市',
  '金华市',
  '衢州市',
  '舟山市',
  '台州市',
  '丽水市',
  '义乌市',
  '永康市',
  '龙游县',
  '黑龙江',
  '浙江',
  '江苏',
  '安徽',
  '福建',
  '江西',
  '山东',
  '河南',
  '湖北',
  '湖南',
  '广东',
  '广西',
  '海南',
  '四川',
  '贵州',
  '云南',
  '陕西',
  '甘肃',
  '青海',
  '宁夏',
  '新疆',
  '西藏',
  '辽宁',
  '吉林',
  '河北',
  '山西',
  '北京',
  '上海',
  '天津',
  '重庆',
  '杭州',
  '宁波',
  '温州',
  '嘉兴',
  '湖州',
  '绍兴',
  '金华',
  '衢州',
  '舟山',
  '台州',
  '丽水',
  '义乌',
  '永康',
  '龙游',
];

class _MerchantMatch {
  const _MerchantMatch(this.name, this.score);

  final String name;
  final int score;
}

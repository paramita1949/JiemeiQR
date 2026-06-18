import 'dart:convert';
import 'dart:io';

import 'package:path_provider/path_provider.dart';

typedef SearchPreferenceFileProvider = Future<File> Function();

class SearchRecordPreference {
  const SearchRecordPreference({
    required this.mode,
    required this.query,
  });

  final String mode;
  final String query;

  Map<String, Object?> toJson() => <String, Object?>{
        'mode': mode,
        'query': query,
      };

  static SearchRecordPreference? fromJson(Object? raw) {
    if (raw is! Map) {
      return null;
    }
    final mode = raw['mode'];
    final query = raw['query'];
    if (mode is! String || query is! String) {
      return null;
    }
    final normalizedQuery = query.trim();
    if (mode.trim().isEmpty || normalizedQuery.isEmpty) {
      return null;
    }
    return SearchRecordPreference(
      mode: mode.trim(),
      query: normalizedQuery,
    );
  }

  @override
  bool operator ==(Object other) {
    return other is SearchRecordPreference &&
        other.mode == mode &&
        other.query == query;
  }

  @override
  int get hashCode => Object.hash(mode, query);
}

abstract class SearchPreferenceStore {
  Future<String?> loadOrderSearchMode();

  Future<void> saveOrderSearchMode(String value);

  Future<List<SearchRecordPreference>> loadOrderSearchRecords();

  Future<void> saveOrderSearchRecords(List<SearchRecordPreference> records);

  Future<String?> loadOutboundSearchType();

  Future<void> saveOutboundSearchType(String value);
}

class FileSearchPreferenceStore implements SearchPreferenceStore {
  const FileSearchPreferenceStore({
    SearchPreferenceFileProvider? fileProvider,
  }) : _fileProvider = fileProvider ?? _defaultFile;

  static const String orderMerchant = 'merchant';
  static const String orderWaybill = 'waybill';
  static const String outboundMerchant = 'merchant';
  static const String outboundWaybill = 'waybill';
  static const String outboundProduct = 'product';

  static const String _orderSearchModeKey = 'orderSearchMode';
  static const String _orderSearchRecordsKey = 'orderSearchRecords';
  static const String _outboundSearchTypeKey = 'outboundSearchType';

  final SearchPreferenceFileProvider _fileProvider;

  @override
  Future<String?> loadOrderSearchMode() async {
    final value = (await _load())[_orderSearchModeKey];
    return value is String ? value : null;
  }

  @override
  Future<void> saveOrderSearchMode(String value) async {
    final map = await _load();
    map[_orderSearchModeKey] = value;
    await _save(map);
  }

  @override
  Future<List<SearchRecordPreference>> loadOrderSearchRecords() async {
    final raw = (await _load())[_orderSearchRecordsKey];
    if (raw is! List) {
      return const <SearchRecordPreference>[];
    }
    return raw
        .map(SearchRecordPreference.fromJson)
        .whereType<SearchRecordPreference>()
        .toList(growable: false);
  }

  @override
  Future<void> saveOrderSearchRecords(
    List<SearchRecordPreference> records,
  ) async {
    final map = await _load();
    map[_orderSearchRecordsKey] =
        records.map((record) => record.toJson()).toList(growable: false);
    await _save(map);
  }

  @override
  Future<String?> loadOutboundSearchType() async {
    final value = (await _load())[_outboundSearchTypeKey];
    return value is String ? value : null;
  }

  @override
  Future<void> saveOutboundSearchType(String value) async {
    final map = await _load();
    map[_outboundSearchTypeKey] = value;
    await _save(map);
  }

  Future<Map<String, Object?>> _load() async {
    final file = await _fileProvider();
    if (!await file.exists()) {
      return <String, Object?>{};
    }
    try {
      final decoded = jsonDecode(await file.readAsString());
      if (decoded is Map<String, Object?>) {
        return Map<String, Object?>.from(decoded);
      }
    } catch (_) {
      // Corrupt preferences should not block entering operational screens.
    }
    return <String, Object?>{};
  }

  Future<void> _save(Map<String, Object?> map) async {
    final file = await _fileProvider();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(map));
  }
}

Future<File> _defaultFile() async {
  final directory = await getApplicationSupportDirectory();
  return File('${directory.path}/search_preferences.json');
}

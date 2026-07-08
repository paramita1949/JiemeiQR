import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/features/delivery_plan/delivery_plan_ocr_models.dart';

class DeliveryPlanDao {
  const DeliveryPlanDao(this._database);

  final AppDatabase _database;

  Future<int> createRecordFromDraft(
    DeliveryPlanOcrDraft draft, {
    String? sourceImagePath,
    DateTime? createdAt,
  }) async {
    final enrichedDraft = await draftWithBaseLocations(draft);
    final rows = enrichedDraft.positiveRows;
    if (rows.isEmpty) {
      throw const EmptyDeliveryPlanException();
    }
    final recordCreatedAt = createdAt ?? DateTime.now();
    return _database.transaction(() async {
      final recordId =
          await _database.into(_database.deliveryPlanRecords).insert(
                DeliveryPlanRecordsCompanion.insert(
                  sourceImagePath: Value(sourceImagePath),
                  lineCount: Value(rows.length),
                  totalNeedBoxes: Value(enrichedDraft.totalNeedBoxes),
                  warningsJson: Value(jsonEncode(enrichedDraft.warnings)),
                  createdAt: Value(recordCreatedAt),
                ),
              );
      for (var index = 0; index < rows.length; index += 1) {
        final row = rows[index];
        await _database.into(_database.deliveryPlanItems).insert(
              DeliveryPlanItemsCompanion.insert(
                recordId: recordId,
                rowIndex: Value(index),
                productCode: row.productCode,
                productName: Value(row.productName),
                location: Value(row.location),
                actualBatch: row.actualBatch,
                dateBatch: row.dateBatch,
                stockTotalBoxes: Value(row.stockTotalBoxes),
                deliveryPlanAvailableBoxes:
                    Value(row.deliveryPlanAvailableBoxes),
                needBoxes: Value(row.needBoxes),
                createdAt: Value(recordCreatedAt),
              ),
            );
      }
      return recordId;
    });
  }

  Future<DeliveryPlanOcrDraft> draftWithBaseLocations(
    DeliveryPlanOcrDraft draft,
  ) async {
    final rows = <DeliveryPlanOcrRow>[];
    for (final row in draft.rows) {
      final baseInfo = await _baseInfoForRow(row);
      rows.add(
        row.copyWith(
          location: baseInfo.location,
          boxesPerBoard: baseInfo.boxesPerBoard,
          stockTotalBoxes: baseInfo.appAvailableBoxes,
        ),
      );
    }
    return DeliveryPlanOcrDraft(rows: rows, warnings: draft.warnings);
  }

  Future<List<DeliveryPlanRecordSummary>> recordSummaries() async {
    final records = await (_database.select(_database.deliveryPlanRecords)
          ..orderBy([
            (table) => OrderingTerm.desc(table.createdAt),
            (table) => OrderingTerm.desc(table.id),
          ]))
        .get();
    return records
        .map(
          (record) => DeliveryPlanRecordSummary(
            id: record.id,
            createdAt: record.createdAt,
            lineCount: record.lineCount,
            totalNeedBoxes: record.totalNeedBoxes,
          ),
        )
        .toList(growable: false);
  }

  Future<DeliveryPlanRecordDetail?> recordDetail(int recordId) async {
    final record = await (_database.select(_database.deliveryPlanRecords)
          ..where((table) => table.id.equals(recordId)))
        .getSingleOrNull();
    if (record == null) {
      return null;
    }
    final rawItems = await (_database.select(_database.deliveryPlanItems)
          ..where((table) => table.recordId.equals(recordId))
          ..orderBy([
            (table) => OrderingTerm.asc(table.rowIndex),
            (table) => OrderingTerm.asc(table.id),
          ]))
        .get();
    final items = <DeliveryPlanRecordLine>[];
    for (final item in rawItems) {
      items.add(
        DeliveryPlanRecordLine(
          item: item,
          boxesPerBoard: await _boxesPerBoardForItem(item),
        ),
      );
    }
    return DeliveryPlanRecordDetail(
      record: record,
      items: items,
      warnings: _decodeWarnings(record.warningsJson),
    );
  }

  Future<void> deleteRecord(int recordId) async {
    await _database.transaction(() async {
      await (_database.delete(_database.deliveryPlanItems)
            ..where((table) => table.recordId.equals(recordId)))
          .go();
      await (_database.delete(_database.deliveryPlanRecords)
            ..where((table) => table.id.equals(recordId)))
          .go();
    });
  }

  List<String> _decodeWarnings(String jsonText) {
    try {
      final decoded = jsonDecode(jsonText);
      if (decoded is List) {
        return decoded
            .map((item) => item.toString().trim())
            .where((item) => item.isNotEmpty)
            .toList(growable: false);
      }
    } catch (_) {
      return const <String>[];
    }
    return const <String>[];
  }

  Future<_DeliveryPlanBaseInfo> _baseInfoForRow(
    DeliveryPlanOcrRow row,
  ) async {
    final productCode = _keyPart(row.productCode);
    if (productCode.isEmpty) {
      return const _DeliveryPlanBaseInfo();
    }
    final candidates = await _database.customSelect(
      '''
      SELECT
        b.id AS batch_id,
        b.actual_batch AS actual_batch,
        b.date_batch AS date_batch,
        b.boxes_per_board AS boxes_per_board,
        COALESCE(b.location, '') AS location,
        b.initial_boxes AS initial_boxes,
        b.frozen_boxes AS frozen_boxes,
        COALESCE((
          SELECT SUM(CASE
            WHEN sm.type IN (${StockMovementType.initial.index}, ${StockMovementType.inAdjust.index})
              THEN sm.boxes
            ELSE -sm.boxes
          END)
          FROM stock_movements sm
          WHERE sm.batch_id = b.id
        ), 0) AS delta_boxes,
        COALESCE((
          SELECT SUM(oi.boxes)
          FROM order_items oi
          INNER JOIN orders o ON o.id = oi.order_id
          WHERE oi.batch_id = b.id
            AND o.status != ${OrderStatus.done.index}
        ), 0) AS reserved_boxes
      FROM batches b
      INNER JOIN products p ON p.id = b.product_id
      WHERE p.code = ?
      ''',
      variables: [Variable.withString(productCode)],
      readsFrom: {
        _database.products,
        _database.batches,
        _database.stockMovements,
        _database.orderItems,
        _database.orders,
      },
    ).get();
    if (candidates.isEmpty) {
      return const _DeliveryPlanBaseInfo();
    }
    final actualKey = _keyPart(row.actualBatch);
    final dateKey = _dateKeyPart(row.dateBatch);
    final exact = candidates.where((candidate) {
      final data = candidate.data;
      return actualKey.isNotEmpty &&
          dateKey.isNotEmpty &&
          _keyPart(data['actual_batch']?.toString() ?? '') == actualKey &&
          _dateKeyPart(data['date_batch']?.toString() ?? '') == dateKey;
    }).toList(growable: false);
    if (exact.isNotEmpty) {
      return _baseInfoFromRows(exact);
    }
    final actualMatches = candidates.where((candidate) {
      final data = candidate.data;
      return actualKey.isNotEmpty &&
          _keyPart(data['actual_batch']?.toString() ?? '') == actualKey;
    }).toList(growable: false);
    if (actualMatches.isNotEmpty) {
      return _baseInfoFromRows(actualMatches);
    }
    final dateMatches = candidates.where((candidate) {
      final data = candidate.data;
      return dateKey.isNotEmpty &&
          _dateKeyPart(data['date_batch']?.toString() ?? '') == dateKey;
    }).toList(growable: false);
    return _baseInfoFromRows(dateMatches);
  }

  _DeliveryPlanBaseInfo _baseInfoFromRows(List<QueryRow> rows) {
    final locations = <String>[];
    var appAvailableBoxes = 0;
    int? resultBoxesPerBoard;
    for (final row in rows) {
      final data = row.data;
      final boxesPerBoard = _intData(data['boxes_per_board']);
      if (boxesPerBoard > 0) {
        resultBoxesPerBoard ??= boxesPerBoard;
      }
      final location = data['location']?.toString().trim() ?? '';
      if (location.isNotEmpty && !locations.contains(location)) {
        locations.add(location);
      }
      final currentBoxes =
          _intData(data['initial_boxes']) + _intData(data['delta_boxes']);
      final available = currentBoxes -
          _intData(data['frozen_boxes']) -
          _intData(data['reserved_boxes']);
      if (available > 0) {
        appAvailableBoxes += available;
      }
    }
    return _DeliveryPlanBaseInfo(
      location: locations.join('、'),
      boxesPerBoard: resultBoxesPerBoard ?? 0,
      appAvailableBoxes: appAvailableBoxes,
    );
  }

  Future<int> _boxesPerBoardForItem(DeliveryPlanItem item) async {
    final productCode = _keyPart(item.productCode);
    if (productCode.isEmpty) {
      return 0;
    }
    final rows = await _database.customSelect(
      '''
      SELECT
        b.actual_batch AS actual_batch,
        b.date_batch AS date_batch,
        b.boxes_per_board AS boxes_per_board
      FROM batches b
      INNER JOIN products p ON p.id = b.product_id
      WHERE p.code = ?
      ''',
      variables: [Variable.withString(productCode)],
      readsFrom: {
        _database.products,
        _database.batches,
      },
    ).get();
    if (rows.isEmpty) {
      return 0;
    }
    final actualKey = _keyPart(item.actualBatch);
    final dateKey = _dateKeyPart(item.dateBatch);
    int firstPositive(List<QueryRow> candidates) {
      for (final candidate in candidates) {
        final value = _intData(candidate.data['boxes_per_board']);
        if (value > 0) {
          return value;
        }
      }
      return 0;
    }

    final exact = rows.where((candidate) {
      final data = candidate.data;
      return actualKey.isNotEmpty &&
          dateKey.isNotEmpty &&
          _keyPart(data['actual_batch']?.toString() ?? '') == actualKey &&
          _dateKeyPart(data['date_batch']?.toString() ?? '') == dateKey;
    }).toList(growable: false);
    final exactValue = firstPositive(exact);
    if (exactValue > 0) {
      return exactValue;
    }

    final actualMatches = rows.where((candidate) {
      final data = candidate.data;
      return actualKey.isNotEmpty &&
          _keyPart(data['actual_batch']?.toString() ?? '') == actualKey;
    }).toList(growable: false);
    final actualValue = firstPositive(actualMatches);
    if (actualValue > 0) {
      return actualValue;
    }

    final dateMatches = rows.where((candidate) {
      final data = candidate.data;
      return dateKey.isNotEmpty &&
          _dateKeyPart(data['date_batch']?.toString() ?? '') == dateKey;
    }).toList(growable: false);
    final dateValue = firstPositive(dateMatches);
    if (dateValue > 0) {
      return dateValue;
    }
    return firstPositive(rows);
  }
}

class _DeliveryPlanBaseInfo {
  const _DeliveryPlanBaseInfo({
    this.location = '',
    this.boxesPerBoard = 0,
    this.appAvailableBoxes = 0,
  });

  final String location;
  final int boxesPerBoard;
  final int appAvailableBoxes;
}

class DeliveryPlanRecordSummary {
  const DeliveryPlanRecordSummary({
    required this.id,
    required this.createdAt,
    required this.lineCount,
    required this.totalNeedBoxes,
  });

  final int id;
  final DateTime createdAt;
  final int lineCount;
  final int totalNeedBoxes;
}

class DeliveryPlanRecordDetail {
  const DeliveryPlanRecordDetail({
    required this.record,
    required this.items,
    required this.warnings,
  });

  final DeliveryPlanRecord record;
  final List<DeliveryPlanRecordLine> items;
  final List<String> warnings;

  int get totalNeedBoxes => record.totalNeedBoxes;
}

class DeliveryPlanRecordLine {
  const DeliveryPlanRecordLine({
    required this.item,
    required this.boxesPerBoard,
  });

  final DeliveryPlanItem item;
  final int boxesPerBoard;

  int get id => item.id;
  int get recordId => item.recordId;
  int get rowIndex => item.rowIndex;
  String get productCode => item.productCode;
  String get productName => item.productName;
  String get location => item.location;
  String get actualBatch => item.actualBatch;
  String get dateBatch => item.dateBatch;
  int get stockTotalBoxes => item.stockTotalBoxes;
  int get deliveryPlanAvailableBoxes => item.deliveryPlanAvailableBoxes;
  int get needBoxes => item.needBoxes;
  DateTime get createdAt => item.createdAt;
}

class EmptyDeliveryPlanException implements Exception {
  const EmptyDeliveryPlanException();

  @override
  String toString() => '没有可生成记录的交货计划行';
}

String _keyPart(String value) =>
    value.trim().toUpperCase().replaceAll(RegExp(r'\s+'), '');

String _dateKeyPart(String value) {
  final normalized = _keyPart(value).replaceAll('。', '.');
  final match = RegExp(r'(\d{4})[.\-/年](\d{1,2})[.\-/月](\d{1,2})日?')
      .firstMatch(normalized);
  if (match == null) {
    return normalized;
  }
  return '${match.group(1)}.${int.parse(match.group(2)!)}.${int.parse(match.group(3)!)}';
}

int _intData(Object? value) {
  if (value is int) {
    return value;
  }
  if (value is num) {
    return value.round();
  }
  return int.tryParse(value?.toString() ?? '') ?? 0;
}

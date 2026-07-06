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
    final rows = draft.positiveRows;
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
                  totalNeedBoxes: Value(draft.totalNeedBoxes),
                  warningsJson: Value(jsonEncode(draft.warnings)),
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
    final items = await (_database.select(_database.deliveryPlanItems)
          ..where((table) => table.recordId.equals(recordId))
          ..orderBy([
            (table) => OrderingTerm.asc(table.rowIndex),
            (table) => OrderingTerm.asc(table.id),
          ]))
        .get();
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
  final List<DeliveryPlanItem> items;
  final List<String> warnings;

  int get totalNeedBoxes => record.totalNeedBoxes;
}

class EmptyDeliveryPlanException implements Exception {
  const EmptyDeliveryPlanException();

  @override
  String toString() => '没有可生成记录的交货计划行';
}

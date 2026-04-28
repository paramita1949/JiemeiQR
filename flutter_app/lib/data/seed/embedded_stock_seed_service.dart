import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';

class EmbeddedStockSeedService {
  const EmbeddedStockSeedService(
    this._database, {
    this.assetBundle,
  });

  final AppDatabase _database;
  final AssetBundle? assetBundle;

  static const String seedAssetPath = 'assets/seed/embedded_stock_seed.json';

  Future<bool> seedIfDatabaseEmpty() async {
    final productQuery = _database.select(_database.products)..limit(1);
    final existingProduct = await productQuery.getSingleOrNull();
    if (existingProduct != null) {
      return false;
    }

    final raw = await (assetBundle ?? rootBundle).loadString(seedAssetPath);
    final rows = _parseSeedRows(raw);
    if (rows.isEmpty) {
      return false;
    }

    final productDao = ProductDao(_database);
    await _database.transaction(() async {
      final productIdByCode = <String, int>{};
      for (final row in rows) {
        if (row.currentBoxes <= 0) {
          continue;
        }
        final productId = productIdByCode[row.code] ??
            await productDao.createProduct(
              code: row.code,
              name: row.name,
              boxesPerBoard: row.boxesPerBoard,
              piecesPerBox: row.piecesPerBox,
            );
        productIdByCode[row.code] = productId;
        await productDao.createBatch(
          productId: productId,
          actualBatch: row.actualBatch,
          dateBatch: row.dateBatch,
          initialBoxes: row.currentBoxes,
          boxesPerBoard: row.boxesPerBoard,
          tsRequired: false,
          location: row.location,
          remark: row.remark,
        );
      }
    });

    return true;
  }
}

List<EmbeddedSeedRow> _parseSeedRows(String raw) {
  final payload = jsonDecode(raw);
  if (payload is! List) {
    return const <EmbeddedSeedRow>[];
  }
  return payload
      .whereType<Map<String, dynamic>>()
      .map(EmbeddedSeedRow.fromJson)
      .toList();
}

class EmbeddedSeedRow {
  const EmbeddedSeedRow({
    required this.code,
    required this.name,
    required this.actualBatch,
    required this.dateBatch,
    required this.currentBoxes,
    required this.piecesPerBox,
    required this.boxesPerBoard,
    required this.location,
    required this.remark,
  });

  final String code;
  final String name;
  final String actualBatch;
  final String dateBatch;
  final int currentBoxes;
  final int piecesPerBox;
  final int boxesPerBoard;
  final String? location;
  final String? remark;

  static EmbeddedSeedRow fromJson(Map<String, dynamic> json) {
    return EmbeddedSeedRow(
      code: (json['code'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      actualBatch: (json['actualBatch'] as String? ?? '').trim(),
      dateBatch: (json['dateBatch'] as String? ?? '').trim(),
      currentBoxes: (json['currentBoxes'] as num?)?.toInt() ?? 0,
      piecesPerBox: (json['piecesPerBox'] as num?)?.toInt() ?? 30,
      boxesPerBoard: (json['boxesPerBoard'] as num?)?.toInt() ?? 40,
      location: (json['location'] as String?)?.trim().isEmpty == true
          ? null
          : (json['location'] as String?)?.trim(),
      remark: (json['remark'] as String?)?.trim().isEmpty == true
          ? null
          : (json['remark'] as String?)?.trim(),
    );
  }
}

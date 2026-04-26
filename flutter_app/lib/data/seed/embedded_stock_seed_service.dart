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
    final existingProduct =
        await _database.select(_database.products).getSingleOrNull();
    if (existingProduct != null) {
      return false;
    }

    final raw = await (assetBundle ?? rootBundle).loadString(seedAssetPath);
    final payload = jsonDecode(raw);
    if (payload is! List) {
      return false;
    }
    final rows = payload
        .whereType<Map<String, dynamic>>()
        .map(EmbeddedSeedRow.fromJson)
        .toList();
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
          location: '浙江仓',
          remark: '内置库存',
        );
      }
    });

    return true;
  }
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
  });

  final String code;
  final String name;
  final String actualBatch;
  final String dateBatch;
  final int currentBoxes;
  final int piecesPerBox;
  final int boxesPerBoard;

  static EmbeddedSeedRow fromJson(Map<String, dynamic> json) {
    return EmbeddedSeedRow(
      code: (json['code'] as String? ?? '').trim(),
      name: (json['name'] as String? ?? '').trim(),
      actualBatch: (json['actualBatch'] as String? ?? '').trim(),
      dateBatch: (json['dateBatch'] as String? ?? '').trim(),
      currentBoxes: (json['currentBoxes'] as num?)?.toInt() ?? 0,
      piecesPerBox: (json['piecesPerBox'] as num?)?.toInt() ?? 30,
      boxesPerBoard: (json['boxesPerBoard'] as num?)?.toInt() ?? 40,
    );
  }
}

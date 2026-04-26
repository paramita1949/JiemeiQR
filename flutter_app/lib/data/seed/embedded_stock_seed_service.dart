import 'dart:convert';

import 'package:flutter/services.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/data_change_notifier.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/shared/utils/startup_trace.dart';

class EmbeddedStockSeedService {
  const EmbeddedStockSeedService(
    this._database, {
    this.assetBundle,
  });

  final AppDatabase _database;
  final AssetBundle? assetBundle;

  static const String seedAssetPath = 'assets/seed/embedded_stock_seed.json';

  Future<bool> seedIfDatabaseEmpty() async {
    StartupTrace.mark('seedIfDatabaseEmpty enter');
    final existingProduct =
        await _database.select(_database.products).getSingleOrNull();
    if (existingProduct != null) {
      StartupTrace.mark('seedIfDatabaseEmpty skip (products already exist)');
      return false;
    }

    final raw = await StartupTrace.time(
      'seed.loadString',
      () => (assetBundle ?? rootBundle).loadString(seedAssetPath),
    );
    final rows = await StartupTrace.time(
      'seed.parse json',
      () async => _parseSeedRows(raw),
    );
    if (rows.isEmpty) {
      StartupTrace.mark('seed rows empty');
      return false;
    }

    final productDao = ProductDao(_database);
    await StartupTrace.time('seed.insert transaction', () async {
      await DataChangeNotifier.instance.runInBatch(() async {
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
      });
    });
    StartupTrace.mark('seed insert completed');

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

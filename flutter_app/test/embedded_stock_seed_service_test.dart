import 'dart:convert';

import 'package:drift/native.dart';
import 'package:flutter/services.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/seed/embedded_stock_seed_service.dart';

class _FakeAssetBundle extends CachingAssetBundle {
  _FakeAssetBundle(this._payload);

  final String _payload;

  @override
  Future<String> loadString(String key, {bool cache = true}) async {
    return _payload;
  }

  @override
  Future<ByteData> load(String key) {
    throw UnimplementedError();
  }
}

void main() {
  test('embedded stock seed imports rows when database is empty', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    final payload = jsonEncode([
      {
        'code': '72067',
        'name': '六神花露水195ML',
        'actualBatch': 'ELTESTEZ',
        'dateBatch': '2029.6.1',
        'currentBoxes': 100,
        'piecesPerBox': 30,
        'boxesPerBoard': 40,
      },
    ]);
    final service = EmbeddedStockSeedService(
      database,
      assetBundle: _FakeAssetBundle(payload),
    );

    final seeded = await service.seedIfDatabaseEmpty();
    final products = await database.select(database.products).get();
    final batches = await database.select(database.batches).get();

    expect(seeded, isTrue);
    expect(products.length, 1);
    expect(batches.length, 1);
    expect(products.first.code, '72067');
    expect(batches.first.initialBoxes, 100);

    await database.close();
  });

  test('embedded stock seed skips when database already has data', () async {
    final database = AppDatabase.forTesting(NativeDatabase.memory());
    await database.into(database.products).insert(
          ProductsCompanion.insert(
            code: '72067',
            name: '已有产品',
            boxesPerBoard: 40,
            piecesPerBox: 30,
          ),
        );
    final service = EmbeddedStockSeedService(
      database,
      assetBundle: _FakeAssetBundle('[]'),
    );

    final seeded = await service.seedIfDatabaseEmpty();

    expect(seeded, isFalse);
    await database.close();
  });
}

import 'dart:io';

import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/seed/startup_seed_service.dart';

void main() {
  test('startup seed runs once and marker prevents reseed after reset',
      () async {
    final tempDir = await Directory.systemTemp.createTemp('jiemei-seed-once-');
    final marker = File('${tempDir.path}/.embedded_stock_seeded');
    var seedCalls = 0;

    final firstDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    final firstService = StartupSeedService(
      database: firstDatabase,
      markerFileProvider: () async => marker,
      seedIfEmpty: () async {
        seedCalls += 1;
        await firstDatabase.into(firstDatabase.products).insert(
              ProductsCompanion.insert(
                code: '72067',
                name: '内置产品',
                boxesPerBoard: 40,
                piecesPerBox: 30,
              ),
            );
        return true;
      },
    );

    final firstSeeded = await firstService.seedOnlyOnFirstInstall();

    expect(firstSeeded, isTrue);
    expect(seedCalls, 1);
    expect(await marker.exists(), isTrue);
    expect(
        await firstDatabase.select(firstDatabase.products).get(), hasLength(1));
    await firstDatabase.close();

    final resetDatabase = AppDatabase.forTesting(NativeDatabase.memory());
    final secondService = StartupSeedService(
      database: resetDatabase,
      markerFileProvider: () async => marker,
      seedIfEmpty: () async {
        seedCalls += 1;
        return true;
      },
    );

    final secondSeeded = await secondService.seedOnlyOnFirstInstall();

    expect(secondSeeded, isFalse);
    expect(seedCalls, 1);
    expect(await resetDatabase.select(resetDatabase.products).get(), isEmpty);
    await resetDatabase.close();
  });

  test('startup seed marks existing data as initialized without adding stock',
      () async {
    final tempDir =
        await Directory.systemTemp.createTemp('jiemei-seed-existing-');
    final marker = File('${tempDir.path}/.embedded_stock_seeded');
    var seedCalls = 0;
    final database = AppDatabase.forTesting(NativeDatabase.memory());

    final service = StartupSeedService(
      database: database,
      markerFileProvider: () async => marker,
      seedIfEmpty: () async {
        seedCalls += 1;
        return false;
      },
    );

    final seeded = await service.seedOnlyOnFirstInstall();

    expect(seeded, isFalse);
    expect(seedCalls, 1);
    expect(await marker.exists(), isTrue);
    await database.close();
  });
}

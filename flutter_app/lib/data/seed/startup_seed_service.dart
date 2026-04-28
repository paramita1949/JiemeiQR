import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/seed/embedded_stock_seed_service.dart';

typedef SeedMarkerFileProvider = Future<File> Function();
typedef SeedIfEmpty = Future<bool> Function();

class StartupSeedService {
  StartupSeedService({
    required AppDatabase database,
    SeedMarkerFileProvider? markerFileProvider,
    SeedIfEmpty? seedIfEmpty,
  })  : _markerFileProvider = markerFileProvider ?? _defaultMarkerFile,
        _seedIfEmpty = seedIfEmpty ??
            (() => EmbeddedStockSeedService(database).seedIfDatabaseEmpty());

  final SeedMarkerFileProvider _markerFileProvider;
  final SeedIfEmpty _seedIfEmpty;

  Future<bool> seedOnlyOnFirstInstall() async {
    final marker = await _markerFileProvider();
    if (await marker.exists()) {
      return false;
    }

    final seeded = await _seedIfEmpty();
    if (!await marker.parent.exists()) {
      await marker.parent.create(recursive: true);
    }
    await marker.writeAsString(DateTime.now().toIso8601String());
    return seeded;
  }

  static Future<File> _defaultMarkerFile() async {
    final dir = await getApplicationDocumentsDirectory();
    return File(p.join(dir.path, '.embedded_stock_seeded'));
  }
}

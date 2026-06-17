import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';

class WaybillOcrMatcher {
  const WaybillOcrMatcher(this._productDao);

  final ProductDao _productDao;

  Future<MatchedWaybillOcrDraft> match(WaybillOcrDraft draft) async {
    final products = await _productDao.allProducts();
    final batchesByProduct = <int, List<BatchRecord>>{};
    final availableBoxesByBatchId = <int, int>{};
    for (final product in products) {
      final availableBatches = await _productDao.availableBatchesForProduct(
        product.id,
        includeZeroAvailable: true,
      );
      batchesByProduct[product.id] = [
        for (final row in availableBatches) row.batch,
      ];
      for (final row in availableBatches) {
        availableBoxesByBatchId[row.batch.id] = row.availableBoxes;
      }
    }
    final batchMatchesByActual = _buildBatchMatchesByActual(
      products: products,
      batchesByProduct: batchesByProduct,
    );
    final groups = <_OcrLineKey, List<_ResolvedOcrRow>>{};

    for (final row in draft.rows.where((row) => row.boxes > 0)) {
      Product? product = _matchProduct(products, row);
      BatchRecord? batch = product == null
          ? null
          : _matchBatchWithHints(
              product: product,
              row: row,
              batches: batchesByProduct[product.id] ?? const [],
            );
      final reasons = <String>[];
      var candidateBatches = const <BatchRecord>[];
      var status = OcrLineStatus.unmatched;

      final fromBatch = _reverseByActualBatch(
        row: row,
        currentProduct: product,
        byActual: batchMatchesByActual,
      );
      if (fromBatch != null) {
        product = fromBatch.product;
        batch = fromBatch.batch;
        reasons.add(fromBatch.reason);
        status = fromBatch.status;
      } else if (product != null && batch == null) {
        final fromProductDate = _reverseByProductAndDate(
          product: product,
          row: row,
          batches: batchesByProduct[product.id] ?? const [],
          availableBoxesByBatchId: availableBoxesByBatchId,
        );
        if (fromProductDate != null) {
          batch = fromProductDate.batch;
          reasons.add(fromProductDate.reason);
          status = fromProductDate.status;
          candidateBatches = fromProductDate.candidateBatches;
        }
      } else if (product != null && batch != null) {
        status = OcrLineStatus.matched;
      }

      if (product != null && batch != null) {
        final preferred = _preferAvailableSameDateBatch(
          product: product,
          row: row,
          selectedBatch: batch,
          batches: batchesByProduct[product.id] ?? const [],
          availableBoxesByBatchId: availableBoxesByBatchId,
        );
        if (preferred != null) {
          batch = preferred.batch;
          status = preferred.status;
          candidateBatches = preferred.candidateBatches;
          reasons.add(preferred.reason);
        }
      }

      final key = _OcrLineKey(
        productId: product?.id,
        actualBatch: _norm(batch?.actualBatch ?? row.actualBatch),
        unresolvedProduct: _norm(
            row.productCode.isNotEmpty ? row.productCode : row.productName),
      );
      groups.putIfAbsent(key, () => <_ResolvedOcrRow>[]).add(
            _ResolvedOcrRow(
              row: row,
              product: product,
              batch: batch,
              status: status,
              reasons: reasons,
              candidateBatches: candidateBatches,
            ),
          );
    }

    final lines = groups.values.map(_buildLine).toList()
      ..sort((a, b) {
        final productCmp =
            (a.product?.code ?? '').compareTo(b.product?.code ?? '');
        if (productCmp != 0) {
          return productCmp;
        }
        return (a.batch?.actualBatch ?? '')
            .compareTo(b.batch?.actualBatch ?? '');
      });

    return MatchedWaybillOcrDraft(
      source: draft,
      orderDate: _parseDate(draft.orderDateText),
      lines: lines,
    );
  }

  Product? _matchProduct(List<Product> products, WaybillOcrRow row) {
    final code = _norm(row.productCode);
    if (code.isNotEmpty) {
      for (final product in products) {
        if (_norm(product.code) == code) {
          return product;
        }
      }
    }
    final name = _norm(row.productName);
    if (name.isEmpty) {
      return null;
    }
    for (final product in products) {
      if (_norm(product.name) == name || _norm(product.name).contains(name)) {
        return product;
      }
    }
    return null;
  }

  BatchRecord? _matchBatchWithHints({
    required Product product,
    required WaybillOcrRow row,
    required List<BatchRecord> batches,
  }) {
    final actualBatch = _norm(row.actualBatch);
    final dateBatch = _dateBatchKey(row.dateBatch);
    if (dateBatch.isNotEmpty) {
      final byDate = batches
          .where((batch) => _dateBatchKey(batch.dateBatch) == dateBatch)
          .toList();
      if (byDate.length == 1) {
        return byDate.single;
      }
      if (byDate.length > 1) {
        if (actualBatch.isNotEmpty) {
          final byActual = byDate
              .where((batch) => _norm(batch.actualBatch) == actualBatch)
              .toList();
          if (byActual.length == 1) {
            return byActual.single;
          }
        }
        return null;
      }
    }
    if (actualBatch.isNotEmpty) {
      final exact = batches
          .where((batch) => _norm(batch.actualBatch) == actualBatch)
          .toList();
      if (exact.length == 1) {
        return exact.single;
      }
      if (exact.length > 1 && dateBatch.isNotEmpty) {
        final withDate = exact
            .where((batch) => _dateBatchKey(batch.dateBatch) == dateBatch)
            .toList();
        if (withDate.length == 1) {
          return withDate.single;
        }
      }
      return exact.isNotEmpty ? exact.first : null;
    }
    return null;
  }

  Map<String, List<_BatchProductMatch>> _buildBatchMatchesByActual({
    required List<Product> products,
    required Map<int, List<BatchRecord>> batchesByProduct,
  }) {
    final productById = {for (final product in products) product.id: product};
    final map = <String, List<_BatchProductMatch>>{};
    for (final entry in batchesByProduct.entries) {
      final product = productById[entry.key];
      if (product == null) {
        continue;
      }
      for (final batch in entry.value) {
        final key = _norm(batch.actualBatch);
        if (key.isEmpty) {
          continue;
        }
        map.putIfAbsent(key, () => <_BatchProductMatch>[]).add(
              _BatchProductMatch(
                product: product,
                batch: batch,
                reason: '',
                status: OcrLineStatus.autoFixed,
              ),
            );
      }
    }
    return map;
  }

  _BatchProductMatch? _reverseByActualBatch({
    required WaybillOcrRow row,
    required Product? currentProduct,
    required Map<String, List<_BatchProductMatch>> byActual,
  }) {
    final actualBatch = _norm(row.actualBatch);
    if (actualBatch.isEmpty) {
      return null;
    }
    final candidates = byActual[actualBatch] ?? const <_BatchProductMatch>[];
    if (candidates.isEmpty) {
      return null;
    }
    if (currentProduct != null) {
      final inProduct = candidates
          .where((candidate) => candidate.product.id == currentProduct.id)
          .toList();
      if (inProduct.length == 1) {
        return _BatchProductMatch(
          product: inProduct.single.product,
          batch: inProduct.single.batch,
          reason: '批号命中，自动补全产品与日期',
          status: OcrLineStatus.autoFixed,
        );
      }
    }
    if (candidates.length == 1) {
      return _BatchProductMatch(
        product: candidates.single.product,
        batch: candidates.single.batch,
        reason: '批号命中，自动修正产品与日期',
        status: OcrLineStatus.autoFixed,
      );
    }
    return null;
  }

  _BatchProductMatch? _reverseByProductAndDate({
    required Product product,
    required WaybillOcrRow row,
    required List<BatchRecord> batches,
    required Map<int, int> availableBoxesByBatchId,
  }) {
    final dateBatch = _dateBatchKey(row.dateBatch);
    if (dateBatch.isEmpty) {
      return null;
    }
    final byDate = batches
        .where((batch) => _dateBatchKey(batch.dateBatch) == dateBatch)
        .toList()
      ..sort(
        (a, b) => _compareOcrBatchCandidates(
          a,
          b,
          availableBoxesByBatchId: availableBoxesByBatchId,
          requestedBoxes: row.boxes,
        ),
      );
    if (byDate.isEmpty) {
      return null;
    }
    if (byDate.length == 1) {
      return _BatchProductMatch(
        product: product,
        batch: byDate.single,
        reason: '产品+日期命中，自动补全批号',
        status: OcrLineStatus.autoFixed,
        candidateBatches: byDate,
      );
    }
    final selectedRank = _availabilityRank(
      byDate.first,
      availableBoxesByBatchId,
      requestedBoxes: row.boxes,
    );
    final hasLowerPriorityCandidate = byDate.any(
      (batch) =>
          _availabilityRank(
            batch,
            availableBoxesByBatchId,
            requestedBoxes: row.boxes,
          ) >
          selectedRank,
    );
    return _BatchProductMatch(
      product: product,
      batch: byDate.first,
      reason: selectedRank < 2 && hasLowerPriorityCandidate
          ? '产品+日期命中多个批号，已优先代选可用批号'
          : '产品+日期命中多个批号，已默认代选批号1',
      status: OcrLineStatus.needReview,
      candidateBatches: byDate,
    );
  }

  _BatchProductMatch? _preferAvailableSameDateBatch({
    required Product product,
    required WaybillOcrRow row,
    required BatchRecord selectedBatch,
    required List<BatchRecord> batches,
    required Map<int, int> availableBoxesByBatchId,
  }) {
    final selectedAvailable = _availableBoxes(
      selectedBatch,
      availableBoxesByBatchId,
    );
    if (selectedAvailable > 0) {
      return null;
    }
    final dateBatch = _dateBatchKey(row.dateBatch);
    if (dateBatch.isEmpty) {
      return null;
    }
    final byDate = batches
        .where((batch) => _dateBatchKey(batch.dateBatch) == dateBatch)
        .toList()
      ..sort(
        (a, b) => _compareOcrBatchCandidates(
          a,
          b,
          availableBoxesByBatchId: availableBoxesByBatchId,
          requestedBoxes: row.boxes,
        ),
      );
    if (byDate.length <= 1) {
      return null;
    }
    final preferred = byDate.first;
    final preferredAvailable = _availableBoxes(
      preferred,
      availableBoxesByBatchId,
    );
    if (preferred.id == selectedBatch.id || preferredAvailable <= 0) {
      return null;
    }
    return _BatchProductMatch(
      product: product,
      batch: preferred,
      reason: '批号可用为0，已优先代选同日期可用批号',
      status: OcrLineStatus.needReview,
      candidateBatches: byDate,
    );
  }

  int _compareOcrBatchCandidates(
    BatchRecord a,
    BatchRecord b, {
    required Map<int, int> availableBoxesByBatchId,
    required int requestedBoxes,
  }) {
    final rankCompare = _availabilityRank(
      a,
      availableBoxesByBatchId,
      requestedBoxes: requestedBoxes,
    ).compareTo(
      _availabilityRank(
        b,
        availableBoxesByBatchId,
        requestedBoxes: requestedBoxes,
      ),
    );
    if (rankCompare != 0) {
      return rankCompare;
    }
    return a.actualBatch.compareTo(b.actualBatch);
  }

  int _availabilityRank(
    BatchRecord batch,
    Map<int, int> availableBoxesByBatchId, {
    required int requestedBoxes,
  }) {
    final available = _availableBoxes(batch, availableBoxesByBatchId);
    if (requestedBoxes > 0 && available >= requestedBoxes) {
      return 0;
    }
    if (available > 0) {
      return 1;
    }
    return 2;
  }

  int _availableBoxes(
    BatchRecord batch,
    Map<int, int> availableBoxesByBatchId,
  ) {
    return availableBoxesByBatchId[batch.id] ?? 0;
  }

  MatchedWaybillOcrLine _buildLine(List<_ResolvedOcrRow> rows) {
    final first = rows.first;
    final boxes = rows.fold<int>(0, (sum, row) => sum + row.row.boxes);
    final messages = <String>[];
    final reasons = <String>[
      for (final row in rows) ...row.reasons,
    ];
    final candidateBatches = <BatchRecord>[
      for (final row in rows) ...row.candidateBatches,
    ];
    if (first.product == null) {
      messages.add('未匹配产品');
    }
    if (first.product != null && first.batch == null) {
      messages.add('未匹配批号');
    }
    if (rows.length > 1) {
      messages.add('已合并${rows.length}行');
    }
    final status = first.status ??
        (first.product != null && first.batch != null
            ? OcrLineStatus.matched
            : OcrLineStatus.unmatched);
    return MatchedWaybillOcrLine(
      product: first.product,
      batch: first.batch,
      boxes: boxes,
      sourceRows: rows.map((row) => row.row).toList(growable: false),
      sourceBoxes: rows.map((row) => row.row.boxes).toList(growable: false),
      messages: messages,
      reasons: reasons.toSet().toList(growable: false),
      status: status,
      candidateBatches: candidateBatches
          .fold<Map<int, BatchRecord>>(<int, BatchRecord>{}, (map, batch) {
            map[batch.id] = batch;
            return map;
          })
          .values
          .toList(growable: false),
    );
  }
}

class _ResolvedOcrRow {
  const _ResolvedOcrRow({
    required this.row,
    required this.product,
    required this.batch,
    required this.status,
    required this.reasons,
    required this.candidateBatches,
  });

  final WaybillOcrRow row;
  final Product? product;
  final BatchRecord? batch;
  final OcrLineStatus? status;
  final List<String> reasons;
  final List<BatchRecord> candidateBatches;
}

class _BatchProductMatch {
  const _BatchProductMatch({
    required this.product,
    required this.batch,
    required this.reason,
    required this.status,
    this.candidateBatches = const [],
  });

  final Product product;
  final BatchRecord batch;
  final String reason;
  final OcrLineStatus status;
  final List<BatchRecord> candidateBatches;
}

class _OcrLineKey {
  const _OcrLineKey({
    required this.productId,
    required this.actualBatch,
    required this.unresolvedProduct,
  });

  final int? productId;
  final String actualBatch;
  final String unresolvedProduct;

  @override
  bool operator ==(Object other) {
    return other is _OcrLineKey &&
        other.productId == productId &&
        other.actualBatch == actualBatch &&
        other.unresolvedProduct == unresolvedProduct;
  }

  @override
  int get hashCode => Object.hash(productId, actualBatch, unresolvedProduct);
}

String _norm(String value) {
  return value
      .trim()
      .toUpperCase()
      .replaceAll(RegExp(r'\s+'), '')
      .replaceAll('。', '.');
}

String _dateBatchKey(String value) {
  final normalized = _norm(value);
  final match = RegExp(r'(\d{4})[.\-/年](\d{1,2})[.\-/月](\d{1,2})日?')
      .firstMatch(normalized);
  if (match == null) {
    return normalized;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  return '$year.$month.$day';
}

DateTime? _parseDate(String value) {
  final match =
      RegExp(r'(\d{4})[.\-/年](\d{1,2})[.\-/月](\d{1,2})').firstMatch(value);
  if (match == null) {
    return null;
  }
  final year = int.parse(match.group(1)!);
  final month = int.parse(match.group(2)!);
  final day = int.parse(match.group(3)!);
  return DateTime(year, month, day);
}

import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/features/orders/ocr/waybill_ocr_models.dart';

class WaybillOcrMatcher {
  const WaybillOcrMatcher(this._productDao);

  final ProductDao _productDao;

  Future<MatchedWaybillOcrDraft> match(WaybillOcrDraft draft) async {
    final products = await _productDao.allProducts();
    final groups = <_OcrLineKey, List<_ResolvedOcrRow>>{};

    for (final row in draft.rows.where((row) => row.boxes > 0)) {
      final product = _matchProduct(products, row);
      final batch = product == null ? null : await _matchBatch(product, row);
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

  Future<BatchRecord?> _matchBatch(Product product, WaybillOcrRow row) async {
    final batches = await _productDao.availableBatchesForProduct(product.id);
    final actualBatch = _norm(row.actualBatch);
    final dateBatch = _norm(row.dateBatch);
    if (actualBatch.isNotEmpty) {
      final exact = batches
          .where((batch) => _norm(batch.batch.actualBatch) == actualBatch)
          .toList();
      if (exact.length == 1) {
        return exact.single.batch;
      }
      if (exact.length > 1 && dateBatch.isNotEmpty) {
        final withDate = exact
            .where((batch) => _norm(batch.batch.dateBatch) == dateBatch)
            .toList();
        if (withDate.length == 1) {
          return withDate.single.batch;
        }
      }
      return exact.isNotEmpty ? exact.first.batch : null;
    }
    if (dateBatch.isNotEmpty) {
      final byDate = batches
          .where((batch) => _norm(batch.batch.dateBatch) == dateBatch)
          .toList();
      if (byDate.length == 1) {
        return byDate.single.batch;
      }
    }
    return null;
  }

  MatchedWaybillOcrLine _buildLine(List<_ResolvedOcrRow> rows) {
    final first = rows.first;
    final boxes = rows.fold<int>(0, (sum, row) => sum + row.row.boxes);
    final messages = <String>[];
    if (first.product == null) {
      messages.add('未匹配产品');
    }
    if (first.product != null && first.batch == null) {
      messages.add('未匹配批号');
    }
    if (rows.length > 1) {
      messages.add('已合并${rows.length}行');
    }
    return MatchedWaybillOcrLine(
      product: first.product,
      batch: first.batch,
      boxes: boxes,
      sourceRows: rows.map((row) => row.row).toList(growable: false),
      sourceBoxes: rows.map((row) => row.row.boxes).toList(growable: false),
      messages: messages,
    );
  }
}

class _ResolvedOcrRow {
  const _ResolvedOcrRow({
    required this.row,
    required this.product,
    required this.batch,
  });

  final WaybillOcrRow row;
  final Product? product;
  final BatchRecord? batch;
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

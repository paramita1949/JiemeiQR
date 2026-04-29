import 'package:flutter/material.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/product_dao.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';

class ProductBatchPicker extends StatelessWidget {
  const ProductBatchPicker({
    super.key,
    required this.products,
    required this.availableBatches,
    required this.selectedProduct,
    required this.selectedBatch,
    required this.onProductChanged,
    required this.onBatchChanged,
  });

  final List<Product> products;
  final List<AvailableBatch> availableBatches;
  final Product? selectedProduct;
  final AvailableBatch? selectedBatch;
  final ValueChanged<int?> onProductChanged;
  final ValueChanged<int?> onBatchChanged;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        DropdownButtonFormField<int>(
          initialValue: selectedProduct?.id,
          validator: (value) => value == null ? '必选' : null,
          decoration: _inputDecoration('产品'),
          items: products
              .map(
                (product) => DropdownMenuItem(
                  value: product.id,
                  child: Text(product.code),
                ),
              )
              .toList(),
          onChanged: onProductChanged,
        ),
        const SizedBox(height: 10),
        DropdownButtonFormField<int>(
          initialValue: selectedBatch?.batch.id,
          validator: (value) => value == null ? '必选' : null,
          decoration: _inputDecoration('批号'),
          items: availableBatches
              .map(
                (row) => DropdownMenuItem(
                  value: row.batch.id,
                  child: RichText(
                    text: TextSpan(
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w600,
                      ),
                      children: [
                        ..._batchCodeSpans(
                          row.batch.actualBatch,
                          variants: availableBatches
                              .where((item) =>
                                  item.batch.dateBatch == row.batch.dateBatch)
                              .map((item) => item.batch.actualBatch)
                              .toList(),
                        ),
                        TextSpan(text: ' · ${row.batch.dateBatch}'),
                      ],
                    ),
                  ),
                ),
              )
              .toList(),
          onChanged: onBatchChanged,
        ),
      ],
    );
  }
}

class ProductInfoChip extends StatelessWidget {
  const ProductInfoChip({
    super.key,
    required this.text,
  });

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: const Color(0xFFF3F6FB),
        borderRadius: BorderRadius.circular(10),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

InputDecoration _inputDecoration(String label) {
  return InputDecoration(
    labelText: label,
    filled: true,
    fillColor: const Color(0xFFF7F9FC),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(12),
      borderSide: BorderSide.none,
    ),
  );
}

List<InlineSpan> _batchCodeSpans(
  String code, {
  required List<String> variants,
}) {
  if (variants.toSet().length <= 1) {
    return <InlineSpan>[
      TextSpan(text: code, style: const TextStyle(color: AppTheme.textPrimary)),
    ];
  }
  final normalized = variants.toSet().toList()..sort();
  final maxLength = normalized.fold<int>(
      0, (max, item) => item.length > max ? item.length : max);
  final differsAt = List<bool>.filled(maxLength, false);
  for (var i = 0; i < maxLength; i += 1) {
    String? pivot;
    for (final value in normalized) {
      final char = i < value.length ? value[i] : '';
      pivot ??= char;
      if (char != pivot) {
        differsAt[i] = true;
        break;
      }
    }
  }
  final spans = <InlineSpan>[];
  for (var i = 0; i < code.length; i += 1) {
    final isDiff = i < differsAt.length && differsAt[i];
    spans.add(
      TextSpan(
        text: code[i],
        style: TextStyle(
          color: isDiff ? const Color(0xFFDC2626) : AppTheme.textPrimary,
        ),
      ),
    );
  }
  return spans;
}

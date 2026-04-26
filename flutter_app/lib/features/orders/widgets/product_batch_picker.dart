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
                  child:
                      Text('${row.batch.actualBatch} · ${row.batch.dateBatch}'),
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

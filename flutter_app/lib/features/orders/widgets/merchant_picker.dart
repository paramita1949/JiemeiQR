import 'package:flutter/material.dart';

class MerchantPicker extends StatelessWidget {
  const MerchantPicker({
    super.key,
    required this.controller,
    required this.merchants,
    required this.validator,
  });

  final TextEditingController controller;
  final List<String> merchants;
  final FormFieldValidator<String> validator;

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        TextFormField(
          key: const Key('merchantNameField'),
          controller: controller,
          validator: validator,
          decoration: _inputDecoration('商家'),
        ),
        if (merchants.isNotEmpty) ...[
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: merchants
                .map(
                  (name) => ActionChip(
                    label: Text(name),
                    onPressed: () {
                      controller.text = name;
                    },
                  ),
                )
                .toList(),
          ),
        ],
      ],
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

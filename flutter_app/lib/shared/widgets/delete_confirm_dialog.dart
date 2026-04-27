import 'package:flutter/material.dart';

enum DeleteRiskLevel { normal, high }

Future<bool> showDeleteConfirmDialog({
  required BuildContext context,
  required String title,
  required String message,
  DeleteRiskLevel riskLevel = DeleteRiskLevel.normal,
}) async {
  final isHighRisk = riskLevel == DeleteRiskLevel.high;
  final iconColor =
      isHighRisk ? const Color(0xFFDC2626) : const Color(0xFFF97316);
  final background =
      isHighRisk ? const Color(0xFFFEE2E2) : const Color(0xFFFFEDD5);
  final riskText = isHighRisk ? '高风险删除' : '普通删除';
  final riskHint = isHighRisk ? '请再次确认，删除后不可恢复。' : '删除后将无法撤销。';

  final confirmed = await showDialog<bool>(
    context: context,
    builder: (context) => AlertDialog(
      title: Text(title),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(message),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            decoration: BoxDecoration(
              color: background,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Row(
              children: [
                Icon(Icons.warning_amber_rounded, size: 16, color: iconColor),
                const SizedBox(width: 6),
                Expanded(
                  child: Text(
                    '$riskText · $riskHint',
                    style: TextStyle(
                      color: iconColor,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () => Navigator.of(context).pop(true),
          child: const Text('删除'),
        ),
      ],
    ),
  );
  return confirmed == true;
}

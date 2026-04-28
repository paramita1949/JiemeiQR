import 'package:flutter/widgets.dart';

Future<void> pushAndRefresh(
  BuildContext context, {
  required Route<void> route,
  required VoidCallback onRefresh,
}) async {
  await Navigator.of(context).push(route);
  if (!context.mounted) {
    return;
  }
  onRefresh();
}

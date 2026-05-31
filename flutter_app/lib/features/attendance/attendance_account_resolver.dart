import 'package:qrscan_flutter/features/transfer/cloud_backup_service.dart';

class AttendanceAccountResolver {
  const AttendanceAccountResolver({
    CloudBackupService? cloudBackupService,
  }) : _cloudBackupService = cloudBackupService;

  final CloudBackupService? _cloudBackupService;

  static const localAccountKey = 'local';

  Future<String> resolve() async {
    try {
      final service = _cloudBackupService ??
          CloudBackupService(api: SupabaseCloudBackupApi());
      final session = await service.loadSavedSession();
      return normalize(session?.email);
    } catch (_) {
      return localAccountKey;
    }
  }

  static String normalize(String? value) {
    final trimmed = value?.trim().toLowerCase() ?? '';
    return trimmed.isEmpty ? localAccountKey : trimmed;
  }
}

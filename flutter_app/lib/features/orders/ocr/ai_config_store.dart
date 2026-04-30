import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AiOcrConfig {
  const AiOcrConfig({
    required this.provider,
    required this.geminiApiKey,
    required this.geminiModel,
    required this.tencentSecretId,
    required this.tencentSecretKey,
    required this.tencentRegion,
  });

  static const defaultModel = 'gemini-3-flash-preview';
  static const defaultProvider = 'gemini';
  static const tencentProvider = 'tencent';
  static const defaultTencentRegion = 'ap-guangzhou';

  final String provider;
  final String geminiApiKey;
  final String geminiModel;
  final String tencentSecretId;
  final String tencentSecretKey;
  final String tencentRegion;

  bool get hasGeminiKey => geminiApiKey.trim().isNotEmpty;
  bool get usesTencentOcr => provider == tencentProvider;
  bool get hasTencentCredential =>
      tencentSecretId.trim().isNotEmpty && tencentSecretKey.trim().isNotEmpty;

  Map<String, Object?> toJson() => {
        'provider': provider,
        'geminiApiKey': geminiApiKey,
        'geminiModel': geminiModel,
        'tencentSecretId': tencentSecretId,
        'tencentSecretKey': tencentSecretKey,
        'tencentRegion': tencentRegion,
      };

  factory AiOcrConfig.fromJson(Map<String, Object?> json) {
    final provider = json['provider']?.toString() == tencentProvider
        ? tencentProvider
        : defaultProvider;
    return AiOcrConfig(
      provider: provider,
      geminiApiKey: json['geminiApiKey']?.toString() ?? '',
      geminiModel: json['geminiModel']?.toString().trim().isNotEmpty == true
          ? json['geminiModel'].toString().trim()
          : defaultModel,
      tencentSecretId: json['tencentSecretId']?.toString() ?? '',
      tencentSecretKey: json['tencentSecretKey']?.toString() ?? '',
      tencentRegion: json['tencentRegion']?.toString().trim().isNotEmpty == true
          ? json['tencentRegion'].toString().trim()
          : defaultTencentRegion,
    );
  }

  AiOcrConfig copyWith({
    String? provider,
    String? geminiApiKey,
    String? geminiModel,
    String? tencentSecretId,
    String? tencentSecretKey,
    String? tencentRegion,
  }) {
    return AiOcrConfig(
      provider: provider ?? this.provider,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      geminiModel: geminiModel ?? this.geminiModel,
      tencentSecretId: tencentSecretId ?? this.tencentSecretId,
      tencentSecretKey: tencentSecretKey ?? this.tencentSecretKey,
      tencentRegion: tencentRegion ?? this.tencentRegion,
    );
  }
}

typedef SettingsFileProvider = Future<File> Function();

class FileAiConfigStore {
  const FileAiConfigStore({
    SettingsFileProvider? settingsFileProvider,
  }) : _settingsFileProvider = settingsFileProvider ?? _defaultSettingsFile;

  final SettingsFileProvider _settingsFileProvider;

  Future<AiOcrConfig> load() async {
    final file = await _settingsFileProvider();
    if (!await file.exists()) {
      return const AiOcrConfig(
        provider: AiOcrConfig.defaultProvider,
        geminiApiKey: '',
        geminiModel: AiOcrConfig.defaultModel,
        tencentSecretId: '',
        tencentSecretKey: '',
        tencentRegion: AiOcrConfig.defaultTencentRegion,
      );
    }
    try {
      final content = jsonDecode(await file.readAsString());
      if (content is Map<String, Object?>) {
        return AiOcrConfig.fromJson(content);
      }
    } catch (_) {
      // Invalid config should not block entering the app.
    }
    return const AiOcrConfig(
      provider: AiOcrConfig.defaultProvider,
      geminiApiKey: '',
      geminiModel: AiOcrConfig.defaultModel,
      tencentSecretId: '',
      tencentSecretKey: '',
      tencentRegion: AiOcrConfig.defaultTencentRegion,
    );
  }

  Future<void> save(AiOcrConfig config) async {
    final file = await _settingsFileProvider();
    await file.parent.create(recursive: true);
    await file.writeAsString(jsonEncode(config.toJson()));
  }
}

Future<File> _defaultSettingsFile() async {
  final directory = await getApplicationDocumentsDirectory();
  return File(p.join(directory.path, 'ai_ocr_config.json'));
}

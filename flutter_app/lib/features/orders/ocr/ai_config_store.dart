import 'dart:convert';
import 'dart:io';

import 'package:path/path.dart' as p;
import 'package:path_provider/path_provider.dart';

class AiOcrConfig {
  const AiOcrConfig({
    required this.geminiApiKey,
    required this.geminiModel,
  });

  static const defaultModel = 'gemini-3-flash-preview';

  final String geminiApiKey;
  final String geminiModel;

  bool get hasGeminiKey => geminiApiKey.trim().isNotEmpty;

  Map<String, Object?> toJson() => {
        'geminiApiKey': geminiApiKey,
        'geminiModel': geminiModel,
      };

  factory AiOcrConfig.fromJson(Map<String, Object?> json) {
    return AiOcrConfig(
      geminiApiKey: json['geminiApiKey']?.toString() ?? '',
      geminiModel: json['geminiModel']?.toString().trim().isNotEmpty == true
          ? json['geminiModel'].toString().trim()
          : defaultModel,
    );
  }

  AiOcrConfig copyWith({
    String? geminiApiKey,
    String? geminiModel,
  }) {
    return AiOcrConfig(
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      geminiModel: geminiModel ?? this.geminiModel,
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
        geminiApiKey: '',
        geminiModel: AiOcrConfig.defaultModel,
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
      geminiApiKey: '',
      geminiModel: AiOcrConfig.defaultModel,
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

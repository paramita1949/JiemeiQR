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
    required this.aliyunAccessKeyId,
    required this.aliyunAccessKeySecret,
    required this.aliyunEndpoint,
    required this.baiduApiKey,
    required this.baiduSecretKey,
    this.modelscopeToken = '',
    this.modelscopeModel = defaultModelScopeModel,
    this.openRouterApiKey = '',
    this.openRouterModel = defaultOpenRouterModel,
    this.geminiModelPresets = defaultGeminiModelPresets,
    this.modelScopeModelPresets = defaultModelScopeModelPresets,
    this.openRouterModelPresets = defaultOpenRouterModelPresets,
    this.ocrPromptPreset = defaultOcrPromptPreset,
  });

  static const defaultModel = 'gemini-3-flash-preview';
  static const defaultProvider = 'gemini';
  static const tencentProvider = 'tencent';
  static const aliyunProvider = 'aliyun';
  static const baiduProvider = 'baidu';
  static const modelscopeProvider = 'modelscope';
  static const openRouterProvider = 'openrouter';
  static const defaultTencentRegion = 'ap-guangzhou';
  static const defaultAliyunEndpoint = 'ocr-api.cn-hangzhou.aliyuncs.com';
  static const defaultModelScopeModel = 'Qwen/Qwen3.5-397B-A17B';
  static const defaultOpenRouterModel = 'tencent/hy3-preview:free';
  static const ocrPromptPresetGeneral = 'general';
  static const ocrPromptPresetWaybillTemplateV2 = 'waybill_template_v2';
  static const defaultOcrPromptPreset = ocrPromptPresetWaybillTemplateV2;
  static const defaultGeminiModelPresets = [
    defaultModel,
    'gemini-2.5-flash',
    'gemini-2.5-pro',
  ];
  static const defaultModelScopeModelPresets = [
    defaultModelScopeModel,
    'Qwen/Qwen2.5-VL-72B-Instruct',
  ];
  static const defaultOpenRouterModelPresets = [
    defaultOpenRouterModel,
    'minimax/minimax-m2.5:free',
    'openai/gpt-oss-120b:free',
  ];

  final String provider;
  final String geminiApiKey;
  final String geminiModel;
  final String tencentSecretId;
  final String tencentSecretKey;
  final String tencentRegion;
  final String aliyunAccessKeyId;
  final String aliyunAccessKeySecret;
  final String aliyunEndpoint;
  final String baiduApiKey;
  final String baiduSecretKey;
  final String modelscopeToken;
  final String modelscopeModel;
  final String openRouterApiKey;
  final String openRouterModel;
  final List<String> geminiModelPresets;
  final List<String> modelScopeModelPresets;
  final List<String> openRouterModelPresets;
  final String ocrPromptPreset;

  bool get hasGeminiKey => geminiApiKey.trim().isNotEmpty;
  bool get usesTencentOcr => provider == tencentProvider;
  bool get usesAliyunOcr => provider == aliyunProvider;
  bool get usesBaiduOcr => provider == baiduProvider;
  bool get usesModelScopeOcr => provider == modelscopeProvider;
  bool get usesOpenRouterOcr => provider == openRouterProvider;
  bool get hasTencentCredential =>
      tencentSecretId.trim().isNotEmpty && tencentSecretKey.trim().isNotEmpty;
  bool get hasAliyunCredential =>
      aliyunAccessKeyId.trim().isNotEmpty &&
      aliyunAccessKeySecret.trim().isNotEmpty;
  bool get hasBaiduCredential =>
      baiduApiKey.trim().isNotEmpty && baiduSecretKey.trim().isNotEmpty;
  bool get hasModelScopeCredential => modelscopeToken.trim().isNotEmpty;
  bool get hasOpenRouterCredential => openRouterApiKey.trim().isNotEmpty;

  Map<String, Object?> toJson() => {
        'provider': provider,
        'geminiApiKey': geminiApiKey,
        'geminiModel': geminiModel,
        'tencentSecretId': tencentSecretId,
        'tencentSecretKey': tencentSecretKey,
        'tencentRegion': tencentRegion,
        'aliyunAccessKeyId': aliyunAccessKeyId,
        'aliyunAccessKeySecret': aliyunAccessKeySecret,
        'aliyunEndpoint': aliyunEndpoint,
        'baiduApiKey': baiduApiKey,
        'baiduSecretKey': baiduSecretKey,
        'modelscopeToken': modelscopeToken,
        'modelscopeModel': modelscopeModel,
        'openRouterApiKey': openRouterApiKey,
        'openRouterModel': openRouterModel,
        'geminiModelPresets': geminiModelPresets,
        'modelScopeModelPresets': modelScopeModelPresets,
        'openRouterModelPresets': openRouterModelPresets,
        'ocrPromptPreset': ocrPromptPreset,
      };

  factory AiOcrConfig.fromJson(Map<String, Object?> json) {
    final provider = switch (json['provider']?.toString()) {
      tencentProvider => tencentProvider,
      aliyunProvider => aliyunProvider,
      baiduProvider => baiduProvider,
      modelscopeProvider => modelscopeProvider,
      _ => defaultProvider,
    };
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
      aliyunAccessKeyId: json['aliyunAccessKeyId']?.toString() ?? '',
      aliyunAccessKeySecret: json['aliyunAccessKeySecret']?.toString() ?? '',
      aliyunEndpoint:
          json['aliyunEndpoint']?.toString().trim().isNotEmpty == true
              ? json['aliyunEndpoint'].toString().trim()
              : defaultAliyunEndpoint,
      baiduApiKey: json['baiduApiKey']?.toString() ?? '',
      baiduSecretKey: json['baiduSecretKey']?.toString() ?? '',
      modelscopeToken: json['modelscopeToken']?.toString() ?? '',
      modelscopeModel:
          json['modelscopeModel']?.toString().trim().isNotEmpty == true
              ? json['modelscopeModel'].toString().trim()
              : defaultModelScopeModel,
      openRouterApiKey: json['openRouterApiKey']?.toString() ?? '',
      openRouterModel:
          json['openRouterModel']?.toString().trim().isNotEmpty == true
              ? json['openRouterModel'].toString().trim()
              : defaultOpenRouterModel,
      geminiModelPresets: _decodePresetList(
        json['geminiModelPresets'],
        fallback: defaultGeminiModelPresets,
      ),
      modelScopeModelPresets: _decodePresetList(
        json['modelScopeModelPresets'],
        fallback: defaultModelScopeModelPresets,
      ),
      openRouterModelPresets: _decodePresetList(
        json['openRouterModelPresets'],
        fallback: defaultOpenRouterModelPresets,
      ),
      ocrPromptPreset:
          json['ocrPromptPreset']?.toString() == ocrPromptPresetGeneral
              ? ocrPromptPresetGeneral
              : ocrPromptPresetWaybillTemplateV2,
    );
  }

  AiOcrConfig copyWith({
    String? provider,
    String? geminiApiKey,
    String? geminiModel,
    String? tencentSecretId,
    String? tencentSecretKey,
    String? tencentRegion,
    String? aliyunAccessKeyId,
    String? aliyunAccessKeySecret,
    String? aliyunEndpoint,
    String? baiduApiKey,
    String? baiduSecretKey,
    String? modelscopeToken,
    String? modelscopeModel,
    String? openRouterApiKey,
    String? openRouterModel,
    List<String>? geminiModelPresets,
    List<String>? modelScopeModelPresets,
    List<String>? openRouterModelPresets,
    String? ocrPromptPreset,
  }) {
    return AiOcrConfig(
      provider: provider ?? this.provider,
      geminiApiKey: geminiApiKey ?? this.geminiApiKey,
      geminiModel: geminiModel ?? this.geminiModel,
      tencentSecretId: tencentSecretId ?? this.tencentSecretId,
      tencentSecretKey: tencentSecretKey ?? this.tencentSecretKey,
      tencentRegion: tencentRegion ?? this.tencentRegion,
      aliyunAccessKeyId: aliyunAccessKeyId ?? this.aliyunAccessKeyId,
      aliyunAccessKeySecret:
          aliyunAccessKeySecret ?? this.aliyunAccessKeySecret,
      aliyunEndpoint: aliyunEndpoint ?? this.aliyunEndpoint,
      baiduApiKey: baiduApiKey ?? this.baiduApiKey,
      baiduSecretKey: baiduSecretKey ?? this.baiduSecretKey,
      modelscopeToken: modelscopeToken ?? this.modelscopeToken,
      modelscopeModel: modelscopeModel ?? this.modelscopeModel,
      openRouterApiKey: openRouterApiKey ?? this.openRouterApiKey,
      openRouterModel: openRouterModel ?? this.openRouterModel,
      geminiModelPresets: geminiModelPresets ?? this.geminiModelPresets,
      modelScopeModelPresets:
          modelScopeModelPresets ?? this.modelScopeModelPresets,
      openRouterModelPresets:
          openRouterModelPresets ?? this.openRouterModelPresets,
      ocrPromptPreset: ocrPromptPreset ?? this.ocrPromptPreset,
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
        aliyunAccessKeyId: '',
        aliyunAccessKeySecret: '',
        aliyunEndpoint: AiOcrConfig.defaultAliyunEndpoint,
        baiduApiKey: '',
        baiduSecretKey: '',
        modelscopeToken: '',
        modelscopeModel: AiOcrConfig.defaultModelScopeModel,
        openRouterApiKey: '',
        openRouterModel: AiOcrConfig.defaultOpenRouterModel,
        geminiModelPresets: AiOcrConfig.defaultGeminiModelPresets,
        modelScopeModelPresets: AiOcrConfig.defaultModelScopeModelPresets,
        openRouterModelPresets: AiOcrConfig.defaultOpenRouterModelPresets,
        ocrPromptPreset: AiOcrConfig.defaultOcrPromptPreset,
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
      aliyunAccessKeyId: '',
      aliyunAccessKeySecret: '',
      aliyunEndpoint: AiOcrConfig.defaultAliyunEndpoint,
      baiduApiKey: '',
      baiduSecretKey: '',
      modelscopeToken: '',
      modelscopeModel: AiOcrConfig.defaultModelScopeModel,
      openRouterApiKey: '',
      openRouterModel: AiOcrConfig.defaultOpenRouterModel,
      geminiModelPresets: AiOcrConfig.defaultGeminiModelPresets,
      modelScopeModelPresets: AiOcrConfig.defaultModelScopeModelPresets,
      openRouterModelPresets: AiOcrConfig.defaultOpenRouterModelPresets,
      ocrPromptPreset: AiOcrConfig.defaultOcrPromptPreset,
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

List<String> _decodePresetList(Object? raw, {required List<String> fallback}) {
  final source = raw is List ? raw : fallback;
  final values = source
      .map((item) => item.toString().trim())
      .where((item) => item.isNotEmpty)
      .toSet()
      .toList();
  return values.isEmpty ? fallback : values;
}

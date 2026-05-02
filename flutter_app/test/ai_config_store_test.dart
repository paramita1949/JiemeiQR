import 'dart:io';

import 'package:flutter_test/flutter_test.dart';
import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';

void main() {
  test('saves and loads Gemini API configuration', () async {
    final dir = await Directory.systemTemp.createTemp('jiemei-ai-config-');
    final store = FileAiConfigStore(
      settingsFileProvider: () async => File('${dir.path}/ai_config.json'),
    );

    await store.save(
      const AiOcrConfig(
        provider: AiOcrConfig.defaultProvider,
        geminiApiKey: 'abc123',
        geminiModel: 'gemini-2.5-flash',
        tencentSecretId: 'sid',
        tencentSecretKey: 'skey',
        tencentRegion: 'ap-shanghai',
        aliyunAccessKeyId: 'ak',
        aliyunAccessKeySecret: 'as',
        aliyunEndpoint: 'ocr-api.cn-hangzhou.aliyuncs.com',
        baiduApiKey: 'bak',
        baiduSecretKey: 'bsk',
      ),
    );

    final loaded = await store.load();
    expect(loaded.provider, AiOcrConfig.defaultProvider);
    expect(loaded.geminiApiKey, 'abc123');
    expect(loaded.geminiModel, 'gemini-2.5-flash');
    expect(loaded.tencentSecretId, 'sid');
    expect(loaded.tencentSecretKey, 'skey');
    expect(loaded.tencentRegion, 'ap-shanghai');
    expect(loaded.aliyunAccessKeyId, 'ak');
    expect(loaded.aliyunAccessKeySecret, 'as');
    expect(loaded.aliyunEndpoint, 'ocr-api.cn-hangzhou.aliyuncs.com');
    expect(loaded.baiduApiKey, 'bak');
    expect(loaded.baiduSecretKey, 'bsk');
    expect(loaded.ocrPromptPreset, AiOcrConfig.defaultOcrPromptPreset);
  });

  test('uses Gemini 3 Flash preview as default model', () async {
    final dir =
        await Directory.systemTemp.createTemp('jiemei-ai-config-empty-');
    final store = FileAiConfigStore(
      settingsFileProvider: () async => File('${dir.path}/ai_config.json'),
    );

    final loaded = await store.load();
    expect(loaded.provider, AiOcrConfig.defaultProvider);
    expect(loaded.geminiApiKey, '');
    expect(loaded.geminiModel, 'gemini-3-flash-preview');
    expect(loaded.tencentRegion, AiOcrConfig.defaultTencentRegion);
    expect(loaded.aliyunEndpoint, AiOcrConfig.defaultAliyunEndpoint);
    expect(loaded.baiduApiKey, '');
    expect(loaded.ocrPromptPreset, AiOcrConfig.defaultOcrPromptPreset);
  });

  test('saves and loads selected Baidu provider', () async {
    final dir =
        await Directory.systemTemp.createTemp('jiemei-ai-config-baidu-');
    final store = FileAiConfigStore(
      settingsFileProvider: () async => File('${dir.path}/ai_config.json'),
    );

    await store.save(
      const AiOcrConfig(
        provider: AiOcrConfig.baiduProvider,
        geminiApiKey: '',
        geminiModel: AiOcrConfig.defaultModel,
        tencentSecretId: '',
        tencentSecretKey: '',
        tencentRegion: AiOcrConfig.defaultTencentRegion,
        aliyunAccessKeyId: '',
        aliyunAccessKeySecret: '',
        aliyunEndpoint: AiOcrConfig.defaultAliyunEndpoint,
        baiduApiKey: 'baidu-api',
        baiduSecretKey: 'baidu-secret',
        ocrPromptPreset: AiOcrConfig.ocrPromptPresetGeneral,
      ),
    );

    final loaded = await store.load();
    expect(loaded.provider, AiOcrConfig.baiduProvider);
    expect(loaded.usesBaiduOcr, isTrue);
    expect(loaded.baiduApiKey, 'baidu-api');
    expect(loaded.baiduSecretKey, 'baidu-secret');
    expect(loaded.ocrPromptPreset, AiOcrConfig.ocrPromptPresetGeneral);
  });
}

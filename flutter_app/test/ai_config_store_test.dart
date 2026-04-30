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
        geminiApiKey: 'abc123',
        geminiModel: 'gemini-2.5-flash',
      ),
    );

    final loaded = await store.load();
    expect(loaded.geminiApiKey, 'abc123');
    expect(loaded.geminiModel, 'gemini-2.5-flash');
  });

  test('uses Gemini 3 Flash preview as default model', () async {
    final dir =
        await Directory.systemTemp.createTemp('jiemei-ai-config-empty-');
    final store = FileAiConfigStore(
      settingsFileProvider: () async => File('${dir.path}/ai_config.json'),
    );

    final loaded = await store.load();
    expect(loaded.geminiApiKey, '');
    expect(loaded.geminiModel, 'gemini-3-flash-preview');
  });
}

# 智谱 GLM 视觉 OCR 接入 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将 `glm-4.6v-flash`、`glm-4v-flash` 和 `glm-4.1v-thinking-flash` 作为独立“智谱”提供方接入订单拍照识别、交货计划截图识别和现有配置/临时切换界面。

**Architecture:** 在现有 `AiOcrConfig` 中加入智谱专用凭据与模型字段；新增一个只负责智谱协议、MIME、响应解析及双模型回退的共享客户端。订单侧增加薄适配器并接入现有路由，交货计划侧在现有 OCR 服务文件中增加薄适配器；界面继续使用 APP 已有“横向提供方卡片 + 当前提供方字段”和拍照面板临时切换模式。

**Tech Stack:** Flutter、Dart、`dart:io`、`dart:convert`、Flutter Test。

**思考策略补充：** 不增加单独开关。客户端在实际请求模型为 `glm-4.1v-thinking-flash` 时发送 `thinking: enabled`，普通模型发送 `disabled`；服务层沿用魔搭的多模态图片 + 结构化提示词 + JSON 解析思路，不调用专用 OCR 接口。

---

## 文件结构

- Create: `lib/features/orders/ocr/zhipu_vision_client.dart`
  - 智谱 HTTP 请求、Bearer 规范化、图片 MIME、响应解析、代码围栏清理和双模型回退。
- Create: `lib/features/orders/ocr/zhipu_waybill_ocr_service.dart`
  - 读取配置、复用图片预处理和运单提示词、生成 `WaybillOcrDraft`、商家历史匹配及诊断日志。
- Modify: `lib/features/orders/ocr/ai_config_store.dart`
  - 新增智谱配置字段、默认模型、预设、序列化和兼容读取。
- Modify: `lib/features/orders/ocr/modelscope_waybill_ocr_service.dart`
  - 公开现有运单提示词选择函数，避免复制提示词。
- Modify: `lib/features/orders/ocr/configured_waybill_ocr_service.dart`
  - 为选中的智谱提供方增加显式路由。
- Modify: `lib/features/delivery_plan/delivery_plan_ocr_service.dart`
  - 增加智谱交货计划适配器和配置路由，复用本文件私有提示词及草稿解析。
- Modify: `lib/features/orders/ocr/ai_config_screen.dart`
  - 增加智谱卡片、Key、模型预设管理和自动保存。
- Modify: `lib/features/orders/order_edit_screen.dart`
  - 在订单拍照面板加入智谱临时选择、模型选择和进度/错误标签。
- Modify: `lib/features/delivery_plan/delivery_plan_screen.dart`
  - 在交货计划拍照面板加入智谱临时选择和模型选择。
- Modify/Test: `test/ai_config_store_test.dart`
- Create/Test: `test/zhipu_vision_client_test.dart`
- Create/Test: `test/zhipu_waybill_ocr_service_test.dart`
- Modify/Test: `test/configured_waybill_ocr_service_test.dart`
- Modify/Test: `test/delivery_plan_ocr_service_test.dart`
- Create/Test: `test/ai_config_screen_test.dart`
- Modify/Test: `test/order_edit_screen_test.dart`
- Modify/Test: `test/delivery_plan_screen_test.dart`

### Task 1: 智谱配置模型与持久化

**Files:**
- Modify: `test/ai_config_store_test.dart`
- Modify: `lib/features/orders/ocr/ai_config_store.dart`

- [ ] **Step 1: 写默认值与保存/读取失败测试**

在 `test/ai_config_store_test.dart` 增加：

```dart
test('uses built-in Zhipu vision models by default', () async {
  final dir = await Directory.systemTemp.createTemp('jiemei-zhipu-default-');
  addTearDown(() async => dir.delete(recursive: true));
  final store = FileAiConfigStore(
    settingsFileProvider: () async => File('${dir.path}/ai_config.json'),
  );

  final loaded = await store.load();

  expect(loaded.zhipuApiKey, '');
  expect(loaded.zhipuModel, 'glm-4.6v-flash');
  expect(loaded.zhipuModelPresets, [
    'glm-4.6v-flash',
    'glm-4v-flash',
    'glm-4.1v-thinking-flash',
  ]);
  expect(loaded.usesZhipuOcr, isFalse);
  expect(loaded.hasZhipuCredential, isFalse);
});

test('saves and loads selected Zhipu provider', () async {
  final dir = await Directory.systemTemp.createTemp('jiemei-zhipu-config-');
  addTearDown(() async => dir.delete(recursive: true));
  final store = FileAiConfigStore(
    settingsFileProvider: () async => File('${dir.path}/ai_config.json'),
  );

  await store.save(
    const AiOcrConfig(
      provider: AiOcrConfig.zhipuProvider,
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
      zhipuApiKey: 'zhipu-key',
      zhipuModel: 'glm-4v-flash',
    ),
  );

  final loaded = await store.load();

  expect(loaded.provider, AiOcrConfig.zhipuProvider);
  expect(loaded.usesZhipuOcr, isTrue);
  expect(loaded.hasZhipuCredential, isTrue);
  expect(loaded.zhipuApiKey, 'zhipu-key');
  expect(loaded.zhipuModel, 'glm-4v-flash');
  expect(loaded.copyWith(zhipuModel: 'glm-4.6v-flash').zhipuModel,
      'glm-4.6v-flash');
});
```

- [ ] **Step 2: 运行测试确认 RED**

Run:

```powershell
C:\tools\flutter\bin\flutter.bat test test\ai_config_store_test.dart
```

Expected: 编译失败，提示 `zhipuProvider`、`zhipuApiKey`、`zhipuModel` 或对应 getter 尚不存在。

- [ ] **Step 3: 最小扩展 `AiOcrConfig`**

在 `AiOcrConfig` 增加：

```dart
static const zhipuProvider = 'zhipu';
static const defaultZhipuModel = 'glm-4.6v-flash';
static const zhipuThinkingModel = 'glm-4.1v-thinking-flash';
static const defaultZhipuModelPresets = [
  defaultZhipuModel,
  'glm-4v-flash',
  zhipuThinkingModel,
];

final String zhipuApiKey;
final String zhipuModel;
final List<String> zhipuModelPresets;

bool get usesZhipuOcr => provider == zhipuProvider;
bool get hasZhipuCredential => zhipuApiKey.trim().isNotEmpty;
```

构造函数使用兼容默认值：

```dart
this.zhipuApiKey = '',
this.zhipuModel = defaultZhipuModel,
this.zhipuModelPresets = defaultZhipuModelPresets,
```

同步处理：

```dart
'zhipuApiKey': zhipuApiKey,
'zhipuModel': zhipuModel,
'zhipuModelPresets': zhipuModelPresets,
```

`fromJson` provider switch 增加 `zhipuProvider`，并用 `_decodePresetList` 读取预设：

```dart
zhipuApiKey: json['zhipuApiKey']?.toString() ?? '',
zhipuModel: json['zhipuModel']?.toString().trim().isNotEmpty == true
    ? json['zhipuModel'].toString().trim()
    : defaultZhipuModel,
zhipuModelPresets: _decodePresetList(
  json['zhipuModelPresets'],
  fallback: defaultZhipuModelPresets,
  ensureIncludes: defaultZhipuModelPresets,
),
```

在 `copyWith` 和两个缺省配置返回值中同步三个字段。

- [ ] **Step 4: 运行配置测试确认 GREEN**

Run:

```powershell
C:\tools\flutter\bin\flutter.bat test test\ai_config_store_test.dart
```

Expected: 全部通过。

- [ ] **Step 5: 提交配置改动**

```powershell
git add flutter_app/lib/features/orders/ocr/ai_config_store.dart flutter_app/test/ai_config_store_test.dart
git commit -m "feat: add Zhipu OCR configuration"
```

### Task 2: 智谱视觉共享客户端

**Files:**
- Create: `test/zhipu_vision_client_test.dart`
- Create: `lib/features/orders/ocr/zhipu_vision_client.dart`

- [ ] **Step 1: 写成功请求、MIME 和围栏清理失败测试**

测试使用临时 PNG 文件和注入的 `ZhipuHttpPost`，断言：

```dart
expect(capturedUri.toString(),
    'https://open.bigmodel.cn/api/paas/v4/chat/completions');
expect(capturedApiKey, 'test-key');
expect(capturedBody?['model'], 'glm-4.6v-flash');
expect(capturedBody?['thinking'], {'type': 'disabled'});
expect(capturedBody?['stream'], isFalse);
expect(capturedBody.toString(), contains('data:image/png;base64,'));
expect(capturedBody.toString(), contains('只做OCR'));
expect(result.model, 'glm-4.6v-flash');
expect(result.content, '{"rows":[]}');
```

模拟响应：

```dart
const ZhipuHttpResponse(
  statusCode: 200,
  body:
      '{"choices":[{"message":{"content":"```json\\n{\\"rows\\":[]}\\n```"}}]}',
)
```

- [ ] **Step 2: 写模型回退和不可回退错误失败测试**

覆盖以下单一行为：

1. 首选模型成功时只请求一次。
2. HTTP 429 时从 `glm-4.6v-flash` 切换至 `glm-4v-flash`。
3. HTTP 200 但 `error.code == 1305` 时回退。
4. 空 `choices/message/content` 时回退。
5. HTTP 401/403 直接抛出“智谱 API Key 无效或无调用权限”，只请求一次。
6. 两次模型尝试都失败时，异常包含两个模型和简短原因，不包含 `test-key` 或 `data:image`。
7. 输入 `Bearer test-key` 时注入回调收到规范化后的 `test-key`。
8. 选择 `glm-4.1v-thinking-flash` 时自动发送 `thinking: enabled`。
9. 思考模型回退到普通模型时，下一次请求自动发送 `thinking: disabled`。

- [ ] **Step 3: 运行客户端测试确认 RED**

Run:

```powershell
C:\tools\flutter\bin\flutter.bat test test\zhipu_vision_client_test.dart
```

Expected: 编译失败，提示 `zhipu_vision_client.dart` 或其类型不存在。

- [ ] **Step 4: 实现客户端公共 API**

创建：

```dart
typedef ZhipuHttpPost = Future<ZhipuHttpResponse> Function(
  Uri uri,
  Map<String, Object?> body,
  String apiKey,
);

class ZhipuHttpResponse {
  const ZhipuHttpResponse({required this.statusCode, required this.body});
  final int statusCode;
  final String body;
}

class ZhipuVisionResult {
  const ZhipuVisionResult({required this.model, required this.content});
  final String model;
  final String content;
}

class ZhipuVisionException implements Exception {
  const ZhipuVisionException(this.message);
  final String message;
  @override
  String toString() => message;
}
```

`ZhipuVisionClient` 构造函数接收 `apiKey`、`model` 和可注入 `httpPost`。`recognize`：

```dart
Future<ZhipuVisionResult> recognize(
  File image, {
  required String prompt,
}) async
```

请求体固定为：

```dart
{
  'model': currentModel,
  'messages': [
    {
      'role': 'user',
      'content': [
        {
          'type': 'image_url',
          'image_url': {'url': dataUrl},
        },
        {
          'type': 'text',
          'text': prompt,
        },
      ],
    },
  ],
  'thinking': {
    'type': currentModel == AiOcrConfig.zhipuThinkingModel
        ? 'enabled'
        : 'disabled',
  },
  'stream': false,
}
```

模型尝试顺序由当前模型加三个内置模型去重后截取两项。每次请求按实际模型自动决定思考状态。HTTP 429、状态码 5xx、错误码 1305、过载/暂不可用文字、空响应结构可回退；401/403 和其他 4xx 直接抛出。默认 HTTP 实现用 `HttpClient` 发送 JSON 与 `Authorization: Bearer $apiKey`。

图片 MIME 通过文件签名识别 PNG、JPEG、WebP，未知格式回退 `image/jpeg`。内容只清理包裹整个返回值的 ````json`/``` 围栏。

- [ ] **Step 5: 运行客户端测试确认 GREEN**

Run:

```powershell
C:\tools\flutter\bin\flutter.bat test test\zhipu_vision_client_test.dart
```

Expected: 全部通过。

- [ ] **Step 6: 提交共享客户端**

```powershell
git add flutter_app/lib/features/orders/ocr/zhipu_vision_client.dart flutter_app/test/zhipu_vision_client_test.dart
git commit -m "feat: add Zhipu vision client"
```

### Task 3: 订单运单 OCR 适配与路由

**Files:**
- Create: `test/zhipu_waybill_ocr_service_test.dart`
- Modify: `test/configured_waybill_ocr_service_test.dart`
- Create: `lib/features/orders/ocr/zhipu_waybill_ocr_service.dart`
- Modify: `lib/features/orders/ocr/modelscope_waybill_ocr_service.dart`
- Modify: `lib/features/orders/ocr/configured_waybill_ocr_service.dart`

- [ ] **Step 1: 写运单服务失败测试**

测试配置读取 `zhipuApiKey`、`zhipuModel` 和当前提示词，并让注入 HTTP 返回：

```dart
jsonEncode({
  'choices': [
    {
      'message': {
        'content': jsonEncode({
          'waybillNo': '1234567',
          'rawMerchantName': '义乌市杜超日化有限公司',
          'merchantName': '杜超日化',
          'totalBoxes': 12,
          'rows': [
            {
              'productCode': '72067',
              'productName': '六神花露水',
              'actualBatch': 'FCMFREZ',
              'dateBatch': '2029.09.12',
              'boxes': 12,
            },
          ],
          'warnings': [],
        }),
      },
    },
  ],
})
```

断言：

```dart
expect(capturedKey, 'zhipu-key');
expect(capturedBody?['model'], 'glm-4.6v-flash');
expect(capturedBody.toString(), contains('waybillNo'));
expect(draft.waybillNo, '1234567');
expect(draft.merchantName, '杜超日化');
expect(draft.rows.single.boxes, 12);
```

另写测试验证商家历史匹配、缺少 Key、无效 JSON 和业务空草稿的中文异常。

- [ ] **Step 2: 写配置路由失败测试**

在 `configured_waybill_ocr_service_test.dart` 保存 `provider: zhipu`，注入四个 factory；智谱 factory 返回草稿，其余 factory 抛错。断言只调用智谱 factory 且传入配置模型为 `glm-4v-flash`。

- [ ] **Step 3: 运行订单智谱测试确认 RED**

Run:

```powershell
C:\tools\flutter\bin\flutter.bat test test\zhipu_waybill_ocr_service_test.dart test\configured_waybill_ocr_service_test.dart
```

Expected: 编译失败，提示智谱服务或 `zhipuServiceFactory` 不存在。

- [ ] **Step 4: 公开运单提示词选择函数**

在 `modelscope_waybill_ocr_service.dart` 将调用改为：

```dart
final primaryPrompt = waybillOcrPromptForPreset(promptPreset);
```

并增加：

```dart
String waybillOcrPromptForPreset(String preset) {
  if (preset == AiOcrConfig.ocrPromptPresetGeneral) {
    return _ocrPromptGeneral;
  }
  return _ocrPromptWaybillTemplateV2;
}
```

- [ ] **Step 5: 实现 `ZhipuWaybillOcrService`**

服务读取显式参数或配置，缺少 Key 抛出 `ZhipuWaybillOcrException('缺少智谱 API Key')`；使用现有 `AiOcrImagePreparer`，在 `finally` 释放临时图片。调用：

```dart
final result = await ZhipuVisionClient(
  apiKey: effectiveApiKey,
  model: effectiveModel,
  httpPost: _httpPost,
).recognize(
  prepared.file,
  prompt: waybillOcrPromptForPreset(config.ocrPromptPreset),
);
```

将 `result.content` 解码为 `Map<String, Object?>`，通过：

```dart
final draft = applyMerchantHistoryMatch(
  WaybillOcrDraft.fromJson(payload),
  merchantHistoryNames,
);
logOcrMerchantDiagnosis(provider: 'zhipu', draft: draft);
```

拒绝没有运单头且没有有效明细的空草稿；把客户端异常与 JSON 格式异常转换为带中文消息的 `ZhipuWaybillOcrException`。

- [ ] **Step 6: 增加订单配置路由**

`ConfiguredWaybillOcrService` 新增 `zhipuServiceFactory`，默认返回 `ZhipuWaybillOcrService(configStore: configStore)`。在 Paddle/ModelScope 之前加入智谱显式分支，不进入 Gemini→ModelScope 回退。

- [ ] **Step 7: 运行订单智谱测试确认 GREEN**

Run:

```powershell
C:\tools\flutter\bin\flutter.bat test test\zhipu_waybill_ocr_service_test.dart test\configured_waybill_ocr_service_test.dart
```

Expected: 全部通过。

- [ ] **Step 8: 提交订单接入**

```powershell
git add flutter_app/lib/features/orders/ocr/modelscope_waybill_ocr_service.dart flutter_app/lib/features/orders/ocr/zhipu_waybill_ocr_service.dart flutter_app/lib/features/orders/ocr/configured_waybill_ocr_service.dart flutter_app/test/zhipu_waybill_ocr_service_test.dart flutter_app/test/configured_waybill_ocr_service_test.dart
git commit -m "feat: route waybill OCR through Zhipu"
```

### Task 4: 交货计划 OCR 适配与路由

**Files:**
- Modify: `test/delivery_plan_ocr_service_test.dart`
- Modify: `lib/features/delivery_plan/delivery_plan_ocr_service.dart`

- [ ] **Step 1: 写智谱交货计划请求与草稿解析失败测试**

保存智谱配置，创建 PNG 文件，注入 `ZhipuHttpPost` 返回带 JSON 围栏的 `choices[0].message.content`。断言：

```dart
expect(capturedKey, 'zhipu-key');
expect(capturedBody?['model'], 'glm-4v-flash');
expect(capturedBody.toString(), contains('data:image/png;base64,'));
expect(capturedBody.toString(), contains('交货计划'));
expect(capturedBody.toString(), contains('不要把库位'));
expect(draft.rows.single.productCode, '72068');
expect(draft.rows.single.location, '');
```

- [ ] **Step 2: 写智谱配置路由失败测试**

保存 `provider: zhipu`，向 `ConfiguredDeliveryPlanOcrService` 注入 `zhipuServiceFactory` 返回 fake，其他 factory 返回会抛错的 fake。断言只调用智谱服务。

- [ ] **Step 3: 运行交货计划测试确认 RED**

Run:

```powershell
C:\tools\flutter\bin\flutter.bat test test\delivery_plan_ocr_service_test.dart
```

Expected: 编译失败，提示 `ZhipuDeliveryPlanOcrService` 或 `zhipuServiceFactory` 不存在。

- [ ] **Step 4: 实现智谱交货计划适配器**

在 `delivery_plan_ocr_service.dart` 导入共享客户端并增加 `ZhipuDeliveryPlanOcrService`。读取 Key/模型，缺少 Key 抛出 `DeliveryPlanOcrException('缺少智谱 API Key')`，调用：

```dart
final result = await ZhipuVisionClient(
  apiKey: effectiveApiKey,
  model: effectiveModel,
  httpPost: _httpPost,
).recognize(image, prompt: _deliveryPlanPrompt);
return _parseDraftPayload(result.content);
```

把 `ZhipuVisionException` 和 `FormatException` 转换成 `DeliveryPlanOcrException`，不改变本地库位匹配。

- [ ] **Step 5: 增加交货计划配置路由**

`ConfiguredDeliveryPlanOcrService` 新增 `zhipuServiceFactory` 和 `_defaultZhipuServiceFactory`，在 Paddle/ModelScope 前显式处理 `config.usesZhipuOcr`。

- [ ] **Step 6: 运行交货计划测试确认 GREEN**

Run:

```powershell
C:\tools\flutter\bin\flutter.bat test test\delivery_plan_ocr_service_test.dart
```

Expected: 全部通过。

- [ ] **Step 7: 提交交货计划服务**

```powershell
git add flutter_app/lib/features/delivery_plan/delivery_plan_ocr_service.dart flutter_app/test/delivery_plan_ocr_service_test.dart
git commit -m "feat: route delivery plan OCR through Zhipu"
```

### Task 5: AI 配置页智谱提供方

**Files:**
- Create: `test/ai_config_screen_test.dart`
- Modify: `lib/features/orders/ocr/ai_config_screen.dart`

- [ ] **Step 1: 写配置页失败测试**

使用内存 `FileAiConfigStore` 启动 `AiConfigScreen`，断言横向列表、智谱卡片和字段：

```dart
expect(find.byKey(const Key('providerCard-zhipu')), findsOneWidget);
expect(
  find.byWidgetPredicate(
    (widget) =>
        widget is SingleChildScrollView &&
        widget.scrollDirection == Axis.horizontal,
  ),
  findsOneWidget,
);
await tester.tap(find.byKey(const Key('providerCard-zhipu')));
await tester.pumpAndSettle();
expect(find.byKey(const Key('zhipuApiKeyField')), findsOneWidget);
expect(find.text('glm-4.6v-flash'), findsWidgets);
expect(find.text('glm-4v-flash'), findsWidgets);
expect(find.text('glm-4.1v-thinking-flash'), findsWidgets);
```

输入 `zhipu-key`，选择 `glm-4v-flash`，点“保存并启用 智谱”，断言 store 中 provider、Key、model 均已保存。

- [ ] **Step 2: 运行配置页测试确认 RED**

Run:

```powershell
C:\tools\flutter\bin\flutter.bat test test\ai_config_screen_test.dart
```

Expected: 找不到 `providerCard-zhipu`。

- [ ] **Step 3: 按现有模式扩展配置页**

新增 `_zhipuApiKeyController`、`_zhipuModelController`、`_zhipuModelPresets`，同步 listener、dispose、load、校验、`_currentConfig`、预设查找和模型 controller 查找。

“默认使用”改成：

```dart
SingleChildScrollView(
  key: const Key('providerHorizontalList'),
  scrollDirection: Axis.horizontal,
  child: Row(
    children: [
      SizedBox(width: 88, child: geminiCard),
      const SizedBox(width: 8),
      SizedBox(width: 88, child: modelScopeCard),
      const SizedBox(width: 8),
      SizedBox(width: 88, child: paddleCard),
      const SizedBox(width: 8),
      SizedBox(width: 88, child: zhipuCard),
    ],
  ),
)
```

新增 `_ZhipuFields`，复用 `_ConfigField` 和 `_ModelPresetEditor`：

```dart
_ConfigField(
  key: const Key('zhipuApiKeyField'),
  controller: apiKeyController,
  label: '智谱 API Key',
  icon: Icons.key_outlined,
  obscureText: true,
)
```

`_providerMeta` 名称为“智谱”，选择色沿用独立紫色；不增加说明段落。

- [ ] **Step 4: 运行配置页与首页相关测试确认 GREEN**

Run:

```powershell
C:\tools\flutter\bin\flutter.bat test test\ai_config_screen_test.dart test\widget_test.dart
```

Expected: 全部通过。

- [ ] **Step 5: 提交配置 UI**

```powershell
git add flutter_app/lib/features/orders/ocr/ai_config_screen.dart flutter_app/test/ai_config_screen_test.dart flutter_app/test/widget_test.dart
git commit -m "feat: add Zhipu provider settings"
```

### Task 6: 两个拍照识别面板加入智谱

**Files:**
- Modify: `test/order_edit_screen_test.dart`
- Modify: `test/delivery_plan_screen_test.dart`
- Modify: `lib/features/orders/order_edit_screen.dart`
- Modify: `lib/features/delivery_plan/delivery_plan_screen.dart`

- [ ] **Step 1: 写订单拍照面板失败测试**

打开订单“拍照识别”面板后断言：

```dart
expect(find.text('智谱'), findsOneWidget);
```

现有测试不注入真实 Key，智谱按钮允许保持禁用；服务路由已由单元测试覆盖。

- [ ] **Step 2: 写交货计划面板选择和保存失败测试**

在测试配置中加入：

```dart
zhipuApiKey: 'zhipu-key',
zhipuModel: 'glm-4.6v-flash',
zhipuModelPresets: const [
  'glm-4.6v-flash',
  'glm-4v-flash',
  'glm-4.1v-thinking-flash',
],
```

打开面板后点“智谱”，打开模型菜单选择 `glm-4v-flash`，再点“相册识别”；断言内存 store：

```dart
expect(configStore.config.provider, AiOcrConfig.zhipuProvider);
expect(configStore.config.zhipuModel, 'glm-4v-flash');
```

- [ ] **Step 3: 运行拍照面板测试确认 RED**

Run:

```powershell
C:\tools\flutter\bin\flutter.bat test test\order_edit_screen_test.dart test\delivery_plan_screen_test.dart
```

Expected: 面板中找不到“智谱”或配置未保存。

- [ ] **Step 4: 扩展订单拍照面板**

在初始 `_aiConfig`、局部模型变量、`activeModelPresets`、四个提供方按钮、PopupMenu 分支、两个 `_OcrCapturePlan` 构造、`copyWith` 和 `_OcrCapturePlan` 字段中加入 `zhipuModel`。

更新标签：

```dart
if (config.usesZhipuOcr) return '智谱';
```

模型标签在 Paddle/ModelScope 前处理 `config.zhipuModel`。增加 `ZhipuWaybillOcrException` catch，直接显示其中文错误。

- [ ] **Step 5: 扩展交货计划拍照面板**

在 `_DeliveryPlanCapturePlan`、state、`initState`、四个提供方按钮、模型菜单、`_activeModel`、`_activeModelPresets`、`_finish` 和 `_startAiScan.copyWith` 中加入 `zhipuModel`。按钮启用条件使用 `initialConfig.hasZhipuCredential`。

- [ ] **Step 6: 运行拍照面板测试确认 GREEN**

Run:

```powershell
C:\tools\flutter\bin\flutter.bat test test\order_edit_screen_test.dart test\delivery_plan_screen_test.dart
```

Expected: 全部通过。

- [ ] **Step 7: 提交面板接入**

```powershell
git add flutter_app/lib/features/orders/order_edit_screen.dart flutter_app/lib/features/delivery_plan/delivery_plan_screen.dart flutter_app/test/order_edit_screen_test.dart flutter_app/test/delivery_plan_screen_test.dart
git commit -m "feat: select Zhipu in OCR capture sheets"
```

### Task 7: 格式化、完整验证与本地合并

**Files:**
- Verify all modified Dart files
- Review: `docs/superpowers/specs/2026-08-12-zhipu-glm-vision-ocr-design.md`
- Review: `docs/superpowers/plans/2026-08-12-zhipu-glm-vision-ocr.md`

- [ ] **Step 1: 格式化本次 Dart 文件**

Run:

```powershell
C:\tools\flutter\bin\dart.bat format lib\features\orders\ocr\ai_config_store.dart lib\features\orders\ocr\zhipu_vision_client.dart lib\features\orders\ocr\zhipu_waybill_ocr_service.dart lib\features\orders\ocr\modelscope_waybill_ocr_service.dart lib\features\orders\ocr\configured_waybill_ocr_service.dart lib\features\delivery_plan\delivery_plan_ocr_service.dart lib\features\orders\ocr\ai_config_screen.dart lib\features\orders\order_edit_screen.dart lib\features\delivery_plan\delivery_plan_screen.dart test\ai_config_store_test.dart test\zhipu_vision_client_test.dart test\zhipu_waybill_ocr_service_test.dart test\configured_waybill_ocr_service_test.dart test\delivery_plan_ocr_service_test.dart test\ai_config_screen_test.dart test\order_edit_screen_test.dart test\delivery_plan_screen_test.dart
```

Expected: exit 0。

- [ ] **Step 2: 顺序运行所有聚焦测试**

Run:

```powershell
C:\tools\flutter\bin\flutter.bat test test\ai_config_store_test.dart test\zhipu_vision_client_test.dart test\zhipu_waybill_ocr_service_test.dart test\configured_waybill_ocr_service_test.dart test\delivery_plan_ocr_service_test.dart test\ai_config_screen_test.dart test\order_edit_screen_test.dart test\delivery_plan_screen_test.dart test\widget_test.dart
```

Expected: 全部通过。

- [ ] **Step 3: 顺序运行完整测试**

Run:

```powershell
C:\tools\flutter\bin\flutter.bat test
```

Expected: exit 0，0 failures。

- [ ] **Step 4: 顺序运行静态分析**

Run:

```powershell
C:\tools\flutter\bin\flutter.bat analyze
```

Expected: `No issues found!`。

- [ ] **Step 5: 审查范围和密钥泄露**

Run:

```powershell
git diff --check
git diff --stat origin/main...HEAD
git diff --name-only origin/main...HEAD
rg -n "ZHIPU_API_KEY|Bearer [A-Za-z0-9._-]{12,}|data:image/.+base64,[A-Za-z0-9+/]{32,}" lib test
```

Expected: 无空白错误；只包含计划内文件；没有真实密钥或完整图片数据。

- [ ] **Step 6: 提交剩余格式/文档改动**

```powershell
git add flutter_app/docs/superpowers/plans/2026-08-12-zhipu-glm-vision-ocr.md flutter_app/lib flutter_app/test
git commit -m "test: verify Zhipu vision OCR integration"
```

若没有剩余改动，则跳过空提交。

- [ ] **Step 7: 本地合并到主支且不推送功能分支**

从仓库根目录执行：

```powershell
git status --short
git switch main
git merge --ff-only codex/zhipu-glm-vision-ocr
git status --short --branch
```

Expected: 工作区干净，`main` 指向已验证提交。不要执行 `git push origin codex/zhipu-glm-vision-ocr`，也不执行其他远程推送。

# Multi-Model AI Provider Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Add an independently configured multi-model vision provider to both order OCR and delivery-plan OCR.

**Architecture:** Extend `AiOcrConfig` with provider-specific token, selected model, and presets. Add one shared OpenAI-compatible vision client plus thin order and delivery-plan adapters, then route both configured OCR entry points to those adapters without changing existing provider fallback behavior.

**Tech Stack:** Flutter, Dart, `dart:io` `HttpClient`, JSON, Flutter widget/unit tests.

---

## File Structure

- Modify `flutter_app/lib/features/orders/ocr/ai_config_store.dart`: persist provider token, model, and presets.
- Create `flutter_app/lib/features/orders/ocr/multi_model_vision_client.dart`: authenticated multimodal requests and API error normalization.
- Create `flutter_app/lib/features/orders/ocr/multi_model_waybill_ocr_service.dart`: order-specific prompt and draft parsing.
- Modify `flutter_app/lib/features/orders/ocr/configured_waybill_ocr_service.dart`: order routing.
- Modify `flutter_app/lib/features/delivery_plan/delivery_plan_ocr_service.dart`: delivery-plan adapter and routing.
- Modify `flutter_app/lib/features/orders/ocr/ai_config_screen.dart`: fourth provider card and fields.
- Modify `flutter_app/lib/features/orders/order_edit_screen.dart`: provider/model labels.
- Add and update focused tests under `flutter_app/test/`.

### Task 1: Configuration persistence

**Files:**
- Modify: `flutter_app/lib/features/orders/ocr/ai_config_store.dart`
- Test: `flutter_app/test/ai_config_store_test.dart`

- [ ] **Step 1: Write a failing round-trip test**

Save and reload a configuration with provider `multi_model`, token `token-123`, model `moonshotai/Kimi-K2.7-Code:novita`, and two presets. Assert provider, credential getter, selected model, and presets survive reload.

- [ ] **Step 2: Run the focused test and verify it fails**

```powershell
C:\tools\flutter\bin\flutter.bat test test\ai_config_store_test.dart
```

Expected: compilation failure because the new members do not exist.

- [ ] **Step 3: Implement the configuration members**

Add the following consistently to the constructor, fields, getters, `toJson`, `fromJson`, `copyWith`, and default configurations:

```dart
static const multiModelProvider = 'multi_model';
static const defaultMultiModelModel =
    'moonshotai/Kimi-K2.7-Code:novita';
static const defaultMultiModelModelPresets = [defaultMultiModelModel];

final String multiModelToken;
final String multiModelModel;
final List<String> multiModelModelPresets;

bool get usesMultiModelOcr => provider == multiModelProvider;
bool get hasMultiModelCredential => multiModelToken.trim().isNotEmpty;
```

Ensure `fromJson` retains the provider and old configuration files receive empty token/default model values.

- [ ] **Step 4: Run the focused test and verify it passes**

- [ ] **Step 5: Commit**

```powershell
git add flutter_app/lib/features/orders/ocr/ai_config_store.dart flutter_app/test/ai_config_store_test.dart
git commit -m "feat: persist multi-model OCR provider config"
```

### Task 2: Shared multimodal API client

**Files:**
- Create: `flutter_app/lib/features/orders/ocr/multi_model_vision_client.dart`
- Create: `flutter_app/test/multi_model_vision_client_test.dart`

- [ ] **Step 1: Write failing request and response tests**

Use this injectable transport boundary:

```dart
typedef MultiModelHttpPost = Future<MultiModelHttpResponse> Function(
  Uri uri,
  Map<String, Object?> body,
  String token,
);

class MultiModelHttpResponse {
  const MultiModelHttpResponse({required this.statusCode, required this.body});
  final int statusCode;
  final String body;
}
```

Assert the request contains the selected model, text, MIME-aware base64 `image_url`, `temperature: 0.0`, and `max_tokens: 4096`. Cover successful content, fenced JSON, 401, 402, 429, unsupported-image errors, and empty content.

- [ ] **Step 2: Run the test and verify it fails**

```powershell
C:\tools\flutter\bin\flutter.bat test test\multi_model_vision_client_test.dart
```

- [ ] **Step 3: Implement `MultiModelVisionClient`**

Use endpoint `https://router.huggingface.co/v1/chat/completions`, normalize optional `Bearer ` prefixes, and map errors to `MultiModelVisionException`:

```dart
401 => '访问令牌无效或无调用权限'
402 => '平台额度不足'
429 => '平台请求过于频繁，请稍后重试'
```

Preserve other status codes and API messages. Read `choices[0].message.content` and remove only surrounding Markdown JSON fences.

- [ ] **Step 4: Run the client tests and verify they pass**

- [ ] **Step 5: Commit**

```powershell
git add flutter_app/lib/features/orders/ocr/multi_model_vision_client.dart flutter_app/test/multi_model_vision_client_test.dart
git commit -m "feat: add multi-model vision API client"
```

### Task 3: Order OCR adapter and routing

**Files:**
- Create: `flutter_app/lib/features/orders/ocr/multi_model_waybill_ocr_service.dart`
- Modify: `flutter_app/lib/features/orders/ocr/configured_waybill_ocr_service.dart`
- Create: `flutter_app/test/multi_model_waybill_ocr_service_test.dart`
- Modify: `flutter_app/test/configured_waybill_ocr_service_test.dart`

- [ ] **Step 1: Write failing adapter tests**

Test configured token/model loading, image preparation, prompt selection, valid JSON parsing into `WaybillOcrDraft`, merchant-history matching, missing token, invalid JSON, and empty result.

- [ ] **Step 2: Write a failing router test**

Inject `multiModelServiceFactory`, select `AiOcrConfig.multiModelProvider`, and assert only that service runs and receives the configured model.

- [ ] **Step 3: Run focused tests and verify failure**

```powershell
C:\tools\flutter\bin\flutter.bat test test\multi_model_waybill_ocr_service_test.dart test\configured_waybill_ocr_service_test.dart
```

- [ ] **Step 4: Implement adapter and explicit router branch**

Follow the existing ModelScope patterns for prompt selection, `AiOcrImagePreparer`, JSON parsing, `applyMerchantHistoryMatch`, empty-result detection, and `logOcrMerchantDiagnosis`. Route the explicitly selected provider before Gemini fallback.

- [ ] **Step 5: Run focused tests and verify they pass**

- [ ] **Step 6: Commit**

```powershell
git add flutter_app/lib/features/orders/ocr/multi_model_waybill_ocr_service.dart flutter_app/lib/features/orders/ocr/configured_waybill_ocr_service.dart flutter_app/test/multi_model_waybill_ocr_service_test.dart flutter_app/test/configured_waybill_ocr_service_test.dart
git commit -m "feat: route order OCR through multi-model provider"
```

### Task 4: Delivery-plan adapter and routing

**Files:**
- Modify: `flutter_app/lib/features/delivery_plan/delivery_plan_ocr_service.dart`
- Test: `flutter_app/test/delivery_plan_ocr_service_test.dart`

- [ ] **Step 1: Write failing tests**

Select the new provider, assert the injected factory runs, and verify the adapter sends `_deliveryPlanPrompt` with the configured model before parsing `rows` and `warnings` through the existing parser.

- [ ] **Step 2: Run the focused test and verify failure**

```powershell
C:\tools\flutter\bin\flutter.bat test test\delivery_plan_ocr_service_test.dart
```

- [ ] **Step 3: Implement `MultiModelDeliveryPlanOcrService`**

Use `MultiModelVisionClient`, existing delivery-plan progress wording, the existing prompt, and the existing response parser. Add `multiModelServiceFactory` and route it before Gemini fallback.

- [ ] **Step 4: Run focused tests and verify they pass**

- [ ] **Step 5: Commit**

```powershell
git add flutter_app/lib/features/delivery_plan/delivery_plan_ocr_service.dart flutter_app/test/delivery_plan_ocr_service_test.dart
git commit -m "feat: support multi-model delivery plan OCR"
```

### Task 5: Configuration UI and labels

**Files:**
- Modify: `flutter_app/lib/features/orders/ocr/ai_config_screen.dart`
- Modify: `flutter_app/lib/features/orders/order_edit_screen.dart`
- Create or modify: `flutter_app/test/ai_config_screen_test.dart`

- [ ] **Step 1: Write failing widget tests**

Assert `providerCard-multi-model` is present; selecting it reveals token/model controls; adding a model updates presets; saving and reloading restore provider, token, and model.

- [ ] **Step 2: Run the widget test and verify failure**

```powershell
C:\tools\flutter\bin\flutter.bat test test\ai_config_screen_test.dart
```

- [ ] **Step 3: Implement UI state and persistence**

Add controllers, presets, listeners, disposal, loading, validation, selected-state logic, metadata, helpers, auto-save, and `_currentConfig` fields. Render four cards using a two-column `Wrap` on phone widths. Label fields `模型中心 Token` and `模型标识`, with a note that the selected model must accept image input.

- [ ] **Step 4: Update order status labels**

Extend `_ocrProviderLabel` and `_ocrModelLabel` so the selected provider/model is displayed instead of the Gemini fallback.

- [ ] **Step 5: Run affected tests**

```powershell
C:\tools\flutter\bin\flutter.bat test test\ai_config_screen_test.dart test\ai_config_store_test.dart test\configured_waybill_ocr_service_test.dart test\delivery_plan_ocr_service_test.dart
```

- [ ] **Step 6: Commit**

```powershell
git add flutter_app/lib/features/orders/ocr/ai_config_screen.dart flutter_app/lib/features/orders/order_edit_screen.dart flutter_app/test/ai_config_screen_test.dart
git commit -m "feat: add multi-model provider configuration UI"
```

### Task 6: Full verification

**Files:**
- Verify all changed Dart files.

- [ ] **Step 1: Format source and tests**

```powershell
C:\tools\flutter\bin\dart.bat format lib test
```

- [ ] **Step 2: Run static analysis**

```powershell
C:\tools\flutter\bin\flutter.bat analyze
```

Expected: exit code 0 with no analyzer errors.

- [ ] **Step 3: Run the complete test suite**

```powershell
C:\tools\flutter\bin\flutter.bat test
```

Expected: exit code 0 and all tests pass.

- [ ] **Step 4: Inspect the final diff**

```powershell
git diff --check HEAD~5..HEAD
git status --short
```

Confirm no token is committed, old configurations remain readable, both routers contain the explicit new-provider branch, and only intended files changed.

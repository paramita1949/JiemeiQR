import 'dart:async';

import 'package:flutter/material.dart';
import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class AiConfigScreen extends StatefulWidget {
  const AiConfigScreen({
    super.key,
    this.configStore = const FileAiConfigStore(),
  });

  final FileAiConfigStore configStore;

  @override
  State<AiConfigScreen> createState() => _AiConfigScreenState();
}

class _AiConfigScreenState extends State<AiConfigScreen> {
  final _formKey = GlobalKey<FormState>();
  final _apiKeyController = TextEditingController();
  final _modelController = TextEditingController();
  final _modelscopeTokenController = TextEditingController();
  final _modelscopeModelController = TextEditingController();
  List<String> _geminiModelPresets = [];
  List<String> _modelScopeModelPresets = [];
  late Future<void> _loadFuture;
  Timer? _autoSaveTimer;
  bool _saving = false;
  bool _autoSaveReady = false;
  String _provider = AiOcrConfig.defaultProvider;

  @override
  void initState() {
    super.initState();
    for (final controller in [
      _apiKeyController,
      _modelController,
      _modelscopeTokenController,
      _modelscopeModelController,
    ]) {
      controller.addListener(_scheduleAutoSave);
    }
    _loadFuture = _load();
  }

  @override
  void dispose() {
    _autoSaveTimer?.cancel();
    if (_autoSaveReady && _selectedConfigError() == null) {
      _saveDraftSilently();
    }
    _apiKeyController.dispose();
    _modelController.dispose();
    _modelscopeTokenController.dispose();
    _modelscopeModelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await widget.configStore.load();
    if (!mounted) {
      return;
    }
    setState(() {
      _provider = config.provider;
      _apiKeyController.text = config.geminiApiKey;
      _modelController.text = config.geminiModel;
      _modelscopeTokenController.text = config.modelscopeToken;
      _modelscopeModelController.text = config.modelscopeModel;
      _geminiModelPresets = [...config.geminiModelPresets];
      _modelScopeModelPresets = [...config.modelScopeModelPresets];
      if (_provider != AiOcrConfig.defaultProvider &&
          _provider != AiOcrConfig.modelscopeProvider) {
        _provider = AiOcrConfig.defaultProvider;
      }
      _autoSaveReady = true;
    });
  }

  @override
  Widget build(BuildContext context) {
    final selectedMeta = _providerMeta(_provider);
    return Scaffold(
      bottomNavigationBar: SafeArea(
        child: Container(
          padding: const EdgeInsets.fromLTRB(18, 10, 18, 16),
          decoration: const BoxDecoration(
            color: Colors.white,
            border: Border(top: BorderSide(color: Color(0xFFE5EAF3))),
          ),
          child: FilledButton.icon(
            style: FilledButton.styleFrom(
              minimumSize: const Size.fromHeight(52),
              textStyle: const TextStyle(
                fontSize: 15,
                fontWeight: FontWeight.w900,
              ),
            ),
            onPressed: _saving ? null : _save,
            icon: _saving
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Icon(Icons.save_outlined),
            label: Text(_saving ? '保存中' : '保存并启用 ${selectedMeta.name}'),
          ),
        ),
      ),
      body: SafeArea(
        child: FutureBuilder<void>(
          future: _loadFuture,
          builder: (context, snapshot) {
            return Form(
              key: _formKey,
              child: ListView(
                padding: const EdgeInsets.fromLTRB(18, 18, 18, 110),
                children: [
                  PageTitle(
                    icon: selectedMeta.icon,
                    title: 'AI配置',
                    subtitle: '拍照识别服务与接口凭据',
                  ),
                  const SizedBox(height: 14),
                  _StatusPanel(
                    meta: selectedMeta,
                    configured: _isSelectedProviderConfigured,
                  ),
                  const SizedBox(height: 14),
                  _SectionShell(
                    title: '默认使用',
                    subtitle: '拍照识别时优先调用选中的服务',
                    child: SingleChildScrollView(
                      key: const Key('providerHorizontalList'),
                      scrollDirection: Axis.horizontal,
                      child: Row(
                        children: [
                          _ProviderCard(
                            key: const Key('providerCard-gemini'),
                            meta: _providerMeta(AiOcrConfig.defaultProvider),
                            selected: _provider == AiOcrConfig.defaultProvider,
                            onTap: () => _selectProvider(
                              AiOcrConfig.defaultProvider,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _ProviderCard(
                            key: const Key('providerCard-modelscope'),
                            meta: _providerMeta(AiOcrConfig.modelscopeProvider),
                            selected:
                                _provider == AiOcrConfig.modelscopeProvider,
                            onTap: () => _selectProvider(
                              AiOcrConfig.modelscopeProvider,
                            ),
                          ),
                        ],
                      ),
                    ),
                  ),
                  const SizedBox(height: 14),
                  _SectionShell(
                    title: '识别密钥',
                    subtitle: selectedMeta.formHint,
                    child: AnimatedSwitcher(
                      duration: const Duration(milliseconds: 180),
                      switchInCurve: Curves.easeOut,
                      switchOutCurve: Curves.easeIn,
                      child: _providerFields(),
                    ),
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  bool get _isSelectedProviderConfigured {
    if (_provider == AiOcrConfig.modelscopeProvider) {
      return _modelscopeTokenController.text.trim().isNotEmpty &&
          _modelscopeModelController.text.trim().isNotEmpty;
    }
    return _apiKeyController.text.trim().isNotEmpty &&
        _modelController.text.trim().isNotEmpty;
  }

  Widget _providerFields() {
    if (_provider == AiOcrConfig.modelscopeProvider) {
      return _ModelScopeFields(
        key: const ValueKey('modelScopeFields'),
        apiKeyController: _modelscopeTokenController,
        modelController: _modelscopeModelController,
        presets: _modelScopeModelPresets,
        onApplyPreset: (model) =>
            _applyModelPreset(_modelscopeModelController, model),
        onAddPreset: (model) =>
            _addModelPreset(AiOcrConfig.modelscopeProvider, model),
        onRemovePreset: (model) => _deleteModelPreset(
          AiOcrConfig.modelscopeProvider,
          model,
        ),
      );
    }
    return _GeminiFields(
      key: const ValueKey('geminiFields'),
      apiKeyController: _apiKeyController,
      modelController: _modelController,
      presets: _geminiModelPresets,
      onApplyPreset: (model) => _applyModelPreset(_modelController, model),
      onAddPreset: (model) =>
          _addModelPreset(AiOcrConfig.defaultProvider, model),
      onRemovePreset: (model) => _deleteModelPreset(
        AiOcrConfig.defaultProvider,
        model,
      ),
    );
  }

  void _selectProvider(String provider) {
    if (_provider == provider) {
      return;
    }
    setState(() => _provider = provider);
    _scheduleAutoSave();
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    final selectedError = _selectedConfigError();
    if (selectedError != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(selectedError)),
      );
      return;
    }
    setState(() => _saving = true);
    await widget.configStore.save(_currentConfig());
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI配置已保存')),
    );
  }

  String? _selectedConfigError() {
    if (_provider == AiOcrConfig.modelscopeProvider) {
      return _modelscopeTokenController.text.trim().isNotEmpty &&
              _modelscopeModelController.text.trim().isNotEmpty
          ? null
          : '请填写魔搭 API KEY 和模型';
    }
    return _apiKeyController.text.trim().isNotEmpty &&
            _modelController.text.trim().isNotEmpty
        ? null
        : '请填写 Gemini API Key 并选择模型';
  }

  AiOcrConfig _currentConfig() {
    return AiOcrConfig(
      provider: _provider,
      geminiApiKey: _apiKeyController.text.trim(),
      geminiModel: _modelController.text.trim(),
      tencentSecretId: '',
      tencentSecretKey: '',
      tencentRegion: AiOcrConfig.defaultTencentRegion,
      aliyunAccessKeyId: '',
      aliyunAccessKeySecret: '',
      aliyunEndpoint: AiOcrConfig.defaultAliyunEndpoint,
      baiduApiKey: '',
      baiduSecretKey: '',
      modelscopeToken: _modelscopeTokenController.text.trim(),
      modelscopeModel: _modelscopeModelController.text.trim(),
      openRouterApiKey: '',
      openRouterModel: AiOcrConfig.defaultOpenRouterModel,
      geminiModelPresets: _geminiModelPresets,
      modelScopeModelPresets: _modelScopeModelPresets,
      openRouterModelPresets: AiOcrConfig.defaultOpenRouterModelPresets,
    );
  }

  void _applyModelPreset(TextEditingController controller, String model) {
    controller.text = model;
  }

  void _addModelPreset(String provider, String model) {
    final normalized = model.trim();
    if (normalized.isEmpty) {
      return;
    }
    final controller = provider == AiOcrConfig.modelscopeProvider
        ? _modelscopeModelController
        : _modelController;
    controller.text = normalized;
    controller.selection = TextSelection.fromPosition(
      TextPosition(offset: normalized.length),
    );
    setState(() {
      final presets = _presetsByProvider(provider);
      if (!presets.contains(normalized)) {
        presets.add(normalized);
      }
    });
    _scheduleAutoSave();
  }

  void _deleteModelPreset(String provider, String model) {
    final controller = provider == AiOcrConfig.modelscopeProvider
        ? _modelscopeModelController
        : _modelController;
    final removeTarget = model.trim();
    final shouldReset = controller.text.trim() == removeTarget;
    final nextModel = _presetsByProvider(provider).firstWhere(
      (item) => item.trim() != removeTarget,
      orElse: () => '',
    );
    setState(() {
      _presetsByProvider(provider).remove(model);
      if (shouldReset) {
        controller.text = nextModel.trim();
      }
    });
    _scheduleAutoSave();
  }

  List<String> _presetsByProvider(String provider) {
    if (provider == AiOcrConfig.modelscopeProvider) {
      return _modelScopeModelPresets;
    }
    return _geminiModelPresets;
  }

  void _scheduleAutoSave() {
    if (!_autoSaveReady || _saving || _selectedConfigError() != null) {
      return;
    }
    _autoSaveTimer?.cancel();
    _autoSaveTimer = Timer(const Duration(milliseconds: 450), () {
      _saveDraftSilently();
    });
  }

  void _saveDraftSilently() {
    unawaited(widget.configStore.save(_currentConfig()).catchError((_) {}));
  }
}

_ProviderMeta _providerMeta(String provider) {
  if (provider == AiOcrConfig.modelscopeProvider) {
    return const _ProviderMeta(
      provider: AiOcrConfig.modelscopeProvider,
      name: '魔搭',
      formHint: '填写魔搭 API KEY 和模型（Model ID）。',
      icon: Icons.document_scanner_outlined,
      color: Color(0xFF2563EB),
    );
  }
  return const _ProviderMeta(
    provider: AiOcrConfig.defaultProvider,
    name: '谷歌',
    formHint: '填写 Gemini Key 和模型名称，保存后拍照识别立即使用。',
    icon: Icons.auto_awesome_outlined,
    color: AppTheme.primary,
  );
}

class _ProviderMeta {
  const _ProviderMeta({
    required this.provider,
    required this.name,
    required this.formHint,
    required this.icon,
    required this.color,
  });

  final String provider;
  final String name;
  final String formHint;
  final IconData icon;
  final Color color;
}

class _StatusPanel extends StatelessWidget {
  const _StatusPanel({
    required this.meta,
    required this.configured,
  });

  final _ProviderMeta meta;
  final bool configured;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: const Color(0xFF101827),
        borderRadius: BorderRadius.circular(18),
        boxShadow: [
          BoxShadow(
            color: const Color(0xFF0F172A).withValues(alpha: 0.12),
            blurRadius: 24,
            offset: const Offset(0, 12),
          ),
        ],
      ),
      child: Row(
        children: [
          Container(
            width: 48,
            height: 48,
            decoration: BoxDecoration(
              color: meta.color.withValues(alpha: 0.16),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: meta.color.withValues(alpha: 0.45)),
            ),
            child: Icon(meta.icon, color: Colors.white, size: 25),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text(
                  '当前启用',
                  style: TextStyle(
                    color: Color(0xFF94A3B8),
                    fontSize: 12,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 3),
                Text(
                  meta.name,
                  style: const TextStyle(
                    color: Colors.white,
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          _StatePill(
            text: configured ? '已配置' : '待填写',
            color:
                configured ? const Color(0xFF22C55E) : const Color(0xFFF59E0B),
          ),
        ],
      ),
    );
  }
}

class _SectionShell extends StatelessWidget {
  const _SectionShell({
    required this.title,
    required this.subtitle,
    required this.child,
  });

  final String title;
  final String subtitle;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: const Color(0xFFE3E8F2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: const TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            subtitle,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          child,
        ],
      ),
    );
  }
}

class _ProviderCard extends StatelessWidget {
  const _ProviderCard({
    super.key,
    required this.meta,
    required this.selected,
    required this.onTap,
  });

  final _ProviderMeta meta;
  final bool selected;
  final VoidCallback onTap;

  @override
  Widget build(BuildContext context) {
    return Material(
      color: selected
          ? meta.color.withValues(alpha: 0.08)
          : const Color(0xFFF7F9FC),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: AnimatedContainer(
          duration: const Duration(milliseconds: 180),
          width: 132,
          constraints: const BoxConstraints(minHeight: 72),
          padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: selected ? meta.color : const Color(0xFFE1E7F0),
              width: selected ? 1.6 : 1,
            ),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                children: [
                  Container(
                    width: 36,
                    height: 36,
                    decoration: BoxDecoration(
                      color: selected ? meta.color : Colors.white,
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(
                      meta.icon,
                      color: selected ? Colors.white : meta.color,
                      size: 21,
                    ),
                  ),
                  const Spacer(),
                  if (selected)
                    Icon(Icons.check_circle, color: meta.color, size: 20),
                ],
              ),
              const SizedBox(height: 10),
              Text(
                meta.name,
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
                style: TextStyle(
                  color: selected ? meta.color : AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _GeminiFields extends StatelessWidget {
  const _GeminiFields({
    super.key,
    required this.apiKeyController,
    required this.modelController,
    required this.presets,
    required this.onApplyPreset,
    required this.onAddPreset,
    required this.onRemovePreset,
  });

  final TextEditingController apiKeyController;
  final TextEditingController modelController;
  final List<String> presets;
  final ValueChanged<String> onApplyPreset;
  final ValueChanged<String> onAddPreset;
  final ValueChanged<String> onRemovePreset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ConfigField(
          key: const Key('geminiApiKeyField'),
          controller: apiKeyController,
          label: 'Gemini API Key',
          icon: Icons.key_outlined,
          obscureText: true,
        ),
        const SizedBox(height: 8),
        _ModelPresetEditor(
          providerName: 'Gemini',
          selectedModel: modelController.text.trim(),
          presets: presets,
          onApplyPreset: onApplyPreset,
          onAddPreset: onAddPreset,
          onRemovePreset: onRemovePreset,
        ),
      ],
    );
  }
}

class _ModelScopeFields extends StatelessWidget {
  const _ModelScopeFields({
    super.key,
    required this.apiKeyController,
    required this.modelController,
    required this.presets,
    required this.onApplyPreset,
    required this.onAddPreset,
    required this.onRemovePreset,
  });

  final TextEditingController apiKeyController;
  final TextEditingController modelController;
  final List<String> presets;
  final ValueChanged<String> onApplyPreset;
  final ValueChanged<String> onAddPreset;
  final ValueChanged<String> onRemovePreset;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ConfigField(
          key: const Key('modelscopeApiKeyField'),
          controller: apiKeyController,
          label: '魔搭 API KEY',
          icon: Icons.key_outlined,
          obscureText: true,
        ),
        const SizedBox(height: 8),
        _ModelPresetEditor(
          providerName: '魔搭',
          selectedModel: modelController.text.trim(),
          presets: presets,
          onApplyPreset: onApplyPreset,
          onAddPreset: onAddPreset,
          onRemovePreset: onRemovePreset,
        ),
      ],
    );
  }
}

class _ModelPresetEditor extends StatefulWidget {
  const _ModelPresetEditor({
    required this.providerName,
    required this.selectedModel,
    required this.presets,
    required this.onApplyPreset,
    required this.onAddPreset,
    required this.onRemovePreset,
  });

  final String providerName;
  final String selectedModel;
  final List<String> presets;
  final ValueChanged<String> onApplyPreset;
  final ValueChanged<String> onAddPreset;
  final ValueChanged<String> onRemovePreset;

  @override
  State<_ModelPresetEditor> createState() => _ModelPresetEditorState();
}

class _ModelPresetEditorState extends State<_ModelPresetEditor> {
  late final TextEditingController _newModelController;

  @override
  void initState() {
    super.initState();
    _newModelController = TextEditingController();
  }

  @override
  void dispose() {
    _newModelController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final selected = widget.selectedModel;
    final hasModels = widget.presets.isNotEmpty;
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Container(
          padding: const EdgeInsets.all(12),
          decoration: BoxDecoration(
            color: const Color(0xFFF8FAFF),
            borderRadius: BorderRadius.circular(14),
            border: Border.all(color: const Color(0xFFDCE5F3)),
          ),
          child: Row(
            children: [
              const Icon(
                Icons.flash_on_rounded,
                color: Color(0xFF1D4ED8),
                size: 18,
              ),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  selected.isEmpty ? '尚未选择模型' : '当前模型：$selected',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: 8),
        Row(
          children: [
            Expanded(
              child: TextField(
                key: Key('${widget.providerName}ModelInput'),
                controller: _newModelController,
                decoration: _fieldDecoration(
                  label:
                      '输入新模型标识，如 ${widget.providerName == 'Gemini' ? 'gemini-2.5-flash' : 'Qwen/Qwen3.5-32B-Instruct'}',
                  icon: Icons.add_circle_outline,
                ),
                onSubmitted: (_) => _submitNewModel(),
              ),
            ),
            const SizedBox(width: 10),
            FilledButton.icon(
              key: Key('${widget.providerName}AddModelButton'),
              onPressed: _submitNewModel,
              icon: const Icon(Icons.add),
              label: const Text('添加'),
            ),
          ],
        ),
        const SizedBox(height: 10),
        if (!hasModels)
          const Text(
            '还没有预设模型，添加后会自动选中并保存到模型列表。',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        if (hasModels)
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: widget.presets
                .map(
                  (model) => _ModelOptionCard(
                    model: model,
                    active: selected == model,
                    onSelect: () => widget.onApplyPreset(model),
                    onDelete: () => widget.onRemovePreset(model),
                  ),
                )
                .toList(),
          ),
      ],
    );
  }

  void _submitNewModel() {
    final model = _newModelController.text.trim();
    if (model.isEmpty) {
      return;
    }
    widget.onAddPreset(model);
    _newModelController.clear();
  }
}

class _ModelOptionCard extends StatelessWidget {
  const _ModelOptionCard({
    required this.model,
    required this.active,
    required this.onSelect,
    required this.onDelete,
  });

  final String model;
  final bool active;
  final VoidCallback onSelect;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: const Duration(milliseconds: 160),
      constraints: const BoxConstraints(minWidth: 150, maxWidth: 260),
      decoration: BoxDecoration(
        color: active ? const Color(0xFFEFF4FF) : Colors.white,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: active ? const Color(0xFF2563EB) : const Color(0xFFDCE4F2),
          width: active ? 1.6 : 1,
        ),
      ),
      child: Material(
        color: Colors.transparent,
        child: InkWell(
          borderRadius: BorderRadius.circular(12),
          onTap: onSelect,
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
            child: Row(
              children: [
                Expanded(
                  child: Text(
                    model,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: TextStyle(
                      color: active
                          ? const Color(0xFF1E3A8A)
                          : AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                IconButton(
                  tooltip: '删除模型',
                  onPressed: onDelete,
                  icon: const Icon(Icons.delete_outline_rounded, size: 18),
                  color: const Color(0xFFDC2626),
                  style: IconButton.styleFrom(
                    minimumSize: const Size(30, 30),
                    padding: EdgeInsets.zero,
                    tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}

class _ConfigField extends StatelessWidget {
  const _ConfigField({
    super.key,
    required this.controller,
    required this.label,
    required this.icon,
    this.obscureText = false,
  });

  final TextEditingController controller;
  final String label;
  final IconData icon;
  final bool obscureText;

  @override
  Widget build(BuildContext context) {
    return TextFormField(
      controller: controller,
      obscureText: obscureText,
      decoration: _fieldDecoration(label: label, icon: icon),
    );
  }
}

InputDecoration _fieldDecoration({
  required String label,
  required IconData icon,
}) {
  return InputDecoration(
    labelText: label,
    prefixIcon: Icon(icon),
    filled: true,
    fillColor: const Color(0xFFF7F9FC),
    border: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFDDE5F0)),
    ),
    enabledBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: Color(0xFFDDE5F0)),
    ),
    focusedBorder: OutlineInputBorder(
      borderRadius: BorderRadius.circular(14),
      borderSide: const BorderSide(color: AppTheme.primary, width: 1.4),
    ),
  );
}

class _StatePill extends StatelessWidget {
  const _StatePill({
    required this.text,
    required this.color,
  });

  final String text;
  final Color color;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(999),
        border: Border.all(color: color.withValues(alpha: 0.28)),
      ),
      child: Text(
        text,
        style: TextStyle(
          color: color,
          fontSize: 11,
          fontWeight: FontWeight.w900,
        ),
      ),
    );
  }
}

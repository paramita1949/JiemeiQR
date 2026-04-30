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
  final _tencentSecretIdController = TextEditingController();
  final _tencentSecretKeyController = TextEditingController();
  final _tencentRegionController = TextEditingController();
  final _aliyunAccessKeyIdController = TextEditingController();
  final _aliyunAccessKeySecretController = TextEditingController();
  final _aliyunEndpointController = TextEditingController();
  final _baiduApiKeyController = TextEditingController();
  final _baiduSecretKeyController = TextEditingController();
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
      _tencentSecretIdController,
      _tencentSecretKeyController,
      _tencentRegionController,
      _aliyunAccessKeyIdController,
      _aliyunAccessKeySecretController,
      _aliyunEndpointController,
      _baiduApiKeyController,
      _baiduSecretKeyController,
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
    _tencentSecretIdController.dispose();
    _tencentSecretKeyController.dispose();
    _tencentRegionController.dispose();
    _aliyunAccessKeyIdController.dispose();
    _aliyunAccessKeySecretController.dispose();
    _aliyunEndpointController.dispose();
    _baiduApiKeyController.dispose();
    _baiduSecretKeyController.dispose();
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
      _tencentSecretIdController.text = config.tencentSecretId;
      _tencentSecretKeyController.text = config.tencentSecretKey;
      _tencentRegionController.text = config.tencentRegion;
      _aliyunAccessKeyIdController.text = config.aliyunAccessKeyId;
      _aliyunAccessKeySecretController.text = config.aliyunAccessKeySecret;
      _aliyunEndpointController.text = config.aliyunEndpoint;
      _baiduApiKeyController.text = config.baiduApiKey;
      _baiduSecretKeyController.text = config.baiduSecretKey;
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
                            key: const Key('providerCard-tencent'),
                            meta: _providerMeta(AiOcrConfig.tencentProvider),
                            selected: _provider == AiOcrConfig.tencentProvider,
                            onTap: () => _selectProvider(
                              AiOcrConfig.tencentProvider,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _ProviderCard(
                            key: const Key('providerCard-aliyun'),
                            meta: _providerMeta(AiOcrConfig.aliyunProvider),
                            selected: _provider == AiOcrConfig.aliyunProvider,
                            onTap: () => _selectProvider(
                              AiOcrConfig.aliyunProvider,
                            ),
                          ),
                          const SizedBox(width: 10),
                          _ProviderCard(
                            key: const Key('providerCard-baidu'),
                            meta: _providerMeta(AiOcrConfig.baiduProvider),
                            selected: _provider == AiOcrConfig.baiduProvider,
                            onTap: () => _selectProvider(
                              AiOcrConfig.baiduProvider,
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
    if (_provider == AiOcrConfig.tencentProvider) {
      return _tencentSecretIdController.text.trim().isNotEmpty &&
          _tencentSecretKeyController.text.trim().isNotEmpty;
    }
    if (_provider == AiOcrConfig.aliyunProvider) {
      return _aliyunAccessKeyIdController.text.trim().isNotEmpty &&
          _aliyunAccessKeySecretController.text.trim().isNotEmpty;
    }
    if (_provider == AiOcrConfig.baiduProvider) {
      return _baiduApiKeyController.text.trim().isNotEmpty &&
          _baiduSecretKeyController.text.trim().isNotEmpty;
    }
    return _apiKeyController.text.trim().isNotEmpty &&
        _modelController.text.trim().isNotEmpty;
  }

  Widget _providerFields() {
    if (_provider == AiOcrConfig.tencentProvider) {
      return _TencentFields(
        key: const ValueKey('tencentFields'),
        secretIdController: _tencentSecretIdController,
        secretKeyController: _tencentSecretKeyController,
      );
    }
    if (_provider == AiOcrConfig.aliyunProvider) {
      return _AliyunFields(
        key: const ValueKey('aliyunFields'),
        accessKeyIdController: _aliyunAccessKeyIdController,
        accessKeySecretController: _aliyunAccessKeySecretController,
      );
    }
    if (_provider == AiOcrConfig.baiduProvider) {
      return _BaiduFields(
        key: const ValueKey('baiduFields'),
        apiKeyController: _baiduApiKeyController,
        secretKeyController: _baiduSecretKeyController,
      );
    }
    return _GeminiFields(
      key: const ValueKey('geminiFields'),
      apiKeyController: _apiKeyController,
      modelController: _modelController,
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
    if (_provider == AiOcrConfig.tencentProvider) {
      return _tencentSecretIdController.text.trim().isNotEmpty &&
              _tencentSecretKeyController.text.trim().isNotEmpty
          ? null
          : '请填写腾讯 SecretId 和 SecretKey';
    }
    if (_provider == AiOcrConfig.aliyunProvider) {
      return _aliyunAccessKeyIdController.text.trim().isNotEmpty &&
              _aliyunAccessKeySecretController.text.trim().isNotEmpty
          ? null
          : '请填写阿里 AccessKeyId 和 AccessKeySecret';
    }
    if (_provider == AiOcrConfig.baiduProvider) {
      return _baiduApiKeyController.text.trim().isNotEmpty &&
              _baiduSecretKeyController.text.trim().isNotEmpty
          ? null
          : '请填写百度 API Key 和 Secret Key';
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
      tencentSecretId: _tencentSecretIdController.text.trim(),
      tencentSecretKey: _tencentSecretKeyController.text.trim(),
      tencentRegion: _tencentRegionController.text.trim().isEmpty
          ? AiOcrConfig.defaultTencentRegion
          : _tencentRegionController.text.trim(),
      aliyunAccessKeyId: _aliyunAccessKeyIdController.text.trim(),
      aliyunAccessKeySecret: _aliyunAccessKeySecretController.text.trim(),
      aliyunEndpoint: _aliyunEndpointController.text.trim().isEmpty
          ? AiOcrConfig.defaultAliyunEndpoint
          : _aliyunEndpointController.text.trim(),
      baiduApiKey: _baiduApiKeyController.text.trim(),
      baiduSecretKey: _baiduSecretKeyController.text.trim(),
    );
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
  if (provider == AiOcrConfig.tencentProvider) {
    return const _ProviderMeta(
      provider: AiOcrConfig.tencentProvider,
      name: '腾讯',
      formHint: '填写腾讯云访问密钥，地域默认使用广州。',
      icon: Icons.article_outlined,
      color: Color(0xFFDC2626),
    );
  }
  if (provider == AiOcrConfig.aliyunProvider) {
    return const _ProviderMeta(
      provider: AiOcrConfig.aliyunProvider,
      name: '阿里',
      formHint: '填写阿里云 AccessKey，默认杭州 OCR API 接入点。',
      icon: Icons.cloud_queue_outlined,
      color: Color(0xFFF97316),
    );
  }
  if (provider == AiOcrConfig.baiduProvider) {
    return const _ProviderMeta(
      provider: AiOcrConfig.baiduProvider,
      name: '百度',
      formHint: '填写百度智能云 API Key 和 Secret Key。',
      icon: Icons.document_scanner_outlined,
      color: Color(0xFF7C3AED),
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
          width: 118,
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
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      meta.name,
                      style: TextStyle(
                        color: selected ? meta.color : AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                  if (selected)
                    Icon(Icons.check_circle, color: meta.color, size: 20),
                ],
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
  });

  final TextEditingController apiKeyController;
  final TextEditingController modelController;

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
        const SizedBox(height: 12),
        _ModelSelectField(
          key: const Key('geminiModelField'),
          controller: modelController,
        ),
      ],
    );
  }
}

class _TencentFields extends StatelessWidget {
  const _TencentFields({
    super.key,
    required this.secretIdController,
    required this.secretKeyController,
  });

  final TextEditingController secretIdController;
  final TextEditingController secretKeyController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ConfigField(
          key: const Key('tencentSecretIdField'),
          controller: secretIdController,
          label: '腾讯 SecretId',
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 12),
        _ConfigField(
          key: const Key('tencentSecretKeyField'),
          controller: secretKeyController,
          label: '腾讯 SecretKey',
          icon: Icons.lock_outline,
          obscureText: true,
        ),
      ],
    );
  }
}

class _AliyunFields extends StatelessWidget {
  const _AliyunFields({
    super.key,
    required this.accessKeyIdController,
    required this.accessKeySecretController,
  });

  final TextEditingController accessKeyIdController;
  final TextEditingController accessKeySecretController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ConfigField(
          key: const Key('aliyunAccessKeyIdField'),
          controller: accessKeyIdController,
          label: '阿里 AccessKeyId',
          icon: Icons.badge_outlined,
        ),
        const SizedBox(height: 12),
        _ConfigField(
          key: const Key('aliyunAccessKeySecretField'),
          controller: accessKeySecretController,
          label: '阿里 AccessKeySecret',
          icon: Icons.lock_outline,
          obscureText: true,
        ),
      ],
    );
  }
}

class _BaiduFields extends StatelessWidget {
  const _BaiduFields({
    super.key,
    required this.apiKeyController,
    required this.secretKeyController,
  });

  final TextEditingController apiKeyController;
  final TextEditingController secretKeyController;

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        _ConfigField(
          key: const Key('baiduApiKeyField'),
          controller: apiKeyController,
          label: '百度 API Key',
          icon: Icons.key_outlined,
        ),
        const SizedBox(height: 12),
        _ConfigField(
          key: const Key('baiduSecretKeyField'),
          controller: secretKeyController,
          label: '百度 Secret Key',
          icon: Icons.lock_outline,
          obscureText: true,
        ),
      ],
    );
  }
}

class _ModelSelectField extends StatelessWidget {
  const _ModelSelectField({
    super.key,
    required this.controller,
  });

  static const _models = [
    AiOcrConfig.defaultModel,
    'gemini-2.5-flash',
    'gemini-2.5-pro',
  ];

  final TextEditingController controller;

  @override
  Widget build(BuildContext context) {
    final current = controller.text.trim().isEmpty
        ? AiOcrConfig.defaultModel
        : controller.text.trim();
    final values = current.isNotEmpty && !_models.contains(current)
        ? [current, ..._models]
        : _models;
    return DropdownButtonFormField<String>(
      key: key,
      initialValue: current,
      items: values
          .map(
            (model) => DropdownMenuItem(
              value: model,
              child: Text(model),
            ),
          )
          .toList(),
      onChanged: (value) {
        if (value != null) {
          controller.text = value;
        }
      },
      validator: (value) => value?.trim().isNotEmpty == true ? null : '必选',
      decoration: _fieldDecoration(
        label: 'Gemini 模型',
        icon: Icons.memory_outlined,
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

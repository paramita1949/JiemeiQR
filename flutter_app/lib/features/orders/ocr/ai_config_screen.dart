import 'package:flutter/material.dart';
import 'package:qrscan_flutter/features/orders/ocr/ai_config_store.dart';
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
  late Future<void> _loadFuture;
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _loadFuture = _load();
  }

  @override
  void dispose() {
    _apiKeyController.dispose();
    _modelController.dispose();
    super.dispose();
  }

  Future<void> _load() async {
    final config = await widget.configStore.load();
    _apiKeyController.text = config.geminiApiKey;
    _modelController.text = config.geminiModel;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      bottomNavigationBar: SafeArea(
        minimum: const EdgeInsets.all(16),
        child: FilledButton.icon(
          onPressed: _saving ? null : _save,
          icon: _saving
              ? const SizedBox(
                  width: 18,
                  height: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Icon(Icons.save_outlined),
          label: const Text('保存配置'),
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
                  const PageTitle(
                    icon: Icons.tune_outlined,
                    title: 'AI配置',
                    subtitle: '',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('geminiApiKeyField'),
                    controller: _apiKeyController,
                    decoration: const InputDecoration(
                      labelText: 'Gemini API Key',
                      border: OutlineInputBorder(),
                    ),
                    obscureText: true,
                    validator: (value) =>
                        value?.trim().isEmpty == false ? null : '必填',
                  ),
                  const SizedBox(height: 12),
                  TextFormField(
                    key: const Key('geminiModelField'),
                    controller: _modelController,
                    decoration: const InputDecoration(
                      labelText: 'Gemini 模型',
                      border: OutlineInputBorder(),
                    ),
                    validator: (value) =>
                        value?.trim().isEmpty == false ? null : '必填',
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Future<void> _save() async {
    if (!_formKey.currentState!.validate()) {
      return;
    }
    setState(() => _saving = true);
    await widget.configStore.save(
      AiOcrConfig(
        geminiApiKey: _apiKeyController.text.trim(),
        geminiModel: _modelController.text.trim(),
      ),
    );
    if (!mounted) {
      return;
    }
    setState(() => _saving = false);
    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(content: Text('AI配置已保存')),
    );
  }
}

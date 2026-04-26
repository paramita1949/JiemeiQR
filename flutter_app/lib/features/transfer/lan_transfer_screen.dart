import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qrscan_flutter/features/transfer/backup_service.dart';
import 'package:qrscan_flutter/features/transfer/lan_transfer_service.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';

class LanTransferScreen extends StatefulWidget {
  const LanTransferScreen({
    super.key,
    this.databasePath = 'jiemei.sqlite',
    this.backupService,
    this.lanTransferService,
    this.onPrepareImport,
    this.onImportCompleted,
  });

  final String databasePath;
  final BackupService? backupService;
  final LanTransferService? lanTransferService;
  final Future<void> Function()? onPrepareImport;
  final Future<void> Function()? onImportCompleted;

  @override
  State<LanTransferScreen> createState() => _LanTransferScreenState();
}

class _LanTransferScreenState extends State<LanTransferScreen> {
  late final BackupService _backupService;
  late final LanTransferService _lanTransferService;
  late BackupDraft _backupDraft;
  bool _creatingBackup = false;
  bool _importingBackup = false;
  bool _resettingDatabase = false;
  bool _sendingServer = false;
  SendSession? _sendSession;
  _ReceiveInput? _lastReceiveInput;
  String? _receiveProgressText;

  @override
  void initState() {
    super.initState();
    _backupService = widget.backupService ??
        BackupService(databaseFileName: widget.databasePath);
    _lanTransferService = widget.lanTransferService ??
        LanTransferService(backupService: _backupService);
    _backupDraft = _backupService.createLocalBackupDraft();
  }

  @override
  void dispose() {
    _lanTransferService.stopSendSession();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 42),
          children: [
            const PageTitle(
              icon: Icons.sync_alt_outlined,
              title: '局域网迁移',
              subtitle: '数据库发送、接收与备份',
            ),
            const SizedBox(height: 14),
            _ModeCard(
              icon: Icons.upload_file_outlined,
              title: '发送数据库',
              description: '启动局域网发送服务，提供配对码供另一台设备接收。',
              actionText: _sendingServer ? '停止发送' : '开始发送',
              onAction: _sendingServer ? _stopSendServer : _startSendServer,
              footer: _sendSession == null
                  ? null
                  : '地址：${_sendSession!.baseUri}\n配对码：${_sendSession!.pairingCode}\n连接码：${_sendSession!.connectionCode}',
              secondaryActionText: _sendSession == null ? null : '复制连接码',
              onSecondaryAction:
                  _sendSession == null ? null : _copyConnectionCode,
            ),
            const SizedBox(height: 10),
            _ModeCard(
              icon: Icons.download_for_offline_outlined,
              title: '接收数据库',
              description: '从另一台设备接收数据库，导入前自动备份当前数据库。',
              actionText: _importingBackup ? '导入中...' : '开始接收',
              onAction: _importingBackup ? null : _startReceiveImport,
              secondaryActionText: _importingBackup
                  ? null
                  : (_lastReceiveInput == null ? '粘贴连接码' : '重试上次接收'),
              onSecondaryAction: _importingBackup
                  ? null
                  : (_lastReceiveInput == null
                      ? _receiveFromClipboardCode
                      : _retryLastReceive),
              footer: _receiveProgressText,
            ),
            const SizedBox(height: 10),
            _ModeCard(
              icon: Icons.save_alt_outlined,
              title: '本地备份',
              description: '备份/导入只在此页面处理',
              footer: '${_backupDraft.fileName}\n${_backupDraft.note}',
              actionText: _creatingBackup ? '生成中...' : '生成备份',
              onAction: _creatingBackup ? null : () => _createBackup(),
            ),
            const SizedBox(height: 10),
            _ModeCard(
              icon: Icons.restart_alt_outlined,
              title: '重置数据库',
              description: '清空当前数据并重新开始，执行前自动生成备份。',
              actionText: _resettingDatabase ? '重置中...' : '重置并重新开始',
              onAction: _resettingDatabase ? null : _confirmAndResetDatabase,
            ),
            const SizedBox(height: 12),
            const Text(
              '发送端启动后请保持页面不退出；接收端输入发送地址与配对码后会自动导入，并在导入前自动备份当前数据库。',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.45,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _createBackup() async {
    setState(() => _creatingBackup = true);
    try {
      final result = await _backupService.createLocalBackup();
      if (!mounted) {
        return;
      }
      setState(() {
        _backupDraft = _backupService.createLocalBackupDraft();
      });
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text('备份完成：${result.fileName}')),
      );
    } on BackupSourceMissingException {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('未找到数据库文件，无法生成备份')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('备份失败，请稍后重试')),
      );
    } finally {
      if (mounted) {
        setState(() => _creatingBackup = false);
      }
    }
  }

  Future<void> _startSendServer() async {
    try {
      final session = await _lanTransferService.startSendSession();
      if (!mounted) {
        return;
      }
      setState(() {
        _sendSession = session;
        _sendingServer = true;
      });
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        SnackBar(
          content: Text(
            '发送服务已启动：${session.baseUri}\n配对码：${session.pairingCode}',
          ),
        ),
      );
    } on BackupSourceMissingException {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('当前数据库不存在，无法生成发送包')),
      );
    } finally {
      // no-op
    }
  }

  Future<void> _stopSendServer() async {
    await _lanTransferService.stopSendSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _sendingServer = false;
      _sendSession = null;
    });
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(content: Text('发送服务已停止')),
    );
  }

  Future<void> _startReceiveImport() async {
    final input = await _showReceiveDialog();
    if (input == null) {
      return;
    }
    await _receiveFromInput(input);
  }

  Future<void> _retryLastReceive() async {
    final input = _lastReceiveInput;
    if (input == null) {
      return;
    }
    await _receiveFromInput(input);
  }

  Future<void> _receiveFromClipboardCode() async {
    final data = await Clipboard.getData(Clipboard.kTextPlain);
    final text = data?.text?.trim() ?? '';
    if (text.isEmpty) {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('剪贴板为空')),
      );
      return;
    }
    await _receiveFromInput(
      _ReceiveInput(baseUrl: text, pairingCode: ''),
    );
  }

  Future<void> _receiveFromInput(_ReceiveInput input) async {
    var hostText = input.baseUrl.trim();
    var codeText = input.pairingCode.trim();
    if (codeText.isEmpty && hostText.startsWith('JM:')) {
      try {
        final parsed = _lanTransferService.parseConnectionCode(hostText);
        hostText = parsed.baseUrl;
        codeText = parsed.pairingCode;
      } on ConnectionCodeParseException {
        if (!mounted) {
          return;
        }
        final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
        messenger.showSnackBar(
          const SnackBar(content: Text('连接码无效')),
        );
        return;
      }
    }
    if (hostText.isEmpty || codeText.isEmpty) {
      return;
    }

    var prepared = false;
    setState(() {
      _importingBackup = true;
      _receiveProgressText = '准备连接发送端...';
      _lastReceiveInput =
          _ReceiveInput(baseUrl: hostText, pairingCode: codeText);
    });
    try {
      final baseUri = Uri.tryParse(hostText);
      if (baseUri == null || !baseUri.hasAuthority) {
        throw const FormatException('invalid-url');
      }
      setState(() => _receiveProgressText = '正在下载迁移包...');
      await widget.onPrepareImport?.call();
      prepared = true;
      setState(() => _receiveProgressText = '正在导入数据库（自动备份）...');
      final result = await _lanTransferService.receiveFromSender(
        baseUri: baseUri,
        pairingCode: codeText,
      );
      if (prepared) {
        await widget.onImportCompleted?.call();
        prepared = false;
      }
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text('接收并导入完成，已自动备份：${result.backupFileName}')),
      );
      setState(() => _receiveProgressText = '最近一次接收成功');
    } on FormatException {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('发送地址格式错误')),
      );
    } on SenderUnavailableException {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('无法连接发送端，请检查地址与局域网')),
      );
    } on PairingCodeRejectedException {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('配对码错误，接收被拒绝')),
      );
    } on InvalidSenderManifestException {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('发送端迁移包无效')),
      );
    } on DatabaseDownloadFailedException {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('下载数据库失败，请重试')),
      );
    } on ImportSourceMissingException {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('接收文件不存在，请检查路径')),
      );
    } on InvalidImportDatabaseException {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('接收文件不是有效数据库')),
      );
    } on BackupSourceMissingException {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('当前数据库不存在，无法导入')),
      );
    } on ImportDatabaseFailedException {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('导入失败，请关闭占用数据库的页面后重试')),
      );
    } finally {
      if (prepared) {
        await widget.onImportCompleted?.call();
      }
      if (mounted) {
        setState(() => _importingBackup = false);
      }
    }
  }

  Future<_ReceiveInput?> _showReceiveDialog() async {
    final urlController = TextEditingController();
    final codeController = TextEditingController();
    return showDialog<_ReceiveInput>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('接收数据库'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              key: const Key('receiveSenderUrlField'),
              controller: urlController,
              decoration: const InputDecoration(
                labelText: '发送地址',
                hintText: '例如：http://192.168.1.8:54021 或 JM:连接码',
              ),
            ),
            const SizedBox(height: 10),
            TextField(
              key: const Key('receivePairingCodeField'),
              controller: codeController,
              keyboardType: TextInputType.number,
              decoration: const InputDecoration(
                labelText: '配对码',
                hintText: '6位数字',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            key: const Key('receiveImportConfirmButton'),
            onPressed: () => Navigator.of(context).pop(
              _ReceiveInput(
                baseUrl: urlController.text,
                pairingCode: codeController.text,
              ),
            ),
            child: const Text('导入'),
          ),
        ],
      ),
    );
  }

  Future<void> _copyConnectionCode() async {
    final session = _sendSession;
    if (session == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: session.connectionCode));
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(
      const SnackBar(content: Text('连接码已复制')),
    );
  }

  Future<void> _confirmAndResetDatabase() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('确认重置数据库'),
        content: const Text('此操作会清空当前所有订单和库存数据，并从零开始。是否继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认重置'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() => _resettingDatabase = true);
    var prepared = false;
    try {
      await widget.onPrepareImport?.call();
      prepared = true;
      final result = await _backupService.resetDatabase();
      await widget.onImportCompleted?.call();
      prepared = false;
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        SnackBar(content: Text('数据库已重置，备份：${result.backupFileName}')),
      );
      Navigator.of(context).pop();
    } on BackupSourceMissingException {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('未找到数据库文件，无法重置')),
      );
    } catch (_) {
      if (!mounted) {
        return;
      }
      final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
      messenger.showSnackBar(
        const SnackBar(content: Text('重置失败，请稍后重试')),
      );
    } finally {
      if (prepared) {
        await widget.onImportCompleted?.call();
      }
      if (mounted) {
        setState(() => _resettingDatabase = false);
      }
    }
  }
}

class _ReceiveInput {
  const _ReceiveInput({
    required this.baseUrl,
    required this.pairingCode,
  });

  final String baseUrl;
  final String pairingCode;
}

class _ModeCard extends StatelessWidget {
  const _ModeCard({
    required this.icon,
    required this.title,
    required this.description,
    this.footer,
    this.actionText,
    this.onAction,
    this.secondaryActionText,
    this.onSecondaryAction,
  });

  final IconData icon;
  final String title;
  final String description;
  final String? footer;
  final String? actionText;
  final Future<void> Function()? onAction;
  final String? secondaryActionText;
  final Future<void> Function()? onSecondaryAction;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              color: const Color(0xFFEAF7FF),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: AppTheme.primary),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 16,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                const SizedBox(height: 5),
                Text(
                  description,
                  style: const TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                    height: 1.35,
                  ),
                ),
                if (footer != null) ...[
                  const SizedBox(height: 8),
                  Text(
                    footer!,
                    style: const TextStyle(
                      color: AppTheme.primary,
                      fontSize: 12,
                      fontWeight: FontWeight.w800,
                      height: 1.35,
                    ),
                  ),
                ],
                if (actionText != null && onAction != null) ...[
                  const SizedBox(height: 10),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: FilledButton.tonal(
                      onPressed: onAction,
                      child: Text(actionText!),
                    ),
                  ),
                ],
                if (secondaryActionText != null &&
                    onSecondaryAction != null) ...[
                  const SizedBox(height: 8),
                  Align(
                    alignment: Alignment.centerLeft,
                    child: OutlinedButton(
                      onPressed: onSecondaryAction,
                      child: Text(secondaryActionText!),
                    ),
                  ),
                ],
              ],
            ),
          ),
        ],
      ),
    );
  }
}

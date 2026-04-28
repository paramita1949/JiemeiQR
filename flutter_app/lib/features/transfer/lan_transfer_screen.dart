import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qr_flutter/qr_flutter.dart';
import 'package:qrscan_flutter/features/qr/scanner_screen.dart';
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
  bool _resettingDatabase = false;
  bool _startingSend = false;
  bool _receiving = false;
  SendSession? _sendSession;
  String? _statusText;

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
    final sending = _sendSession != null;
    return Scaffold(
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(18, 18, 18, 42),
          children: [
            const PageTitle(
              icon: Icons.backup_outlined,
              title: '数据备份',
              subtitle: '两台手机同一局域网，扫码或输入配对码即可互传',
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _CircleActionButton(
                    title: '发送',
                    subtitle: sending ? '正在等待接收' : '生成二维码',
                    icon: Icons.upload_rounded,
                    active: sending,
                    busy: _startingSend,
                    onTap: _startingSend ? null : _startSend,
                  ),
                ),
                const SizedBox(width: 14),
                Expanded(
                  child: _CircleActionButton(
                    title: '接收',
                    subtitle: '扫码 / 配对码',
                    icon: Icons.download_rounded,
                    active: _receiving,
                    busy: _receiving,
                    onTap: _receiving ? null : _showReceiveOptions,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            if (_sendSession != null) _buildSendPanel(_sendSession!),
            if (_statusText != null) ...[
              const SizedBox(height: 12),
              _StatusCard(text: _statusText!),
            ],
            const SizedBox(height: 16),
            _UtilityPanel(
              backupFileName: _backupDraft.fileName,
              creatingBackup: _creatingBackup,
              resettingDatabase: _resettingDatabase,
              onCreateBackup: _creatingBackup ? null : _createBackup,
              onResetDatabase:
                  _resettingDatabase ? null : _confirmAndResetDatabase,
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildSendPanel(SendSession session) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(22),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          const Text(
            '让另一台手机扫码接收',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 6),
          const Text(
            '或者在接收端输入下面的6位配对码',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 13,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: Colors.white,
              borderRadius: BorderRadius.circular(20),
              border: Border.all(color: const Color(0xFFE5E7EB)),
            ),
            child: QrImageView(
              data: session.connectionCode,
              size: 210,
              backgroundColor: Colors.white,
            ),
          ),
          const SizedBox(height: 14),
          Text(
            session.pairingCode,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 5,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              OutlinedButton.icon(
                onPressed: _copyConnectionCode,
                icon: const Icon(Icons.copy_rounded),
                label: const Text('复制二维码内容'),
              ),
              FilledButton.tonalIcon(
                onPressed: _stopSend,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('停止发送'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Future<void> _startSend() async {
    if (_sendSession != null) {
      return;
    }
    setState(() {
      _startingSend = true;
      _statusText = '正在生成发送二维码...';
    });
    try {
      final session = await _lanTransferService.startSendSession();
      if (!mounted) {
        return;
      }
      setState(() {
        _sendSession = session;
        _statusText = '发送已开启，请保持此页面不退出。';
      });
    } on BackupSourceMissingException {
      _showSnack('当前数据库不存在，无法发送');
      if (mounted) {
        setState(() => _statusText = '未找到数据库文件');
      }
    } catch (_) {
      _showSnack('启动发送失败，请确认已连接局域网');
      if (mounted) {
        setState(() => _statusText = '发送启动失败');
      }
    } finally {
      if (mounted) {
        setState(() => _startingSend = false);
      }
    }
  }

  Future<void> _stopSend() async {
    await _lanTransferService.stopSendSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _sendSession = null;
      _statusText = '发送已停止';
    });
  }

  Future<void> _showReceiveOptions() async {
    final action = await showModalBottomSheet<String>(
      context: context,
      showDragHandle: true,
      builder: (context) => SafeArea(
        child: Padding(
          padding: const EdgeInsets.fromLTRB(18, 6, 18, 22),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              const Text(
                '接收数据',
                style: TextStyle(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 12),
              FilledButton.icon(
                onPressed: () => Navigator.of(context).pop('scan'),
                icon: const Icon(Icons.qr_code_scanner_rounded),
                label: const Text('扫码接收'),
              ),
              const SizedBox(height: 10),
              OutlinedButton.icon(
                onPressed: () => Navigator.of(context).pop('code'),
                icon: const Icon(Icons.pin_rounded),
                label: const Text('输入6位配对码'),
              ),
            ],
          ),
        ),
      ),
    );
    if (!mounted || action == null) {
      return;
    }
    if (action == 'scan') {
      await _scanAndReceive();
    } else if (action == 'code') {
      await _receiveByCodeInput();
    }
  }

  Future<void> _scanAndReceive() async {
    final content = await Navigator.of(context).push<String>(
      MaterialPageRoute(
        builder: (_) => const ScannerScreen(title: '扫描备份二维码'),
      ),
    );
    if (!mounted || content == null || content.trim().isEmpty) {
      return;
    }
    await _receiveWithPreparation(
      () => _lanTransferService.receiveFromConnectionCode(content.trim()),
      progressText: '正在扫码连接发送端...',
    );
  }

  Future<void> _receiveByCodeInput() async {
    final controller = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('输入6位配对码'),
        content: TextField(
          autofocus: true,
          controller: controller,
          keyboardType: TextInputType.number,
          maxLength: 6,
          decoration: const InputDecoration(
            hintText: '例如 456789',
            counterText: '',
          ),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(controller.text),
            child: const Text('开始接收'),
          ),
        ],
      ),
    );
    controller.dispose();
    final trimmed = code?.trim() ?? '';
    if (!mounted || trimmed.isEmpty) {
      return;
    }
    if (trimmed.length != 6) {
      _showSnack('请输入6位配对码');
      return;
    }
    await _receiveWithPreparation(
      () => _lanTransferService.receiveByPairingCode(trimmed),
      progressText: '正在局域网内查找发送端...',
    );
  }

  Future<void> _receiveWithPreparation(
    Future<ReceiveResult> Function() receive, {
    required String progressText,
  }) async {
    setState(() {
      _receiving = true;
      _statusText = progressText;
    });
    var prepared = false;
    try {
      await widget.onPrepareImport?.call();
      prepared = true;
      setState(() => _statusText = '正在接收并导入数据库...');
      final result = await receive();
      await widget.onImportCompleted?.call();
      prepared = false;
      if (!mounted) {
        return;
      }
      setState(() => _statusText = '接收完成，已自动备份：${result.backupFileName}');
      _showSnack('接收完成');
    } on ConnectionCodeParseException {
      _showSnack('二维码无效');
      if (mounted) {
        setState(() => _statusText = '二维码无效');
      }
    } on SenderUnavailableException {
      _showSnack('未找到发送端，请确认两台手机在同一局域网');
      if (mounted) {
        setState(() => _statusText = '未找到发送端');
      }
    } on PairingCodeRejectedException {
      _showSnack('配对码错误');
      if (mounted) {
        setState(() => _statusText = '配对码错误');
      }
    } on InvalidSenderManifestException {
      _showSnack('发送数据无效');
    } on DatabaseDownloadFailedException {
      _showSnack('下载数据库失败，请重试');
    } on ImportSourceMissingException {
      _showSnack('接收文件不存在');
    } on InvalidImportDatabaseException {
      _showSnack('接收文件不是有效数据库');
    } on BackupSourceMissingException {
      _showSnack('当前数据库不存在，无法导入');
    } on ImportDatabaseFailedException {
      _showSnack('导入失败，请关闭占用数据库的页面后重试');
    } catch (_) {
      _showSnack('接收失败，请重试');
    } finally {
      if (prepared) {
        try {
          await widget.onImportCompleted?.call();
        } catch (_) {
          _showSnack('数据库恢复失败，请重启应用后再试');
        }
      }
      if (mounted) {
        setState(() => _receiving = false);
      }
    }
  }

  Future<void> _createBackup() async {
    setState(() => _creatingBackup = true);
    try {
      final result = await _backupService.createLocalBackup();
      if (!mounted) {
        return;
      }
      setState(() => _backupDraft = _backupService.createLocalBackupDraft());
      _showSnack('备份完成：${result.fileName}');
    } on BackupSourceMissingException {
      _showSnack('未找到数据库文件，无法生成备份');
    } catch (_) {
      _showSnack('备份失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _creatingBackup = false);
      }
    }
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
      _showSnack('数据库已重置，备份：${result.backupFileName}');
      Navigator.of(context).pop();
    } on BackupSourceMissingException {
      _showSnack('未找到数据库文件，无法重置');
    } catch (_) {
      _showSnack('重置失败，请稍后重试');
    } finally {
      if (prepared) {
        await widget.onImportCompleted?.call();
      }
      if (mounted) {
        setState(() => _resettingDatabase = false);
      }
    }
  }

  Future<void> _copyConnectionCode() async {
    final session = _sendSession;
    if (session == null) {
      return;
    }
    await Clipboard.setData(ClipboardData(text: session.connectionCode));
    _showSnack('二维码内容已复制');
  }

  void _showSnack(String text) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }
}

class _CircleActionButton extends StatelessWidget {
  const _CircleActionButton({
    required this.title,
    required this.subtitle,
    required this.icon,
    required this.active,
    required this.busy,
    required this.onTap,
  });

  final String title;
  final String subtitle;
  final IconData icon;
  final bool active;
  final bool busy;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final fill = active ? AppTheme.primary : Colors.white;
    final foreground = active ? Colors.white : AppTheme.textPrimary;
    return InkWell(
      borderRadius: BorderRadius.circular(999),
      onTap: onTap,
      child: AspectRatio(
        aspectRatio: 1,
        child: Container(
          decoration: BoxDecoration(
            color: fill,
            shape: BoxShape.circle,
            boxShadow: const [
              BoxShadow(
                color: Color(0x14000000),
                blurRadius: 18,
                offset: Offset(0, 8),
              ),
            ],
            border: Border.all(
              color: active ? AppTheme.primary : const Color(0xFFE5E7EB),
            ),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              busy
                  ? SizedBox(
                      width: 28,
                      height: 28,
                      child: CircularProgressIndicator(
                        strokeWidth: 3,
                        color: active ? Colors.white : AppTheme.primary,
                      ),
                    )
                  : Icon(icon,
                      size: 32,
                      color: active ? Colors.white : AppTheme.primary),
              const SizedBox(height: 10),
              Text(
                title,
                style: TextStyle(
                  color: foreground,
                  fontSize: 22,
                  fontWeight: FontWeight.w900,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                subtitle,
                textAlign: TextAlign.center,
                style: TextStyle(
                  color:
                      active ? const Color(0xFFEAF2FF) : AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StatusCard extends StatelessWidget {
  const _StatusCard({required this.text});

  final String text;

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Text(
        text,
        style: const TextStyle(
          color: AppTheme.primary,
          fontSize: 13,
          fontWeight: FontWeight.w800,
        ),
      ),
    );
  }
}

class _UtilityPanel extends StatelessWidget {
  const _UtilityPanel({
    required this.backupFileName,
    required this.creatingBackup,
    required this.resettingDatabase,
    required this.onCreateBackup,
    required this.onResetDatabase,
  });

  final String backupFileName;
  final bool creatingBackup;
  final bool resettingDatabase;
  final VoidCallback? onCreateBackup;
  final VoidCallback? onResetDatabase;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Text(
            '本地备份',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            backupFileName,
            style: const TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Wrap(
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.tonal(
                onPressed: onCreateBackup,
                child: Text(creatingBackup ? '生成中...' : '生成备份'),
              ),
              OutlinedButton(
                onPressed: onResetDatabase,
                child: Text(resettingDatabase ? '重置中...' : '重置数据库'),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

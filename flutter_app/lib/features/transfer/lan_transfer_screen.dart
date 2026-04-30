import 'dart:async';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qrscan_flutter/features/qr/scanner_screen.dart';
import 'package:qrscan_flutter/features/transfer/backup_service.dart';
import 'package:qrscan_flutter/features/transfer/lan_transfer_service.dart';
import 'package:qrscan_flutter/shared/theme/app_theme.dart';
import 'package:qrscan_flutter/shared/widgets/page_title.dart';
import 'package:share_plus/share_plus.dart';

typedef DatabaseReloadCallback = Future<void> Function({
  bool seedIfEmpty,
});
typedef BackupShareCallback = Future<void> Function(
  String path,
  String fileName,
);
typedef BackupImportPicker = Future<String?> Function();

class LanTransferScreen extends StatefulWidget {
  const LanTransferScreen({
    super.key,
    this.databasePath = 'jiemei.sqlite',
    this.initialImportPath,
    this.backupService,
    this.lanTransferService,
    this.onPrepareImport,
    this.onImportCompleted,
    this.shareFile,
    this.pickImportFile,
  });

  final String databasePath;
  final String? initialImportPath;
  final BackupService? backupService;
  final LanTransferService? lanTransferService;
  final Future<void> Function()? onPrepareImport;
  final DatabaseReloadCallback? onImportCompleted;
  final BackupShareCallback? shareFile;
  final BackupImportPicker? pickImportFile;

  @override
  State<LanTransferScreen> createState() => _LanTransferScreenState();
}

class _LanTransferScreenState extends State<LanTransferScreen> {
  late final BackupService _backupService;
  late final LanTransferService _lanTransferService;

  bool _creatingBackup = false;
  bool _resettingDatabase = false;
  bool _startingSend = false;
  bool _receiving = false;
  bool _loadingBackups = true;
  bool _cleaningBackups = false;
  bool _applyingSchedule = false;
  bool _sharingBackup = false;
  bool _importingSharedBackup = false;
  String? _restoringBackupPath;
  String? _sharingBackupPath;
  List<BackupSnapshot> _backupSnapshots = const [];
  BackupSchedule _backupSchedule = BackupSchedule.off;
  SendSession? _sendSession;
  String? _statusText;
  _ReceiveStage _receiveStage = _ReceiveStage.idle;
  Timer? _sendSessionMonitor;
  StreamSubscription<TransferRequest>? _transferRequestSubscription;
  bool _showingTransferRequest = false;

  @override
  void initState() {
    super.initState();
    _backupService = widget.backupService ??
        BackupService(databaseFileName: widget.databasePath);
    _lanTransferService = widget.lanTransferService ??
        LanTransferService(backupService: _backupService);
    _bootstrapBackupPanel();
    final initialImportPath = widget.initialImportPath?.trim();
    if (initialImportPath != null && initialImportPath.isNotEmpty) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (!mounted) {
          return;
        }
        unawaited(_importSharedBackupWithConfirm(initialImportPath));
      });
    }
  }

  @override
  void dispose() {
    _sendSessionMonitor?.cancel();
    _transferRequestSubscription?.cancel();
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
            ),
            const SizedBox(height: 18),
            Row(
              children: [
                Expanded(
                  child: _CircleActionButton(
                    title: '发送',
                    subtitle: sending ? '发送中' : '给其他设备',
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
                    subtitle: '附近设备',
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
            const SizedBox(height: 12),
            _TransferFeedbackCard(
              statusText: _statusText,
              stage: _receiveStage,
              sending: sending,
              receiving: _receiving,
            ),
            const SizedBox(height: 16),
            _UtilityPanel(
              creatingBackup: _creatingBackup,
              resettingDatabase: _resettingDatabase,
              loadingBackups: _loadingBackups,
              applyingSchedule: _applyingSchedule,
              backupSchedule: _backupSchedule,
              backupSnapshots: _backupSnapshots,
              restoringBackupPath: _restoringBackupPath,
              sharingBackupPath: _sharingBackupPath,
              onCreateBackup: _creatingBackup ? null : _createBackup,
              onImportSharedBackup:
                  _importingSharedBackup ? null : _pickAndImportSharedBackup,
              onResetDatabase:
                  _resettingDatabase ? null : _confirmAndResetDatabase,
              onSelectSchedule: _selectBackupSchedule,
              onRestoreBackup: _confirmAndRestoreBackup,
              onShareBackup: _shareBackupSnapshot,
              onDeleteBackup: _confirmAndDeleteBackup,
              onCleanupBackups: _confirmAndCleanupBackups,
              cleaningBackups: _cleaningBackups,
              sharingBackup: _sharingBackup,
              importingSharedBackup: _importingSharedBackup,
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
          Text(
            session.pairingCode,
            style: const TextStyle(
              color: AppTheme.primary,
              fontSize: 34,
              fontWeight: FontWeight.w900,
              letterSpacing: 8,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            alignment: WrapAlignment.center,
            spacing: 10,
            runSpacing: 8,
            children: [
              FilledButton.tonalIcon(
                onPressed: _stopSend,
                icon: const Icon(Icons.stop_circle_outlined),
                label: const Text('停止'),
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
      _receiveStage = _ReceiveStage.idle;
      _statusText = '正在生成配对会话...';
    });
    try {
      final session = await _lanTransferService.startSendSession();
      if (!mounted) {
        return;
      }
      setState(() {
        _sendSession = session;
        _statusText = '发送已开启，等待附近设备连接。';
      });
      _listenForTransferRequests();
      _startSendSessionMonitor();
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
    _sendSessionMonitor?.cancel();
    _sendSessionMonitor = null;
    await _transferRequestSubscription?.cancel();
    _transferRequestSubscription = null;
    await _lanTransferService.stopSendSession();
    if (!mounted) {
      return;
    }
    setState(() {
      _sendSession = null;
      _statusText = null;
    });
  }

  void _startSendSessionMonitor() {
    _sendSessionMonitor?.cancel();
    _sendSessionMonitor =
        Timer.periodic(const Duration(milliseconds: 350), (timer) {
      if (!mounted) {
        timer.cancel();
        return;
      }
      if (_sendSession != null && !_lanTransferService.hasActiveSendSession) {
        timer.cancel();
        _sendSessionMonitor = null;
        setState(() {
          _sendSession = null;
          _statusText = '发送完成，配对已自动结束';
        });
      }
    });
  }

  void _listenForTransferRequests() {
    _transferRequestSubscription?.cancel();
    _transferRequestSubscription =
        _lanTransferService.transferRequests.listen((request) {
      unawaited(_handleTransferRequest(request));
    });
  }

  Future<void> _handleTransferRequest(TransferRequest request) async {
    if (!mounted || _showingTransferRequest) {
      return;
    }
    _showingTransferRequest = true;
    final approved = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        title: const Text('接收请求'),
        content: Text('${request.receiverName} 请求接收当前数据库，是否允许？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('拒绝'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('允许'),
          ),
        ],
      ),
    );
    _showingTransferRequest = false;
    if (approved == true) {
      await _lanTransferService.approveTransferRequest(request.id);
      if (mounted) {
        setState(() => _statusText = '已允许 ${request.receiverName} 接收数据');
      }
    } else {
      await _lanTransferService.rejectTransferRequest(request.id);
      if (mounted) {
        setState(() => _statusText = '已拒绝 ${request.receiverName} 的请求');
      }
    }
  }

  Future<void> _showReceiveOptions() async {
    setState(() {
      _receiving = true;
      _receiveStage = _ReceiveStage.pairing;
      _statusText = '正在搜索附近设备...';
    });
    List<DiscoveryAnnouncement> senders = const [];
    try {
      senders = await _lanTransferService.discoverSenders(
        timeout: const Duration(seconds: 2),
      );
    } catch (_) {
      senders = const [];
    } finally {
      if (mounted) {
        setState(() {
          _receiving = false;
          _receiveStage = _ReceiveStage.idle;
          _statusText =
              senders.isEmpty ? '未发现附近设备' : '发现 ${senders.length} 台附近设备';
        });
      }
    }
    if (!mounted) {
      return;
    }

    final choice = await showModalBottomSheet<_ReceiveChoice>(
      context: context,
      showDragHandle: true,
      builder: (context) => _ReceiveOptionsSheet(
        senders: senders,
      ),
    );
    if (!mounted || choice == null) {
      return;
    }
    if (choice.action == _ReceiveAction.nearby && choice.sender != null) {
      await _receiveFromNearby(choice.sender!);
    } else if (choice.action == _ReceiveAction.scan) {
      await _scanAndReceive();
    } else if (choice.action == _ReceiveAction.code) {
      await _receiveByCodeInput();
    }
  }

  Future<void> _receiveFromNearby(DiscoveryAnnouncement sender) async {
    await _receiveWithPreparation(
      () => _lanTransferService.receiveFromDiscoveredSender(sender),
      progressText: '正在连接 ${sender.deviceName}...',
    );
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
    final code = await showDialog<String>(
      context: context,
      barrierDismissible: false,
      builder: (context) => const _PairingCodeDialog(),
    );
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
      progressText: '正在校验配对码并查找发送端...',
    );
  }

  Future<void> _receiveWithPreparation(
    Future<ReceiveResult> Function() receive, {
    required String progressText,
  }) async {
    setState(() {
      _receiving = true;
      _receiveStage = _ReceiveStage.pairing;
      _statusText = progressText;
    });
    var prepared = false;
    try {
      await widget.onPrepareImport?.call();
      prepared = true;
      setState(() {
        _receiveStage = _ReceiveStage.transferring;
        _statusText = '配对成功，正在接收并导入数据库...';
      });
      final result = await receive();
      await widget.onImportCompleted?.call(seedIfEmpty: false);
      prepared = false;
      if (!mounted) {
        return;
      }
      await _loadBackupSnapshots();
      setState(() {
        _receiveStage = _ReceiveStage.success;
        _statusText = '接收完成，已自动备份：${result.backupFileName}';
        _sendSession = null;
      });
      _showSnack('接收完成');
    } on ConnectionCodeParseException {
      _showSnack('二维码无效');
      if (mounted) {
        setState(() {
          _receiveStage = _ReceiveStage.error;
          _statusText = '二维码无效';
        });
      }
    } on SenderUnavailableException {
      _showSnack('未找到发送端，请确认两台手机在同一局域网');
      if (mounted) {
        setState(() {
          _receiveStage = _ReceiveStage.error;
          _statusText = '未找到发送端';
        });
      }
    } on PairingCodeRejectedException {
      _showSnack('配对码错误');
      if (mounted) {
        setState(() {
          _receiveStage = _ReceiveStage.error;
          _statusText = '配对码错误';
        });
      }
    } on TransferRequestRejectedException {
      _showSnack('对方已拒绝');
      if (mounted) {
        setState(() {
          _receiveStage = _ReceiveStage.error;
          _statusText = '对方已拒绝';
        });
      }
    } on TransferRequestExpiredException {
      _showSnack('对方确认超时');
      if (mounted) {
        setState(() {
          _receiveStage = _ReceiveStage.error;
          _statusText = '对方确认超时';
        });
      }
    } on InvalidSenderManifestException {
      _showSnack('发送数据无效');
      if (mounted) {
        setState(() => _receiveStage = _ReceiveStage.error);
      }
    } on DatabaseDownloadFailedException {
      _showSnack('下载数据库失败，请重试');
      if (mounted) {
        setState(() => _receiveStage = _ReceiveStage.error);
      }
    } on ImportSourceMissingException {
      _showSnack('接收文件不存在');
      if (mounted) {
        setState(() => _receiveStage = _ReceiveStage.error);
      }
    } on InvalidImportDatabaseException {
      _showSnack('接收文件不是有效数据库');
      if (mounted) {
        setState(() => _receiveStage = _ReceiveStage.error);
      }
    } on BackupSourceMissingException {
      _showSnack('当前数据库不存在，无法导入');
      if (mounted) {
        setState(() => _receiveStage = _ReceiveStage.error);
      }
    } on ImportDatabaseFailedException {
      _showSnack('导入失败，请关闭占用数据库的页面后重试');
      if (mounted) {
        setState(() => _receiveStage = _ReceiveStage.error);
      }
    } catch (_) {
      _showSnack('接收失败，请重试');
      if (mounted) {
        setState(() => _receiveStage = _ReceiveStage.error);
      }
    } finally {
      if (prepared) {
        try {
          await widget.onImportCompleted?.call(seedIfEmpty: false);
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
      setState(() {});
      await _loadBackupSnapshots();
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

  Future<void> _shareBackupSnapshot(BackupSnapshot snapshot) async {
    await _createAndSharePackage(snapshotPath: snapshot.filePath);
  }

  Future<void> _createAndSharePackage({required String? snapshotPath}) async {
    setState(() {
      _sharingBackup = true;
      _sharingBackupPath = snapshotPath;
      _statusText = '正在生成分享备份包...';
    });
    try {
      final package =
          await _backupService.createSharePackage(snapshotPath: snapshotPath);
      await _shareFile(package.filePath, package.fileName);
      if (!mounted) {
        return;
      }
      setState(() => _statusText = '分享面板已打开：${package.fileName}');
      _showSnack('请选择微信、QQ 或文件助手发送备份');
    } on BackupSourceMissingException {
      _showSnack('未找到备份文件，无法分享');
      if (mounted) {
        setState(() => _statusText = '分享失败：未找到备份文件');
      }
    } catch (_) {
      _showSnack('分享失败，请稍后重试');
      if (mounted) {
        setState(() => _statusText = '分享失败');
      }
    } finally {
      if (mounted) {
        setState(() {
          _sharingBackup = false;
          _sharingBackupPath = null;
        });
      }
    }
  }

  Future<void> _pickAndImportSharedBackup() async {
    final path = await _pickImportFile();
    if (!mounted || path == null || path.trim().isEmpty) {
      return;
    }
    await _importSharedBackupWithConfirm(path.trim());
  }

  Future<void> _importSharedBackupWithConfirm(String path) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('导入备份文件'),
        content: const Text(
          '导入会覆盖当前业务数据。导入前会自动备份当前数据，是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认导入'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _importingSharedBackup = true;
      _statusText = '正在导入分享备份...';
      _receiveStage = _ReceiveStage.transferring;
    });
    var prepared = false;
    try {
      await widget.onPrepareImport?.call();
      prepared = true;
      final result = await _backupService.importSharedBackupPackage(path);
      await widget.onImportCompleted?.call(seedIfEmpty: false);
      prepared = false;
      if (!mounted) {
        return;
      }
      await _loadBackupSnapshots();
      setState(() {
        _receiveStage = _ReceiveStage.success;
        _statusText = '导入完成，已自动备份当前数据：${result.backupFileName}';
      });
      _showSnack('备份文件已导入');
    } on ImportSourceMissingException {
      _showSnack('未找到选择的备份文件');
      if (mounted) {
        setState(() => _receiveStage = _ReceiveStage.error);
      }
    } on InvalidImportDatabaseException {
      _showSnack('备份文件无效，无法导入');
      if (mounted) {
        setState(() => _receiveStage = _ReceiveStage.error);
      }
    } on BackupSourceMissingException {
      _showSnack('当前数据库不存在，无法导入');
      if (mounted) {
        setState(() => _receiveStage = _ReceiveStage.error);
      }
    } on ImportDatabaseFailedException {
      _showSnack('导入失败，请关闭占用数据库的页面后重试');
      if (mounted) {
        setState(() => _receiveStage = _ReceiveStage.error);
      }
    } catch (_) {
      _showSnack('导入失败，请稍后重试');
      if (mounted) {
        setState(() => _receiveStage = _ReceiveStage.error);
      }
    } finally {
      if (prepared) {
        try {
          await widget.onImportCompleted?.call(seedIfEmpty: false);
        } catch (_) {
          _showSnack('数据库恢复失败，请重启应用后再试');
        }
      }
      if (mounted) {
        setState(() => _importingSharedBackup = false);
      }
    }
  }

  Future<void> _shareFile(String path, String fileName) async {
    final override = widget.shareFile;
    if (override != null) {
      await override(path, fileName);
      return;
    }
    await SharePlus.instance.share(
      ShareParams(
        title: '分享洁美备份',
        text: '洁美备份快照：$fileName',
        files: [
          XFile(
            path,
            mimeType: 'application/octet-stream',
            name: fileName,
          ),
        ],
        fileNameOverrides: [fileName],
      ),
    );
  }

  Future<String?> _pickImportFile() async {
    final override = widget.pickImportFile;
    if (override != null) {
      return override();
    }
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['jiemei', 'sqlite', 'zip'],
      allowMultiple: false,
    );
    return result?.files.single.path;
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
      await widget.onImportCompleted?.call(seedIfEmpty: false);
      prepared = false;
      if (!mounted) {
        return;
      }
      await _loadBackupSnapshots();
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
        await widget.onImportCompleted?.call(seedIfEmpty: false);
      }
      if (mounted) {
        setState(() => _resettingDatabase = false);
      }
    }
  }

  Future<void> _bootstrapBackupPanel() async {
    _backupSchedule = await _backupService.getBackupSchedule();
    final autoBackup = await _backupService.runAutoBackupIfDue();
    if (autoBackup != null) {
      _statusText = '已自动生成备份快照';
    }
    await _loadBackupSnapshots();
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _loadBackupSnapshots() async {
    if (mounted) {
      setState(() => _loadingBackups = true);
    }
    try {
      final snapshots = await _backupService.listLocalBackups();
      if (!mounted) {
        return;
      }
      setState(() {
        _backupSnapshots = snapshots;
        _loadingBackups = false;
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _backupSnapshots = const [];
        _loadingBackups = false;
      });
    }
  }

  Future<void> _selectBackupSchedule(BackupSchedule schedule) async {
    if (_backupSchedule == schedule) {
      return;
    }
    setState(() => _applyingSchedule = true);
    try {
      await _backupService.setBackupSchedule(schedule);
      final autoBackup = await _backupService.runAutoBackupIfDue();
      if (!mounted) {
        return;
      }
      setState(() {
        _backupSchedule = schedule;
        if (autoBackup != null) {
          _statusText = '策略已更新，并自动生成了备份快照';
        }
      });
      await _loadBackupSnapshots();
      _showSnack(
        switch (schedule) {
          BackupSchedule.off => '自动备份已关闭',
          BackupSchedule.daily => '自动备份已设置为每天一次',
          BackupSchedule.weekly => '自动备份已设置为每周一次',
        },
      );
    } catch (_) {
      _showSnack('自动备份策略保存失败');
    } finally {
      if (mounted) {
        setState(() => _applyingSchedule = false);
      }
    }
  }

  Future<void> _confirmAndRestoreBackup(BackupSnapshot snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('恢复备份快照'),
        content: Text(
          '将当前业务数据恢复到 ${_formatSnapshotTime(snapshot.createdAt)} 的备份。'
          '恢复前会自动备份当前数据，是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认恢复'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _restoringBackupPath = snapshot.filePath;
      _statusText = '正在恢复备份快照...';
    });
    var prepared = false;
    try {
      await widget.onPrepareImport?.call();
      prepared = true;
      final result =
          await _backupService.restoreBackupSnapshot(snapshot.filePath);
      await widget.onImportCompleted?.call(seedIfEmpty: false);
      prepared = false;
      if (!mounted) {
        return;
      }
      await _loadBackupSnapshots();
      setState(() => _statusText = '恢复完成，已自动备份当前数据：${result.backupFileName}');
      _showSnack('备份已恢复');
    } on InvalidImportDatabaseException {
      _showSnack('备份文件无效，无法恢复');
    } on BackupSourceMissingException {
      _showSnack('当前数据库不存在，无法恢复');
    } on ImportDatabaseFailedException {
      _showSnack('恢复失败，请关闭占用数据库的页面后重试');
    } catch (_) {
      _showSnack('恢复失败，请稍后重试');
    } finally {
      if (prepared) {
        try {
          await widget.onImportCompleted?.call(seedIfEmpty: false);
        } catch (_) {
          _showSnack('数据库恢复失败，请重启应用后再试');
        }
      }
      if (mounted) {
        setState(() => _restoringBackupPath = null);
      }
    }
  }

  Future<void> _confirmAndDeleteBackup(BackupSnapshot snapshot) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除备份快照'),
        content: Text('删除 ${_formatSnapshotTime(snapshot.createdAt)} 的快照？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    try {
      await _backupService.deleteBackupSnapshot(snapshot.filePath);
      await _loadBackupSnapshots();
      _showSnack('备份快照已删除');
    } catch (_) {
      _showSnack('删除失败，请稍后重试');
    }
  }

  Future<void> _confirmAndCleanupBackups() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('清理旧备份'),
        content: const Text('将仅保留最近 30 个快照，继续？'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('清理'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }
    setState(() => _cleaningBackups = true);
    try {
      final deleted =
          await _backupService.cleanupBackupsByCount(keepLatest: 30);
      await _loadBackupSnapshots();
      _showSnack(deleted == 0 ? '无需清理' : '已清理 $deleted 个旧备份');
    } catch (_) {
      _showSnack('清理失败，请稍后重试');
    } finally {
      if (mounted) {
        setState(() => _cleaningBackups = false);
      }
    }
  }

  void _showSnack(String text) {
    if (!mounted) {
      return;
    }
    final messenger = ScaffoldMessenger.of(context)..clearSnackBars();
    messenger.showSnackBar(SnackBar(content: Text(text)));
  }
}

class _PairingCodeDialog extends StatefulWidget {
  const _PairingCodeDialog();

  @override
  State<_PairingCodeDialog> createState() => _PairingCodeDialogState();
}

class _PairingCodeDialogState extends State<_PairingCodeDialog> {
  final List<TextEditingController> _controllers = List.generate(
    6,
    (_) => TextEditingController(),
  );
  final List<FocusNode> _focusNodes = List.generate(6, (_) => FocusNode());
  bool _submitting = false;

  @override
  void dispose() {
    for (final controller in _controllers) {
      controller.dispose();
    }
    for (final focusNode in _focusNodes) {
      focusNode.dispose();
    }
    super.dispose();
  }

  void _onDigitChanged(int index, String value) {
    if (_submitting) {
      return;
    }
    final normalized = value.isEmpty ? '' : value[value.length - 1];
    _controllers[index].text = normalized;
    _controllers[index].selection = TextSelection.collapsed(
      offset: _controllers[index].text.length,
    );

    if (normalized.isNotEmpty && index < 5) {
      _focusNodes[index + 1].requestFocus();
    }

    final code = _controllers.map((item) => item.text).join();
    if (code.length == 6 && !_controllers.any((item) => item.text.isEmpty)) {
      _submitting = true;
      Navigator.of(context).pop(code);
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('输入6位配对码'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          const Text(
            '输入完成后将自动校验并开始配对',
            style: TextStyle(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: List.generate(
              6,
              (index) => SizedBox(
                width: 38,
                child: TextField(
                  autofocus: index == 0,
                  controller: _controllers[index],
                  focusNode: _focusNodes[index],
                  textAlign: TextAlign.center,
                  keyboardType: TextInputType.number,
                  textInputAction:
                      index == 5 ? TextInputAction.done : TextInputAction.next,
                  maxLength: 1,
                  inputFormatters: [
                    FilteringTextInputFormatter.digitsOnly,
                  ],
                  style: const TextStyle(
                    fontSize: 20,
                    fontWeight: FontWeight.w900,
                  ),
                  decoration: const InputDecoration(
                    counterText: '',
                    contentPadding: EdgeInsets.symmetric(vertical: 10),
                    border: OutlineInputBorder(),
                  ),
                  onChanged: (value) => _onDigitChanged(index, value),
                  onTap: () =>
                      _controllers[index].selection = TextSelection.collapsed(
                    offset: _controllers[index].text.length,
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
      ],
    );
  }
}

enum _ReceiveAction {
  nearby,
  scan,
  code,
}

class _ReceiveChoice {
  const _ReceiveChoice(this.action, {this.sender});

  final _ReceiveAction action;
  final DiscoveryAnnouncement? sender;
}

class _ReceiveOptionsSheet extends StatelessWidget {
  const _ReceiveOptionsSheet({
    required this.senders,
  });

  final List<DiscoveryAnnouncement> senders;

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Padding(
        padding: const EdgeInsets.fromLTRB(18, 6, 18, 22),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            const Text(
              '发现附近设备',
              style: TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 20,
                fontWeight: FontWeight.w900,
              ),
            ),
            const SizedBox(height: 12),
            if (senders.isEmpty)
              Container(
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  color: const Color(0xFFF8FAFC),
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(color: const Color(0xFFE5E7EB)),
                ),
                child: const Text(
                  '未发现正在发送的设备',
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              )
            else
              ...senders.map(
                (sender) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: ListTile(
                    shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(14),
                      side: const BorderSide(color: Color(0xFFE5E7EB)),
                    ),
                    leading: const Icon(
                      Icons.devices_rounded,
                      color: AppTheme.primary,
                    ),
                    title: Text(
                      sender.deviceName,
                      style: const TextStyle(
                        color: AppTheme.textPrimary,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    subtitle: Text(sender.baseUri.host),
                    trailing: const Icon(Icons.chevron_right_rounded),
                    onTap: () => Navigator.of(context).pop(
                      _ReceiveChoice(_ReceiveAction.nearby, sender: sender),
                    ),
                  ),
                ),
              ),
            const SizedBox(height: 8),
            FilledButton.icon(
              onPressed: () => Navigator.of(context).pop(
                const _ReceiveChoice(_ReceiveAction.scan),
              ),
              icon: const Icon(Icons.qr_code_scanner_rounded),
              label: const Text('扫码接收'),
            ),
            const SizedBox(height: 10),
            OutlinedButton.icon(
              onPressed: () => Navigator.of(context).pop(
                const _ReceiveChoice(_ReceiveAction.code),
              ),
              icon: const Icon(Icons.pin_rounded),
              label: const Text('输入6位配对码'),
            ),
          ],
        ),
      ),
    );
  }
}

enum _ReceiveStage {
  idle,
  pairing,
  transferring,
  success,
  error,
}

class _TransferFeedbackCard extends StatelessWidget {
  const _TransferFeedbackCard({
    required this.statusText,
    required this.stage,
    required this.sending,
    required this.receiving,
  });

  final String? statusText;
  final _ReceiveStage stage;
  final bool sending;
  final bool receiving;

  @override
  Widget build(BuildContext context) {
    if (statusText == null && !sending && !receiving) {
      return const SizedBox.shrink();
    }
    final icon = switch (stage) {
      _ReceiveStage.pairing => Icons.sync_rounded,
      _ReceiveStage.transferring => Icons.cloud_download_rounded,
      _ReceiveStage.success => Icons.check_circle_rounded,
      _ReceiveStage.error => Icons.error_outline_rounded,
      _ReceiveStage.idle =>
        sending ? Icons.wifi_tethering_rounded : Icons.info_outline_rounded,
    };
    final color = switch (stage) {
      _ReceiveStage.success => const Color(0xFF0E9F6E),
      _ReceiveStage.error => const Color(0xFFDC2626),
      _ReceiveStage.pairing || _ReceiveStage.transferring => AppTheme.primary,
      _ReceiveStage.idle => AppTheme.primary,
    };
    final showProgress = stage == _ReceiveStage.pairing ||
        stage == _ReceiveStage.transferring ||
        receiving ||
        sending;

    return AnimatedContainer(
      duration: const Duration(milliseconds: 240),
      curve: Curves.easeOutCubic,
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      decoration: BoxDecoration(
        color: const Color(0xFFEAF7FF),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Icon(icon, size: 18, color: color),
              const SizedBox(width: 8),
              Expanded(
                child: Text(
                  statusText ?? '等待操作',
                  style: TextStyle(
                    color: color,
                    fontSize: 13,
                    fontWeight: FontWeight.w800,
                  ),
                ),
              ),
            ],
          ),
          if (showProgress) ...[
            const SizedBox(height: 10),
            ClipRRect(
              borderRadius: BorderRadius.circular(99),
              child: const LinearProgressIndicator(minHeight: 4),
            ),
          ],
        ],
      ),
    );
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

class _UtilityPanel extends StatelessWidget {
  const _UtilityPanel({
    required this.creatingBackup,
    required this.resettingDatabase,
    required this.loadingBackups,
    required this.applyingSchedule,
    required this.backupSchedule,
    required this.backupSnapshots,
    required this.restoringBackupPath,
    required this.sharingBackupPath,
    required this.onCreateBackup,
    required this.onImportSharedBackup,
    required this.onResetDatabase,
    required this.onSelectSchedule,
    required this.onRestoreBackup,
    required this.onShareBackup,
    required this.onDeleteBackup,
    required this.onCleanupBackups,
    required this.cleaningBackups,
    required this.sharingBackup,
    required this.importingSharedBackup,
  });

  final bool creatingBackup;
  final bool resettingDatabase;
  final bool loadingBackups;
  final bool applyingSchedule;
  final BackupSchedule backupSchedule;
  final List<BackupSnapshot> backupSnapshots;
  final String? restoringBackupPath;
  final String? sharingBackupPath;
  final VoidCallback? onCreateBackup;
  final VoidCallback? onImportSharedBackup;
  final VoidCallback? onResetDatabase;
  final ValueChanged<BackupSchedule> onSelectSchedule;
  final ValueChanged<BackupSnapshot> onRestoreBackup;
  final ValueChanged<BackupSnapshot> onShareBackup;
  final ValueChanged<BackupSnapshot> onDeleteBackup;
  final VoidCallback onCleanupBackups;
  final bool cleaningBackups;
  final bool sharingBackup;
  final bool importingSharedBackup;

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
          SizedBox(
            width: double.infinity,
            child: FilledButton.icon(
              onPressed: onCreateBackup,
              icon: creatingBackup
                  ? const SizedBox(
                      width: 18,
                      height: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Icon(Icons.add_circle_outline_rounded),
              label: Text(creatingBackup ? '生成中...' : '生成备份'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 14),
                shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14),
                ),
              ),
            ),
          ),
          const SizedBox(height: 12),
          _BackupToolAction(
            icon: Icons.file_open_rounded,
            title: importingSharedBackup ? '导入中...' : '导入备份',
            subtitle: '.jiemei / .sqlite',
            color: AppTheme.primary,
            onTap: onImportSharedBackup,
          ),
          const SizedBox(height: 8),
          _BackupToolAction(
            icon: Icons.auto_delete_outlined,
            title: cleaningBackups ? '清理中...' : '清理备份',
            subtitle: '保留最近30个',
            color: const Color(0xFF0E9F6E),
            onTap: cleaningBackups ? null : onCleanupBackups,
          ),
          const SizedBox(height: 8),
          _BackupToolAction(
            icon: Icons.warning_amber_rounded,
            title: resettingDatabase ? '重置中...' : '重置数据',
            subtitle: '重置前自动备份',
            color: const Color(0xFFDC2626),
            onTap: onResetDatabase,
          ),
          const SizedBox(height: 12),
          const Text(
            '自动备份',
            style: TextStyle(
              color: AppTheme.textPrimary,
              fontSize: 14,
              fontWeight: FontWeight.w900,
            ),
          ),
          const SizedBox(height: 8),
          Wrap(
            spacing: 8,
            runSpacing: 8,
            children: BackupSchedule.values
                .map(
                  (schedule) => ChoiceChip(
                    label: Text(
                      switch (schedule) {
                        BackupSchedule.off => '关闭',
                        BackupSchedule.daily => '每天一次',
                        BackupSchedule.weekly => '每周一次',
                      },
                    ),
                    selected: schedule == backupSchedule,
                    onSelected: applyingSchedule
                        ? null
                        : (_) => onSelectSchedule(schedule),
                  ),
                )
                .toList(),
          ),
          const SizedBox(height: 14),
          const Divider(height: 1),
          const SizedBox(height: 12),
          Row(
            children: [
              const Expanded(
                child: Text(
                  '备份快照',
                  style: TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
              Text(
                loadingBackups ? '读取中' : '${backupSnapshots.length} 个',
                style: const TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          if (loadingBackups)
            const Text(
              '正在读取备份快照...',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            )
          else if (backupSnapshots.isEmpty)
            const Text(
              '暂无备份。生成备份、重置前、接收前都会创建日期快照。',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 12,
                fontWeight: FontWeight.w700,
              ),
            )
          else
            ...backupSnapshots.take(5).map(
                  (snapshot) => _BackupSnapshotTile(
                    snapshot: snapshot,
                    restoring: restoringBackupPath == snapshot.filePath,
                    sharing: sharingBackupPath == snapshot.filePath,
                    onRestore: () => onRestoreBackup(snapshot),
                    onShare: () => onShareBackup(snapshot),
                    onDelete: () => onDeleteBackup(snapshot),
                  ),
                ),
          if (backupSnapshots.length > 5)
            const Padding(
              padding: EdgeInsets.only(top: 8),
              child: Text(
                '仅显示最近5个快照',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

class _BackupToolAction extends StatelessWidget {
  const _BackupToolAction({
    required this.icon,
    required this.title,
    required this.subtitle,
    required this.color,
    required this.onTap,
  });

  final IconData icon;
  final String title;
  final String subtitle;
  final Color color;
  final VoidCallback? onTap;

  @override
  Widget build(BuildContext context) {
    final disabled = onTap == null;
    return Material(
      color: disabled ? const Color(0xFFF8FAFC) : const Color(0xFFFFFFFF),
      borderRadius: BorderRadius.circular(16),
      child: InkWell(
        borderRadius: BorderRadius.circular(16),
        onTap: onTap,
        child: Container(
          constraints: const BoxConstraints(minHeight: 68),
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 11),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(16),
            border: Border.all(
              color: disabled
                  ? const Color(0xFFE5E7EB)
                  : color.withValues(alpha: .2),
            ),
          ),
          child: Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: color.withValues(alpha: disabled ? .06 : .12),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  icon,
                  color: disabled ? const Color(0xFF9CA3AF) : color,
                  size: 22,
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      title,
                      style: TextStyle(
                        color: disabled
                            ? const Color(0xFF9CA3AF)
                            : AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      subtitle,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                        height: 1.25,
                      ),
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 8),
              Icon(
                Icons.chevron_right_rounded,
                color: disabled ? const Color(0xFFCBD5E1) : color,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _BackupSnapshotTile extends StatelessWidget {
  const _BackupSnapshotTile({
    required this.snapshot,
    required this.restoring,
    required this.sharing,
    required this.onRestore,
    required this.onShare,
    required this.onDelete,
  });

  final BackupSnapshot snapshot;
  final bool restoring;
  final bool sharing;
  final VoidCallback onRestore;
  final VoidCallback onShare;
  final VoidCallback onDelete;

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(top: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
      decoration: BoxDecoration(
        color: const Color(0xFFF8FAFC),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: const Color(0xFFE5E7EB)),
      ),
      child: Row(
        children: [
          const Icon(
            Icons.history_rounded,
            size: 20,
            color: AppTheme.primary,
          ),
          const SizedBox(width: 8),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _formatSnapshotTime(snapshot.createdAt),
                  maxLines: 1,
                  softWrap: false,
                  overflow: TextOverflow.visible,
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 13,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ],
            ),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 40),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: restoring ? null : onRestore,
            child: Text(restoring ? '恢复中' : '恢复'),
          ),
          TextButton(
            style: TextButton.styleFrom(
              minimumSize: const Size(44, 40),
              padding: const EdgeInsets.symmetric(horizontal: 6),
              tapTargetSize: MaterialTapTargetSize.shrinkWrap,
            ),
            onPressed: restoring || sharing ? null : onShare,
            child: Text(sharing ? '分享中' : '分享'),
          ),
          IconButton(
            tooltip: '删除备份',
            constraints: const BoxConstraints.tightFor(width: 40, height: 40),
            padding: EdgeInsets.zero,
            onPressed: restoring || sharing ? null : onDelete,
            icon: const Icon(Icons.delete_outline, size: 18),
          ),
        ],
      ),
    );
  }
}

String _formatSnapshotTime(DateTime value) {
  String pad2(int n) => n.toString().padLeft(2, '0');
  return '${value.year}.${value.month}.${value.day} '
      '${pad2(value.hour)}:${pad2(value.minute)}';
}

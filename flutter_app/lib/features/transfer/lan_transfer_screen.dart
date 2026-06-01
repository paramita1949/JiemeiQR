import 'dart:async';
import 'dart:io';

import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qrscan_flutter/features/qr/scanner_screen.dart';
import 'package:qrscan_flutter/features/transfer/backup_service.dart';
import 'package:qrscan_flutter/features/transfer/cloud_backup_service.dart';
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
    this.cloudBackupService,
    this.initialCloudSession,
    this.onPrepareImport,
    this.onImportCompleted,
    this.shareFile,
    this.pickImportFile,
  });

  final String databasePath;
  final String? initialImportPath;
  final BackupService? backupService;
  final LanTransferService? lanTransferService;
  final CloudBackupService? cloudBackupService;
  final CloudBackupSession? initialCloudSession;
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
  late final CloudBackupService _cloudBackupService;

  bool _creatingBackup = false;
  bool _resettingDatabase = false;
  bool _startingSend = false;
  bool _receiving = false;
  bool _loadingBackups = true;
  bool _cleaningBackups = false;
  bool _applyingSchedule = false;
  bool _sharingBackup = false;
  bool _importingSharedBackup = false;
  bool _loadingCloudSession = true;
  bool _cloudSigningIn = false;
  bool _cloudUploading = false;
  bool _cloudRestoring = false;
  bool _loadingCloudBackups = false;
  String? _restoringBackupPath;
  String? _sharingBackupPath;
  List<BackupSnapshot> _backupSnapshots = const [];
  BackupSchedule _backupSchedule = BackupSchedule.off;
  SendSession? _sendSession;
  CloudBackupSession? _cloudSession;
  List<CloudBackupRemoteBackup> _cloudBackups = const [];
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
    _cloudBackupService = widget.cloudBackupService ??
        CloudBackupService(api: SupabaseCloudBackupApi());
    _cloudSession = widget.initialCloudSession;
    _loadingCloudSession = widget.initialCloudSession == null;
    _bootstrapBackupPanel();
    if (widget.initialCloudSession == null) {
      unawaited(_loadCloudSession());
    } else {
      unawaited(_loadCloudBackups(widget.initialCloudSession!));
    }
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
            _CloudBackupPanel(
              loading: _loadingCloudSession,
              session: _cloudSession,
              signingIn: _cloudSigningIn,
              uploading: _cloudUploading,
              restoring: _cloudRestoring,
              loadingBackups: _loadingCloudBackups,
              backups: _cloudBackups,
              onLogin: _showCloudLoginDialog,
              onLogout: _logoutCloudBackup,
              onUpload: _cloudSession?.canUpload == true
                  ? _confirmAndUploadCloudBackup
                  : null,
              onRestore:
                  _cloudSession == null ? null : _confirmAndRestoreCloudBackup,
              onRestoreBackup: _cloudSession == null
                  ? null
                  : (backup) => _confirmAndRestoreCloudBackup(backup: backup),
              onManageAccounts: _cloudSession?.canUpload == true
                  ? _showCloudAccountManager
                  : null,
            ),
            const SizedBox(height: 16),
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

  Future<void> _loadCloudSession() async {
    try {
      final session = await _cloudBackupService.loadSavedSession();
      if (!mounted) {
        return;
      }
      setState(() {
        _cloudSession = session;
        _loadingCloudSession = false;
      });
      if (session != null) {
        unawaited(_loadCloudBackups(session));
      }
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() => _loadingCloudSession = false);
    }
  }

  Future<void> _showCloudLoginDialog() async {
    final result = await showDialog<_CloudLoginResult>(
      context: context,
      builder: (context) => const _CloudLoginDialog(),
    );
    if (result == null) {
      return;
    }
    setState(() => _cloudSigningIn = true);
    try {
      final session = await _cloudBackupService.signIn(
        email: result.email,
        password: result.password,
      );
      if (!mounted) {
        return;
      }
      setState(() => _cloudSession = session);
      unawaited(_loadCloudBackups(session));
      _showSnack('云备份已登录');
    } catch (_) {
      _showSnack('云备份登录失败');
    } finally {
      if (mounted) {
        setState(() => _cloudSigningIn = false);
      }
    }
  }

  Future<void> _logoutCloudBackup() async {
    await _cloudBackupService.signOut();
    if (!mounted) {
      return;
    }
    setState(() {
      _cloudSession = null;
      _cloudBackups = const [];
      _loadingCloudBackups = false;
    });
    _showSnack('已退出云备份账号');
  }

  Future<void> _showCloudAccountManager() async {
    final session = _cloudSession;
    if (session == null || !session.canUpload) {
      return;
    }
    await showDialog<void>(
      context: context,
      builder: (context) => _CloudAccountManagerDialog(
        service: _cloudBackupService,
        session: session,
      ),
    );
  }

  Future<void> _loadCloudBackups(CloudBackupSession session) async {
    if (!mounted) {
      return;
    }
    setState(() => _loadingCloudBackups = true);
    try {
      final backups =
          await _cloudBackupService.listBackups(session: session, limit: 5);
      if (!mounted || _cloudSession?.accessToken != session.accessToken) {
        return;
      }
      setState(() => _cloudBackups = backups);
    } catch (_) {
      if (!mounted || _cloudSession?.accessToken != session.accessToken) {
        return;
      }
      setState(() => _cloudBackups = const []);
    } finally {
      if (mounted && _cloudSession?.accessToken == session.accessToken) {
        setState(() => _loadingCloudBackups = false);
      }
    }
  }

  Future<void> _confirmAndUploadCloudBackup() async {
    final session = _cloudSession;
    if (session == null || !session.canUpload) {
      return;
    }
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('上传到云端'),
        content: const Text(
          '将用本机当前数据和 AI 配置覆盖云端备份。其他手机下载后会变成本机当前数据，是否继续？',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('确认上传'),
          ),
        ],
      ),
    );
    if (confirmed != true) {
      return;
    }

    setState(() {
      _cloudUploading = true;
      _statusText = '正在合并云端数据...';
    });
    try {
      final package = await _createMergedCloudPackageOrLocal(session);
      await _cloudBackupService.uploadPackage(
        session: session,
        packageFile: File(package.filePath),
      );
      await widget.onPrepareImport?.call();
      await _backupService.importSharedBackupPackage(package.filePath);
      await widget.onImportCompleted?.call(seedIfEmpty: false);
      if (!mounted) {
        return;
      }
      await _loadCloudBackups(session);
      setState(() => _statusText = '合并同步完成：${package.fileName}');
      _showSnack('合并同步已完成');
    } on BackupSourceMissingException {
      _showSnack('当前数据库不存在，无法上传');
    } on CloudBackupPermissionException {
      _showSnack('当前账号没有上传权限');
    } on CloudBackupRequestException catch (error) {
      final message = '合并同步失败：${error.debugMessage}';
      _showSnack(message);
      if (mounted) {
        setState(() => _statusText = message);
      }
    } catch (error) {
      final message = '合并同步失败：$error';
      _showSnack(message);
      if (mounted) {
        setState(() => _statusText = message);
      }
    } finally {
      if (mounted) {
        setState(() => _cloudUploading = false);
      }
    }
  }

  Future<void> _confirmAndRestoreCloudBackup({
    CloudBackupRemoteBackup? backup,
  }) async {
    final session = _cloudSession;
    if (session == null) {
      return;
    }
    final backupText = backup == null
        ? '云端最新备份'
        : '云端备份 ${_formatSnapshotTime(backup.createdAt)}';
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('从云端恢复'),
        content: Text(
          '将用$backupText覆盖本机数据和 AI 配置。恢复前会自动备份当前数据，是否继续？',
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
      _cloudRestoring = true;
      _statusText = '正在下载云备份...';
      _receiveStage = _ReceiveStage.transferring;
    });
    var prepared = false;
    try {
      final packageFile = await _cloudBackupService.downloadPackage(
        session: session,
        backup: backup,
      );
      final mergedPackage = await _backupService.createMergedSharePackage(
        cloudPackagePath: packageFile.path,
      );
      await widget.onPrepareImport?.call();
      prepared = true;
      final result = await _backupService
          .importSharedBackupPackage(mergedPackage.filePath);
      await widget.onImportCompleted?.call(seedIfEmpty: false);
      prepared = false;
      if (!mounted) {
        return;
      }
      await _loadBackupSnapshots();
      setState(() {
        _receiveStage = _ReceiveStage.success;
        _statusText = '云备份恢复完成，已自动备份当前数据：${result.backupFileName}';
      });
      _showSnack('云备份已恢复');
    } on IncompatibleBackupVersionException {
      _showSnack('云端备份来自新版本，请先升级 App');
      if (mounted) {
        setState(() => _receiveStage = _ReceiveStage.error);
      }
    } on InvalidImportDatabaseException {
      _showSnack('云端备份文件无效');
      if (mounted) {
        setState(() => _receiveStage = _ReceiveStage.error);
      }
    } on BackupSourceMissingException {
      _showSnack('当前数据库不存在，无法恢复');
      if (mounted) {
        setState(() => _receiveStage = _ReceiveStage.error);
      }
    } on ImportDatabaseFailedException {
      _showSnack('恢复失败，请关闭占用数据库的页面后重试');
      if (mounted) {
        setState(() => _receiveStage = _ReceiveStage.error);
      }
    } on CloudBackupRequestException catch (error) {
      final message = '云备份恢复失败：${error.debugMessage}';
      _showSnack(message);
      if (mounted) {
        setState(() {
          _receiveStage = _ReceiveStage.error;
          _statusText = message;
        });
      }
    } catch (error) {
      final message = '云备份恢复失败：$error';
      _showSnack(message);
      if (mounted) {
        setState(() {
          _receiveStage = _ReceiveStage.error;
          _statusText = message;
        });
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
        setState(() => _cloudRestoring = false);
      }
    }
  }

  Future<SharePackageResult> _createMergedCloudPackageOrLocal(
    CloudBackupSession session,
  ) async {
    try {
      final cloudPackage = await _cloudBackupService.downloadPackage(
        session: session,
      );
      return _backupService.createMergedSharePackage(
        cloudPackagePath: cloudPackage.path,
      );
    } on CloudBackupRequestException catch (error) {
      if (error.statusCode == 404) {
        return _backupService.createSharePackage();
      }
      rethrow;
    }
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

class _CloudAccountManagerDialog extends StatefulWidget {
  const _CloudAccountManagerDialog({
    required this.service,
    required this.session,
  });

  final CloudBackupService service;
  final CloudBackupSession session;

  @override
  State<_CloudAccountManagerDialog> createState() =>
      _CloudAccountManagerDialogState();
}

class _CloudAccountManagerDialogState
    extends State<_CloudAccountManagerDialog> {
  var _loading = true;
  var _saving = false;
  String? _errorText;
  List<CloudManagedAccount> _accounts = const [];

  @override
  void initState() {
    super.initState();
    unawaited(_loadAccounts());
  }

  Future<void> _loadAccounts() async {
    setState(() {
      _loading = true;
      _errorText = null;
    });
    try {
      final accounts =
          await widget.service.listAccounts(session: widget.session);
      if (mounted) {
        setState(() => _accounts = accounts);
      }
    } on CloudBackupRequestException catch (error) {
      if (mounted) {
        setState(() => _errorText = error.debugMessage);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorText = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _loading = false);
      }
    }
  }

  Future<void> _runAccountAction(Future<void> Function() action) async {
    setState(() {
      _saving = true;
      _errorText = null;
    });
    try {
      await action();
      await _loadAccounts();
    } on CloudBackupRequestException catch (error) {
      if (mounted) {
        setState(() => _errorText = error.debugMessage);
      }
    } catch (error) {
      if (mounted) {
        setState(() => _errorText = '$error');
      }
    } finally {
      if (mounted) {
        setState(() => _saving = false);
      }
    }
  }

  Future<void> _showCreateDialog() async {
    final result = await showDialog<_CloudAccountFormResult>(
      context: context,
      builder: (context) => const _CloudAccountFormDialog(),
    );
    if (result == null) {
      return;
    }
    await _runAccountAction(
      () => widget.service.createAccount(
        session: widget.session,
        email: result.email,
        password: result.password,
        role: result.role,
      ),
    );
  }

  Future<void> _showPasswordDialog(CloudManagedAccount account) async {
    final result = await showDialog<_CloudAccountFormResult>(
      context: context,
      builder: (context) => _CloudAccountFormDialog(
        email: account.email,
        fixedEmail: true,
        title: '修改密码',
        submitText: '保存密码',
      ),
    );
    if (result == null) {
      return;
    }
    await _runAccountAction(
      () => widget.service.updateAccountPassword(
        session: widget.session,
        email: account.email,
        password: result.password,
      ),
    );
  }

  Future<void> _confirmDelete(CloudManagedAccount account) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('删除账号'),
        content: Text('确定删除 ${account.email}？删除后该账号无法登录云备份。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('取消'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFDC2626),
              foregroundColor: Colors.white,
            ),
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('删除'),
          ),
        ],
      ),
    );
    if (confirmed == true) {
      await _runAccountAction(
        () => widget.service.deleteAccount(
          session: widget.session,
          email: account.email,
        ),
      );
    }
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text(
        '账号管理',
        style: TextStyle(fontWeight: FontWeight.w900),
      ),
      content: SizedBox(
        width: 430,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            const Text(
              '管理云备份登录账号',
              style: TextStyle(
                color: AppTheme.textSecondary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
            const SizedBox(height: 14),
            if (_errorText != null) ...[
              Container(
                width: double.infinity,
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: const Color(0xFFFFF1F2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Text(
                  _errorText!,
                  style: const TextStyle(
                    color: Color(0xFFBE123C),
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              const SizedBox(height: 10),
            ],
            if (_loading)
              const Padding(
                padding: EdgeInsets.all(24),
                child: CircularProgressIndicator(),
              )
            else
              Flexible(
                child: ListView.separated(
                  shrinkWrap: true,
                  itemCount: _accounts.length,
                  separatorBuilder: (_, __) => const SizedBox(height: 10),
                  itemBuilder: (context, index) {
                    final account = _accounts[index];
                    final isSelf = account.email == widget.session.email;
                    final isAdmin = account.role == CloudBackupRole.admin;
                    return Container(
                      padding: const EdgeInsets.all(12),
                      decoration: BoxDecoration(
                        color: Colors.white,
                        borderRadius: BorderRadius.circular(18),
                        border: Border.all(color: const Color(0xFFE5E7EB)),
                      ),
                      child: Row(
                        children: [
                          Expanded(
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Text(
                                  account.email,
                                  maxLines: 2,
                                  overflow: TextOverflow.ellipsis,
                                  style: const TextStyle(
                                    color: AppTheme.textPrimary,
                                    fontSize: 15,
                                    fontWeight: FontWeight.w900,
                                    height: 1.2,
                                  ),
                                ),
                                const SizedBox(height: 8),
                                Wrap(
                                  spacing: 6,
                                  runSpacing: 6,
                                  children: [
                                    _CloudAccountRoleChip(
                                      icon: isAdmin
                                          ? Icons.shield_outlined
                                          : Icons.cloud_download_outlined,
                                      label: isAdmin ? '管理员' : '普通账户',
                                      admin: isAdmin,
                                    ),
                                    if (isAdmin)
                                      const _CloudAccountRoleChip(
                                        icon: Icons.cloud_upload_outlined,
                                        label: '可上传',
                                        admin: true,
                                      ),
                                  ],
                                ),
                              ],
                            ),
                          ),
                          const SizedBox(width: 10),
                          Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              _CloudAccountIconButton(
                                tooltip: '修改密码',
                                icon: Icons.lock_reset_outlined,
                                onPressed: _saving
                                    ? null
                                    : () => _showPasswordDialog(account),
                              ),
                              const SizedBox(width: 6),
                              _CloudAccountIconButton(
                                tooltip: isSelf ? '不能删除当前登录账号' : '删除账号',
                                icon: Icons.delete_outline,
                                danger: true,
                                onPressed: _saving || isSelf
                                    ? null
                                    : () => _confirmDelete(account),
                              ),
                            ],
                          ),
                        ],
                      ),
                    );
                  },
                ),
              ),
          ],
        ),
      ),
      actions: [
        SizedBox(
          width: 430,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: _saving ? null : () => Navigator.of(context).pop(),
                  child: const Text('关闭'),
                ),
              ),
              const SizedBox(width: 10),
              Expanded(
                child: FilledButton(
                  onPressed: _saving ? null : _showCreateDialog,
                  child: const Text('新建'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }
}

class _CloudAccountRoleChip extends StatelessWidget {
  const _CloudAccountRoleChip({
    required this.icon,
    required this.label,
    required this.admin,
  });

  final IconData icon;
  final String label;
  final bool admin;

  @override
  Widget build(BuildContext context) {
    final color = admin ? const Color(0xFF027A48) : const Color(0xFF155EEF);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 5),
      decoration: BoxDecoration(
        color: admin ? const Color(0xFFE9F9F2) : const Color(0xFFEEF4FF),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 14, color: color),
          const SizedBox(width: 4),
          Text(
            label,
            style: TextStyle(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w900,
            ),
          ),
        ],
      ),
    );
  }
}

class _CloudAccountIconButton extends StatelessWidget {
  const _CloudAccountIconButton({
    required this.tooltip,
    required this.icon,
    required this.onPressed,
    this.danger = false,
  });

  final String tooltip;
  final IconData icon;
  final VoidCallback? onPressed;
  final bool danger;

  @override
  Widget build(BuildContext context) {
    final color = danger ? const Color(0xFFDC2626) : const Color(0xFF475467);
    return Tooltip(
      message: tooltip,
      child: InkWell(
        onTap: onPressed,
        borderRadius: BorderRadius.circular(12),
        child: Opacity(
          opacity: onPressed == null ? 0.42 : 1,
          child: Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: danger ? const Color(0xFFFFF1F2) : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                color:
                    danger ? const Color(0xFFFECACA) : const Color(0xFFE5E7EB),
              ),
            ),
            child: Icon(icon, color: color),
          ),
        ),
      ),
    );
  }
}

class _CloudAccountFormResult {
  const _CloudAccountFormResult({
    required this.email,
    required this.password,
    required this.role,
  });

  final String email;
  final String password;
  final CloudBackupRole role;
}

class _CloudAccountFormDialog extends StatefulWidget {
  const _CloudAccountFormDialog({
    this.email = '',
    this.fixedEmail = false,
    this.title = '新建账号',
    this.submitText = '创建',
  });

  final String email;
  final bool fixedEmail;
  final String title;
  final String submitText;

  @override
  State<_CloudAccountFormDialog> createState() =>
      _CloudAccountFormDialogState();
}

class _CloudAccountFormDialogState extends State<_CloudAccountFormDialog> {
  late final TextEditingController _emailController;
  final _passwordController = TextEditingController(text: 'qqmima');
  var _role = CloudBackupRole.viewer;
  String? _errorText;

  @override
  void initState() {
    super.initState();
    _emailController = TextEditingController(text: widget.email);
  }

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  void _submit() {
    final email = _emailController.text.trim().toLowerCase();
    final password = _passwordController.text;
    if (!email.contains('@') || !email.contains('.')) {
      setState(() => _errorText = '请输入正确邮箱账号');
      return;
    }
    if (password.length < 6) {
      setState(() => _errorText = '密码至少 6 位');
      return;
    }
    Navigator.of(context).pop(
      _CloudAccountFormResult(
        email: email,
        password: password,
        role: _role,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.title),
      content: SizedBox(
        width: 360,
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            TextField(
              controller: _emailController,
              enabled: !widget.fixedEmail,
              keyboardType: TextInputType.emailAddress,
              decoration: const InputDecoration(labelText: '邮箱账号'),
            ),
            const SizedBox(height: 10),
            TextField(
              controller: _passwordController,
              decoration: InputDecoration(
                labelText: widget.fixedEmail ? '新密码' : '初始密码',
                helperText: widget.fixedEmail ? null : '默认可填 qqmima',
              ),
            ),
            if (!widget.fixedEmail) ...[
              const SizedBox(height: 12),
              SegmentedButton<CloudBackupRole>(
                segments: const [
                  ButtonSegment(
                    value: CloudBackupRole.viewer,
                    label: Text('普通账户'),
                  ),
                  ButtonSegment(
                    value: CloudBackupRole.admin,
                    label: Text('管理员'),
                  ),
                ],
                selected: {_role},
                onSelectionChanged: (value) {
                  setState(() => _role = value.first);
                },
              ),
            ],
            if (_errorText != null) ...[
              const SizedBox(height: 10),
              Text(
                _errorText!,
                style: const TextStyle(color: Color(0xFFBE123C)),
              ),
            ],
          ],
        ),
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: _submit,
          child: Text(widget.submitText),
        ),
      ],
    );
  }
}

class _CloudBackupPanel extends StatelessWidget {
  const _CloudBackupPanel({
    required this.loading,
    required this.session,
    required this.signingIn,
    required this.uploading,
    required this.restoring,
    required this.loadingBackups,
    required this.backups,
    required this.onLogin,
    required this.onLogout,
    required this.onUpload,
    required this.onRestore,
    required this.onRestoreBackup,
    required this.onManageAccounts,
  });

  final bool loading;
  final CloudBackupSession? session;
  final bool signingIn;
  final bool uploading;
  final bool restoring;
  final bool loadingBackups;
  final List<CloudBackupRemoteBackup> backups;
  final VoidCallback onLogin;
  final VoidCallback onLogout;
  final VoidCallback? onUpload;
  final VoidCallback? onRestore;
  final ValueChanged<CloudBackupRemoteBackup>? onRestoreBackup;
  final VoidCallback? onManageAccounts;

  @override
  Widget build(BuildContext context) {
    final current = session;
    final roleText = current == null
        ? '未登录'
        : current.canUpload
            ? '可上传、可恢复'
            : '只能恢复';
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(20),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 42,
                height: 42,
                decoration: BoxDecoration(
                  color: const Color(0xFFEAF7EF),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: const Icon(
                  Icons.cloud_done_outlined,
                  color: Color(0xFF168A4A),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '云备份',
                      style: TextStyle(
                        color: AppTheme.textPrimary,
                        fontSize: 17,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                    const SizedBox(height: 3),
                    Text(
                      loading ? '正在读取账号...' : current?.email ?? '登录后使用云端备份',
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                      style: const TextStyle(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ],
                ),
              ),
              if (current != null)
                TextButton(
                  onPressed:
                      uploading || restoring || signingIn ? null : onLogout,
                  child: const Text('退出'),
                ),
            ],
          ),
          const SizedBox(height: 12),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              color: current?.canUpload == true
                  ? const Color(0xFFF3F8FF)
                  : const Color(0xFFF8FAFC),
              borderRadius: BorderRadius.circular(14),
            ),
            child: Text(
              '权限：$roleText。云备份包含业务数据和 AI 配置。',
              style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                height: 1.35,
              ),
            ),
          ),
          const SizedBox(height: 12),
          if (current?.canUpload == true && onManageAccounts != null) ...[
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: uploading || restoring ? null : onManageAccounts,
                icon: const Icon(Icons.manage_accounts_outlined),
                label: const Text('账号管理'),
              ),
            ),
            const SizedBox(height: 12),
          ],
          if (current == null)
            SizedBox(
              width: double.infinity,
              child: FilledButton.icon(
                onPressed: loading || signingIn ? null : onLogin,
                icon: signingIn
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(strokeWidth: 2),
                      )
                    : const Icon(Icons.login_rounded),
                label: Text(signingIn ? '登录中...' : '登录云备份'),
              ),
            )
          else
            Column(
              children: [
                Row(
                  children: [
                    if (current.canUpload) ...[
                      Expanded(
                        child: FilledButton.icon(
                          onPressed: uploading || restoring ? null : onUpload,
                          icon: uploading
                              ? const SizedBox(
                                  width: 18,
                                  height: 18,
                                  child:
                                      CircularProgressIndicator(strokeWidth: 2),
                                )
                              : const Icon(Icons.cloud_upload_outlined),
                          label: Text(uploading ? '上传中...' : '上传到云端'),
                        ),
                      ),
                      const SizedBox(width: 10),
                    ],
                    Expanded(
                      child: FilledButton.tonalIcon(
                        onPressed: uploading || restoring ? null : onRestore,
                        icon: restoring
                            ? const SizedBox(
                                width: 18,
                                height: 18,
                                child:
                                    CircularProgressIndicator(strokeWidth: 2),
                              )
                            : const Icon(Icons.cloud_download_outlined),
                        label: Text(restoring ? '恢复中...' : '恢复最新'),
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 12),
                _CloudBackupHistoryList(
                  loading: loadingBackups,
                  restoring: restoring,
                  backups: backups,
                  onRestoreBackup: onRestoreBackup,
                ),
              ],
            ),
        ],
      ),
    );
  }
}

class _CloudBackupHistoryList extends StatelessWidget {
  const _CloudBackupHistoryList({
    required this.loading,
    required this.restoring,
    required this.backups,
    required this.onRestoreBackup,
  });

  final bool loading;
  final bool restoring;
  final List<CloudBackupRemoteBackup> backups;
  final ValueChanged<CloudBackupRemoteBackup>? onRestoreBackup;

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '正在读取最近5次备份...',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    if (backups.isEmpty) {
      return const Align(
        alignment: Alignment.centerLeft,
        child: Text(
          '暂无历史备份，上传后会保留最近5次。',
          style: TextStyle(
            color: AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w700,
          ),
        ),
      );
    }
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          '最近5次备份',
          style: TextStyle(
            color: AppTheme.textPrimary,
            fontSize: 13,
            fontWeight: FontWeight.w900,
          ),
        ),
        const SizedBox(height: 8),
        ...backups.map(
          (backup) => Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: Row(
              children: [
                const Icon(
                  Icons.history_rounded,
                  size: 18,
                  color: AppTheme.textSecondary,
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    _formatSnapshotTime(backup.createdAt),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: const TextStyle(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                TextButton(
                  onPressed: restoring || onRestoreBackup == null
                      ? null
                      : () => onRestoreBackup!(backup),
                  child: const Text('恢复'),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

class _CloudLoginResult {
  const _CloudLoginResult({
    required this.email,
    required this.password,
  });

  final String email;
  final String password;
}

class _CloudLoginDialog extends StatefulWidget {
  const _CloudLoginDialog();

  @override
  State<_CloudLoginDialog> createState() => _CloudLoginDialogState();
}

class _CloudLoginDialogState extends State<_CloudLoginDialog> {
  final TextEditingController _emailController = TextEditingController();
  final TextEditingController _passwordController = TextEditingController();

  @override
  void dispose() {
    _emailController.dispose();
    _passwordController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: const Text('登录云备份'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _emailController,
            keyboardType: TextInputType.emailAddress,
            decoration: const InputDecoration(
              labelText: '账号',
              hintText: 'admin@jiemei.com / role@jiemei.com',
            ),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _passwordController,
            obscureText: true,
            decoration: const InputDecoration(labelText: '密码'),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('取消'),
        ),
        FilledButton(
          onPressed: () {
            Navigator.of(context).pop(
              _CloudLoginResult(
                email: _emailController.text.trim(),
                password: _passwordController.text,
              ),
            );
          },
          child: const Text('登录'),
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

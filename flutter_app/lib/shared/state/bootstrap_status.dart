import 'package:flutter/foundation.dart';

enum BootstrapPhase { idle, running, success, failure }

class BootstrapStatus {
  const BootstrapStatus({
    required this.phase,
    required this.message,
    this.progress,
  });

  final BootstrapPhase phase;
  final String message;
  final double? progress;

  static const BootstrapStatus idle = BootstrapStatus(
    phase: BootstrapPhase.idle,
    message: '',
  );
}

class BootstrapStatusController {
  BootstrapStatusController._();

  static final BootstrapStatusController instance = BootstrapStatusController._();

  final ValueNotifier<BootstrapStatus> status =
      ValueNotifier<BootstrapStatus>(BootstrapStatus.idle);

  void start({
    String message = '数据库初始化中',
    double? progress,
  }) {
    status.value = BootstrapStatus(
      phase: BootstrapPhase.running,
      message: message,
      progress: progress,
    );
  }

  void update({
    String? message,
    double? progress,
  }) {
    final current = status.value;
    status.value = BootstrapStatus(
      phase: BootstrapPhase.running,
      message: message ?? current.message,
      progress: progress ?? current.progress,
    );
  }

  void success([String message = '数据库初始化成功']) {
    status.value = BootstrapStatus(
      phase: BootstrapPhase.success,
      message: message,
      progress: 1,
    );
  }

  void failure([String message = '数据库初始化失败']) {
    status.value = BootstrapStatus(
      phase: BootstrapPhase.failure,
      message: message,
    );
  }
}

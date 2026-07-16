import 'dart:async';
import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:qrscan_flutter/shared/camera/ai_camera_math.dart';

class AiDocumentCameraScreen extends StatefulWidget {
  const AiDocumentCameraScreen({super.key});

  @override
  State<AiDocumentCameraScreen> createState() => _AiDocumentCameraScreenState();
}

class _AiDocumentCameraScreenState extends State<AiDocumentCameraScreen>
    with WidgetsBindingObserver {
  CameraController? _controller;
  File? _capturedImage;
  String? _errorMessage;
  bool _initializing = true;
  bool _takingPicture = false;
  double _minZoom = 1;
  double _maxZoom = 1;
  double _currentZoom = 1;
  double _zoomAtScaleStart = 1;
  FlashMode _flashMode = FlashMode.off;
  CameraPoint? _focusPoint;
  Timer? _focusIndicatorTimer;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    unawaited(_initializeCamera());
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (_capturedImage != null) {
      return;
    }
    if (state == AppLifecycleState.inactive ||
        state == AppLifecycleState.paused) {
      unawaited(_disposeController());
    } else if (state == AppLifecycleState.resumed && _controller == null) {
      unawaited(_initializeCamera());
    }
  }

  Future<void> _initializeCamera() async {
    if (mounted) {
      setState(() {
        _initializing = true;
        _errorMessage = null;
      });
    }
    try {
      final cameras = await availableCameras();
      final rearCameras = cameras
          .where((camera) => camera.lensDirection == CameraLensDirection.back)
          .toList(growable: false);
      if (rearCameras.isEmpty) {
        throw CameraException(
          'NoRearCamera',
          '未检测到可用后置摄像头',
        );
      }
      final controller = CameraController(
        rearCameras.first,
        ResolutionPreset.max,
        enableAudio: false,
        imageFormatGroup: ImageFormatGroup.jpeg,
      );
      await controller.initialize();
      await _tryCameraAction(() => controller.setFocusMode(FocusMode.auto));
      await _tryCameraAction(
        () => controller.setExposureMode(ExposureMode.auto),
      );
      await _tryCameraAction(() => controller.setFlashMode(FlashMode.off));
      final zoomLevels = await Future.wait<double>([
        controller.getMinZoomLevel(),
        controller.getMaxZoomLevel(),
      ]);
      if (!mounted) {
        await controller.dispose();
        return;
      }
      await _disposeController();
      setState(() {
        _controller = controller;
        _minZoom = zoomLevels[0];
        _maxZoom = zoomLevels[1];
        _currentZoom = zoomLevels[0];
        _flashMode = FlashMode.off;
        _initializing = false;
      });
    } on CameraException catch (error) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
        _errorMessage = _cameraErrorText(error);
      });
    } catch (_) {
      if (!mounted) {
        return;
      }
      setState(() {
        _initializing = false;
        _errorMessage = '相机初始化失败，请重试';
      });
    }
  }

  Future<void> _tryCameraAction(Future<void> Function() action) async {
    try {
      await action();
    } on CameraException {
      // Some devices do not support every focus, exposure, or flash operation.
    }
  }

  Future<void> _disposeController() async {
    final controller = _controller;
    _controller = null;
    if (controller != null) {
      await controller.dispose();
    }
  }

  Future<void> _focusAt(TapUpDetails details, Size previewSize) async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final point = normalizedCameraPoint(
      localX: details.localPosition.dx,
      localY: details.localPosition.dy,
      previewWidth: previewSize.width,
      previewHeight: previewSize.height,
    );
    final offset = Offset(point.x, point.y);
    if (controller.value.focusPointSupported) {
      await _tryCameraAction(() => controller.setFocusPoint(offset));
    }
    if (controller.value.exposurePointSupported) {
      await _tryCameraAction(() => controller.setExposurePoint(offset));
    }
    if (!mounted) {
      return;
    }
    _focusIndicatorTimer?.cancel();
    setState(() => _focusPoint = point);
    _focusIndicatorTimer = Timer(const Duration(milliseconds: 900), () {
      if (mounted) {
        setState(() => _focusPoint = null);
      }
    });
  }

  void _onScaleStart(ScaleStartDetails details) {
    _zoomAtScaleStart = _currentZoom;
  }

  Future<void> _onScaleUpdate(ScaleUpdateDetails details) async {
    if (details.pointerCount < 2) {
      return;
    }
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final zoom = clampCameraZoom(
      _zoomAtScaleStart * details.scale,
      minZoom: _minZoom,
      maxZoom: _maxZoom,
    );
    if ((zoom - _currentZoom).abs() < 0.02) {
      return;
    }
    _currentZoom = zoom;
    await _tryCameraAction(() => controller.setZoomLevel(zoom));
    if (mounted) {
      setState(() {});
    }
  }

  Future<void> _cycleFlashMode() async {
    final controller = _controller;
    if (controller == null || !controller.value.isInitialized) {
      return;
    }
    final next = switch (_flashMode) {
      FlashMode.off => FlashMode.auto,
      FlashMode.auto => FlashMode.always,
      _ => FlashMode.off,
    };
    try {
      await controller.setFlashMode(next);
      if (mounted) {
        setState(() => _flashMode = next);
      }
    } on CameraException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('当前设备不支持此闪光灯模式')),
        );
      }
    }
  }

  Future<void> _takePicture() async {
    final controller = _controller;
    if (controller == null ||
        !controller.value.isInitialized ||
        controller.value.isTakingPicture ||
        _takingPicture) {
      return;
    }
    setState(() => _takingPicture = true);
    try {
      final file = await controller.takePicture();
      if (!mounted) {
        return;
      }
      setState(() {
        _capturedImage = File(file.path);
        _takingPicture = false;
      });
      await _disposeController();
    } on CameraException {
      if (!mounted) {
        return;
      }
      setState(() => _takingPicture = false);
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('拍照失败，请重新尝试')),
      );
    }
  }

  Future<void> _retake() async {
    setState(() => _capturedImage = null);
    await _initializeCamera();
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _focusIndicatorTimer?.cancel();
    unawaited(_disposeController());
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      body: SafeArea(
        child: _capturedImage != null
            ? _buildReview(_capturedImage!)
            : _buildCamera(),
      ),
    );
  }

  Widget _buildCamera() {
    final controller = _controller;
    return Stack(
      fit: StackFit.expand,
      children: [
        if (controller != null && controller.value.isInitialized)
          Center(
            child: AspectRatio(
              aspectRatio: controller.value.aspectRatio,
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final size = Size(
                    constraints.maxWidth,
                    constraints.maxHeight,
                  );
                  return GestureDetector(
                    behavior: HitTestBehavior.opaque,
                    onTapUp: (details) => _focusAt(details, size),
                    onScaleStart: _onScaleStart,
                    onScaleUpdate: _onScaleUpdate,
                    child: Stack(
                      fit: StackFit.expand,
                      children: [
                        CameraPreview(controller),
                        if (_focusPoint case final point?)
                          Positioned(
                            left: point.x * size.width - 24,
                            top: point.y * size.height - 24,
                            child: const IgnorePointer(
                              child: _FocusIndicator(),
                            ),
                          ),
                      ],
                    ),
                  );
                },
              ),
            ),
          )
        else if (_initializing)
          const Center(
            child: CircularProgressIndicator(color: Colors.white),
          )
        else
          _CameraError(
            message: _errorMessage ?? '相机不可用',
            onRetry: _initializeCamera,
          ),
        Positioned(
          left: 8,
          top: 8,
          child: IconButton.filled(
            tooltip: '关闭相机',
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.close),
          ),
        ),
        if (controller != null && controller.value.isInitialized) ...[
          Positioned(
            right: 8,
            top: 8,
            child: IconButton.filled(
              key: const Key('aiCameraFlashButton'),
              tooltip: _flashTooltip,
              onPressed: _cycleFlashMode,
              style: IconButton.styleFrom(
                backgroundColor: Colors.black54,
                foregroundColor: Colors.white,
              ),
              icon: Icon(_flashIcon),
            ),
          ),
          Positioned(
            left: 0,
            right: 0,
            bottom: 28,
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
                  decoration: BoxDecoration(
                    color: Colors.black54,
                    borderRadius: BorderRadius.circular(99),
                  ),
                  child: Text(
                    '${_currentZoom.toStringAsFixed(1)}× · 点按对焦 · 双指缩放',
                    style: const TextStyle(
                      color: Colors.white,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
                const SizedBox(height: 14),
                Semantics(
                  button: true,
                  label: '拍照',
                  child: GestureDetector(
                    key: const Key('aiCameraShutterButton'),
                    onTap: _takingPicture ? null : _takePicture,
                    child: Container(
                      width: 76,
                      height: 76,
                      padding: const EdgeInsets.all(5),
                      decoration: BoxDecoration(
                        shape: BoxShape.circle,
                        border: Border.all(color: Colors.white, width: 3),
                      ),
                      child: DecoratedBox(
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          color: _takingPicture ? Colors.white54 : Colors.white,
                        ),
                        child: _takingPicture
                            ? const Padding(
                                padding: EdgeInsets.all(16),
                                child: CircularProgressIndicator(
                                  strokeWidth: 3,
                                  color: Colors.black54,
                                ),
                              )
                            : null,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ],
    );
  }

  Widget _buildReview(File image) {
    return Stack(
      fit: StackFit.expand,
      children: [
        Image.file(image, fit: BoxFit.contain),
        Positioned(
          left: 8,
          top: 8,
          child: IconButton.filled(
            tooltip: '关闭预览',
            onPressed: () => Navigator.of(context).pop(),
            style: IconButton.styleFrom(
              backgroundColor: Colors.black54,
              foregroundColor: Colors.white,
            ),
            icon: const Icon(Icons.close),
          ),
        ),
        Positioned(
          left: 18,
          right: 18,
          bottom: 18,
          child: Row(
            children: [
              Expanded(
                child: OutlinedButton.icon(
                  key: const Key('aiCameraRetakeButton'),
                  onPressed: _retake,
                  style: OutlinedButton.styleFrom(
                    minimumSize: const Size(0, 50),
                    foregroundColor: Colors.white,
                    backgroundColor: Colors.black54,
                    side: const BorderSide(color: Colors.white70),
                  ),
                  icon: const Icon(Icons.refresh),
                  label: const Text('重拍'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: FilledButton.icon(
                  key: const Key('aiCameraUsePhotoButton'),
                  onPressed: () => Navigator.of(context).pop(image),
                  style: FilledButton.styleFrom(
                    minimumSize: const Size(0, 50),
                  ),
                  icon: const Icon(Icons.check),
                  label: const Text('使用照片'),
                ),
              ),
            ],
          ),
        ),
      ],
    );
  }

  IconData get _flashIcon => switch (_flashMode) {
        FlashMode.auto => Icons.flash_auto,
        FlashMode.always => Icons.flash_on,
        _ => Icons.flash_off,
      };

  String get _flashTooltip => switch (_flashMode) {
        FlashMode.auto => '闪光灯：自动',
        FlashMode.always => '闪光灯：开启',
        _ => '闪光灯：关闭',
      };

  String _cameraErrorText(CameraException error) {
    return switch (error.code) {
      'CameraAccessDenied' ||
      'CameraAccessDeniedWithoutPrompt' ||
      'CameraAccessRestricted' =>
        '相机权限未开启，请在系统设置中允许相机权限',
      'NoRearCamera' => '未检测到可用后置摄像头',
      _ => '相机初始化失败，请重试',
    };
  }
}

class _FocusIndicator extends StatelessWidget {
  const _FocusIndicator();

  @override
  Widget build(BuildContext context) {
    return Container(
      width: 48,
      height: 48,
      decoration: BoxDecoration(
        border: Border.all(color: Colors.amber, width: 2),
        borderRadius: BorderRadius.circular(8),
      ),
    );
  }
}

class _CameraError extends StatelessWidget {
  const _CameraError({required this.message, required this.onRetry});

  final String message;
  final Future<void> Function() onRetry;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.no_photography_outlined,
                color: Colors.white70, size: 42),
            const SizedBox(height: 12),
            Text(
              message,
              textAlign: TextAlign.center,
              style: const TextStyle(color: Colors.white),
            ),
            const SizedBox(height: 16),
            FilledButton.icon(
              onPressed: onRetry,
              icon: const Icon(Icons.refresh),
              label: const Text('重新尝试'),
            ),
          ],
        ),
      ),
    );
  }
}

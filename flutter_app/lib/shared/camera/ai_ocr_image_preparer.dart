import 'dart:io';
import 'dart:isolate';

import 'package:image/image.dart' as img;

class AiPreparedImage {
  const AiPreparedImage({
    required this.file,
    required this.isTemporary,
  });

  final File file;
  final bool isTemporary;

  Future<void> dispose() async {
    if (isTemporary && await file.exists()) {
      await file.delete();
    }
  }
}

class AiOcrImagePreparationException implements Exception {
  const AiOcrImagePreparationException(this.message);

  final String message;

  @override
  String toString() => message;
}

class AiOcrImagePreparer {
  const AiOcrImagePreparer({
    this.maxLongEdge = 4096,
    this.maxBytes = 3 * 1024 * 1024,
    this.targetLongEdges = const [4096, 3584, 3072],
    this.jpegQualities = const [95, 92, 90, 88],
    this.outputDirectory,
  });

  final int maxLongEdge;
  final int maxBytes;
  final List<int> targetLongEdges;
  final List<int> jpegQualities;
  final Directory? outputDirectory;

  Future<AiPreparedImage> prepare(File source) async {
    if (!source.existsSync()) {
      throw const AiOcrImagePreparationException('图片文件不存在');
    }
    if (source.lengthSync() <= maxBytes) {
      final sourceBytes = source.readAsBytesSync();
      final decoder = img.findDecoderForData(sourceBytes);
      final info = decoder?.startDecode(sourceBytes);
      if (info == null) {
        throw const AiOcrImagePreparationException('图片格式无法读取');
      }
      final longEdge = info.width > info.height ? info.width : info.height;
      if (longEdge <= maxLongEdge) {
        return AiPreparedImage(file: source, isTemporary: false);
      }
    }
    final result = await Isolate.run(
      () => _prepareImageSync(
        sourcePath: source.path,
        outputDirectoryPath: outputDirectory?.path,
        maxLongEdge: maxLongEdge,
        maxBytes: maxBytes,
        targetLongEdges: targetLongEdges,
        jpegQualities: jpegQualities,
      ),
    );
    return AiPreparedImage(
      file: File(result.path),
      isTemporary: result.isTemporary,
    );
  }
}

class _PreparedImageResult {
  const _PreparedImageResult(this.path, this.isTemporary);

  final String path;
  final bool isTemporary;
}

_PreparedImageResult _prepareImageSync({
  required String sourcePath,
  required String? outputDirectoryPath,
  required int maxLongEdge,
  required int maxBytes,
  required List<int> targetLongEdges,
  required List<int> jpegQualities,
}) {
  final source = File(sourcePath);
  final sourceBytes = source.readAsBytesSync();
  final decoded = img.decodeImage(sourceBytes);
  if (decoded == null) {
    throw const AiOcrImagePreparationException('图片格式无法读取');
  }
  final oriented = img.bakeOrientation(decoded);
  final originalLongEdge =
      oriented.width > oriented.height ? oriented.width : oriented.height;
  if (originalLongEdge <= maxLongEdge && sourceBytes.length <= maxBytes) {
    return _PreparedImageResult(sourcePath, false);
  }

  List<int>? selectedBytes;
  for (final requestedEdge in targetLongEdges) {
    final targetEdge =
        requestedEdge < originalLongEdge ? requestedEdge : originalLongEdge;
    final resized = targetEdge < originalLongEdge
        ? (oriented.width >= oriented.height
            ? img.copyResize(
                oriented,
                width: targetEdge,
                interpolation: img.Interpolation.cubic,
              )
            : img.copyResize(
                oriented,
                height: targetEdge,
                interpolation: img.Interpolation.cubic,
              ))
        : oriented;
    for (final quality in jpegQualities) {
      final encoded = img.encodeJpg(resized, quality: quality);
      selectedBytes = encoded;
      if (encoded.length <= maxBytes) {
        break;
      }
    }
    if (selectedBytes != null && selectedBytes.length <= maxBytes) {
      break;
    }
  }

  if (selectedBytes == null) {
    throw const AiOcrImagePreparationException('图片压缩失败');
  }
  final directory = outputDirectoryPath == null
      ? Directory.systemTemp
      : Directory(outputDirectoryPath);
  directory.createSync(recursive: true);
  final output = File(
    '${directory.path}${Platform.pathSeparator}'
    'qrscan_ai_ocr_${DateTime.now().microsecondsSinceEpoch}.jpg',
  );
  output.writeAsBytesSync(selectedBytes, flush: true);
  return _PreparedImageResult(output.path, true);
}

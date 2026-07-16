import 'dart:io';

import 'package:flutter/material.dart';
import 'package:image_picker/image_picker.dart';
import 'package:qrscan_flutter/shared/camera/ai_document_camera_screen.dart';

Future<File?> pickAiDocumentImage(
  BuildContext context,
  ImageSource source, {
  ImagePicker? imagePicker,
}) async {
  if (source == ImageSource.camera && Platform.isAndroid) {
    return Navigator.of(context).push<File>(
      MaterialPageRoute<File>(
        fullscreenDialog: true,
        builder: (_) => const AiDocumentCameraScreen(),
      ),
    );
  }
  final picked = await (imagePicker ?? ImagePicker()).pickImage(source: source);
  return picked == null ? null : File(picked.path);
}

import 'dart:io';

import 'package:image_picker/image_picker.dart';

Future<File?> pickAiDocumentImage(
  ImageSource source, {
  ImagePicker? imagePicker,
}) async {
  final picked = await (imagePicker ?? ImagePicker()).pickImage(
    source: source,
    preferredCameraDevice: CameraDevice.rear,
  );
  return picked == null ? null : File(picked.path);
}

class CameraPoint {
  const CameraPoint(this.x, this.y);

  final double x;
  final double y;

  @override
  bool operator ==(Object other) {
    return other is CameraPoint && other.x == x && other.y == y;
  }

  @override
  int get hashCode => Object.hash(x, y);
}

CameraPoint normalizedCameraPoint({
  required double localX,
  required double localY,
  required double previewWidth,
  required double previewHeight,
}) {
  if (previewWidth <= 0 || previewHeight <= 0) {
    return const CameraPoint(0.5, 0.5);
  }
  return CameraPoint(
    (localX / previewWidth).clamp(0.0, 1.0),
    (localY / previewHeight).clamp(0.0, 1.0),
  );
}

double clampCameraZoom(
  double value, {
  required double minZoom,
  required double maxZoom,
}) {
  if (maxZoom < minZoom) {
    return minZoom;
  }
  return value.clamp(minZoom, maxZoom);
}

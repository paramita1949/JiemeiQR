import 'dart:async';

enum DataChangeKind {
  inventory,
  baseInfo,
  orders,
}

class DataChangeNotifier {
  DataChangeNotifier._();

  static final DataChangeNotifier instance = DataChangeNotifier._();

  final StreamController<DataChangeKind> _controller =
      StreamController<DataChangeKind>.broadcast();
  final Set<DataChangeKind> _pendingKinds = <DataChangeKind>{};
  int _batchDepth = 0;

  Stream<DataChangeKind> get stream => _controller.stream;

  void emit(DataChangeKind kind) {
    if (_controller.isClosed) {
      return;
    }
    if (_batchDepth > 0) {
      _pendingKinds.add(kind);
      return;
    }
    _controller.add(kind);
  }

  void beginBatch() {
    _batchDepth += 1;
  }

  void endBatch() {
    if (_batchDepth == 0) {
      return;
    }
    _batchDepth -= 1;
    if (_batchDepth > 0 || _controller.isClosed || _pendingKinds.isEmpty) {
      return;
    }
    final kinds = _pendingKinds.toList(growable: false);
    _pendingKinds.clear();
    for (final kind in kinds) {
      _controller.add(kind);
    }
  }

  Future<T> runInBatch<T>(Future<T> Function() action) async {
    beginBatch();
    try {
      return await action();
    } finally {
      endBatch();
    }
  }
}

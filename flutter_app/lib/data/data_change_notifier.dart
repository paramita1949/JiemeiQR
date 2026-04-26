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

  Stream<DataChangeKind> get stream => _controller.stream;

  void emit(DataChangeKind kind) {
    if (_controller.isClosed) {
      return;
    }
    _controller.add(kind);
  }
}

class DebugEventLog {
  DebugEventLog._();

  static const int _maxEntries = 200;
  static final List<String> _entries = <String>[];

  static void add(String tag, String message) {
    final now = DateTime.now();
    final line =
        '${now.toIso8601String()} [$tag] $message';
    _entries.add(line);
    if (_entries.length > _maxEntries) {
      _entries.removeAt(0);
    }
  }

  static List<String> dump() => List<String>.unmodifiable(_entries);
}


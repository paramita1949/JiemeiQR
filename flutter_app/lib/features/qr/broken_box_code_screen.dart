import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:qrscan_flutter/data/app_database.dart';
import 'package:qrscan_flutter/data/daos/broken_box_code_dao.dart';
import 'package:qrscan_flutter/services/qr_parser.dart';

import 'scanner_screen.dart';

class BrokenBoxCodeScreen extends StatefulWidget {
  const BrokenBoxCodeScreen({super.key, this.database});

  final AppDatabase? database;

  @override
  State<BrokenBoxCodeScreen> createState() => _BrokenBoxCodeScreenState();
}

class _BrokenBoxCodeScreenState extends State<BrokenBoxCodeScreen> {
  late final AppDatabase _db;
  late final bool _owns;
  late final BrokenBoxCodeDao _dao;
  final List<BrokenBoxCodeEntry> _rows = <BrokenBoxCodeEntry>[];

  @override
  void initState() {
    super.initState();
    _owns = widget.database == null;
    _db = widget.database ?? AppDatabase();
    _dao = BrokenBoxCodeDao(_db);
    _load();
  }

  @override
  void dispose() {
    if (_owns) {
      _db.close();
    }
    super.dispose();
  }

  Future<void> _load() async {
    final rows = await _dao.latest();
    if (!mounted) return;
    setState(() {
      _rows
        ..clear()
        ..addAll(rows);
    });
  }

  Future<void> _scanAdd() async {
    final code = await Navigator.of(context).push<String>(
      MaterialPageRoute(builder: (_) => const ScannerScreen(title: '扫描破损箱码')),
    );
    if (code == null || code.trim().isEmpty) return;
    await _saveCode(code.trim());
  }

  Future<void> _manualAdd() async {
    final c = TextEditingController();
    final code = await showDialog<String>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('手动输入完整码'),
        content: TextField(controller: c),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, c.text.trim()), child: const Text('保存')),
        ],
      ),
    );
    if (code == null || code.isEmpty) return;
    await _saveCode(code);
  }

  Future<void> _saveCode(String full) async {
    final parsed = QrParser.parse(full);
    if (parsed == null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('格式不匹配')),
      );
      return;
    }
    final day = DateTime.now();
    final dayKey = '${day.year}-${day.month.toString().padLeft(2, '0')}-${day.day.toString().padLeft(2, '0')}';
    final productCode = parsed.prefix.replaceAll(RegExp(r'[^0-9A-Za-z]'), '');
    await _dao.insert(
      day: dayKey,
      productCode: productCode,
      actualBatch: parsed.batch,
      fullCode: full,
    );
    await _load();
  }

  Future<void> _generateByRule() async {
    final prefix = TextEditingController();
    final start = TextEditingController();
    final batch = TextEditingController();
    final suffix = TextEditingController(text: '31');
    final count = TextEditingController(text: '1');
    final ok = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('按规则生成破损码'),
        content: SingleChildScrollView(
          child: Column(
            children: [
              TextField(controller: prefix, decoration: const InputDecoration(labelText: '前缀(含产品编号)')),
              TextField(controller: start, decoration: const InputDecoration(labelText: '起始流水号10位')),
              TextField(controller: batch, decoration: const InputDecoration(labelText: '批号7位')),
              TextField(controller: suffix, decoration: const InputDecoration(labelText: '后缀')),
              TextField(controller: count, decoration: const InputDecoration(labelText: '数量')),
            ],
          ),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(context, false), child: const Text('取消')),
          FilledButton(onPressed: () => Navigator.pop(context, true), child: const Text('生成保存')),
        ],
      ),
    );
    if (ok != true) return;
    final countNum = int.tryParse(count.text.trim()) ?? 0;
    final startNum = int.tryParse(start.text.trim());
    if (countNum <= 0 || startNum == null) return;
    for (var i = 0; i < countNum; i++) {
      final serial = (startNum + i).toString().padLeft(10, '0');
      final full = '${prefix.text.trim()}$serial${batch.text.trim()}${suffix.text.trim()}';
      await _saveCode(full);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('破损箱码')),
      body: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          children: [
            Row(
              children: [
                Expanded(child: FilledButton.icon(onPressed: _scanAdd, icon: const Icon(Icons.qr_code_scanner), label: const Text('扫码保存'))),
                const SizedBox(width: 8),
                Expanded(child: OutlinedButton.icon(onPressed: _manualAdd, icon: const Icon(Icons.keyboard), label: const Text('手动录入'))),
              ],
            ),
            const SizedBox(height: 8),
            SizedBox(
              width: double.infinity,
              child: OutlinedButton.icon(
                onPressed: _generateByRule,
                icon: const Icon(Icons.auto_fix_high_outlined),
                label: const Text('按参数生成并保存'),
              ),
            ),
            const SizedBox(height: 12),
            Expanded(
              child: ListView.builder(
                itemCount: _rows.length,
                itemBuilder: (context, i) {
                  final item = _rows[i];
                  return Card(
                    child: ListTile(
                      title: Text('${item.day} | ${item.productCode} | ${item.actualBatch}'),
                      subtitle: Text(item.fullCode),
                      trailing: Wrap(
                        spacing: 2,
                        children: [
                          IconButton(
                            onPressed: () => Clipboard.setData(ClipboardData(text: item.fullCode)),
                            icon: const Icon(Icons.copy_outlined),
                          ),
                          IconButton(
                            onPressed: () async {
                              await _dao.deleteById(item.id);
                              _load();
                            },
                            icon: const Icon(Icons.delete_outline, color: Colors.red),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }
}

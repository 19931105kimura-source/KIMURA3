import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../data/server_config.dart';
import '../state/order_state.dart';
import '../utils/price_format.dart';

class OwnerDeletedOrdersPage extends StatefulWidget {
  const OwnerDeletedOrdersPage({super.key});

  @override
  State<OwnerDeletedOrdersPage> createState() => _OwnerDeletedOrdersPageState();
}

class _OwnerDeletedOrdersPageState extends State<OwnerDeletedOrdersPage> {
  bool _loading = true;
  List<Map<String, dynamic>> _entries = [];

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    try {
      final res = await http.get(ServerConfig.api('/api/deleted-orders'));
      if (res.statusCode >= 200 && res.statusCode < 300) {
        final body = jsonDecode(res.body);
        final raw = body is Map<String, dynamic> ? body['deletedOrders'] : null;
        if (raw is List) {
          _entries = raw
              .whereType<Map>()
              .map((e) => Map<String, dynamic>.from(e))
              .toList();
        }
      }
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _restore(Map<String, dynamic> entry) async {
    final tables = context.read<OrderState>().tables;
    final target = await showDialog<String>(
      context: context,
      builder: (dialogContext) => SimpleDialog(
        title: const Text('復元先の席を選択'),
        children: tables
            .map(
              (table) => SimpleDialogOption(
                onPressed: () => Navigator.pop(dialogContext, table),
                child: Text(table),
              ),
            )
            .toList(),
      ),
    );
    if (target == null || !mounted) return;

    final id = Uri.encodeComponent(entry['id'].toString());
    final res = await http.post(
      ServerConfig.api('/api/deleted-orders/$id/restore'),
      headers: {'Content-Type': 'application/json'},
      body: jsonEncode({'table': target}),
    );

    if (!mounted) return;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('$target に復元しました')),
      );
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('復元に失敗しました')),
      );
    }
  }

  Future<void> _deleteHistory(Map<String, dynamic> entry) async {
    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('履歴を削除しますか？'),
        content: const Text('この削除履歴を完全に削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final id = Uri.encodeComponent(entry['id'].toString());
    final res = await http.delete(ServerConfig.api('/api/deleted-orders/$id'));

    if (!mounted) return;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('履歴削除に失敗しました')),
      );
    }
  }

  Future<void> _deleteAllHistory() async {
    if (_entries.isEmpty) return;

    final ok = await showDialog<bool>(
      context: context,
      builder: (dialogContext) => AlertDialog(
        title: const Text('削除履歴をすべて削除しますか？'),
        content: const Text('すべての削除履歴を完全に削除します。'),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(dialogContext, false),
            child: const Text('キャンセル'),
          ),
          FilledButton(
            onPressed: () => Navigator.pop(dialogContext, true),
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            child: const Text('すべて削除'),
          ),
        ],
      ),
    );
    if (ok != true) return;

    final res = await http.delete(ServerConfig.api('/api/deleted-orders'));

    if (!mounted) return;
    if (res.statusCode >= 200 && res.statusCode < 300) {
      await _load();
    } else {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('削除履歴の一括削除に失敗しました')),
      );
    }
  }

  int _total(List<dynamic> lines) {
    var sum = 0;
    for (final line in lines) {
      if (line is! Map) continue;
      final price = int.tryParse('${line['price'] ?? 0}') ?? 0;
      final qty = int.tryParse('${line['qty'] ?? line['quantity'] ?? 0}') ?? 0;
      sum += price * qty;
    }
    return sum;
  }

  String _formatDate(dynamic value) {
    final parsed = DateTime.tryParse(value?.toString() ?? '');
    if (parsed == null) return '-';
    final local = parsed.toLocal();
    String two(int n) => n.toString().padLeft(2, '0');
    return '${local.year}/${two(local.month)}/${two(local.day)} '
        '${two(local.hour)}:${two(local.minute)}';
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('削除履歴'),
        actions: [
          if (_entries.isNotEmpty)
            IconButton(
              tooltip: 'すべて削除',
              onPressed: _deleteAllHistory,
              icon: const Icon(Icons.delete_sweep),
            ),
          IconButton(
            onPressed: _load,
            icon: const Icon(Icons.refresh),
          ),
        ],
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _entries.isEmpty
              ? const Center(child: Text('削除履歴はありません'))
              : ListView.builder(
                  itemCount: _entries.length,
                  itemBuilder: (context, index) {
                    final entry = _entries[index];
                    final lines = (entry['lines'] is List)
                        ? List<dynamic>.from(entry['lines'])
                        : <dynamic>[];
                    final restoredAt = entry['restoredAt'];

                    return Card(
                      margin: const EdgeInsets.all(12),
                      child: Padding(
                        padding: const EdgeInsets.all(12),
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Row(
                              children: [
                                Expanded(
                                  child: Text(
                                    '席 ${entry['originalTable'] ?? '-'} / '
                                    '${_formatDate(entry['deletedAt'])}',
                                    style: const TextStyle(
                                      fontWeight: FontWeight.bold,
                                      fontSize: 16,
                                    ),
                                  ),
                                ),
                                Text(formatYenTruncatedToTen(_total(lines))),
                              ],
                            ),
                            if (restoredAt != null)
                              Padding(
                                padding: const EdgeInsets.only(top: 6),
                                child: Text(
                                  '復元済み: ${entry['restoredToTable'] ?? '-'}',
                                  style: const TextStyle(color: Colors.amber),
                                ),
                              ),
                            const Divider(),
                            ...lines.map((raw) {
                              final line = raw is Map ? raw : {};
                              final brand = line['brand']?.toString() ?? '';
                              final label = line['label']?.toString() ?? '';
                              final qty = line['qty'] ?? line['quantity'] ?? 0;
                              final price =
                                  int.tryParse('${line['price'] ?? 0}') ?? 0;
                              return Padding(
                                padding: const EdgeInsets.symmetric(vertical: 3),
                                child: Row(
                                  children: [
                                    Expanded(child: Text('$brand $label'.trim())),
                                    Text(
                                      'x$qty  ${formatYenTruncatedToTen(price)}',
                                    ),
                                  ],
                                ),
                              );
                            }),
                            const SizedBox(height: 8),
                            Row(
                              mainAxisAlignment: MainAxisAlignment.end,
                              children: [
                                TextButton(
                                  onPressed: restoredAt == null
                                      ? () => _restore(entry)
                                      : null,
                                  child: const Text('復元'),
                                ),
                                TextButton(
                                  onPressed: () => _deleteHistory(entry),
                                  child: const Text(
                                    '完全削除',
                                    style: TextStyle(color: Colors.red),
                                  ),
                                ),
                              ],
                            ),
                          ],
                        ),
                      ),
                    );
                  },
                ),
    );
  }
}

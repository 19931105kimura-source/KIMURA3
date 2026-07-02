import 'dart:convert';

import 'package:flutter/material.dart';
import 'package:http/http.dart' as http;
import 'package:provider/provider.dart';

import '../data/server_config.dart';
import '../state/diagnostic_log_state.dart';

class OwnerDiagnosticLogsPage extends StatefulWidget {
  const OwnerDiagnosticLogsPage({super.key});

  @override
  State<OwnerDiagnosticLogsPage> createState() =>
      _OwnerDiagnosticLogsPageState();
}

class _OwnerDiagnosticLogsPageState extends State<OwnerDiagnosticLogsPage> {
  bool _loading = false;
  String? _error;
  List<Map<String, dynamic>> _serverLogs = [];

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadServerLogs());
  }

  Future<void> _loadServerLogs() async {
    setState(() {
      _loading = true;
      _error = null;
    });

    try {
      final res = await http
          .get(ServerConfig.api('/api/diagnostics/order-logs'))
          .timeout(const Duration(seconds: 8));
      if (res.statusCode < 200 || res.statusCode >= 300) {
        throw Exception('HTTP ${res.statusCode}');
      }
      final body = jsonDecode(res.body);
      final logs = body is Map ? body['logs'] : null;
      setState(() {
        _serverLogs = logs is List
            ? logs
                  .whereType<Map>()
                  .map((e) => Map<String, dynamic>.from(e))
                  .toList()
            : [];
      });
    } catch (e) {
      setState(() => _error = 'サーバーログ取得に失敗しました: $e');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _clearServerLogs() async {
    try {
      await http
          .delete(ServerConfig.api('/api/diagnostics/order-logs'))
          .timeout(const Duration(seconds: 8));
      if (!mounted) return;
      context.read<DiagnosticLogState>().clear();
      await _loadServerLogs();
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text('ログ削除に失敗しました: $e')));
    }
  }

  String _formatLocalTime(DateTime at) {
    final h = at.hour.toString().padLeft(2, '0');
    final m = at.minute.toString().padLeft(2, '0');
    final s = at.second.toString().padLeft(2, '0');
    return '$h:$m:$s';
  }

  String _formatServerTime(String? raw) {
    if (raw == null || raw.isEmpty) return '-';
    final parsed = DateTime.tryParse(raw);
    if (parsed == null) return raw;
    return _formatLocalTime(parsed.toLocal());
  }

  @override
  Widget build(BuildContext context) {
    final localLogs = context.watch<DiagnosticLogState>().entries;

    return Scaffold(
      appBar: AppBar(
        title: const Text('診断ログ'),
        actions: [
          IconButton(
            tooltip: '更新',
            onPressed: _loading ? null : _loadServerLogs,
            icon: const Icon(Icons.refresh),
          ),
          IconButton(
            tooltip: 'ログを消す',
            onPressed: _clearServerLogs,
            icon: const Icon(Icons.delete_outline),
          ),
        ],
      ),
      body: RefreshIndicator(
        onRefresh: _loadServerLogs,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            const Text(
              '注文が同期中になった時は、この画面を更新して [ORDER_SUBMIT] と [ORDER_API] の前後を見ます。',
              style: TextStyle(color: Colors.white70),
            ),
            const SizedBox(height: 12),
            if (_loading) const LinearProgressIndicator(),
            if (_error != null) ...[
              const SizedBox(height: 12),
              Text(_error!, style: const TextStyle(color: Colors.orange)),
            ],
            const SizedBox(height: 16),
            _SectionTitle(title: 'サーバーに集まったログ (${_serverLogs.length})'),
            if (_serverLogs.isEmpty)
              const _EmptyLog(text: 'サーバーログはまだありません')
            else
              ..._serverLogs.map(
                (log) => _LogTile(
                  time: _formatServerTime(log['at']?.toString()),
                  source: log['source']?.toString() ?? 'server',
                  message: log['message']?.toString() ?? '',
                ),
              ),
            const SizedBox(height: 24),
            _SectionTitle(title: 'この端末のログ (${localLogs.length})'),
            if (localLogs.isEmpty)
              const _EmptyLog(text: 'この端末のログはまだありません')
            else
              ...localLogs.map(
                (log) => _LogTile(
                  time: _formatLocalTime(log.at),
                  source: log.source,
                  message: log.message,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _SectionTitle extends StatelessWidget {
  final String title;

  const _SectionTitle({required this.title});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 8),
      child: Text(
        title,
        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
      ),
    );
  }
}

class _EmptyLog extends StatelessWidget {
  final String text;

  const _EmptyLog({required this.text});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white10,
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(text, style: const TextStyle(color: Colors.white60)),
    );
  }
}

class _LogTile extends StatelessWidget {
  final String time;
  final String source;
  final String message;

  const _LogTile({
    required this.time,
    required this.source,
    required this.message,
  });

  @override
  Widget build(BuildContext context) {
    final isProblem =
        message.contains('blocked') ||
        message.contains('error') ||
        message.contains('failed') ||
        message.contains('rejected');

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: isProblem
            ? Colors.orange.withValues(alpha: 0.16)
            : Colors.white10,
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: isProblem ? Colors.orange : Colors.white12),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '$time  [$source]',
            style: TextStyle(color: Colors.grey.shade400, fontSize: 12),
          ),
          const SizedBox(height: 4),
          SelectableText(
            message,
            style: const TextStyle(fontFamily: 'monospace', fontSize: 12),
          ),
        ],
      ),
    );
  }
}

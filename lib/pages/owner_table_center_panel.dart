import 'dart:convert';
import '../data/server_config.dart';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:http/http.dart' as http;

import '../state/order_state.dart';
import 'owner_add_order_page.dart';
import '../../billing/billing_calculator.dart';
import '../utils/price_format.dart';
import '../utils/confirm_order_deletion.dart';
import '../state/realtime_state.dart';

class OwnerTableCenterPanel extends StatefulWidget {
  final String table;
  const OwnerTableCenterPanel({super.key, required this.table});

  @override
  State<OwnerTableCenterPanel> createState() => _OwnerTableCenterPanelState();
}

class _OwnerTableCenterPanelState extends State<OwnerTableCenterPanel> {
  bool _printing = false;
  bool _loadingDetail = false;
  String? _detailLoadedFor;
  String? _lastDetailSummaryKey;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _loadTableDetail());
  }

  @override
  void didUpdateWidget(covariant OwnerTableCenterPanel oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.table != widget.table) {
      _detailLoadedFor = null;
      _lastDetailSummaryKey = null;
      WidgetsBinding.instance.addPostFrameCallback((_) => _loadTableDetail());
    }
  }

  String _summaryKey(OrderState orderState) {
    return '${orderState.summaryItemCountOf(widget.table)}:${orderState.summaryTotalOf(widget.table)}';
  }

  Future<void> _loadTableDetail({bool force = false}) async {
    if (!mounted || _loadingDetail) return;
    if (!force && _detailLoadedFor == widget.table) return;
    final summaryKey = _summaryKey(context.read<OrderState>());
    setState(() => _loadingDetail = true);
    final loaded = await context.read<OrderState>().fetchRealtimeTableDetail(
      widget.table,
    );
    if (!mounted) return;
    setState(() {
      _loadingDetail = false;
      if (loaded) {
        _detailLoadedFor = widget.table;
        _lastDetailSummaryKey = summaryKey;
      }
    });
  }

  @override
  Widget build(BuildContext context) {
    final orderState = context.watch<OrderState>();
    final rtState = context.watch<RealtimeState>();

    final orderData = orderState.orderOf(widget.table);
    final displayOrder =
        orderState.realtimeOrderForDisplay(widget.table) ?? orderData;
    final rtTable = rtState.tables[widget.table] as Map<String, dynamic>?;
    final status = (rtTable?['status'] ?? '').toString();
    final isActive = status == 'ordering';
    final printFailures = rtState.printFailures
        .where((failure) => failure.tableId == widget.table)
        .take(5)
        .toList();

    debugPrint('RT TABLE ${widget.table} status = $status');

    final billing = displayOrder == null
        ? null
        : BillingCalculator.calculateFromLines(displayOrder.lines);
    final currentSummaryKey = _summaryKey(orderState);
    if (_detailLoadedFor == widget.table &&
        _lastDetailSummaryKey != null &&
        _lastDetailSummaryKey != currentSummaryKey &&
        !_loadingDetail) {
      WidgetsBinding.instance.addPostFrameCallback(
        (_) => _loadTableDetail(force: true),
      );
    }

    return Padding(
      padding: const EdgeInsets.all(20),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            widget.table,
            style: const TextStyle(fontSize: 32, fontWeight: FontWeight.bold),
          ),

          const SizedBox(height: 8),

          Text(
            isActive ? '使用中' : '未開始',
            style: TextStyle(
              color: isActive ? Colors.amber : Colors.grey,
              fontWeight: FontWeight.bold,
            ),
          ),

          if (printFailures.isNotEmpty) ...[
            const SizedBox(height: 10),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: Colors.red.withValues(alpha: 0.14),
                border: Border.all(color: Colors.redAccent, width: 1.5),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  const Row(
                    children: [
                      Icon(
                        Icons.warning_amber_rounded,
                        color: Colors.redAccent,
                      ),
                      SizedBox(width: 8),
                      Text(
                        '印刷失敗',
                        style: TextStyle(
                          color: Colors.redAccent,
                          fontWeight: FontWeight.w900,
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  for (final failure in printFailures)
                    Text(
                      '${failure.targetLabel} / ${failure.itemSummary}',
                      style: const TextStyle(fontWeight: FontWeight.w700),
                    ),
                ],
              ),
            ),
          ],

          const Divider(height: 32),

          if (_loadingDetail) ...[
            const LinearProgressIndicator(minHeight: 3),
            const SizedBox(height: 12),
          ],

          // ===== 会計表示 =====
          Column(
            crossAxisAlignment: CrossAxisAlignment.stretch,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  const Text('現在の会計', style: TextStyle(fontSize: 16)),
                  Text(
                    formatYenTruncatedToTen(billing?.total ?? 0),
                    style: const TextStyle(
                      fontSize: 22,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (billing != null) ...[
                const SizedBox(height: 6),
                Align(
                  alignment: Alignment.centerRight,
                  child: Text(
                    '内訳：税 ${formatYen(billing.taxAmount)} / サ ${formatYen(billing.serviceAmount)}',
                    style: const TextStyle(fontSize: 12, color: Colors.white70),
                  ),
                ),
              ],
            ],
          ),

          const SizedBox(height: 16),
          // ===== 注文一覧 =====
          if (displayOrder != null && displayOrder.lines.isNotEmpty)
            SizedBox(
              height: 180,
              child: Builder(
                builder: (context) {
                  final lines = orderState.aggregateLinesForDisplay(
                    displayOrder.lines,
                  );

                  bool isExtension(dynamic l) {
                    final b = (l.brand ?? '').toString();
                    final lab = (l.label ?? '').toString();
                    return b.contains('延長') || lab.contains('延長');
                  }

                  lines.sort((a, b) {
                    final aIsSet = a.category == 'セット';
                    final bIsSet = b.category == 'セット';
                    if (aIsSet && !bIsSet) return -1;
                    if (!aIsSet && bIsSet) return 1;

                    if (aIsSet && bIsSet) {
                      final aExt = isExtension(a);
                      final bExt = isExtension(b);
                      if (!aExt && bExt) return -1;
                      if (aExt && !bExt) return 1;
                    }
                    return 0;
                  });

                  return ListView.builder(
                    itemCount: lines.length,
                    itemBuilder: (context, i) {
                      final l = lines[i];
                      final name = l.label.trim().isEmpty
                          ? l.brand
                          : '${l.brand} ${l.label}';

                      return Container(
                        margin: const EdgeInsets.symmetric(vertical: 4),
                        padding: const EdgeInsets.all(8),
                        decoration: BoxDecoration(
                          color: Colors.white.withOpacity(0.04),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Row(
                          children: [
                            Expanded(
                              flex: 4,
                              child: Text(
                                name,
                                maxLines: 2,
                                overflow: TextOverflow.ellipsis,
                                style: const TextStyle(
                                  fontSize: 15,
                                  fontWeight: FontWeight.w600,
                                ),
                              ),
                            ),
                            Expanded(
                              flex: 2,
                              child: Text(
                                formatYen(l.price),
                                textAlign: TextAlign.right,
                                style: const TextStyle(
                                  fontSize: 14,
                                  color: Colors.amber,
                                  fontWeight: FontWeight.bold,
                                ),
                              ),
                            ),
                            const SizedBox(width: 8),
                            Text(
                              '×${l.qty}',
                              style: const TextStyle(
                                fontSize: 14,
                                fontWeight: FontWeight.bold,
                              ),
                            ),
                          ],
                        ),
                      );
                    },
                  );
                },
              ),
            )
          else
            const Padding(padding: EdgeInsets.all(16), child: Text('注文はありません')),

          // ===== 操作ボタン =====
          Wrap(
            spacing: 12,
            runSpacing: 12,
            alignment: WrapAlignment.center,
            children: [
              ElevatedButton(
                onPressed: isActive
                    ? null
                    : () async {
                        final ok = await orderState.startTable(widget.table);
                        if (!ok && context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('席を開始できませんでした。通信状態を確認してください。'),
                            ),
                          );
                        }
                      },

                child: const Text('注文開始'),
              ),

              ElevatedButton(
                onPressed: () {
                  Navigator.pop(context);
                  Navigator.push(
                    context,
                    MaterialPageRoute(
                      builder: (_) => OwnerAddOrderPage(table: widget.table),
                    ),
                  );
                },
                child: const Text('注文を追加'),
              ),

              OutlinedButton(
                onPressed: (displayOrder == null || displayOrder.lines.isEmpty)
                    ? null
                    : () async {
                        final to = await _selectTableDialog(
                          context,
                          title: '移動先の席を選択',
                          exclude: widget.table,
                        );
                        if (to == null) return;
                        await orderState.moveTable(from: widget.table, to: to);
                        Navigator.pop(context);
                      },
                child: const Text('席移動'),
              ),

              OutlinedButton(
                onPressed: (displayOrder == null || displayOrder.lines.isEmpty)
                    ? null
                    : () async {
                        final to = await _selectTableDialog(
                          context,
                          title: '合算先の席を選択',
                          exclude: widget.table,
                          onlyWithOrder: true,
                        );
                        if (to == null) return;
                        await orderState.mergeTables(
                          from: widget.table,
                          to: to,
                        );
                        if (!mounted) return;
                        if (context.mounted) {
                          Navigator.pop(context);
                        }
                      },
                child: const Text('席合算'),
              ),

              ElevatedButton(
                onPressed:
                    !_printing &&
                        displayOrder != null &&
                        displayOrder.lines.isNotEmpty
                    ? () async {
                        await _printReceipt(context, widget.table);
                      }
                    : null,
                style: ElevatedButton.styleFrom(
                  backgroundColor: Colors.blueGrey,
                ),
                child: _printing
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: Colors.white,
                        ),
                      )
                    : const Text('伝票印刷'),
              ),

              OutlinedButton(
                onPressed: isActive
                    ? () async {
                        final ok = await orderState.endTable(widget.table);
                        if (ok) {
                          if (!context.mounted) return;
                          Navigator.pop(context);
                        } else if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('席を終了できませんでした。通信状態を確認してください。'),
                            ),
                          );
                        }
                      }
                    : null,
                child: const Text('終了'),
              ),

              TextButton(
                onPressed: displayOrder != null && displayOrder.lines.isNotEmpty
                    ? () async {
                        final confirmed = await confirmOrderDeletion(context);
                        if (!confirmed || !context.mounted) return;

                        final ok = await orderState.removeOrdersForTable(
                          widget.table,
                        );
                        if (!ok) {
                          if (!context.mounted) return;
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text('注文削除の同期に失敗しました。再試行してください。'),
                            ),
                          );
                          return;
                        }
                        final ended = await orderState.endTable(widget.table);
                        if (!context.mounted) return;
                        if (!ended) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            const SnackBar(
                              content: Text(
                                '注文は削除しましたが、席を終了できませんでした。もう一度「終了」を押してください。',
                              ),
                            ),
                          );
                          return;
                        }
                        Navigator.pop(context);
                      }
                    : null,
                child: const Text('注文削除', style: TextStyle(color: Colors.red)),
              ),

              TextButton(
                onPressed: () => Navigator.pop(context),
                child: const Text('閉じる'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  // ===== テーブル選択ダイアログ =====
  Future<String?> _selectTableDialog(
    BuildContext context, {
    required String title,
    required String exclude,
    bool onlyWithOrder = false,
  }) async {
    final orderState = context.read<OrderState>();

    final tables = orderState.tables.where((t) {
      if (t == exclude) return false;
      if (onlyWithOrder) {
        return orderState.hasOrderSummary(t);
      }
      return true;
    }).toList();

    if (tables.isEmpty) return null;

    return showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: Text(title),
        content: SizedBox(
          width: 300,
          child: ListView(
            shrinkWrap: true,
            children: tables
                .map(
                  (t) => ListTile(
                    title: Text(t),
                    onTap: () => Navigator.pop(context, t),
                  ),
                )
                .toList(),
          ),
        ),
      ),
    );
  }

  Future<void> _printReceipt(BuildContext context, String tableId) async {
    if (_printing) return;

    setState(() => _printing = true);

    try {
      final res = await http.post(
        ServerConfig.api('/api/print/receipt'),
        headers: {'Content-Type': 'application/json'},
        body: jsonEncode({'tableId': tableId}),
      );

      if (res.statusCode != 200) throw Exception('http error');

      final data = jsonDecode(res.body);
      if (data['success'] != true) throw Exception('print failed');

      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('会計伝票を印刷しました')));
    } catch (_) {
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(const SnackBar(content: Text('印刷に失敗しました')));
    } finally {
      if (mounted) setState(() => _printing = false);
    }
  }
}

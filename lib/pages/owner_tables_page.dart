import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/app_state.dart';
import '../state/order_state.dart';
import '../state/realtime_state.dart';
import '../utils/price_format.dart';
import '../utils/print_failure_announcer.dart';
import 'login_page.dart';
import 'owner_table_center_panel.dart';

class OwnerTablePage extends StatefulWidget {
  const OwnerTablePage({super.key});

  @override
  State<OwnerTablePage> createState() => _OwnerTablePageState();
}

class _OwnerTablePageState extends State<OwnerTablePage> {
  bool _editMode = false;
  RealtimeState? _rtState;
  final Set<String> _announcedPrintFailureIds = {};
  bool _printFailureIdsInitialized = false;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) {
      context.read<RealtimeState>().connectAsOwner();
      context.read<OrderState>().refreshTablesFromServer();
    });
  }

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<RealtimeState>();
    if (_rtState == next) return;
    _rtState?.removeListener(_handlePrintFailures);
    _rtState = next;
    _rtState?.addListener(_handlePrintFailures);
  }

  @override
  void dispose() {
    _rtState?.removeListener(_handlePrintFailures);
    super.dispose();
  }

  void _handlePrintFailures() {
    final failures = _rtState?.printFailures ?? const <PrintFailureNotice>[];
    if (!_printFailureIdsInitialized) {
      _announcedPrintFailureIds.addAll(failures.map((e) => e.id));
      _printFailureIdsInitialized = true;
      return;
    }

    final newFailures =
        failures
            .where((failure) => !_announcedPrintFailureIds.contains(failure.id))
            .toList()
          ..sort((a, b) {
            final aTime = a.at ?? DateTime.fromMillisecondsSinceEpoch(0);
            final bTime = b.at ?? DateTime.fromMillisecondsSinceEpoch(0);
            return aTime.compareTo(bTime);
          });

    for (final failure in newFailures) {
      _announcedPrintFailureIds.add(failure.id);
      announcePrintFailure(failure.announceText);
    }
  }

  @override
  Widget build(BuildContext context) {
    final orderState = context.watch<OrderState>();
    final rtState = context.watch<RealtimeState>();
    final tables = orderState.tables;
    final printFailures = rtState.printFailures;

    return Scaffold(
      appBar: AppBar(
        title: const Text('席管理'),
        actions: [
          IconButton(
            tooltip: _editMode ? '編集モードを終了' : '編集モード',
            icon: Icon(_editMode ? Icons.check_circle : Icons.edit),
            onPressed: () => setState(() => _editMode = !_editMode),
          ),
          IconButton(
            icon: const Icon(Icons.logout),
            tooltip: 'ログアウト',
            onPressed: () async {
              final ok = await showDialog<bool>(
                context: context,
                builder: (_) => AlertDialog(
                  title: const Text('ログアウト'),
                  content: const Text('ログアウトしますか？'),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.pop(context, false),
                      child: const Text('キャンセル'),
                    ),
                    ElevatedButton(
                      onPressed: () => Navigator.pop(context, true),
                      child: const Text('OK'),
                    ),
                  ],
                ),
              );

              if (!context.mounted) return;
              if (ok == true) {
                context.read<AppState>().logout();
                Navigator.pushAndRemoveUntil(
                  context,
                  MaterialPageRoute(builder: (_) => const LoginPage()),
                  (route) => false,
                );
              }
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () => _addTable(context),
        icon: const Icon(Icons.add),
        label: const Text('席を追加'),
      ),
      body: Padding(
        padding: const EdgeInsets.all(50),
        child: Column(
          children: [
            if (printFailures.isNotEmpty) ...[
              _PrintFailureBanner(failures: printFailures.take(5).toList()),
              const SizedBox(height: 20),
            ],
            Expanded(
              child: GridView.builder(
                itemCount: tables.length,
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 4,
                  crossAxisSpacing: 35,
                  mainAxisSpacing: 35,
                  childAspectRatio: 1.10,
                ),
                itemBuilder: (context, index) {
                  final table = tables[index];
                  final isActive = orderState.isActive(table);
                  final hasOrder = orderState.hasOrderSummary(table);
                  final total = orderState.summaryTotalOf(table);

                  return _TableBigNumberCard(
                    table: table,
                    isActive: isActive,
                    hasOrder: hasOrder,
                    total: total,
                    editMode: _editMode,
                    hasPrintFailure: printFailures.any(
                      (failure) => failure.tableId == table,
                    ),
                    onTap: () => _openTableDialog(context, table),
                    onRename: () => _renameTable(context, table),
                    onDelete: hasOrder
                        ? null
                        : () => orderState.removeTable(table),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _addTable(BuildContext context) async {
    final ctrl = TextEditingController();

    final name = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('席を追加'),
        content: TextField(
          controller: ctrl,
          decoration: const InputDecoration(hintText: '例: T13 / VIP4'),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('追加'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (name != null && name.isNotEmpty) {
      context.read<OrderState>().addTable(name);
    }
  }

  Future<void> _renameTable(BuildContext context, String table) async {
    final ctrl = TextEditingController(text: table);

    final newName = await showDialog<String>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('席名を変更'),
        content: TextField(controller: ctrl),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context),
            child: const Text('キャンセル'),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(context, ctrl.text.trim()),
            child: const Text('変更'),
          ),
        ],
      ),
    );

    if (!context.mounted) return;
    if (newName != null && newName.isNotEmpty && newName != table) {
      context.read<OrderState>().renameTable(table, newName);
    }
  }
}

class _TableBigNumberCard extends StatelessWidget {
  final String table;
  final bool isActive;
  final bool hasOrder;
  final int total;
  final bool editMode;
  final bool hasPrintFailure;
  final VoidCallback onTap;
  final VoidCallback onRename;
  final VoidCallback? onDelete;

  const _TableBigNumberCard({
    required this.table,
    required this.isActive,
    required this.hasOrder,
    required this.total,
    required this.editMode,
    required this.hasPrintFailure,
    required this.onTap,
    required this.onRename,
    required this.onDelete,
  });

  @override
  Widget build(BuildContext context) {
    final borderColor = isActive ? Colors.amber : Colors.grey.shade400;
    final bgColor = isActive
        ? Colors.amber.withValues(alpha: 0.16)
        : Colors.grey.shade200;

    return InkWell(
      borderRadius: BorderRadius.circular(18),
      onTap: onTap,
      child: Container(
        decoration: BoxDecoration(
          color: bgColor,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: borderColor, width: 2),
        ),
        padding: const EdgeInsets.all(14),
        child: Stack(
          children: [
            Align(
              alignment: Alignment.topLeft,
              child: Padding(
                padding: const EdgeInsets.only(top: 6, right: 6),
                child: Text(
                  table,
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.2,
                    color: hasOrder ? Colors.amber.shade900 : Colors.black87,
                  ),
                ),
              ),
            ),
            if (isActive && hasOrder)
              Align(
                alignment: Alignment.center,
                child: Text(
                  formatYenTruncatedToTen(total),
                  style: TextStyle(
                    fontSize: 40,
                    fontWeight: FontWeight.w900,
                    color: borderColor,
                  ),
                ),
              ),
            Align(
              alignment: Alignment.bottomCenter,
              child: Padding(
                padding: const EdgeInsets.only(bottom: 6),
                child: isActive
                    ? Text(
                        '使用中',
                        style: TextStyle(
                          fontWeight: FontWeight.w800,
                          color: borderColor,
                        ),
                      )
                    : const Text(
                        '空席',
                        style: TextStyle(
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                          color: Colors.grey,
                        ),
                      ),
              ),
            ),
            if (editMode)
              Align(
                alignment: Alignment.topRight,
                child: Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    IconButton(
                      tooltip: '編集',
                      icon: const Icon(Icons.edit),
                      onPressed: onRename,
                    ),
                    IconButton(
                      tooltip: hasOrder ? '注文があるため削除できません' : '削除',
                      icon: Icon(
                        Icons.delete,
                        color: hasOrder ? Colors.grey : Colors.red,
                      ),
                      onPressed: onDelete,
                    ),
                  ],
                ),
              ),
            if (hasPrintFailure && !editMode)
              const Align(
                alignment: Alignment.topRight,
                child: Icon(
                  Icons.warning_amber_rounded,
                  color: Colors.red,
                  size: 34,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _PrintFailureBanner extends StatelessWidget {
  final List<PrintFailureNotice> failures;

  const _PrintFailureBanner({required this.failures});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.red.withValues(alpha: 0.14),
        border: Border.all(color: Colors.redAccent, width: 2),
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          const Row(
            children: [
              Icon(Icons.volume_up, color: Colors.redAccent),
              SizedBox(width: 8),
              Text(
                '印刷失敗',
                style: TextStyle(
                  fontSize: 18,
                  fontWeight: FontWeight.w900,
                  color: Colors.redAccent,
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          for (final failure in failures)
            Padding(
              padding: const EdgeInsets.only(top: 4),
              child: Text(
                '席 ${failure.tableId} / ${failure.targetLabel} / ${failure.itemSummary}',
                style: const TextStyle(
                  fontSize: 14,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ),
        ],
      ),
    );
  }
}

void _openTableDialog(BuildContext context, String table) {
  showDialog(
    context: context,
    barrierDismissible: true,
    builder: (_) => Dialog(
      insetPadding: const EdgeInsets.all(24),
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      child: SizedBox(width: 520, child: OwnerTableCenterPanel(table: table)),
    ),
  );
}

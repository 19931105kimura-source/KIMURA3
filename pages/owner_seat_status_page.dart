import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/order_state.dart';
import '../utils/price_format.dart';
import '../../billing/billing_calculator.dart';

enum _SeatSortMode { ownerOrder, remainingTime }

class OwnerSeatStatusPage extends StatefulWidget {
  const OwnerSeatStatusPage({super.key});
  
 @override
  State<OwnerSeatStatusPage> createState() => _OwnerSeatStatusPageState();
}

class _OwnerSeatStatusPageState extends State<OwnerSeatStatusPage> {
  _SeatSortMode _sortMode = _SeatSortMode.ownerOrder;
  static const _bgTop = Color(0xFF0F172A);
  static const _bgBottom = Color(0xFF111827);
  static const _accent = Color(0xFF22D3EE);
  static const _accent2 = Color(0xFF6366F1);
  String _formatRemaining(int sec) {
    final safe = sec < 0 ? 0 : sec;
    final h = safe ~/ 3600;
    final m = (safe % 3600) ~/ 60;
    final s = safe % 60;
    if (h > 0) {
      return '${h}時間${m.toString().padLeft(2, '0')}分';
    }
    return '${m}分${s.toString().padLeft(2, '0')}秒';
  }

  @override
  Widget build(BuildContext context) {
    final orderState = context.watch<OrderState>();
    final activeTables = orderState.tables.where(orderState.isActive).toList();
    final tableIndex = {
      for (var i = 0; i < orderState.tables.length; i++) orderState.tables[i]: i,
    };
    if (_sortMode == _SeatSortMode.remainingTime) {
      activeTables.sort((a, b) {
        final aTimer = orderState.timerOf(a);
        final bTimer = orderState.timerOf(b);
        final aRemain = aTimer?.remainingSeconds ?? 1 << 30;
        final bRemain = bTimer?.remainingSeconds ?? 1 << 30;
        if (aRemain != bRemain) return aRemain.compareTo(bRemain);
        return (tableIndex[a] ?? 1 << 20).compareTo(tableIndex[b] ?? 1 << 20);
      });
    }
    
  return Scaffold(
      appBar: AppBar(
        elevation: 0,
        backgroundColor: _bgTop,
        title: Text(
          '使用中の席（${activeTables.length}）',
          style: const TextStyle(
            fontWeight: FontWeight.w900,
            letterSpacing: 0.8,
          ),
        ),
        actions: [
          PopupMenuButton<_SeatSortMode>(
            tooltip: '並び替え',
            icon: const Icon(Icons.sort),
            initialValue: _sortMode,
            onSelected: (mode) => setState(() => _sortMode = mode),
            itemBuilder: (context) => const [
              PopupMenuItem(
                value: _SeatSortMode.ownerOrder,
                child: Text('席順（オーナー管理順）'),
              ),
              PopupMenuItem(
                value: _SeatSortMode.remainingTime,
                child: Text('残り時間が少ない順'),
              ),
            ],
          ),
        ],
      ),
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [_bgTop, _bgBottom],
          ),
        ),
        child: activeTables.isEmpty
            ? const Center(
                child: Text(
                '現在使用中の席はありません',
                style: TextStyle(
                  fontSize: 16,
                  fontWeight: FontWeight.w700,
                  color: Colors.white70,
                ),
              ),
            )
            : GridView.builder(
                padding: const EdgeInsets.all(16),
                gridDelegate: const SliverGridDelegateWithMaxCrossAxisExtent(
                  maxCrossAxisExtent: 260,
                  mainAxisSpacing: 12,
                  crossAxisSpacing: 12,
                  childAspectRatio: 1.0,
                ),
                itemCount: activeTables.length,
                itemBuilder: (context, index) {
                  final table = activeTables[index];
                  final order = orderState.orderForDisplay(table);
                  final total = order == null
                      ? 0
                      : BillingCalculator.calculateFromLines(order.lines).total;
                  final timer = orderState.timerOf(table);

                  return Container(
                    decoration: BoxDecoration(
                      borderRadius: BorderRadius.circular(16),
                      gradient: LinearGradient(
                        begin: Alignment.topLeft,
                        end: Alignment.bottomRight,
                        colors: [
                          Colors.white.withValues(alpha: 0.10),
                          Colors.white.withValues(alpha: 0.03),
                        ],
                      ),
                      border: Border.all(
                        color: _accent.withValues(alpha: 0.35),
                        width: 1.2,
                      ),
                      boxShadow: [
                        BoxShadow(
                          color: _accent2.withValues(alpha: 0.18),
                          blurRadius: 16,
                          offset: const Offset(0, 6),
                        ),
                      ],
                    ),
                    child: Padding(
                      padding: const EdgeInsets.all(12),
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            '席 $table',
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: Colors.white,
                              letterSpacing: 1.0,
                            ),
                          ),
                          const Spacer(),
                          Text(
                            '会計金額',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.74),
                            ),
                          ),
                          Text(
                            formatYenTruncatedToTen(total),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 24,
                              fontWeight: FontWeight.w900,
                              color: _accent,
                            ),
                          ),
                          const SizedBox(height: 8),
                          Text(
                            '残り時間',
                            style: TextStyle(
                              fontSize: 13,
                              color: Colors.white.withValues(alpha: 0.74),
                            ),
                          ),
                          Text(
                            timer == null
                                ? '--'
                                : _formatRemaining(timer.remainingSeconds),
                            maxLines: 1,
                            overflow: TextOverflow.ellipsis,
                            style: const TextStyle(
                              fontSize: 22,
                              fontWeight: FontWeight.bold,
                              color: Colors.white,
                            ),
                          ),
                        ],
                      ),
                    ),
                  );
                },
              ),
      ),
    );
  }
}
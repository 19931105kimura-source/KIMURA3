import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../state/order_state.dart';
import '../utils/price_format.dart';

class OwnerSeatStatusPage extends StatelessWidget {
  const OwnerSeatStatusPage({super.key});

  static const _bgTop = Color(0xFF0F172A);
  static const _bgBottom = Color(0xFF111827);
  static const _accent = Color(0xFF22D3EE);
  static const _accent2 = Color(0xFF6366F1);

  @override
  Widget build(BuildContext context) {
    final orderState = context.watch<OrderState>();
    final activeTables = orderState.tables.where(orderState.isActive).toList();

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
                  final total = orderState.summaryTotalOf(table);

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
                      child: Stack(
                        children: [
                          Align(
                            alignment: Alignment.topLeft,
                            child: Text(
                              '席 $table',
                              style: const TextStyle(
                                fontSize: 24,
                                fontWeight: FontWeight.w900,
                                color: Colors.white,
                                letterSpacing: 1.0,
                              ),
                            ),
                          ),
                          Center(
                            child: Padding(
                              padding: const EdgeInsets.symmetric(
                                horizontal: 8,
                              ),
                              child: Column(
                                mainAxisSize: MainAxisSize.min,
                                children: [
                                  Text(
                                    '会計金額',
                                    style: TextStyle(
                                      fontSize: 14,
                                      color: Colors.white.withValues(
                                        alpha: 0.74,
                                      ),
                                    ),
                                  ),
                                  const SizedBox(height: 6),
                                  FittedBox(
                                    fit: BoxFit.scaleDown,
                                    child: Text(
                                      formatYenTruncatedToTen(total),
                                      maxLines: 1,
                                      style: const TextStyle(
                                        fontSize: 36,
                                        fontWeight: FontWeight.w900,
                                        color: _accent,
                                      ),
                                    ),
                                  ),
                                ],
                              ),
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

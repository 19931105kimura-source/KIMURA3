// lib/repository/shared_order_repository.dart

import '../model/shared_order.dart';

class SharedOrderRepository {
  // ==========================
  // 席ごとの注文履歴
  // key: tableId
  // ==========================
  final Map<String, List<Order>> _ordersByTable = {};

  // ==========================
  // 注文を追加
  // ==========================
  void addOrder(Order order) {
    final list = _ordersByTable.putIfAbsent(
      order.tableId,
      () => <Order>[],
    );
    list.add(order);
  }

  // ==========================
  // 席の注文履歴を取得
  // ==========================
  List<Order> getOrders(String tableId) {
    return List.unmodifiable(
      _ordersByTable[tableId] ?? const [],
    );
  }

  // ==========================
  // 席の合計金額（表示用）
  // ==========================
  int getTotalAmount(String tableId) {
    return getOrders(tableId)
        .fold(0, (sum, o) => sum + o.total);
  }

  // ==========================
  // 席の注文があるか
  // ==========================
  bool hasOrders(String tableId) {
    return _ordersByTable[tableId]?.isNotEmpty ?? false;
  }
}

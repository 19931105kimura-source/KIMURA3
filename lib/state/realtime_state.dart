import 'dart:async';

import 'package:flutter/material.dart';
import '../services/websocket_service.dart';
import 'order_state.dart';

class RealtimeState extends ChangeNotifier with WidgetsBindingObserver {
  final OrderState orderState;
  final WebSocketService _ws = WebSocketService();

  bool _connected = false;
  bool _connecting = false;
  Timer? _reconnectTimer;
  Timer? _snapshotTimeoutTimer;
  int _connectionGeneration = 0;

  RealtimeState(this.orderState) {
    WidgetsBinding.instance.addObserver(this);
  }

  Map<String, dynamic> _snapshot = {};
  DateTime? _lastSnapshotAt;

  Map<String, dynamic> get snapshot => _snapshot;
  DateTime? get lastSnapshotAt => _lastSnapshotAt;
  bool get connected => _connected;
  bool get connecting => _connecting;

  Map<String, dynamic> tables = {};
  Map<String, dynamic> ordersByTable = {};
  Map<String, dynamic> orderItems = {};

  void applySnapshot(Map<String, dynamic> payload) {
    debugPrint('SNAPSHOT RECEIVED');
    _snapshotTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    _connected = true;
    _connecting = false;
    _snapshot = payload;
    _lastSnapshotAt = DateTime.now();

    tables = Map<String, dynamic>.from(payload['tables'] ?? {});
    ordersByTable = Map<String, dynamic>.from(payload['ordersByTable'] ?? {});
    orderItems = Map<String, dynamic>.from(payload['orderItems'] ?? {});

    orderState.applyRealtimeSnapshot(payload);
    notifyListeners();
  }

  void connect({bool force = false}) {
    if (_connecting) return;
    if (_connected && !force) return;

    final generation = ++_connectionGeneration;
    _reconnectTimer?.cancel();
    _snapshotTimeoutTimer?.cancel();
    if (force) {
      _connected = false;
      orderState.markNeedsResync();
    }
    _connecting = true;
    notifyListeners();

    _ws.connect(
      (payload) {
        if (generation != _connectionGeneration) return;
        applySnapshot(payload);
      },
      onConnected: () {
        if (generation != _connectionGeneration) return;
        _snapshotTimeoutTimer = Timer(const Duration(seconds: 8), () {
          if (generation != _connectionGeneration || _connected) return;
          _connectionGeneration++;
          _connecting = false;
          _connected = false;
          orderState.markNeedsResync();
          _ws.dispose();
          _scheduleReconnect();
          notifyListeners();
        });
      },
      onDisconnected: () {
        if (generation != _connectionGeneration) return;
        _snapshotTimeoutTimer?.cancel();
        _connected = false;
        _connecting = false;
        orderState.markNeedsResync();
        _scheduleReconnect();
        notifyListeners();
      },
    );
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 2), () => connect());
  }

  void reconnectNow() {
    _connectionGeneration++;
    _snapshotTimeoutTimer?.cancel();
    _reconnectTimer?.cancel();
    _connected = false;
    _connecting = false;
    orderState.markNeedsResync();
    _ws.dispose();
    connect(force: true);
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    if (state == AppLifecycleState.resumed) {
      reconnectNow();
      return;
    }

    if (state == AppLifecycleState.paused ||
        state == AppLifecycleState.inactive ||
        state == AppLifecycleState.detached) {
      orderState.markNeedsResync();
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _reconnectTimer?.cancel();
    _snapshotTimeoutTimer?.cancel();
    _connectionGeneration++;
    _ws.dispose();
    super.dispose();
  }
}

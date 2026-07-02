import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

// ---- data ----
import 'data/menu_data.dart';
import 'data/cast_data.dart';
import 'data/cast_drink_data.dart';
import 'data/other_item_data.dart';

// ---- state ----
import 'state/app_state.dart';
import 'state/cart_state.dart';
import 'state/order_state.dart';
import 'state/promo_state.dart';
import 'state/set_data.dart';
import 'state/realtime_state.dart';
import 'state/diagnostic_log_state.dart';

// ---- pages ----
import 'pages/login_page.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();

  // 起動前ロード
  final menuData = MenuData();
  await menuData.load();

  final orderState = OrderState();
  await orderState.load();

  runApp(
    MultiProvider(
      providers: [
        // --- core ---
        ChangeNotifierProvider(create: (_) => AppState()),
        ChangeNotifierProvider(create: (_) => CartState()),
        ChangeNotifierProvider(create: (_) => PromoState()),
        ChangeNotifierProvider(create: (_) => SetData()),
        ChangeNotifierProvider.value(value: DiagnosticLogState.instance),

        // --- master data ---
        ChangeNotifierProvider(create: (_) => CastData()),
        ChangeNotifierProvider(create: (_) => CastDrinkData()),
        ChangeNotifierProvider(create: (_) => OtherItemData()),
        ChangeNotifierProvider(create: (_) => menuData),

        // --- order / realtime ---
        ChangeNotifierProvider(create: (_) => orderState),
        ChangeNotifierProvider(create: (_) => RealtimeState(orderState)),
      ],
      child: const GlobalRealtimeRefresh(child: MyApp()),
    ),
  );
}

class GlobalRealtimeRefresh extends StatefulWidget {
  final Widget child;

  const GlobalRealtimeRefresh({super.key, required this.child});

  @override
  State<GlobalRealtimeRefresh> createState() => _GlobalRealtimeRefreshState();
}

class _GlobalRealtimeRefreshState extends State<GlobalRealtimeRefresh> {
  RealtimeState? _realtime;
  int _seenGlobalUpdateSeq = 0;
  bool _refreshing = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    final next = context.read<RealtimeState>();
    if (_realtime == next) return;
    _realtime?.removeListener(_handleRealtimeChanged);
    _realtime = next;
    _realtime?.addListener(_handleRealtimeChanged);
  }

  @override
  void dispose() {
    _realtime?.removeListener(_handleRealtimeChanged);
    super.dispose();
  }

  void _handleRealtimeChanged() {
    final realtime = _realtime;
    if (realtime == null) return;
    final seq = realtime.globalUpdateSeq;
    if (seq <= 0 || seq == _seenGlobalUpdateSeq || _refreshing) return;

    _seenGlobalUpdateSeq = seq;
    _refreshing = true;
    final menuData = context.read<MenuData>();
    final castData = context.read<CastData>();
    final castDrinkData = context.read<CastDrinkData>();
    final promoState = context.read<PromoState>();
    Future.microtask(() async {
      try {
        final kind = realtime.globalUpdateKind;
        if (kind == 'menu') {
          await menuData.load();
          await Future.wait([castData.load(), castDrinkData.load()]);
        } else if (kind == 'promos') {
          await promoState.load();
        }
      } finally {
        _refreshing = false;
      }
    });
  }

  @override
  Widget build(BuildContext context) => widget.child;
}

class MyApp extends StatelessWidget {
  const MyApp({super.key});

  @override
  Widget build(BuildContext context) {
    return MaterialApp(
      debugShowCheckedModeBanner: false,
      theme: ThemeData.dark(),
      home: const LoginPage(),
    );
  }
}

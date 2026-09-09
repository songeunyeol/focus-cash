import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../design/ds.dart';
import '../../providers/auth_provider.dart';
import '../../services/credit_service.dart';
import '../../services/server_api.dart';
import '../../services/store_service.dart';
import '../../widgets/credit_display.dart';
import 'store_exchange_tab.dart';
import 'store_raffle_tab.dart';
import 'store_roulette_tab.dart';

/// 상점 — 응모 · 룰렛 · 교환.
///
/// 계기 모드. 글로우·그라디언트·등급색 무지개는 걷어내고 불꽃 액센트만 남긴다.
/// 당첨 다이얼로그만 보상 모드다.
class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  final CreditService _creditService = CreditService();
  final StoreService _storeService = StoreService();
  final ServerApi _serverApi = ServerApi();

  static const List<String> _tabs = <String>['응모방', '룰렛', '교환'];

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: _tabs.length, vsync: this);
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final int credits =
        context.watch<AuthProvider>().user?.totalCredits ?? 0;

    return Scaffold(
        backgroundColor: c.bg,
        appBar: AppBar(
          title: const Text('상점'),
          actions: <Widget>[
            Padding(
              padding: const EdgeInsets.only(right: Sp.x4),
              child: CreditDisplay(credits: credits),
            ),
          ],
          bottom: PreferredSize(
            preferredSize: const Size.fromHeight(44),
            child: Container(
              decoration: BoxDecoration(
                border: Border(
                  bottom: BorderSide(
                      color: c.borderSubtle, width: Stroke.hairline),
                ),
              ),
              child: TabBar(
                controller: _tabController,
                labelStyle: DsType.label,
                unselectedLabelStyle: DsType.label,
                labelColor: c.textPrimary,
                unselectedLabelColor: c.textTertiary,
                indicatorColor: c.flame,
                indicatorSize: TabBarIndicatorSize.label,
                indicatorWeight: Stroke.thick,
                dividerColor: Colors.transparent,
                splashFactory: NoSplash.splashFactory,
                overlayColor:
                    const WidgetStatePropertyAll<Color>(Colors.transparent),
                tabs: _tabs.map((String t) => Tab(text: t)).toList(),
              ),
            ),
          ),
        ),
        body: TabBarView(
          controller: _tabController,
          children: <Widget>[
            StoreRaffleTab(
              storeService: _storeService,
              creditService: _creditService,
            ),
            StoreRouletteTab(
              storeService: _storeService,
              creditService: _creditService,
              serverApi: _serverApi,
            ),
            StoreExchangeTab(
              storeService: _storeService,
              creditService: _creditService,
              serverApi: _serverApi,
            ),
          ],
        ),
    );
  }
}

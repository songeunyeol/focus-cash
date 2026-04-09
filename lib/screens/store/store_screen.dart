import 'dart:convert';
import 'dart:math';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';
import '../../config/theme.dart';
import '../../config/constants.dart';
import '../../models/store_item.dart';
import '../../models/roulette_config.dart';
import '../../models/raffle_room.dart';
import '../../models/gifticon_code.dart';
import '../../providers/auth_provider.dart';
import '../../services/credit_service.dart';
import '../../services/store_service.dart';
import '../../widgets/credit_display.dart';

class StoreScreen extends StatefulWidget {
  const StoreScreen({super.key});

  @override
  State<StoreScreen> createState() => _StoreScreenState();
}

class _StoreScreenState extends State<StoreScreen>
    with SingleTickerProviderStateMixin {
  late TabController _tabController;
  late FixedExtentScrollController _slotController;
  bool _isSpinning = false;
  int _lastHapticItem = -1;
  final CreditService _creditService = CreditService();
  final StoreService _storeService = StoreService();

  // 기프티콘 재고 캐시 (storeItemId → 남은 수량)
  Map<String, int> _gifticonStocks = {};
  bool _stocksLoading = false;
  String _lastStockIdsKey = '';

  void _maybeRefreshStocks(RouletteConfig config) {
    final ids = config.prizes
        .where((p) => p.gifticonStoreItemId != null)
        .map((p) => p.gifticonStoreItemId!)
        .toList()
      ..sort();
    final key = ids.join(',');
    if (key == _lastStockIdsKey || _stocksLoading) return;
    _lastStockIdsKey = key;
    if (ids.isEmpty) {
      setState(() => _gifticonStocks = {});
      return;
    }
    _stocksLoading = true;
    _storeService.getAvailableCounts(ids).then((stocks) {
      if (mounted) {
        setState(() {
          _gifticonStocks = stocks;
          _stocksLoading = false;
        });
      }
    }).catchError((_) {
      if (mounted) setState(() => _stocksLoading = false);
    });
  }

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    _slotController = FixedExtentScrollController(initialItem: 1);
    _slotController.addListener(_onSlotScroll);
  }

  void _onSlotScroll() {
    if (!_isSpinning) return;
    final current = _slotController.selectedItem;
    if (current != _lastHapticItem) {
      _lastHapticItem = current;
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _tabController.dispose();
    _slotController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return Scaffold(
      backgroundColor: AppTheme.of(context).storeBg,
      appBar: AppBar(
        backgroundColor: AppTheme.of(context).storeBg,
        title: ShaderMask(
          shaderCallback: (bounds) =>
              AppTheme.primaryGradient.createShader(bounds),
          child: const Text(
            '상점',
            style: TextStyle(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: 22,
            ),
          ),
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: 16),
            child: CreditDisplay(credits: user?.totalCredits ?? 0),
          ),
        ],
        bottom: TabBar(
          controller: _tabController,
          indicatorColor: AppTheme.primaryColor,
          indicatorWeight: 3,
          indicatorSize: TabBarIndicatorSize.label,
          labelColor: AppTheme.primaryColor,
          unselectedLabelColor: AppTheme.of(context).textMuted,
          labelStyle: const TextStyle(
            fontWeight: FontWeight.w700,
            fontSize: 14,
          ),
          tabs: const [
            Tab(icon: Icon(Icons.emoji_events_outlined, size: 18), text: '응모방'),
            Tab(icon: Icon(Icons.casino_outlined, size: 18), text: '룰렛'),
            Tab(icon: Icon(Icons.card_giftcard_outlined, size: 18), text: '교환'),
          ],
        ),
      ),
      body: TabBarView(
        controller: _tabController,
        children: [
          _buildRaffleTab(),
          _buildRouletteTab(),
          _buildExchangeTab(),
        ],
      ),
    );
  }

  // ───────────────────────────────────────────
  // 교환 탭 (2열 그리드)
  // ───────────────────────────────────────────

  Widget _buildExchangeTab() {
    return StreamBuilder<List<StoreItem>>(
      stream: _storeService.watchStoreItems(),
      builder: (context, snapshot) {
        if (snapshot.hasError || !snapshot.hasData) {
          return _buildExchangeGrid(_fallbackItems());
        }
        final items = snapshot.data!;
        if (items.isEmpty) return _buildExchangeGrid(_fallbackItems());
        return _buildExchangeGridFromStore(items);
      },
    );
  }

  List<Map<String, dynamic>> _fallbackItems() => [
        {'name': '편의점 1,000원 쿠폰', 'cost': 1500, 'icon': Icons.store},
        {'name': 'GS25 5,000원 쿠폰', 'cost': 7000, 'icon': Icons.card_giftcard},
        {
          'name': '스타벅스 아메리카노',
          'cost': AppConstants.coffeeCouponCost,
          'icon': Icons.coffee
        },
        {'name': '배달의민족 5,000원', 'cost': 7500, 'icon': Icons.delivery_dining},
        {'name': '투썸 케이크 세트', 'cost': 13000, 'icon': Icons.cake},
        {'name': 'CGV 영화 1매', 'cost': 21000, 'icon': Icons.movie},
      ];

  Widget _buildExchangeGridFromStore(List<StoreItem> items) {
    final user = context.watch<AuthProvider>().user;
    final userCredits = user?.totalCredits ?? 0;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final canAfford = userCredits >= item.cost;
        return _ExchangeListTile(
          name: item.name,
          cost: item.cost,
          icon: IconData(item.iconCode, fontFamily: 'MaterialIcons'),
          canAfford: canAfford,
          onTap: () =>
              _showExchangeBottomSheet(item.id, item.name, item.cost),
        );
      },
    );
  }

  Widget _buildExchangeGrid(List<Map<String, dynamic>> items) {
    final user = context.watch<AuthProvider>().user;
    final userCredits = user?.totalCredits ?? 0;

    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      itemCount: items.length,
      itemBuilder: (context, index) {
        final item = items[index];
        final cost = item['cost'] as int;
        final canAfford = userCredits >= cost;
        return _ExchangeListTile(
          name: item['name'] as String,
          cost: cost,
          icon: item['icon'] as IconData,
          canAfford: false,
          onTap: () => ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('상품 데이터를 불러오는 중입니다. 잠시 후 다시 시도하세요.')),
          ),
          unavailableReason: canAfford ? '준비 중' : null,
        );
      },
    );
  }

  Future<void> _showExchangeBottomSheet(
      String storeItemId, String itemName, int cost) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final available = await _storeService.getAvailableCount(storeItemId);
    if (!mounted) return;

    if (available == 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('재고가 없습니다. 곧 충전될 예정입니다.')),
      );
      return;
    }

    final confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _ExchangeBottomSheet(
          itemName: itemName, cost: cost, stockCount: available),
    );

    if (confirmed != true || !mounted) return;

    final success = await _creditService.spendCredits(
      userId: user.uid,
      amount: cost,
      description: '$itemName 교환',
    );

    if (!mounted) return;
    if (!success) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('크레딧이 부족합니다')),
      );
      return;
    }

    final gifticonCode = await _storeService.redeemGifticon(
      storeItemId: storeItemId,
      userId: user.uid,
    );

    if (!mounted) return;
    context.read<AuthProvider>().loadUser();

    if (gifticonCode != null) {
      _showGifticonResultDialog(gifticonCode);
    } else {
      await _creditService.addCredits(
        userId: user.uid,
        amount: cost,
        description: '$itemName 교환 환불 (재고 소진)',
      );
      if (mounted) {
        context.read<AuthProvider>().loadUser();
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('재고가 소진되었습니다. 크레딧이 환불됩니다.')),
        );
      }
    }
  }

  void _showGifticonResultDialog(GifticonCode gifticonCode) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (context) => Dialog(
        backgroundColor: AppTheme.of(context).card,
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        child: Padding(
          padding: const EdgeInsets.all(24),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Row(
                mainAxisSize: MainAxisSize.min,
                children: const [
                  Icon(Icons.card_giftcard_outlined,
                      color: AppTheme.creditGold, size: 22),
                  SizedBox(width: 8),
                  Text('교환 완료!',
                      style: TextStyle(
                          color: AppTheme.creditGold,
                          fontSize: 20,
                          fontWeight: FontWeight.bold)),
                ],
              ),
              SizedBox(height: 4),
              Text(gifticonCode.storeItemName,
                  style: TextStyle(
                      color: AppTheme.of(context).textSecondary, fontSize: 13)),
              const SizedBox(height: 20),
              if (gifticonCode.imageBase64.isNotEmpty)
                ClipRRect(
                  borderRadius: BorderRadius.circular(12),
                  child: Image.memory(
                    base64Decode(gifticonCode.imageBase64),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
              if (gifticonCode.imageBase64.isNotEmpty)
                SizedBox(height: 16),
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: 16, vertical: 14),
                decoration: BoxDecoration(
                  color: AppTheme.of(context).surface,
                  borderRadius: BorderRadius.circular(12),
                  border: Border.all(
                      color: AppTheme.primaryColor
                          .withValues(alpha: 0.3)),
                ),
                child: Column(
                  children: [
                    Text('기프티콘 코드',
                        style: TextStyle(
                            color: AppTheme.of(context).textSecondary,
                            fontSize: 12)),
                    SizedBox(height: 6),
                    SelectableText(
                      gifticonCode.code,
                      style: TextStyle(
                        color: AppTheme.of(context).textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 1.5,
                        fontFamily: 'monospace',
                      ),
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              SizedBox(height: 8),
              Text('코드를 길게 눌러 복사하세요',
                  style: TextStyle(
                      color: AppTheme.of(context).textSecondary, fontSize: 11)),
              const SizedBox(height: 20),
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  // ───────────────────────────────────────────
  // 룰렛 탭
  // ───────────────────────────────────────────

  static const _rarityColors = [
    Color(0xFF78909C),
    Color(0xFF42A5F5),
    Color(0xFF66BB6A),
    Color(0xFFAB47BC),
    Color(0xFFFF7043),
    Color(0xFFFFD700),
  ];

  static const double _slotItemExtent = 68.0;

  Widget _buildRouletteTab() {
    final user = context.watch<AuthProvider>().user;

    return StreamBuilder<RouletteConfig>(
      stream: _storeService.watchRouletteConfig(),
      builder: (context, snapshot) {
        final config = snapshot.data ?? RouletteConfig.defaultConfig;
        WidgetsBinding.instance.addPostFrameCallback(
            (_) { if (mounted) _maybeRefreshStocks(config); });
        return SingleChildScrollView(
          padding: const EdgeInsets.all(20),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // 남은 스핀 횟수 표시
              if (user != null)
                FutureBuilder<int>(
                  future: _storeService.getRemainingSpins(
                      user.uid, config.dailySpinLimit),
                  builder: (context, spinSnap) {
                    final remaining = spinSnap.data ?? config.dailySpinLimit;
                    return Container(
                      width: double.infinity,
                      padding: const EdgeInsets.symmetric(
                          horizontal: 16, vertical: 10),
                      margin: const EdgeInsets.only(bottom: 16),
                      decoration: BoxDecoration(
                        color: AppTheme.of(context).surface,
                        borderRadius: BorderRadius.circular(12),
                      ),
                      child: Row(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          Icon(Icons.refresh,
                              size: 16, color: AppTheme.of(context).textSecondary),
                          SizedBox(width: 8),
                          Text(
                            '오늘 남은 횟수: $remaining/${config.dailySpinLimit}',
                            style: TextStyle(
                              color: remaining > 0
                                  ? AppTheme.of(context).textPrimary
                                  : AppTheme.of(context).textSecondary,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                        ],
                      ),
                    );
                  },
                ),
              _buildSlotMachine(config),
              SizedBox(height: 16),
              SizedBox(
                width: double.infinity,
                height: 52,
                child: ElevatedButton(
                  onPressed: _isSpinning ? null : () => _spinRoulette(config),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: _isSpinning
                        ? AppTheme.of(context).surface
                        : AppTheme.secondaryColor,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _isSpinning
                      ? const Text('돌아가는 중...',
                          style: TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold))
                      : Text('돌리기  (${config.cost} 크레딧)',
                          style: const TextStyle(
                              fontSize: 16, fontWeight: FontWeight.bold)),
                ),
              ),
              const SizedBox(height: 28),
              _buildProbabilityTable(config),
            ],
          ),
        );
      },
    );
  }

  Widget _buildProbabilityTable(RouletteConfig config) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(14),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('당첨 확률표',
              style: TextStyle(
                  color: AppTheme.of(context).textPrimary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14)),
          const SizedBox(height: 10),
          ...List.generate(config.prizes.length, (i) {
            final prize = config.prizes[i];
            final color = _rarityColors[i.clamp(0, _rarityColors.length - 1)];
            final isGifticon = prize.gifticonStoreItemId != null;
            final isSoldOut = isGifticon &&
                (_gifticonStocks[prize.gifticonStoreItemId] ?? 1) == 0;
            final totalWeight =
                config.prizes.fold(0, (sum, p) => sum + p.probability);
            final pct = totalWeight > 0
                ? (prize.probability / totalWeight * 100)
                : 0.0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: 5),
              child: Opacity(
                opacity: isSoldOut ? 0.4 : 1.0,
                child: Row(
                  children: [
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                          color: isSoldOut ? Colors.grey : color,
                          shape: BoxShape.circle),
                    ),
                    SizedBox(width: 10),
                    Expanded(
                      child: Row(
                        children: [
                          Text(prize.name,
                              style: TextStyle(
                                  color: isSoldOut
                                      ? AppTheme.of(context).textSecondary
                                      : AppTheme.of(context).textSecondary,
                                  fontSize: 13)),
                          if (isGifticon) ...[
                            const SizedBox(width: 6),
                            Container(
                              padding: const EdgeInsets.symmetric(
                                  horizontal: 5, vertical: 2),
                              decoration: BoxDecoration(
                                color: isSoldOut
                                    ? Colors.grey.withValues(alpha: 0.15)
                                    : AppTheme.primaryColor
                                        .withValues(alpha: 0.15),
                                borderRadius: BorderRadius.circular(4),
                              ),
                              child: Text(
                                isSoldOut ? '품절' : '기프티콘',
                                style: TextStyle(
                                    color: isSoldOut
                                        ? Colors.redAccent
                                        : AppTheme.primaryColor,
                                    fontSize: 10),
                              ),
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isGifticon)
                      Text('+${prize.credits}C',
                          style: TextStyle(
                              color: color,
                              fontWeight: FontWeight.bold,
                              fontSize: 13)),
                    SizedBox(width: 12),
                    Text('${pct.toStringAsFixed(1)}%',
                        style: TextStyle(
                            color: AppTheme.of(context).textSecondary, fontSize: 13)),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildSlotMachine(RouletteConfig config) {
    const windowHeight = _slotItemExtent * 3;
    return AnimatedContainer(
      duration: Duration(milliseconds: 300),
      decoration: BoxDecoration(
        color: AppTheme.of(context).surface,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: _isSpinning
              ? AppTheme.creditGold
              : AppTheme.primaryColor.withValues(alpha: 0.24),
          width: _isSpinning ? 2.0 : 1.5,
        ),
        boxShadow: _isSpinning
            ? [
                BoxShadow(
                  color: AppTheme.creditGold.withValues(alpha: 0.31),
                  blurRadius: 16,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: [
          SizedBox(
            height: windowHeight,
            child: ListWheelScrollView.useDelegate(
              controller: _slotController,
              physics: const NeverScrollableScrollPhysics(),
              itemExtent: _slotItemExtent,
              perspective: 0.004,
              diameterRatio: 3.5,
              childDelegate: ListWheelChildLoopingListDelegate(
                children: List.generate(
                  config.prizes.length,
                  (i) => _buildSlotItem(
                    config.prizes[i],
                    i,
                    config.prizes.fold(0, (s, p) => s + p.probability),
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Divider(
                    color: AppTheme.primaryColor, thickness: 1.5, height: 0),
                const SizedBox(height: _slotItemExtent),
                Divider(
                    color: AppTheme.primaryColor, thickness: 1.5, height: 0),
              ],
            ),
          ),
          IgnorePointer(
            child: SizedBox(
              height: windowHeight,
              child: Column(
                children: [
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: [
                            AppTheme.of(context).surface,
                            AppTheme.of(context).surface.withValues(alpha: 0),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                            top: Radius.circular(20)),
                      ),
                    ),
                  ),
                  SizedBox(height: _slotItemExtent),
                  Expanded(
                    child: Container(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: [
                            AppTheme.of(context).surface,
                            AppTheme.of(context).surface.withValues(alpha: 0),
                          ],
                        ),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(20)),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSlotItem(RoulettePrize prize, int index, int totalWeight) {
    final color = _rarityColors[index.clamp(0, _rarityColors.length - 1)];
    final isGifticon = prize.gifticonStoreItemId != null;
    final isSoldOut = isGifticon &&
        (_gifticonStocks[prize.gifticonStoreItemId] ?? 1) == 0;
    final pct = totalWeight > 0
        ? (prize.probability / totalWeight * 100)
        : 0.0;
    return SizedBox(
      height: _slotItemExtent,
      child: Opacity(
        opacity: isSoldOut ? 0.4 : 1.0,
        child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20),
        child: Row(
          children: [
            Container(
              width: 36,
              height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.12),
                shape: BoxShape.circle,
              ),
              child: Icon(
                isGifticon ? Icons.card_giftcard : Icons.toll,
                color: color,
                size: 20,
              ),
            ),
            SizedBox(width: 14),
            Expanded(
              child: Column(
                mainAxisAlignment: MainAxisAlignment.center,
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(prize.name,
                      style: TextStyle(
                          color: AppTheme.of(context).textPrimary,
                          fontWeight: FontWeight.w600,
                          fontSize: 14)),
                  Text(
                    isSoldOut ? '품절' : '${pct.toStringAsFixed(1)}%',
                    style: TextStyle(
                        color: isSoldOut
                            ? Colors.redAccent
                            : AppTheme.of(context).textSecondary,
                        fontSize: 12,
                        fontWeight: isSoldOut
                            ? FontWeight.bold
                            : FontWeight.normal),
                  ),
                ],
              ),
            ),
            if (isSoldOut)
              Container(
                padding: const EdgeInsets.symmetric(
                    horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: Colors.redAccent.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: const Text('품절',
                    style: TextStyle(
                        color: Colors.redAccent,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              )
            else if (!isGifticon)
              Text('+${prize.credits}C',
                  style: TextStyle(
                      color: color,
                      fontWeight: FontWeight.bold,
                      fontSize: 18))
            else
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                  color: color.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text('기프티콘',
                    style: TextStyle(
                        color: color,
                        fontWeight: FontWeight.bold,
                        fontSize: 13)),
              ),
          ],
        ),
        ),
      ),
    );
  }

  Future<void> _spinRoulette(RouletteConfig config) async {
    if (_isSpinning) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    // 기프티콘 재고 최신 조회 → 품절 상품 제외
    final gifticonIds = config.prizes
        .where((p) => p.gifticonStoreItemId != null)
        .map((p) => p.gifticonStoreItemId!)
        .toList();
    final freshStocks = gifticonIds.isEmpty
        ? <String, int>{}
        : await _storeService.getAvailableCounts(gifticonIds);
    if (mounted) setState(() => _gifticonStocks = freshStocks);

    final eligiblePrizes = config.prizes.where((p) {
      if (p.gifticonStoreItemId == null) return true;
      return (freshStocks[p.gifticonStoreItemId] ?? 0) > 0;
    }).toList();

    if (eligiblePrizes.isEmpty) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 교환 가능한 상품이 없습니다')),
        );
      }
      return;
    }

    // 하루 횟수 체크
    final allowed = await _storeService.incrementRouletteSpins(
        user.uid, config.dailySpinLimit);
    if (!allowed) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('오늘 횟수를 모두 사용했습니다')),
        );
      }
      return;
    }

    final success = await _creditService.spendCredits(
      userId: user.uid,
      amount: config.cost,
      description: '룰렛 사용',
    );

    if (!success) {
      // 횟수를 썼지만 크레딧이 부족 → 횟수 환원은 복잡하므로 스낵바만
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('크레딧이 부족합니다')),
        );
      }
      return;
    }

    final totalWeight =
        eligiblePrizes.fold(0, (sum, p) => sum + p.probability);

    // 모든 상품 가중치가 0이면 스핀 불가 → 크레딧 환불 후 종료
    if (totalWeight == 0) {
      await _creditService.addCredits(
        userId: user.uid,
        amount: config.cost,
        description: '룰렛 오류 환불',
      );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('현재 룰렛 상품이 준비 중입니다. 크레딧이 환불되었습니다.')),
        );
      }
      return;
    }

    final roll = Random().nextInt(totalWeight);
    int cumulative = 0;
    RoulettePrize? wonPrize;

    for (final prize in eligiblePrizes) {
      cumulative += prize.probability;
      if (roll < cumulative) {
        wonPrize = prize;
        break;
      }
    }
    wonPrize ??= eligiblePrizes.last;

    // 애니메이션용 인덱스는 전체 상품 목록에서 찾음
    final winnerIndex =
        config.prizes.indexOf(wonPrize).clamp(0, config.prizes.length - 1);

    final currentIdx = _slotController.selectedItem;
    final currentPrizeIdx = currentIdx % config.prizes.length;
    final delta = (winnerIndex - currentPrizeIdx + config.prizes.length) %
        config.prizes.length;
    final targetItem = currentIdx + 8 * config.prizes.length + delta;

    setState(() => _isSpinning = true);
    await _slotController.animateToItem(
      targetItem - 3,
      duration: const Duration(milliseconds: 2800),
      curve: Curves.easeIn,
    );

    if (!mounted) return;
    for (int i = 2; i >= 0; i--) {
      await _slotController.animateToItem(
        targetItem - i,
        duration: Duration(milliseconds: 300 + (2 - i) * 250),
        curve: Curves.easeOut,
      );
      if (i > 0) HapticFeedback.mediumImpact();
    }
    HapticFeedback.heavyImpact();

    if (!mounted) return;
    setState(() => _isSpinning = false);

    final prize = wonPrize;

    // 기프티콘 당첨 처리
    if (prize.gifticonStoreItemId != null) {
      final gifticonCode = await _storeService.redeemGifticon(
        storeItemId: prize.gifticonStoreItemId!,
        userId: user.uid,
      );

      if (!mounted) return;
      context.read<AuthProvider>().loadUser();

      if (gifticonCode != null) {
        _showGifticonResultDialog(gifticonCode);
      } else {
        // 재고 없음 → 크레딧 100 지급
        await _creditService.addCredits(
          userId: user.uid,
          amount: 100,
          description: '룰렛 기프티콘 재고 부족 보상',
        );
        if (mounted) {
          context.read<AuthProvider>().loadUser();
          showDialog(
            context: context,
            builder: (context) => AlertDialog(
              backgroundColor: AppTheme.of(context).card,
              title: const Text('🎉 기프티콘 당첨!',
                  style: TextStyle(color: AppTheme.creditGold)),
              content: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.card_giftcard,
                      size: 48, color: AppTheme.primaryColor),
                  SizedBox(height: 12),
                  Text(prize.name,
                      style: TextStyle(
                          color: AppTheme.of(context).textPrimary,
                          fontSize: 18,
                          fontWeight: FontWeight.bold)),
                  SizedBox(height: 8),
                  Text('현재 재고가 소진되어\n100 크레딧으로 대체되었습니다.',
                      textAlign: TextAlign.center,
                      style: TextStyle(
                          color: AppTheme.of(context).textSecondary, fontSize: 13)),
                ],
              ),
              actions: [
                SizedBox(
                  width: double.infinity,
                  child: ElevatedButton(
                    onPressed: () => Navigator.of(context).pop(),
                    child: const Text('확인'),
                  ),
                ),
              ],
            ),
          );
        }
      }
    } else {
      // 크레딧 당첨
      await _creditService.addCredits(
        userId: user.uid,
        amount: prize.credits,
        description: '룰렛 당첨: ${prize.name}',
      );
      await _storeService.saveRouletteWinRecord(
        userId: user.uid,
        prizeName: prize.name,
        imageBase64: prize.imageBase64,
      );

      if (mounted) {
        context.read<AuthProvider>().loadUser();
        showDialog(
          context: context,
          builder: (context) => AlertDialog(
            backgroundColor: AppTheme.of(context).card,
            title: const Text('🎉 축하합니다!',
                style: TextStyle(color: AppTheme.creditGold)),
            content: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Icon(Icons.casino, size: 48, color: AppTheme.creditGold),
                SizedBox(height: 12),
                Text(prize.name,
                    style: TextStyle(
                        color: AppTheme.of(context).textPrimary,
                        fontSize: 22,
                        fontWeight: FontWeight.bold)),
                const SizedBox(height: 4),
                Text('+${prize.credits} 크레딧 획득!',
                    style: const TextStyle(
                        color: AppTheme.creditGold, fontSize: 16)),
              ],
            ),
            actions: [
              SizedBox(
                width: double.infinity,
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(),
                  child: const Text('확인'),
                ),
              ),
            ],
          ),
        );
      }
    }
  }

  // ───────────────────────────────────────────
  // 응모방 탭
  // ───────────────────────────────────────────

  Widget _buildRaffleTab() {
    final user = context.watch<AuthProvider>().user;
    if (user == null) {
      return Center(
        child: Text('로그인이 필요합니다.',
            style: TextStyle(color: AppTheme.of(context).textSecondary)),
      );
    }

    return StreamBuilder<Set<String>>(
      stream: _storeService.watchMyEnteredRoomIds(user.uid),
      builder: (context, entrySnap) {
        final myRoomIds = entrySnap.data ?? {};

        return StreamBuilder<List<RaffleRoom>>(
          stream: _storeService.watchRaffleRooms(),
          builder: (context, roomSnap) {
            if (roomSnap.hasError || !roomSnap.hasData) {
              return Center(
                child: Text('응모방을 불러오는 중...',
                    style: TextStyle(color: AppTheme.of(context).textSecondary)),
              );
            }

            final now = DateTime.now();
            final rooms = roomSnap.data!.where((room) {
              if (!room.isClosed) return true; // 진행중은 항상 표시
              // 종료된 방: 내가 응모했든 아니든 closedAt 기준 24시간 이내만 표시
              if (room.closedAt.isEmpty) return false;
              final closed = DateTime.tryParse(room.closedAt);
              if (closed == null) return false;
              return now.difference(closed).inHours < 24;
            }).toList();

            if (rooms.isEmpty) {
              return Center(
                child: Text('진행 중인 응모방이 없습니다.',
                    style: TextStyle(color: AppTheme.of(context).textSecondary)),
              );
            }

            // 내가 응모한 방 먼저, 그 중 진행중인 방 먼저
            rooms.sort((a, b) {
              final aEntered = myRoomIds.contains(a.id);
              final bEntered = myRoomIds.contains(b.id);
              if (aEntered != bEntered) return aEntered ? -1 : 1;
              if (a.isClosed != b.isClosed) return a.isClosed ? 1 : -1;
              return 0;
            });

            return ListView.builder(
              padding: const EdgeInsets.all(16),
              itemCount: rooms.length,
              itemBuilder: (context, index) {
                final room = rooms[index];
                return _buildRaffleCard(room, user.uid, myRoomIds);
              },
            );
          },
        );
      },
    );
  }

  Widget _buildRaffleCard(RaffleRoom room, String userId, Set<String> myRoomIds) {
    return StreamBuilder<int>(
      stream: _storeService.watchUserRaffleEntry(userId, room.id),
      builder: (context, ticketSnap) {
        final myTickets = ticketSnap.data ?? 0;
        final isClosed = room.isClosed;
        final iWon = isClosed && room.winner == userId;
        final iLost = isClosed && room.winner.isNotEmpty && room.winner != userId && myTickets > 0;

        // 테두리/광채 색상
        Color? glowColor;
        if (iWon) glowColor = AppTheme.creditGold;
        if (iLost) glowColor = AppTheme.accentRed;

        return Container(
          margin: const EdgeInsets.only(bottom: 16),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(12),
            boxShadow: glowColor != null
                ? [
                    BoxShadow(
                      color: glowColor.withValues(alpha: 0.5),
                      blurRadius: 16,
                      spreadRadius: 2,
                    ),
                  ]
                : null,
          ),
          child: Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(12),
              side: glowColor != null
                  ? BorderSide(color: glowColor, width: 2)
                  : BorderSide.none,
            ),
            child: Padding(
            padding: const EdgeInsets.all(16),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Expanded(
                      child: Text(room.title,
                          style: TextStyle(
                            color: isClosed
                                ? AppTheme.of(context).textSecondary
                                : AppTheme.of(context).textPrimary,
                            fontSize: 16,
                            fontWeight: FontWeight.bold,
                          )),
                    ),
                    // 당첨/미당첨/진행중 배지
                    if (iWon)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.creditGold.withValues(alpha: 0.15),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.creditGold),
                        ),
                        child: const Row(
                          mainAxisSize: MainAxisSize.min,
                          children: [
                            Icon(Icons.emoji_events, color: AppTheme.creditGold, size: 14),
                            SizedBox(width: 4),
                            Text('당첨!',
                                style: TextStyle(
                                    color: AppTheme.creditGold,
                                    fontWeight: FontWeight.bold,
                                    fontSize: 13)),
                          ],
                        ),
                      )
                    else if (iLost)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.accentRed.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(color: AppTheme.accentRed.withValues(alpha: 0.5)),
                        ),
                        child: const Text('미당첨',
                            style: TextStyle(
                                color: AppTheme.accentRed,
                                fontSize: 12)),
                      )
                    else
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: isClosed
                              ? AppTheme.of(context).surface
                              : AppTheme.accentRed.withValues(alpha: 0.12),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text(
                          isClosed ? '종료됨' : '진행중',
                          style: TextStyle(
                            color: isClosed
                                ? AppTheme.of(context).textSecondary
                                : AppTheme.accentRed,
                            fontSize: 12,
                          ),
                        ),
                      ),
                  ],
                ),
                SizedBox(height: 8),
                Text('상품: ${room.prize}',
                    style: TextStyle(
                        color: AppTheme.of(context).textSecondary)),
                if (isClosed && room.winner.isNotEmpty && !iWon) ...[
                  const SizedBox(height: 4),
                  Row(children: [
                    const Icon(Icons.emoji_events,
                        color: AppTheme.creditGold, size: 16),
                    const SizedBox(width: 4),
                    Text('당첨자: ${room.winnerName.isNotEmpty ? room.winnerName : '집중러'}',
                        style: const TextStyle(
                            color: AppTheme.creditGold, fontSize: 13)),
                  ]),
                ],
                SizedBox(height: 12),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: room.fillRatio,
                    backgroundColor: AppTheme.of(context).surface,
                    valueColor: AlwaysStoppedAnimation(
                      isClosed
                          ? AppTheme.of(context).textSecondary
                          : room.fillRatio > 0.8
                              ? AppTheme.accentRed
                              : AppTheme.primaryColor,
                    ),
                    minHeight: 8,
                  ),
                ),
                const SizedBox(height: 8),
                Row(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${room.currentCreditsPool} / ${room.totalCreditsPool} 크레딧',
                          style: TextStyle(
                              color: AppTheme.of(context).textSecondary, fontSize: 13),
                        ),
                        if (myTickets > 0)
                          Text(
                            '내 티켓: $myTickets장',
                            style: const TextStyle(
                                color: AppTheme.primaryColor, fontSize: 12),
                          ),
                      ],
                    ),
                    if (isClosed)
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        decoration: BoxDecoration(
                          color: AppTheme.of(context).surface,
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('응모 종료',
                            style: TextStyle(
                                color: AppTheme.of(context).textSecondary,
                                fontSize: 14)),
                      )
                    else
                      ElevatedButton(
                        onPressed: () => _showRaffleEntrySheet(room),
                        style: ElevatedButton.styleFrom(
                          padding: const EdgeInsets.symmetric(
                              horizontal: 16, vertical: 8),
                        ),
                        child: Text(myTickets > 0 ? '추가 응모' : '응모하기'),
                      ),
                  ],
                ),
              ],
            ),
          ),
          ),
        );
      },
    );
  }

  void _showRaffleEntrySheet(RaffleRoom room) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _RaffleEntrySheet(
        room: room,
        storeService: _storeService,
        creditService: _creditService,
        onSuccess: (winnerId) {
          context.read<AuthProvider>().loadUser();
          if (winnerId != null) {
            showDialog(
              context: context,
              builder: (_) => AlertDialog(
                backgroundColor: AppTheme.of(context).card,
                title: const Text('추첨 완료!',
                    style: TextStyle(color: AppTheme.creditGold)),
                content: Column(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Icon(Icons.emoji_events,
                        size: 48, color: AppTheme.creditGold),
                    SizedBox(height: 12),
                    Text('풀이 가득 찼습니다!\n추첨이 완료되었습니다.',
                        textAlign: TextAlign.center,
                        style: TextStyle(color: AppTheme.of(context).textPrimary)),
                  ],
                ),
                actions: [
                  SizedBox(
                    width: double.infinity,
                    child: ElevatedButton(
                      onPressed: () => Navigator.of(context).pop(),
                      child: const Text('확인'),
                    ),
                  ),
                ],
              ),
            );
          }
        },
      ),
    );
  }
}

// ───────────────────────────────────────────
// 응모방 티켓 입력 바텀시트
// ───────────────────────────────────────────

class _RaffleEntrySheet extends StatefulWidget {
  final RaffleRoom room;
  final StoreService storeService;
  final CreditService creditService;
  final void Function(String? winnerId) onSuccess; // winnerId: null=미추첨, non-null=추첨완료

  const _RaffleEntrySheet({
    required this.room,
    required this.storeService,
    required this.creditService,
    required this.onSuccess,
  });

  @override
  State<_RaffleEntrySheet> createState() => _RaffleEntrySheetState();
}

class _RaffleEntrySheetState extends State<_RaffleEntrySheet> {
  final _ticketCtrl = TextEditingController();
  bool _isLoading = false;

  @override
  void dispose() {
    _ticketCtrl.dispose();
    super.dispose();
  }

  Future<void> _submit() async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final tickets = int.tryParse(_ticketCtrl.text.trim());
    if (tickets == null || tickets <= 0) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('올바른 티켓 수를 입력하세요')),
      );
      return;
    }

    if (user.totalCredits < tickets) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('크레딧이 부족합니다')),
      );
      return;
    }

    setState(() => _isLoading = true);

    try {
      final success = await widget.creditService.spendCredits(
        userId: user.uid,
        amount: tickets,
        description: '${widget.room.title} 응모',
      );

      if (!success) {
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('크레딧 차감에 실패했습니다')),
          );
        }
        return;
      }

      try {
        final (winnerId, actualTickets) =
            await widget.storeService.enterRaffleWithTickets(
          userId: user.uid,
          roomId: widget.room.id,
          tickets: tickets,
        );

        // 풀 마감으로 실제 투입이 적었을 경우 차액 환불
        if (actualTickets < tickets) {
          await widget.creditService.addCredits(
            userId: user.uid,
            amount: tickets - actualTickets,
            description: '${widget.room.title} 응모 초과 크레딧 환불',
          );
        }

        if (mounted) {
          Navigator.of(context).pop();
          widget.onSuccess(winnerId);
        }
      } catch (e) {
        // 티켓 투입 실패 시 차감한 크레딧 전액 환불
        await widget.creditService.addCredits(
          userId: user.uid,
          amount: tickets,
          description: '${widget.room.title} 응모 실패 환불',
        );
        if (mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('응모 실패: $e')),
          );
        }
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('오류: $e')),
        );
      }
    } finally {
      if (mounted) setState(() => _isLoading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final room = widget.room;
    final remaining = room.totalCreditsPool - room.currentCreditsPool;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            room.title,
            style: TextStyle(
                color: AppTheme.of(context).textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold),
          ),
          SizedBox(height: 4),
          Text(
            '상품: ${room.prize}',
            style: TextStyle(
                color: AppTheme.of(context).textSecondary, fontSize: 14),
          ),
          SizedBox(height: 16),
          // 진행바
          ClipRRect(
            borderRadius: BorderRadius.circular(4),
            child: LinearProgressIndicator(
              value: room.fillRatio,
              backgroundColor: AppTheme.of(context).surface,
              valueColor: AlwaysStoppedAnimation(AppTheme.primaryColor),
              minHeight: 10,
            ),
          ),
          SizedBox(height: 6),
          Text(
            '${room.currentCreditsPool} / ${room.totalCreditsPool} 크레딧 (남은 자리: $remaining)',
            style: TextStyle(
                color: AppTheme.of(context).textSecondary, fontSize: 12),
          ),
          SizedBox(height: 20),
          // 티켓 입력
          TextField(
            controller: _ticketCtrl,
            keyboardType: TextInputType.number,
            style: TextStyle(color: AppTheme.of(context).textPrimary),
            decoration: InputDecoration(
              labelText: '투입할 티켓 수 (1크레딧 = 1티켓)',
              labelStyle:
                  TextStyle(color: AppTheme.of(context).textSecondary),
              hintText: '최대 $remaining',
              hintStyle: TextStyle(color: AppTheme.of(context).textSecondary),
              filled: true,
              fillColor: AppTheme.of(context).surface,
              border: OutlineInputBorder(
                borderRadius: BorderRadius.circular(12),
                borderSide: BorderSide.none,
              ),
            ),
          ),
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 52,
            child: ElevatedButton(
              onPressed: _isLoading ? null : _submit,
              child: _isLoading
                  ? const CircularProgressIndicator(color: Colors.white)
                  : const Text('응모하기',
                      style: TextStyle(fontSize: 16)),
            ),
          ),
        ],
      ),
    );
  }
}

// ───────────────────────────────────────────
// 교환 카드 위젯
// ───────────────────────────────────────────

class _ExchangeListTile extends StatelessWidget {
  final String name;
  final int cost;
  final IconData icon;
  final bool canAfford;
  final VoidCallback onTap;
  final String? unavailableReason;

  const _ExchangeListTile({
    required this.name,
    required this.cost,
    required this.icon,
    required this.canAfford,
    required this.onTap,
    this.unavailableReason,
  });

  @override
  Widget build(BuildContext context) {
    final glowColor =
        canAfford ? AppTheme.rarityEpic : AppTheme.rarityCommon;

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      decoration: BoxDecoration(
        color: AppTheme.of(context).storeCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: glowColor.withValues(alpha: canAfford ? 0.5 : 0.15),
          width: 1,
        ),
        boxShadow: canAfford
            ? [
                BoxShadow(
                  color: glowColor.withValues(alpha: 0.15),
                  blurRadius: 16,
                  spreadRadius: 0,
                ),
              ]
            : null,
      ),
      child: InkWell(
        onTap: canAfford ? onTap : null,
        borderRadius: BorderRadius.circular(16),
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
          child: Row(
            children: [
              Container(
                width: 52,
                height: 52,
                decoration: BoxDecoration(
                  gradient: canAfford
                      ? LinearGradient(
                          colors: [
                            glowColor.withValues(alpha: 0.3),
                            glowColor.withValues(alpha: 0.1),
                          ],
                          begin: Alignment.topLeft,
                          end: Alignment.bottomRight,
                        )
                      : null,
                  color: canAfford ? null : AppTheme.of(context).storeCard,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                    color: glowColor.withValues(alpha: canAfford ? 0.4 : 0.1),
                    width: 1,
                  ),
                ),
                child: Icon(
                  icon,
                  color: canAfford ? glowColor : AppTheme.of(context).textMuted,
                  size: 26,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      name,
                      style: TextStyle(
                        color: canAfford
                            ? AppTheme.of(context).textPrimary
                            : AppTheme.of(context).textMuted,
                        fontWeight: FontWeight.w700,
                        fontSize: 14,
                        letterSpacing: -0.2,
                      ),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    SizedBox(height: 5),
                    Row(
                      children: [
                        Icon(Icons.monetization_on_rounded,
                            size: 13,
                            color: canAfford
                                ? AppTheme.creditGold
                                : AppTheme.of(context).textMuted),
                        SizedBox(width: 3),
                        Text(
                          '$cost C',
                          style: TextStyle(
                            color: canAfford
                                ? AppTheme.creditGold
                                : AppTheme.of(context).textMuted,
                            fontWeight: FontWeight.bold,
                            fontSize: 13,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const SizedBox(width: 12),
              Container(
                width: 76,
                height: 38,
                decoration: canAfford
                    ? BoxDecoration(
                        gradient: AppTheme.primaryGradient,
                        borderRadius: BorderRadius.circular(10),
                        boxShadow: [
                          BoxShadow(
                            color: AppTheme.primaryColor.withValues(alpha: 0.4),
                            blurRadius: 10,
                            offset: Offset(0, 3),
                          ),
                        ],
                      )
                    : BoxDecoration(
                        color: AppTheme.of(context).storeCard,
                        borderRadius: BorderRadius.circular(10),
                        border: Border.all(
                            color: AppTheme.of(context).borderSubtle, width: 1),
                      ),
                child: InkWell(
                  onTap: canAfford ? onTap : null,
                  borderRadius: BorderRadius.circular(10),
                  child: Center(
                    child: Text(
                      unavailableReason ?? (canAfford ? '교환' : '부족'),
                      style: TextStyle(
                        color: canAfford
                            ? Colors.white
                            : AppTheme.of(context).textMuted,
                        fontSize: 13,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

// ───────────────────────────────────────────
// 교환 확인 바텀시트
// ───────────────────────────────────────────

class _ExchangeBottomSheet extends StatelessWidget {
  final String itemName;
  final int cost;
  final int stockCount;

  const _ExchangeBottomSheet({
    required this.itemName,
    required this.cost,
    required this.stockCount,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppTheme.of(context).card,
        borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
      ),
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 24,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(Icons.card_giftcard,
              size: 48, color: AppTheme.primaryColor),
          SizedBox(height: 12),
          Text(
            itemName,
            style: TextStyle(
                color: AppTheme.of(context).textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold),
            textAlign: TextAlign.center,
          ),
          SizedBox(height: 8),
          Text(
            '$cost 크레딧을 사용합니다',
            style: TextStyle(
                color: AppTheme.of(context).textSecondary, fontSize: 14),
          ),
          SizedBox(height: 4),
          Text(
            '재고: $stockCount개',
            style: TextStyle(
                color: AppTheme.of(context).textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 24),
          Row(
            children: [
              Expanded(
                child: OutlinedButton(
                  onPressed: () => Navigator.of(context).pop(false),
                  child: const Text('취소'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: ElevatedButton(
                  onPressed: () => Navigator.of(context).pop(true),
                  child: const Text('교환하기'),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

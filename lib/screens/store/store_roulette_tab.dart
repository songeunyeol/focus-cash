import 'dart:async';
import 'dart:math';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../design/ds.dart';
import '../../domain/weighted_pick.dart';
import '../../models/gifticon_code.dart';
import '../../models/roulette_config.dart';
import '../../providers/auth_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/credit_service.dart';
import '../../services/server_api.dart';
import '../../services/store_service.dart';
import '../../widgets/common/ds_button.dart';
import 'store_dialogs.dart';

/// 룰렛 항목 등급. 색이 아니라 명도 단계(Rarity.ring)로만 구분한다.
Rarity _rarityAt(int index) {
  const List<Rarity> order = <Rarity>[
    Rarity.common,
    Rarity.rare,
    Rarity.epic,
    Rarity.legendary,
    Rarity.limited,
  ];
  return order[index.clamp(0, order.length - 1)];
}

class StoreRouletteTab extends StatefulWidget {
  const StoreRouletteTab({
    super.key,
    required this.storeService,
    required this.creditService,
    required this.serverApi,
  });

  final StoreService storeService;
  final CreditService creditService;
  final ServerApi serverApi;

  @override
  State<StoreRouletteTab> createState() => _StoreRouletteTabState();
}

class _StoreRouletteTabState extends State<StoreRouletteTab> {
  late final FixedExtentScrollController _slotController;
  bool _isSpinning = false;
  int _lastHapticItem = -1;
  Map<String, int> _gifticonStocks = <String, int>{};
  bool _stocksLoading = false;
  String _lastStockIdsKey = '';
  Future<int>? _remainingFuture;
  String _remainingKey = '';

  static const double _slotItemExtent = 68;

  @override
  void initState() {
    super.initState();
    _slotController = FixedExtentScrollController(initialItem: 1);
    _slotController.addListener(_onSlotScroll);
  }

  void _onSlotScroll() {
    if (!_isSpinning) return;
    final int current = _slotController.selectedItem;
    if (current != _lastHapticItem) {
      _lastHapticItem = current;
      HapticFeedback.selectionClick();
    }
  }

  @override
  void dispose() {
    _slotController.removeListener(_onSlotScroll);
    _slotController.dispose();
    super.dispose();
  }

  void _ensureRemaining(String uid, int limit) {
    final String key = '$uid:$limit';
    if (_remainingKey == key && _remainingFuture != null) return;
    _remainingKey = key;
    _remainingFuture =
        widget.storeService.getRemainingSpins(uid, limit);
  }

  void _invalidateRemaining() {
    _remainingFuture = null;
    _remainingKey = '';
  }

  void _maybeRefreshStocks(RouletteConfig config) {
    final List<String> ids = config.prizes
        .where((RoulettePrize p) => p.gifticonStoreItemId != null)
        .map((RoulettePrize p) => p.gifticonStoreItemId!)
        .toList()
      ..sort();
    final String key = ids.join(',');
    if (key == _lastStockIdsKey || _stocksLoading) return;
    _lastStockIdsKey = key;
    if (ids.isEmpty) {
      setState(() => _gifticonStocks = <String, int>{});
      return;
    }
    _stocksLoading = true;
    widget.storeService.getAvailableCounts(ids).then((Map<String, int> stocks) {
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
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;

    return StreamBuilder<RouletteConfig>(
      stream: widget.storeService.watchRouletteConfig(),
      builder: (BuildContext context, AsyncSnapshot<RouletteConfig> snapshot) {
        final RouletteConfig config =
            snapshot.data ?? RouletteConfig.defaultConfig;
        WidgetsBinding.instance.addPostFrameCallback((_) {
          if (mounted) _maybeRefreshStocks(config);
        });
        if (user != null) {
          _ensureRemaining(user.uid, config.dailySpinLimit);
        }
        return SingleChildScrollView(
          padding: const EdgeInsets.all(Sp.x4),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: <Widget>[
              if (user != null)
                FutureBuilder<int>(
                  future: _remainingFuture,
                  builder: (BuildContext context, AsyncSnapshot<int> spinSnap) {
                    final int remaining = spinSnap.data ?? config.dailySpinLimit;
                    return _RemainingBanner(
                      remaining: remaining,
                      limit: config.dailySpinLimit,
                    );
                  },
                ),
              _SlotMachine(
                config: config,
                controller: _slotController,
                spinning: _isSpinning,
                stocks: _gifticonStocks,
                itemExtent: _slotItemExtent,
              ),
              const SizedBox(height: Sp.x4),
              DsButton(
                label: _isSpinning
                    ? '돌아가는 중...'
                    : '돌리기  (${config.cost} 크레딧)',
                onPressed:
                    _isSpinning ? null : () => _spinRoulette(config),
              ),
              const SizedBox(height: Sp.x8),
              _ProbabilityTable(
                config: config,
                stocks: _gifticonStocks,
              ),
            ],
          ),
        );
      },
    );
  }

  Future<void> _spinRoulette(RouletteConfig config) async {
    if (_isSpinning) return;
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    if (AppConfig.useServerStore) {
      await _spinRouletteViaServer(config);
      return;
    }

    final List<String> gifticonIds = config.prizes
        .where((RoulettePrize p) => p.gifticonStoreItemId != null)
        .map((RoulettePrize p) => p.gifticonStoreItemId!)
        .toList();
    final Map<String, int> freshStocks = gifticonIds.isEmpty
        ? <String, int>{}
        : await widget.storeService.getAvailableCounts(gifticonIds);
    if (mounted) setState(() => _gifticonStocks = freshStocks);

    final List<RoulettePrize> eligiblePrizes = config.prizes.where((RoulettePrize p) {
      if (p.gifticonStoreItemId == null) return true;
      return (freshStocks[p.gifticonStoreItemId] ?? 0) > 0;
    }).toList();

    if (eligiblePrizes.isEmpty) {
      if (!mounted) return;
      showStoreSnack(context, '현재 교환 가능한 상품이 없습니다');
      return;
    }

    final bool success = await widget.creditService.spendCredits(
      userId: user.uid,
      amount: config.cost,
      description: '룰렛 사용',
    );
    if (!mounted) return;
    if (!success) {
      showStoreSnack(context, '크레딧이 부족합니다');
      return;
    }

    final bool allowed = await widget.storeService
        .incrementRouletteSpins(user.uid, config.dailySpinLimit);
    if (!mounted) return;
    if (!allowed) {
      await widget.creditService.addCredits(
        userId: user.uid,
        amount: config.cost,
        description: '룰렛 일일 한도 초과 환불',
      );
      if (!mounted) return;
      context.read<AuthProvider>().loadUser();
      showStoreSnack(context, '오늘 횟수를 모두 사용했습니다');
      return;
    }

    final int totalWeight =
        eligiblePrizes.fold(0, (int sum, RoulettePrize p) => sum + p.probability);

    if (totalWeight == 0) {
      await widget.creditService.addCredits(
        userId: user.uid,
        amount: config.cost,
        description: '룰렛 오류 환불',
      );
      if (!mounted) return;
      showStoreSnack(context, '현재 룰렛 상품이 준비 중입니다. 크레딧이 환불되었습니다.');
      return;
    }

    final int roll = Random().nextInt(totalWeight);
    final int? pickedIndex = pickWeightedIndex(
      eligiblePrizes.map((RoulettePrize p) => p.probability).toList(),
      roll,
    );
    final RoulettePrize wonPrize =
        eligiblePrizes[pickedIndex ?? eligiblePrizes.length - 1];
    unawaited(AnalyticsService.instance
        .rouletteSpin(cost: config.cost, prize: wonPrize.name));

    final int winnerIndex =
        config.prizes.indexOf(wonPrize).clamp(0, config.prizes.length - 1);
    await _animateSlotTo(config, winnerIndex);
    if (!mounted) return;
    _invalidateRemaining();

    if (wonPrize.gifticonStoreItemId != null) {
      final GifticonCode? gifticonCode = await widget.storeService.redeemGifticon(
        storeItemId: wonPrize.gifticonStoreItemId!,
        userId: user.uid,
      );

      if (!mounted) return;
      context.read<AuthProvider>().loadUser();

      if (gifticonCode != null) {
        showGifticonResultDialog(context, gifticonCode);
      } else {
        await widget.creditService.addCredits(
          userId: user.uid,
          amount: 100,
          description: '룰렛 기프티콘 재고 부족 보상',
        );
        if (mounted) {
          context.read<AuthProvider>().loadUser();
          showStockFallbackDialog(context, wonPrize.name);
        }
      }
    } else {
      await widget.creditService.addCredits(
        userId: user.uid,
        amount: wonPrize.credits,
        description: '룰렛 당첨: ${wonPrize.name}',
      );
      await widget.storeService.saveRouletteWinRecord(
        userId: user.uid,
        prizeName: wonPrize.name,
        imageBase64: wonPrize.imageBase64,
      );

      if (mounted) {
        context.read<AuthProvider>().loadUser();
        showCreditWinDialog(context, wonPrize.name, wonPrize.credits);
      }
    }
  }

  Future<void> _spinRouletteViaServer(RouletteConfig config) async {
    Map<String, dynamic> r;
    try {
      r = await widget.serverApi.spinRoulette();
    } on FirebaseFunctionsException catch (e) {
      if (!mounted) return;
      showStoreSnack(context, e.message ?? '룰렛을 돌릴 수 없습니다');
      return;
    } catch (_) {
      if (!mounted) return;
      showStoreSnack(context, '네트워크 오류로 룰렛을 돌리지 못했습니다');
      return;
    }
    if (!mounted) return;

    final int prizeIndex =
        (r['prizeIndex'] as int? ?? 0).clamp(0, config.prizes.length - 1);
    final String prizeName =
        r['prizeName'] as String? ?? config.prizes[prizeIndex].name;
    final int credits = r['credits'] as int? ?? 0;
    final Object? gifticonRaw = r['gifticon'];
    unawaited(AnalyticsService.instance
        .rouletteSpin(cost: config.cost, prize: prizeName));

    await _animateSlotTo(config, prizeIndex);
    if (!mounted) return;
    _invalidateRemaining();
    context.read<AuthProvider>().loadUser();

    if (gifticonRaw is Map) {
      showGifticonResultDialog(
        context,
        GifticonCode.fromMap(Map<String, dynamic>.from(gifticonRaw)),
      );
    } else if (credits > 0) {
      showCreditWinDialog(context, prizeName, credits);
    } else {
      showStockFallbackDialog(context, prizeName);
    }
  }

  Future<void> _animateSlotTo(RouletteConfig config, int winnerIndex) async {
    if (config.prizes.isEmpty) return;
    final int currentIdx = _slotController.selectedItem;
    final int currentPrizeIdx = currentIdx % config.prizes.length;
    final int delta = (winnerIndex - currentPrizeIdx + config.prizes.length) %
        config.prizes.length;
    final int targetItem = currentIdx + 8 * config.prizes.length + delta;

    setState(() => _isSpinning = true);
    try {
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
    } on Object {
      // 탭을 떠나면 컨트롤러가 dispose 된다. 결과는 이미 서버/클라에서 반영됨.
    } finally {
      if (mounted) setState(() => _isSpinning = false);
    }
  }
}

class _RemainingBanner extends StatelessWidget {
  const _RemainingBanner({required this.remaining, required this.limit});

  final int remaining;
  final int limit;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x2 + 2),
      margin: const EdgeInsets.only(bottom: Sp.x4),
      decoration: DsSurface.e1(c),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: <Widget>[
          Icon(Icons.refresh, size: 16, color: c.textSecondary),
          const SizedBox(width: Sp.x2),
          Text(
            '오늘 남은 횟수: $remaining/$limit',
            style: DsType.bodyStrong
                .on(remaining > 0 ? c.textPrimary : c.textSecondary)
                .tnum,
          ),
        ],
      ),
    );
  }
}

class _SlotMachine extends StatelessWidget {
  const _SlotMachine({
    required this.config,
    required this.controller,
    required this.spinning,
    required this.stocks,
    required this.itemExtent,
  });

  final RouletteConfig config;
  final FixedExtentScrollController controller;
  final bool spinning;
  final Map<String, int> stocks;
  final double itemExtent;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final double windowHeight = itemExtent * 3;
    final int totalWeight =
        config.prizes.fold(0, (int s, RoulettePrize p) => s + p.probability);

    return AnimatedContainer(
      duration: Motion.page,
      decoration: DsSurface.of(
        c,
        DsElevation.e1,
        radius: R.rLg,
        borderColor: spinning ? c.flame : c.borderDefault,
      ),
      child: Stack(
        alignment: Alignment.center,
        children: <Widget>[
          SizedBox(
            height: windowHeight,
            child: ListWheelScrollView.useDelegate(
              controller: controller,
              physics: const NeverScrollableScrollPhysics(),
              itemExtent: itemExtent,
              perspective: 0.004,
              diameterRatio: 3.5,
              childDelegate: ListWheelChildLoopingListDelegate(
                children: List<Widget>.generate(
                  config.prizes.length,
                  (int i) => _SlotItem(
                    prize: config.prizes[i],
                    index: i,
                    totalWeight: totalWeight,
                    soldOut: config.prizes[i].gifticonStoreItemId != null &&
                        (stocks[config.prizes[i].gifticonStoreItemId] ?? 1) ==
                            0,
                    itemExtent: itemExtent,
                  ),
                ),
              ),
            ),
          ),
          IgnorePointer(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: <Widget>[
                Divider(color: c.flame, thickness: Stroke.hairline, height: 0),
                SizedBox(height: itemExtent),
                Divider(color: c.flame, thickness: Stroke.hairline, height: 0),
              ],
            ),
          ),
          IgnorePointer(
            child: SizedBox(
              height: windowHeight,
              child: Column(
                children: <Widget>[
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.topCenter,
                          end: Alignment.bottomCenter,
                          colors: <Color>[c.surface, c.surface.withValues(alpha: 0)],
                        ),
                        borderRadius:
                            const BorderRadius.vertical(top: Radius.circular(R.lg)),
                      ),
                    ),
                  ),
                  SizedBox(height: itemExtent),
                  Expanded(
                    child: DecoratedBox(
                      decoration: BoxDecoration(
                        gradient: LinearGradient(
                          begin: Alignment.bottomCenter,
                          end: Alignment.topCenter,
                          colors: <Color>[c.surface, c.surface.withValues(alpha: 0)],
                        ),
                        borderRadius: const BorderRadius.vertical(
                            bottom: Radius.circular(R.lg)),
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
}

class _SlotItem extends StatelessWidget {
  const _SlotItem({
    required this.prize,
    required this.index,
    required this.totalWeight,
    required this.soldOut,
    required this.itemExtent,
  });

  final RoulettePrize prize;
  final int index;
  final int totalWeight;
  final bool soldOut;
  final double itemExtent;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final Color tone = _rarityAt(index).ring(c);
    final bool isGifticon = prize.gifticonStoreItemId != null;
    final double pct =
        totalWeight > 0 ? (prize.probability / totalWeight * 100) : 0;

    return SizedBox(
      height: itemExtent,
      child: Opacity(
        opacity: soldOut ? Motion.disabledOpacity : 1,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x4),
          child: Row(
            children: <Widget>[
              Container(
                width: 36,
                height: 36,
                decoration: DsSurface.tint(c, tone.withValues(alpha: 0.12),
                    radius: R.rPill),
                child: Icon(
                  isGifticon ? Icons.card_giftcard : Icons.toll,
                  color: tone,
                  size: 20,
                ),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(prize.name, style: DsType.bodyStrong.on(c.textPrimary)),
                    Text(
                      soldOut ? '품절' : '${pct.toStringAsFixed(1)}%',
                      style: DsType.caption
                          .on(soldOut ? c.danger : c.textSecondary)
                          .tnum,
                    ),
                  ],
                ),
              ),
              if (soldOut)
                StoreChip(
                    label: '품절', tone: c.danger.withValues(alpha: 0.12), foreground: c.danger)
              else if (!isGifticon)
                Text('+${prize.credits}C',
                    style: DsType.subhead.on(tone).tnum)
              else
                StoreChip(label: '기프티콘', tone: tone.withValues(alpha: 0.15), foreground: tone),
            ],
          ),
        ),
      ),
    );
  }
}

class _ProbabilityTable extends StatelessWidget {
  const _ProbabilityTable({required this.config, required this.stocks});

  final RouletteConfig config;
  final Map<String, int> stocks;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final int totalWeight =
        config.prizes.fold(0, (int sum, RoulettePrize p) => sum + p.probability);

    return Container(
      padding: Sp.card,
      decoration: DsSurface.e1(c),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: <Widget>[
          Text('당첨 확률표', style: DsType.subhead.on(c.textPrimary)),
          const SizedBox(height: Sp.x2),
          ...List<Widget>.generate(config.prizes.length, (int i) {
            final RoulettePrize prize = config.prizes[i];
            final Color tone = _rarityAt(i).ring(c);
            final bool isGifticon = prize.gifticonStoreItemId != null;
            final bool isSoldOut = isGifticon &&
                (stocks[prize.gifticonStoreItemId] ?? 1) == 0;
            final double pct =
                totalWeight > 0 ? (prize.probability / totalWeight * 100) : 0;
            return Padding(
              padding: const EdgeInsets.symmetric(vertical: Sp.x1),
              child: Opacity(
                opacity: isSoldOut ? Motion.disabledOpacity : 1,
                child: Row(
                  children: <Widget>[
                    Container(
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: isSoldOut ? c.textDisabled : tone,
                        shape: BoxShape.circle,
                      ),
                    ),
                    const SizedBox(width: Sp.x2),
                    Expanded(
                      child: Row(
                        children: <Widget>[
                          Flexible(
                            child: Text(prize.name,
                                style: DsType.caption.on(c.textSecondary)),
                          ),
                          if (isGifticon) ...<Widget>[
                            const SizedBox(width: Sp.x1),
                            StoreChip(
                              label: isSoldOut ? '품절' : '기프티콘',
                              tone: isSoldOut
                                  ? c.textDisabled.withValues(alpha: 0.15)
                                  : c.flameTint,
                              foreground: isSoldOut ? c.danger : c.flame,
                            ),
                          ],
                        ],
                      ),
                    ),
                    if (!isGifticon)
                      Text('+${prize.credits}C',
                          style: DsType.caption.on(tone).tnum),
                    const SizedBox(width: Sp.x3),
                    Text('${pct.toStringAsFixed(1)}%',
                        style: DsType.caption.on(c.textSecondary).tnum),
                  ],
                ),
              ),
            );
          }),
        ],
      ),
    );
  }
}

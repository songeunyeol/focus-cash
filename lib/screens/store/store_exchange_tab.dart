import 'dart:async';

import 'package:cloud_functions/cloud_functions.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/app_config.dart';
import '../../config/constants.dart';
import '../../design/ds.dart';
import '../../models/gifticon_code.dart';
import '../../models/store_item.dart';
import '../../providers/auth_provider.dart';
import '../../services/analytics_service.dart';
import '../../services/credit_service.dart';
import '../../services/server_api.dart';
import '../../services/store_service.dart';
import '../../widgets/common/ds_button.dart';
import 'store_dialogs.dart';

class StoreExchangeTab extends StatelessWidget {
  const StoreExchangeTab({
    super.key,
    required this.storeService,
    required this.creditService,
    required this.serverApi,
  });

  final StoreService storeService;
  final CreditService creditService;
  final ServerApi serverApi;

  List<Map<String, dynamic>> _fallbackItems() => <Map<String, dynamic>>[
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

  @override
  Widget build(BuildContext context) {
    return StreamBuilder<List<StoreItem>>(
      stream: storeService.watchStoreItems(),
      builder: (BuildContext context, AsyncSnapshot<List<StoreItem>> snapshot) {
        if (snapshot.hasError || !snapshot.hasData || snapshot.data!.isEmpty) {
          return _FallbackList(items: _fallbackItems());
        }
        return _ItemList(
          items: snapshot.data!,
          onTap: (StoreItem item) => _showExchangeBottomSheet(
            context,
            storeItemId: item.id,
            itemName: item.name,
            cost: item.cost,
          ),
        );
      },
    );
  }

  Future<void> _showExchangeBottomSheet(
    BuildContext context, {
    required String storeItemId,
    required String itemName,
    required int cost,
  }) async {
    final user = context.read<AuthProvider>().user;
    if (user == null) return;

    final int available = await storeService.getAvailableCount(storeItemId);
    if (!context.mounted) return;

    if (available == 0) {
      showStoreSnack(context, '재고가 없습니다. 곧 충전될 예정입니다.');
      return;
    }

    final bool? confirmed = await showModalBottomSheet<bool>(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (BuildContext ctx) => _ExchangeConfirmSheet(
        itemName: itemName,
        cost: cost,
        stockCount: available,
      ),
    );

    if (confirmed != true || !context.mounted) return;

    if (AppConfig.useServerStore) {
      try {
        final Map<String, dynamic> r =
            await serverApi.redeemGifticon(storeItemId);
        if (!context.mounted) return;
        context.read<AuthProvider>().loadUser();
        unawaited(AnalyticsService.instance
            .exchange(itemId: storeItemId, cost: cost));
        showGifticonResultDialog(
          context,
          GifticonCode.fromMap(<String, dynamic>{
            ...r,
            'storeItemId': storeItemId,
            'isUsed': true,
            'usedBy': user.uid,
          }),
        );
      } on FirebaseFunctionsException catch (e) {
        showStoreSnack(context, e.message ?? '교환에 실패했습니다');
      } catch (_) {
        showStoreSnack(context, '네트워크 오류로 교환하지 못했습니다');
      }
      return;
    }

    final bool success = await creditService.spendCredits(
      userId: user.uid,
      amount: cost,
      description: '$itemName 교환',
    );

    if (!context.mounted) return;
    if (!success) {
      showStoreSnack(context, '크레딧이 부족합니다');
      return;
    }

    final GifticonCode? gifticonCode = await storeService.redeemGifticon(
      storeItemId: storeItemId,
      userId: user.uid,
    );

    if (!context.mounted) return;
    context.read<AuthProvider>().loadUser();

    if (gifticonCode != null) {
      unawaited(AnalyticsService.instance
          .exchange(itemId: storeItemId, cost: cost));
      showGifticonResultDialog(context, gifticonCode);
    } else {
      await creditService.addCredits(
        userId: user.uid,
        amount: cost,
        description: '$itemName 교환 환불 (재고 소진)',
      );
      if (context.mounted) {
        context.read<AuthProvider>().loadUser();
        showStoreSnack(context, '재고가 소진되었습니다. 크레딧이 환불됩니다.');
      }
    }
  }
}

class _FallbackList extends StatelessWidget {
  const _FallbackList({required this.items});

  final List<Map<String, dynamic>> items;

  @override
  Widget build(BuildContext context) {
    final int userCredits =
        context.watch<AuthProvider>().user?.totalCredits ?? 0;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final Map<String, dynamic> item = items[index];
        final int cost = item['cost'] as int;
        return ExchangeListTile(
          name: item['name'] as String,
          cost: cost,
          icon: item['icon'] as IconData,
          canAfford: false,
          onTap: () => showStoreSnack(
            context,
            '상품 데이터를 불러오는 중입니다. 잠시 후 다시 시도하세요.',
          ),
          unavailableReason: userCredits >= cost ? '준비 중' : null,
        );
      },
    );
  }
}

class _ItemList extends StatelessWidget {
  const _ItemList({required this.items, required this.onTap});

  final List<StoreItem> items;
  final void Function(StoreItem item) onTap;

  @override
  Widget build(BuildContext context) {
    final int userCredits =
        context.watch<AuthProvider>().user?.totalCredits ?? 0;
    return ListView.builder(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
      itemCount: items.length,
      itemBuilder: (BuildContext context, int index) {
        final StoreItem item = items[index];
        return ExchangeListTile(
          name: item.name,
          cost: item.cost,
          icon: IconData(item.iconCode, fontFamily: 'MaterialIcons'),
          canAfford: userCredits >= item.cost,
          onTap: () => onTap(item),
        );
      },
    );
  }
}

class ExchangeListTile extends StatelessWidget {
  const ExchangeListTile({
    super.key,
    required this.name,
    required this.cost,
    required this.icon,
    required this.canAfford,
    required this.onTap,
    this.unavailableReason,
  });

  final String name;
  final int cost;
  final IconData icon;
  final bool canAfford;
  final VoidCallback onTap;
  final String? unavailableReason;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final Color iconColor = canAfford ? c.flame : c.textDisabled;
    return Padding(
      padding: const EdgeInsets.only(bottom: Sp.x3),
      child: StoreTap(
        onTap: canAfford ? onTap : null,
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: Sp.x4, vertical: Sp.x3),
          decoration: DsSurface.e1(c),
          child: Row(
            children: <Widget>[
              Container(
                width: 48,
                height: 48,
                decoration: DsSurface.tint(
                  c,
                  canAfford ? c.flameTint : c.surface,
                  radius: R.rMd,
                ),
                child: Icon(icon, color: iconColor, size: 24),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: <Widget>[
                    Text(
                      name,
                      style: DsType.bodyStrong.on(
                          canAfford ? c.textPrimary : c.textDisabled),
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    const SizedBox(height: Sp.x1),
                    Text(
                      '$cost C',
                      style: DsType.caption
                          .on(canAfford ? c.accentText : c.textDisabled)
                          .tnum,
                    ),
                  ],
                ),
              ),
              const SizedBox(width: Sp.x3),
              Container(
                width: 72,
                height: 36,
                decoration: BoxDecoration(
                  color: canAfford ? c.flame : c.surface,
                  borderRadius: R.rSm,
                  border: canAfford
                      ? null
                      : Border.all(color: c.borderSubtle, width: Stroke.hairline),
                ),
                alignment: Alignment.center,
                child: Text(
                  unavailableReason ?? (canAfford ? '교환' : '부족'),
                  style: DsType.label.on(
                      canAfford ? c.onAccent : c.textDisabled),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExchangeConfirmSheet extends StatelessWidget {
  const _ExchangeConfirmSheet({
    required this.itemName,
    required this.cost,
    required this.stockCount,
  });

  final String itemName;
  final int cost;
  final int stockCount;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return StoreSheet(
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: <Widget>[
          const StoreSheetHandle(),
          const SizedBox(height: Sp.x4),
          Icon(Icons.card_giftcard, size: 40, color: c.flame),
          const SizedBox(height: Sp.x3),
          Text(itemName,
              style: DsType.subhead.on(c.textPrimary),
              textAlign: TextAlign.center),
          const SizedBox(height: Sp.x2),
          Text('$cost 크레딧을 사용합니다',
              style: DsType.body.on(c.textSecondary).tnum),
          const SizedBox(height: Sp.x1),
          Text('재고: $stockCount개',
              style: DsType.caption.on(c.textTertiary).tnum),
          const SizedBox(height: Sp.x6),
          Row(
            children: <Widget>[
              Expanded(
                child: DsButton(
                  label: '취소',
                  variant: DsButtonVariant.quiet,
                  onPressed: () => Navigator.of(context).pop(false),
                ),
              ),
              const SizedBox(width: Sp.x3),
              Expanded(
                child: DsButton(
                  label: '교환하기',
                  onPressed: () => Navigator.of(context).pop(true),
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }
}

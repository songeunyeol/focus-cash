import 'dart:convert';

import 'package:flutter/material.dart';

import '../../design/ds.dart';
import '../../models/gifticon_code.dart';
import '../../widgets/common/ds_button.dart';
import '../../widgets/common/ds_pressable.dart';

void showStoreSnack(BuildContext context, String message) {
  if (!context.mounted) return;
  ScaffoldMessenger.of(context).showSnackBar(SnackBar(content: Text(message)));
}

void showGifticonResultDialog(BuildContext context, GifticonCode gifticonCode) {
  showDialog<void>(
    context: context,
    barrierDismissible: false,
    builder: (BuildContext ctx) {
      final DsColors dc = ctx.ds;
      return Dialog(
        backgroundColor: dc.surfaceRaised,
        shape: const RoundedRectangleBorder(borderRadius: R.rLg),
        child: Padding(
          padding: const EdgeInsets.all(Sp.x6),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: <Widget>[
              Icon(Icons.card_giftcard_outlined, color: dc.flame, size: 22),
              const SizedBox(height: Sp.x2),
              Text('교환 완료', style: DsType.heading.on(dc.accentText)),
              const SizedBox(height: Sp.x1),
              Text(gifticonCode.storeItemName,
                  style: DsType.caption.on(dc.textSecondary)),
              const SizedBox(height: Sp.x6),
              if (gifticonCode.imageBase64.isNotEmpty) ...<Widget>[
                ClipRRect(
                  borderRadius: R.rMd,
                  child: Image.memory(
                    base64Decode(gifticonCode.imageBase64),
                    height: 180,
                    width: double.infinity,
                    fit: BoxFit.contain,
                  ),
                ),
                const SizedBox(height: Sp.x4),
              ],
              Container(
                width: double.infinity,
                padding: const EdgeInsets.symmetric(
                    horizontal: Sp.x4, vertical: Sp.x3),
                decoration: DsSurface.e1(dc),
                child: Column(
                  children: <Widget>[
                    Text('기프티콘 코드', style: DsType.caption.on(dc.textSecondary)),
                    const SizedBox(height: Sp.x2),
                    SelectableText(
                      gifticonCode.code,
                      style: DsType.subhead.on(dc.textPrimary).tnum,
                      textAlign: TextAlign.center,
                    ),
                  ],
                ),
              ),
              const SizedBox(height: Sp.x2),
              Text('코드를 길게 눌러 복사하세요',
                  style: DsType.micro.on(dc.textTertiary)),
              const SizedBox(height: Sp.x6),
              DsButton(
                label: '확인',
                onPressed: () => Navigator.of(ctx).pop(),
              ),
            ],
          ),
        ),
      );
    },
  );
}

void showCreditWinDialog(
    BuildContext context, String prizeName, int credits) {
  showDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
      final DsColors c = ctx.ds;
      return DsModeScope(
        mode: DsMode.reward,
        child: AlertDialog(
        backgroundColor: c.surfaceRaised,
        shape: const RoundedRectangleBorder(borderRadius: R.rLg),
        title: Text('당첨', style: DsType.heading.on(c.accentText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.casino, size: 40, color: c.flame),
            const SizedBox(height: Sp.x3),
            Text(prizeName, style: DsType.title.on(c.textPrimary)),
            const SizedBox(height: Sp.x1),
            Text('+$credits 크레딧',
                style: DsType.subhead.on(c.accentText).tnum),
          ],
        ),
        actions: <Widget>[
          DsButton(
            label: '확인',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
        ),
      );
    },
  );
}

void showStockFallbackDialog(BuildContext context, String prizeName) {
  showDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
      final DsColors c = ctx.ds;
      return AlertDialog(
        backgroundColor: c.surfaceRaised,
        shape: const RoundedRectangleBorder(borderRadius: R.rLg),
        title: Text('기프티콘 당첨', style: DsType.heading.on(c.accentText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.card_giftcard, size: 40, color: c.flame),
            const SizedBox(height: Sp.x3),
            Text(prizeName, style: DsType.subhead.on(c.textPrimary)),
            const SizedBox(height: Sp.x2),
            Text(
              '현재 재고가 소진되어\n100 크레딧으로 대체되었습니다.',
              textAlign: TextAlign.center,
              style: DsType.caption.on(c.textSecondary),
            ),
          ],
        ),
        actions: <Widget>[
          DsButton(
            label: '확인',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      );
    },
  );
}

void showRaffleDrawDialog(BuildContext context) {
  showDialog<void>(
    context: context,
    builder: (BuildContext ctx) {
      final DsColors c = ctx.ds;
      return AlertDialog(
        backgroundColor: c.surfaceRaised,
        shape: const RoundedRectangleBorder(borderRadius: R.rLg),
        title: Text('추첨 완료', style: DsType.heading.on(c.accentText)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            Icon(Icons.emoji_events, size: 40, color: c.flame),
            const SizedBox(height: Sp.x3),
            Text(
              '풀이 가득 찼습니다.\n추첨이 완료되었습니다.',
              textAlign: TextAlign.center,
              style: DsType.body.on(c.textPrimary),
            ),
          ],
        ),
        actions: <Widget>[
          DsButton(
            label: '확인',
            onPressed: () => Navigator.of(ctx).pop(),
          ),
        ],
      );
    },
  );
}

class StoreChip extends StatelessWidget {
  const StoreChip({
    super.key,
    required this.label,
    this.tone,
    this.foreground,
  });

  final String label;
  final Color? tone;
  final Color? foreground;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final Color bg = tone ?? c.flameTint;
    final Color fg = foreground ?? c.accentText;
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: Sp.x2, vertical: 2),
      decoration: DsSurface.tint(c, bg, radius: R.rSm),
      child: Text(label, style: DsType.micro.on(fg)),
    );
  }
}

class StoreSheetHandle extends StatelessWidget {
  const StoreSheetHandle({super.key});

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Center(
      child: Container(
        width: 36,
        height: 4,
        decoration: BoxDecoration(
          color: c.borderStrong,
          borderRadius: R.rPill,
        ),
      ),
    );
  }
}

/// 바텀시트 공통 껍데기.
class StoreSheet extends StatelessWidget {
  const StoreSheet({super.key, required this.child});

  final Widget child;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Container(
      decoration: DsSurface.e2(c, radius: R.rSheet),
      padding: EdgeInsets.only(
        left: Sp.x6,
        right: Sp.x6,
        top: Sp.x4,
        bottom: MediaQuery.of(context).viewInsets.bottom + Sp.x6,
      ),
      child: child,
    );
  }
}

class StoreEmpty extends StatelessWidget {
  const StoreEmpty(this.message, {super.key});

  final String message;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(Sp.x8),
        child: Text(
          message,
          textAlign: TextAlign.center,
          style: DsType.body.on(c.textTertiary),
        ),
      ),
    );
  }
}

/// 눌림 = 불투명도. 상점 카드·칩에 공통.
class StoreTap extends StatelessWidget {
  const StoreTap({super.key, required this.onTap, required this.child});

  final VoidCallback? onTap;
  final Widget child;

  @override
  Widget build(BuildContext context) {
    return DsPressable(onTap: onTap, child: child);
  }
}

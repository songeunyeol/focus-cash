import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../config/constants.dart';
import '../../design/ds.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/common/ds_pressable.dart';
import 'records_shared.dart';

/// 업적 탭 — 배지 12개 그리드. 획득한 것만 액센트를 받는다.
class AchievementsTab extends StatelessWidget {
  const AchievementsTab({super.key});

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final user = context.watch<AuthProvider>().user;
    final List<String> earned = user?.badges ?? const <String>[];
    final List<Map<String, dynamic>> defs = AppConstants.badgeDefinitions;
    final int earnedCount = defs.where((b) => earned.contains(b['id'])).length;

    return CustomScrollView(
      slivers: <Widget>[
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, 0),
          sliver: SliverToBoxAdapter(
            child: Container(
              padding: Sp.card,
              decoration: DsSurface.e1(c),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: <Widget>[
                  Row(
                    mainAxisAlignment: MainAxisAlignment.spaceBetween,
                    children: <Widget>[
                      Text('획득한 배지', style: DsType.caption.on(c.textTertiary)),
                      Text('$earnedCount / ${defs.length}',
                          style: DsType.bodyStrong.on(c.textPrimary).tnum),
                    ],
                  ),
                  const SizedBox(height: Sp.x3),
                  ClipRRect(
                    borderRadius: R.rPill,
                    child: LinearProgressIndicator(
                      value: defs.isEmpty ? 0 : earnedCount / defs.length,
                      minHeight: 4,
                      backgroundColor: c.surfaceOverlay,
                      valueColor: AlwaysStoppedAnimation<Color>(c.flame),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ),
        SliverPadding(
          padding: const EdgeInsets.fromLTRB(Sp.x4, Sp.x4, Sp.x4, Sp.x12),
          sliver: SliverGrid(
            gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
              crossAxisCount: 3,
              crossAxisSpacing: Sp.x3,
              mainAxisSpacing: Sp.x3,
              childAspectRatio: 0.82,
            ),
            delegate: SliverChildBuilderDelegate(
              (context, i) => _BadgeCell(
                badge: defs[i],
                earned: earned.contains(defs[i]['id']),
              ),
              childCount: defs.length,
            ),
          ),
        ),
      ],
    );
  }
}

class _BadgeCell extends StatelessWidget {
  const _BadgeCell({required this.badge, required this.earned});

  final Map<String, dynamic> badge;
  final bool earned;

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    return DsPressable(
      onTap: () => _showDetail(context),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: Sp.x2, vertical: Sp.x3),
        decoration: DsSurface.of(
          c,
          DsElevation.e1,
          borderColor: earned ? c.flameDim : null,
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: <Widget>[
            _BadgeIcon(icon: badge['icon'] as String, earned: earned, size: 44),
            const SizedBox(height: Sp.x2),
            Text(
              badge['name'] as String,
              textAlign: TextAlign.center,
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: DsType.micro
                  .on(earned ? c.textPrimary : c.textTertiary)
                  .copyWith(fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ),
    );
  }

  void _showDetail(BuildContext context) {
    final DsColors c = context.ds;
    showModalBottomSheet<void>(
      context: context,
      backgroundColor: c.surfaceRaised,
      shape: const RoundedRectangleBorder(borderRadius: R.rSheet),
      builder: (_) => Padding(
        padding: const EdgeInsets.fromLTRB(Sp.x6, Sp.x3, Sp.x6, Sp.x8),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: <Widget>[
            const SheetHandle(),
            const SizedBox(height: Sp.x6),
            _BadgeIcon(icon: badge['icon'] as String, earned: earned, size: 72),
            const SizedBox(height: Sp.x4),
            Text(badge['name'] as String,
                style: DsType.heading.on(c.textPrimary)),
            const SizedBox(height: Sp.x2),
            Text(
              badge['desc'] as String,
              textAlign: TextAlign.center,
              style: DsType.body.on(c.textSecondary),
            ),
            const SizedBox(height: Sp.x4),
            Container(
              padding: const EdgeInsets.symmetric(
                  horizontal: Sp.x3, vertical: Sp.x1 + 2),
              decoration: earned
                  ? DsSurface.tint(c, c.flameTint, radius: R.rPill)
                  : DsSurface.of(c, DsElevation.e1, radius: R.rPill),
              child: Text(
                earned ? '획득 완료' : '미획득',
                style: DsType.label
                    .on(earned ? c.accentText : c.textTertiary),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _BadgeIcon extends StatelessWidget {
  const _BadgeIcon({
    required this.icon,
    required this.earned,
    required this.size,
  });

  final String icon;
  final bool earned;
  final double size;

  static const ColorFilter _grayscale = ColorFilter.matrix(<double>[
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0.2126, 0.7152, 0.0722, 0, 0,
    0, 0, 0, 0.45, 0,
  ]);

  @override
  Widget build(BuildContext context) {
    final DsColors c = context.ds;
    final Widget emoji = Text(icon, style: TextStyle(fontSize: size * 0.5));
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: earned ? c.flameTint : c.surfaceRaised,
        border: Border.all(
          color: earned ? c.flameDim : c.borderSubtle,
          width: Stroke.hairline,
        ),
      ),
      child: Center(
        child: earned
            ? emoji
            : ColorFiltered(colorFilter: _grayscale, child: emoji),
      ),
    );
  }
}

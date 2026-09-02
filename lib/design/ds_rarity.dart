import 'package:flutter/material.dart';

import 'ds_colors.dart';

/// 등급 체계.
///
/// 단일 액센트 규칙과 5단계 희귀도는 정면 충돌한다. flameDim/flame/flameBright 는
/// 명도만 다르므로 40~80px 아바타 링에서는 육안 구분이 되지 않는다.
/// 그래서 **색을 보조로 내리고 형태를 주 신호로 삼는다** —
/// 링 개수, 분절 아크, 오너먼트가 등급을 말하고 색은 거들기만 한다.
enum Rarity { none, common, rare, epic, legendary, limited }

/// 등급의 형태 규격. 조정이 필요하면 이 파일 한 곳만 고치면 된다.
@immutable
class RarityGeometry {
  const RarityGeometry({
    required this.ringCount,
    required this.strokeWidths,
    required this.gap,
    required this.arcSegments,
    required this.ornaments,
    required this.rotates,
  });

  /// 동심 링 개수 (0이면 링 없음)
  final int ringCount;

  /// 링별 두께. 바깥에서 안쪽 순서.
  final List<double> strokeWidths;

  /// 링 사이 간격
  final double gap;

  /// 분절 아크 개수 (0이면 이어진 원)
  final int arcSegments;

  /// 오너먼트 점 개수
  final int ornaments;

  /// 회전 애니메이션 여부.
  /// 리스트 컨텍스트에서는 호출부가 강제로 끈다 — 랭킹에 20명이 렌더되면
  /// AnimationController 가 동시에 수십 개 돌아 프레임이 떨어진다.
  final bool rotates;
}

extension RarityX on Rarity {
  /// 링 색. 등급이 오를수록 차가운 무채색에서 따뜻한 액센트로 옮겨간다.
  Color ring(DsColors c) => switch (this) {
        Rarity.none => const Color(0x00000000),
        Rarity.common => c.textTertiary,
        Rarity.rare => c.textPrimary,
        Rarity.epic => c.flameDim,
        Rarity.legendary => c.flame,
        Rarity.limited => c.flameBright,
      };

  RarityGeometry get geometry => switch (this) {
        Rarity.none => const RarityGeometry(
            ringCount: 0,
            strokeWidths: <double>[],
            gap: 0,
            arcSegments: 0,
            ornaments: 0,
            rotates: false,
          ),
        Rarity.common => const RarityGeometry(
            ringCount: 1,
            strokeWidths: <double>[1.5],
            gap: 0,
            arcSegments: 0,
            ornaments: 0,
            rotates: false,
          ),
        Rarity.rare => const RarityGeometry(
            ringCount: 2,
            strokeWidths: <double>[2, 1],
            gap: 2,
            arcSegments: 0,
            ornaments: 0,
            rotates: false,
          ),
        Rarity.epic => const RarityGeometry(
            ringCount: 2,
            strokeWidths: <double>[2, 1],
            gap: 3,
            arcSegments: 0,
            ornaments: 0,
            rotates: false,
          ),
        Rarity.legendary => const RarityGeometry(
            ringCount: 2,
            strokeWidths: <double>[2.5, 1],
            gap: 3,
            arcSegments: 4,
            ornaments: 0,
            rotates: true,
          ),
        Rarity.limited => const RarityGeometry(
            ringCount: 2,
            strokeWidths: <double>[2.5, 1],
            gap: 3,
            arcSegments: 4,
            ornaments: 3,
            rotates: true,
          ),
      };

  String get label => switch (this) {
        Rarity.none => '',
        Rarity.common => '일반',
        Rarity.rare => '희귀',
        Rarity.epic => '영웅',
        Rarity.legendary => '전설',
        Rarity.limited => '한정',
      };

  /// 기존 코드의 grade 정수(0~5)를 등급으로 옮긴다.
  static Rarity fromGrade(int grade) => switch (grade) {
        <= 0 => Rarity.none,
        1 => Rarity.common,
        2 => Rarity.rare,
        3 => Rarity.epic,
        4 => Rarity.legendary,
        _ => Rarity.limited,
      };
}

/// 랭킹 순위 표시. 1위만 액센트를 쓰고 2·3위는 무채색 명도 차로 구분한다.
enum RankTier { first, second, third, other }

extension RankTierX on RankTier {
  static RankTier fromRank(int rank) => switch (rank) {
        1 => RankTier.first,
        2 => RankTier.second,
        3 => RankTier.third,
        _ => RankTier.other,
      };

  Color color(DsColors c) => switch (this) {
        RankTier.first => c.flame,
        RankTier.second => c.textPrimary,
        RankTier.third => c.textSecondary,
        RankTier.other => c.textTertiary,
      };
}

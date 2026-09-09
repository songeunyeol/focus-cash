import 'package:flutter_test/flutter_test.dart';
import 'package:focus_cash/domain/weighted_pick.dart';

void main() {
  group('pickWeightedIndex', () {
    test('roll 이 누적 가중치 구간에 속한 인덱스를 돌려준다', () {
      final w = [40, 25, 15, 10, 7, 3]; // total 100
      expect(pickWeightedIndex(w, 0), 0);
      expect(pickWeightedIndex(w, 39), 0);
      expect(pickWeightedIndex(w, 40), 1);
      expect(pickWeightedIndex(w, 64), 1);
      expect(pickWeightedIndex(w, 65), 2);
      expect(pickWeightedIndex(w, 96), 4);
      expect(pickWeightedIndex(w, 97), 5);
      expect(pickWeightedIndex(w, 99), 5);
    });

    test('가중치 0 항목은 절대 선택되지 않는다', () {
      final w = [0, 10, 0];
      for (var roll = 0; roll < 10; roll++) {
        expect(pickWeightedIndex(w, roll), 1);
      }
    });

    test('roll 이 범위를 벗어나면 null', () {
      expect(pickWeightedIndex([1, 1], 2), isNull);
      expect(pickWeightedIndex([1, 1], -1), isNull);
      expect(pickWeightedIndex([], 0), isNull);
    });
  });

  group('expectedValue', () {
    test('가중치 기댓값을 계산한다 (룰렛 하우스엣지 검증용)', () {
      // 기존 defaultConfig: EV 116.5 → 비용 50 보다 커서 운영자 손해였다
      expect(
        expectedValue(values: [10, 50, 100, 200, 500, 1000], weights: [40, 25, 15, 10, 7, 3]),
        closeTo(116.5, 0.001),
      );
      // 16차 추천 설정: EV 24.05 → 비용 50 대비 하우스엣지 약 52%
      expect(
        expectedValue(values: [5, 10, 30, 80, 200, 500], weights: [55, 25, 10, 6, 3, 1]),
        closeTo(24.05, 0.001),
      );
    });

    test('가중치 합이 0이면 0', () {
      expect(expectedValue(values: [1], weights: [0]), 0);
    });
  });
}

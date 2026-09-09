/// 가중 추첨. 룰렛과 응모방이 같은 규칙을 쓴다.
///
/// [roll] 은 `[0, sum(weights))` 범위의 난수여야 한다. 난수 생성은 호출부가 맡는다 —
/// 그래야 테스트에서 결정적으로 검증할 수 있고, 서버로 옮길 때도 함수는 그대로다.
int? pickWeightedIndex(List<int> weights, int roll) {
  if (roll < 0) return null;
  int cumulative = 0;
  for (int i = 0; i < weights.length; i++) {
    cumulative += weights[i];
    if (roll < cumulative) return i;
  }
  return null;
}

/// 가중 기댓값. 룰렛 설정이 운영자에게 손해인지 확인하는 데 쓴다.
double expectedValue({required List<int> values, required List<int> weights}) {
  assert(values.length == weights.length);
  final int total = weights.fold<int>(0, (a, b) => a + b);
  if (total == 0) return 0;
  double sum = 0;
  for (int i = 0; i < values.length; i++) {
    sum += values[i] * weights[i];
  }
  return sum / total;
}

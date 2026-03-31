class RoulettePrize {
  final String name;
  final int credits;
  final int probability;
  final String? gifticonStoreItemId; // null이면 크레딧 상품, 값이 있으면 기프티콘
  final String imageBase64;

  const RoulettePrize({
    required this.name,
    required this.credits,
    required this.probability,
    this.gifticonStoreItemId,
    this.imageBase64 = '',
  });

  factory RoulettePrize.fromMap(Map<String, dynamic> map) => RoulettePrize(
        name: map['name'] as String,
        credits: map['credits'] as int,
        probability: map['probability'] as int,
        gifticonStoreItemId: map['gifticonStoreItemId'] as String?,
        imageBase64: map['imageBase64'] as String? ?? '',
      );
}

class RouletteConfig {
  final int cost;
  final List<RoulettePrize> prizes;
  final int dailySpinLimit;

  const RouletteConfig({
    required this.cost,
    required this.prizes,
    this.dailySpinLimit = 3,
  });

  factory RouletteConfig.fromMap(Map<String, dynamic> map) => RouletteConfig(
        cost: map['cost'] as int,
        prizes: (map['prizes'] as List)
            .map((p) => RoulettePrize.fromMap(p as Map<String, dynamic>))
            .toList(),
        dailySpinLimit: map['dailySpinLimit'] as int? ?? 3,
      );

  static RouletteConfig get defaultConfig => const RouletteConfig(
        cost: 50,
        dailySpinLimit: 3,
        prizes: [
          RoulettePrize(name: '10 크레딧', credits: 10, probability: 40),
          RoulettePrize(name: '50 크레딧', credits: 50, probability: 25),
          RoulettePrize(name: '100 크레딧', credits: 100, probability: 15),
          RoulettePrize(name: '200 크레딧', credits: 200, probability: 10),
          RoulettePrize(name: '500 크레딧', credits: 500, probability: 7),
          RoulettePrize(name: '1000 크레딧', credits: 1000, probability: 3),
        ],
      );
}

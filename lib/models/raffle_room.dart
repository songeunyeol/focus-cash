class RaffleRoom {
  final String id;
  final String title;
  final String prize;
  final int totalCreditsPool;
  final int currentCreditsPool;
  final bool isActive;
  final String winner;     // userId or ''
  final String winnerName; // displayName (추첨 시점 저장)
  final String prizeType;  // 'gifticon' | 'manual'
  final String gifticonStoreItemId;
  final String prizeImageBase64;
  final String closedAt; // ISO8601, 종료 시점

  const RaffleRoom({
    required this.id,
    required this.title,
    required this.prize,
    required this.totalCreditsPool,
    this.currentCreditsPool = 0,
    this.isActive = true,
    this.winner = '',
    this.winnerName = '',
    this.prizeType = 'manual',
    this.gifticonStoreItemId = '',
    this.prizeImageBase64 = '',
    this.closedAt = '',
  });

  bool get isClosed => !isActive || currentCreditsPool >= totalCreditsPool;
  double get fillRatio =>
      (currentCreditsPool / totalCreditsPool).clamp(0.0, 1.0);

  RaffleRoom copyWith({
    String? title,
    String? prize,
    int? totalCreditsPool,
    int? currentCreditsPool,
    bool? isActive,
    String? winner,
    String? winnerName,
    String? prizeType,
    String? gifticonStoreItemId,
    String? prizeImageBase64,
    String? closedAt,
  }) =>
      RaffleRoom(
        id: id,
        title: title ?? this.title,
        prize: prize ?? this.prize,
        totalCreditsPool: totalCreditsPool ?? this.totalCreditsPool,
        currentCreditsPool: currentCreditsPool ?? this.currentCreditsPool,
        isActive: isActive ?? this.isActive,
        winner: winner ?? this.winner,
        winnerName: winnerName ?? this.winnerName,
        prizeType: prizeType ?? this.prizeType,
        gifticonStoreItemId: gifticonStoreItemId ?? this.gifticonStoreItemId,
        prizeImageBase64: prizeImageBase64 ?? this.prizeImageBase64,
        closedAt: closedAt ?? this.closedAt,
      );

  Map<String, dynamic> toMap() => {
        'id': id,
        'title': title,
        'prize': prize,
        'totalCreditsPool': totalCreditsPool,
        'currentCreditsPool': currentCreditsPool,
        'isActive': isActive,
        'winner': winner,
        'winnerName': winnerName,
        'prizeType': prizeType,
        'gifticonStoreItemId': gifticonStoreItemId,
        'prizeImageBase64': prizeImageBase64,
        'closedAt': closedAt,
      };

  factory RaffleRoom.fromMap(Map<String, dynamic> map) => RaffleRoom(
        id: map['id'] as String? ?? '',
        title: map['title'] as String? ?? '',
        prize: map['prize'] as String? ?? '',
        totalCreditsPool: map['totalCreditsPool'] as int? ?? 1,
        currentCreditsPool: map['currentCreditsPool'] as int? ?? 0,
        isActive: map['isActive'] as bool? ?? true,
        winner: map['winner'] as String? ?? '',
        winnerName: map['winnerName'] as String? ?? '',
        prizeType: map['prizeType'] as String? ?? 'manual',
        gifticonStoreItemId: map['gifticonStoreItemId'] as String? ?? '',
        prizeImageBase64: map['prizeImageBase64'] as String? ?? '',
        closedAt: map['closedAt'] as String? ?? '',
      );
}

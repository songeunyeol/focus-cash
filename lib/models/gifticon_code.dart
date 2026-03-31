class GifticonCode {
  final String id;
  final String storeItemId;
  final String storeItemName;
  final String code;
  final String imageBase64;
  final bool isUsed;
  final String usedBy;
  final String? usedAt;
  final String createdAt;
  // 직접배송 전용
  final String prizeType; // 'gifticon' | 'direct' | 'roulette'
  final String deliveryStatus; // 'pending' | 'submitted'
  final String deliveryName;
  final String deliveryPhone;
  final String deliveryAddress;
  // 응모방 당첨 확인 또는 직접배송 제출 시각 (24시간 후 목록에서 숨김)
  final String? hiddenAt;

  const GifticonCode({
    required this.id,
    required this.storeItemId,
    required this.storeItemName,
    required this.code,
    this.imageBase64 = '',
    this.isUsed = false,
    this.usedBy = '',
    this.usedAt,
    required this.createdAt,
    this.prizeType = 'gifticon',
    this.deliveryStatus = '',
    this.deliveryName = '',
    this.deliveryPhone = '',
    this.deliveryAddress = '',
    this.hiddenAt,
  });

  Map<String, dynamic> toMap() => {
        'id': id,
        'storeItemId': storeItemId,
        'storeItemName': storeItemName,
        'code': code,
        'imageBase64': imageBase64,
        'isUsed': isUsed,
        'usedBy': usedBy,
        'usedAt': usedAt,
        'createdAt': createdAt,
        'prizeType': prizeType,
        'deliveryStatus': deliveryStatus,
        'deliveryName': deliveryName,
        'deliveryPhone': deliveryPhone,
        'deliveryAddress': deliveryAddress,
        'hiddenAt': hiddenAt,
      };

  factory GifticonCode.fromMap(Map<String, dynamic> map) => GifticonCode(
        id: map['id'] as String? ?? '',
        storeItemId: map['storeItemId'] as String? ?? '',
        storeItemName: map['storeItemName'] as String? ?? '',
        code: map['code'] as String? ?? '',
        imageBase64: map['imageBase64'] as String? ?? '',
        isUsed: map['isUsed'] as bool? ?? false,
        usedBy: map['usedBy'] as String? ?? '',
        usedAt: map['usedAt'] as String?,
        createdAt: map['createdAt'] as String? ?? '',
        prizeType: map['prizeType'] as String? ?? 'gifticon',
        deliveryStatus: map['deliveryStatus'] as String? ?? '',
        deliveryName: map['deliveryName'] as String? ?? '',
        deliveryPhone: map['deliveryPhone'] as String? ?? '',
        deliveryAddress: map['deliveryAddress'] as String? ?? '',
        hiddenAt: map['hiddenAt'] as String?,
      );
}

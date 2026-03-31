import 'dart:math';
import 'package:cloud_firestore/cloud_firestore.dart';
import '../models/store_item.dart';
import '../models/roulette_config.dart';
import '../models/raffle_room.dart';
import '../models/gifticon_code.dart';
import 'telegram_service.dart';

class StoreService {
  final FirebaseFirestore _db = FirebaseFirestore.instance;

  Stream<List<StoreItem>> watchStoreItems() {
    return _db
        .collection('store_items')
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => StoreItem.fromMap(doc.data()))
            .where((item) => item.isActive)
            .toList());
  }

  Stream<RouletteConfig> watchRouletteConfig() {
    return _db
        .collection('roulette_config')
        .doc('config')
        .snapshots()
        .map((doc) {
      if (!doc.exists || doc.data() == null) {
        return RouletteConfig.defaultConfig;
      }
      return RouletteConfig.fromMap(doc.data()!);
    });
  }

  Stream<List<RaffleRoom>> watchRaffleRooms() {
    return _db
        .collection('raffle_rooms')
        .snapshots()
        .map((snap) {
          final rooms = snap.docs
              .map((doc) => RaffleRoom.fromMap(doc.data()))
              .toList();
          rooms.sort((a, b) {
            if (a.isClosed == b.isClosed) return 0;
            return a.isClosed ? 1 : -1;
          });
          return rooms;
        });
  }

  /// 유저가 응모한 방 ID 목록 실시간 반환
  Stream<Set<String>> watchMyEnteredRoomIds(String userId) {
    return _db
        .collection('raffle_entries')
        .where('userId', isEqualTo: userId)
        .snapshots()
        .map((snap) => snap.docs
            .map((doc) => doc.data()['roomId'] as String)
            .toSet());
  }

  /// 특정 응모방에서 유저의 현재 티켓 수를 실시간으로 반환 (없으면 0)
  Stream<int> watchUserRaffleEntry(String userId, String roomId) {
    return _db
        .collection('raffle_entries')
        .doc('${userId}_$roomId')
        .snapshots()
        .map((doc) =>
            doc.exists ? (doc.data()!['ticketCount'] as int? ?? 0) : 0);
  }

  /// 유저가 교환한 기프티콘 목록
  /// hiddenAt이 설정된 지 24시간이 지난 항목은 자동으로 숨김
  Stream<List<GifticonCode>> watchMyGifticons(String userId) {
    return _db
        .collection('gifticon_codes')
        .where('usedBy', isEqualTo: userId)
        .orderBy('usedAt', descending: true)
        .snapshots()
        .map((snap) {
          final now = DateTime.now();
          return snap.docs
              .map((doc) => GifticonCode.fromMap(doc.data()))
              .where((g) {
                if (g.hiddenAt == null) return true;
                try {
                  final hiddenTime = DateTime.parse(g.hiddenAt!);
                  return now.difference(hiddenTime).inHours < 24;
                } catch (_) {
                  return true;
                }
              })
              .toList();
        });
  }

  /// 여러 상품의 미사용 코드 수를 한번에 조회 (storeItemId → count)
  Future<Map<String, int>> getAvailableCounts(
      List<String> storeItemIds) async {
    final entries = await Future.wait(
      storeItemIds.map((id) async => MapEntry(id, await getAvailableCount(id))),
    );
    return Map.fromEntries(entries);
  }

  /// 상품별 미사용 코드 수 조회
  Future<int> getAvailableCount(String storeItemId) async {
    final snap = await _db
        .collection('gifticon_codes')
        .where('storeItemId', isEqualTo: storeItemId)
        .where('isUsed', isEqualTo: false)
        .count()
        .get();
    return snap.count ?? 0;
  }

  /// 미사용 코드 1개를 원자적으로 발급
  /// 성공 시 GifticonCode 반환, 재고 없으면 null 반환
  Future<GifticonCode?> redeemGifticon({
    required String storeItemId,
    required String userId,
  }) async {
    final snap = await _db
        .collection('gifticon_codes')
        .where('storeItemId', isEqualTo: storeItemId)
        .where('isUsed', isEqualTo: false)
        .limit(1)
        .get();

    if (snap.docs.isEmpty) return null;

    final docRef = snap.docs.first.reference;
    GifticonCode? result;

    await _db.runTransaction((tx) async {
      final docSnap = await tx.get(docRef);
      if (!docSnap.exists) return;

      final data = docSnap.data()!;
      if (data['isUsed'] == true) return;

      final now = DateTime.now().toIso8601String();
      tx.update(docRef, {
        'isUsed': true,
        'usedBy': userId,
        'usedAt': now,
      });

      result = GifticonCode.fromMap(
          {...data, 'isUsed': true, 'usedBy': userId, 'usedAt': now});
    });

    return result;
  }

  /// 티켓 투입. 풀이 채워지면 자동 추첨하고 당첨자 userId 반환
  /// 반환값: (winnerId, actualTickets) — actualTickets가 요청보다 적을 수 있음(풀 마감 직전)
  Future<(String?, int)> enterRaffleWithTickets({
    required String userId,
    required String roomId,
    required int tickets,
  }) async {
    final roomRef = _db.collection('raffle_rooms').doc(roomId);
    final entryRef =
        _db.collection('raffle_entries').doc('${userId}_$roomId');

    bool justClosed = false;
    int totalPool = 0;
    int actualTickets = 0;

    await _db.runTransaction((tx) async {
      final roomSnap = await tx.get(roomRef);
      if (!roomSnap.exists) throw Exception('방을 찾을 수 없습니다');

      final roomData = roomSnap.data()!;
      final currentPool = roomData['currentCreditsPool'] as int? ?? 0;
      totalPool = roomData['totalCreditsPool'] as int;
      final isActive = roomData['isActive'] as bool? ?? true;

      if (!isActive || currentPool >= totalPool) {
        throw Exception('이미 종료된 응모방입니다');
      }

      final remaining = totalPool - currentPool;
      actualTickets = tickets > remaining ? remaining : tickets;
      final newPool = currentPool + actualTickets;

      final entrySnap = await tx.get(entryRef);
      final currentTickets = entrySnap.exists
          ? (entrySnap.data()!['ticketCount'] as int? ?? 0)
          : 0;

      tx.set(
          entryRef,
          {
            'userId': userId,
            'roomId': roomId,
            'ticketCount': currentTickets + actualTickets,
            'updatedAt': DateTime.now().toIso8601String(),
          },
          SetOptions(merge: true));

      if (newPool >= totalPool) {
        tx.update(roomRef, {
          'currentCreditsPool': newPool,
          'isActive': false,
          'closedAt': DateTime.now().toIso8601String(),
        });
        justClosed = true;
      } else {
        tx.update(roomRef, {'currentCreditsPool': newPool});
      }
    });

    if (justClosed) {
      final winnerId = await _drawRaffleWinner(roomId, totalPool);
      return (winnerId, actualTickets);
    }
    return (null, actualTickets);
  }

  Future<String?> _drawRaffleWinner(String roomId, int totalPool) async {
    final entriesSnap = await _db
        .collection('raffle_entries')
        .where('roomId', isEqualTo: roomId)
        .get();

    if (entriesSnap.docs.isEmpty) return null;

    final pick = Random().nextInt(totalPool);
    int cumulative = 0;
    String? winnerId;

    for (final doc in entriesSnap.docs) {
      cumulative += (doc.data()['ticketCount'] as int? ?? 0);
      if (pick < cumulative) {
        winnerId = doc.data()['userId'] as String;
        break;
      }
    }

    // 부동소수점 오차 등으로 pick >= 누적합이 될 경우 마지막 참가자를 당첨자로 확정
    if (winnerId == null && entriesSnap.docs.isNotEmpty) {
      winnerId = entriesSnap.docs.last.data()['userId'] as String;
    }
    if (winnerId == null) return null;

    // 당첨자 정보 조회
    final userDoc = await _db.collection('users').doc(winnerId).get();
    final userData = userDoc.data() ?? {};
    final winnerName = (userData['displayName'] as String? ?? '').isNotEmpty
        ? userData['displayName'] as String
        : '집중러';
    // 응모방 정보 조회
    final roomDoc = await _db.collection('raffle_rooms').doc(roomId).get();
    final roomData = roomDoc.data() ?? {};
    final roomTitle = roomData['title'] as String? ?? '';
    final prize = roomData['prize'] as String? ?? '';
    final prizeType = roomData['prizeType'] as String? ?? 'manual';

    // Firestore 당첨 기록
    await _db.collection('raffle_rooms').doc(roomId).update({
      'winner': winnerId,
      'winnerName': winnerName,
    });

    // 응모방 이미지 조회
    final prizeImageBase64 = roomData['prizeImageBase64'] as String? ?? '';

    // 수령 방식에 따라 분기
    if (prizeType == 'gifticon') {
      // 응모방 기프티콘: gifticon_codes에 직접 문서 생성
      final now = DateTime.now().toIso8601String();
      final docId = 'raffle_${roomId}_$winnerId';
      await _db.collection('gifticon_codes').doc(docId).set({
        'id': docId,
        'storeItemId': 'raffle_$roomId',
        'storeItemName': prize,
        'code': '',
        'imageBase64': prizeImageBase64,
        'isUsed': true,
        'usedBy': winnerId,
        'usedAt': now,
        'createdAt': now,
        'prizeType': 'gifticon',
      });
    } else {
      // 직접 배송: gifticon_codes에 pending 문서 생성 (배송지 입력 대기)
      final now = DateTime.now().toIso8601String();
      final docId = 'raffle_${roomId}_$winnerId';
      await _db.collection('gifticon_codes').doc(docId).set({
        'id': docId,
        'storeItemId': 'raffle_$roomId',
        'storeItemName': prize,
        'code': '',
        'imageBase64': prizeImageBase64,
        'isUsed': true,
        'usedBy': winnerId,
        'usedAt': now,
        'createdAt': now,
        'prizeType': 'direct',
        'deliveryStatus': 'pending',
        'deliveryName': '',
        'deliveryPhone': '',
        'deliveryAddress': '',
        '_roomTitle': roomTitle,
      });
    }

    return winnerId;
  }

  /// 직접배송 배송지 정보 저장 후 텔레그램 알림
  Future<void> submitDeliveryInfo({
    required String docId,
    required String name,
    required String phone,
    required String address,
    required String winnerId,
  }) async {
    if (name.trim().isEmpty || phone.trim().isEmpty || address.trim().isEmpty) {
      throw Exception('모든 항목을 입력해주세요.');
    }
    if (name.length > 50 || phone.length > 20 || address.length > 200) {
      throw Exception('입력 길이가 너무 깁니다.');
    }
    // hiddenAt은 최초 제출 시에만 기록 (재수정 시 타이머 리셋 방지)
    final existing = await _db.collection('gifticon_codes').doc(docId).get();
    final alreadyHidden = existing.data()?['hiddenAt'] != null;

    final updates = <String, dynamic>{
      'deliveryName': name,
      'deliveryPhone': phone,
      'deliveryAddress': address,
      'deliveryStatus': 'submitted',
    };
    if (!alreadyHidden) updates['hiddenAt'] = DateTime.now().toIso8601String();

    await _db.collection('gifticon_codes').doc(docId).update(updates);

    final doc = await _db.collection('gifticon_codes').doc(docId).get();
    final data = doc.data() ?? {};

    try {
      await TelegramService.sendRaffleWinnerAlert(
        roomTitle: data['_roomTitle'] as String? ?? '',
        prize: data['storeItemName'] as String? ?? '',
        winnerName: name,
        winnerPhone: phone,
        winnerAddress: address,
        winnerId: winnerId,
      );
    } catch (_) {
      // 텔레그램 알림 실패는 배송지 제출 성공에 영향 없음
    }
  }

  /// 응모방 기프티콘 당첨 확인 완료 — 24시간 후 목록에서 숨겨짐
  Future<void> confirmRaffleGifticon(String docId) async {
    await _db.collection('gifticon_codes').doc(docId).update({
      'hiddenAt': DateTime.now().toIso8601String(),
    });
  }

  /// 룰렛 크레딧 당첨 기록을 내 기프티콘에 저장
  Future<void> saveRouletteWinRecord({
    required String userId,
    required String prizeName,
    required String imageBase64,
  }) async {
    final now = DateTime.now();
    final docId =
        'roulette_${userId}_${now.millisecondsSinceEpoch}';
    await _db.collection('gifticon_codes').doc(docId).set({
      'id': docId,
      'storeItemId': 'roulette_win',
      'storeItemName': prizeName,
      'code': '',
      'imageBase64': imageBase64,
      'isUsed': true,
      'usedBy': userId,
      'usedAt': now.toIso8601String(),
      'createdAt': now.toIso8601String(),
      'prizeType': 'roulette',
    });
  }

  /// 오늘 남은 스핀 횟수 반환 (0이면 불가)
  Future<int> getRemainingSpins(String userId, int dailyLimit) async {
    final doc = await _db.collection('users').doc(userId).get();
    final data = doc.data() ?? {};
    final today = DateTime.now().toIso8601String().substring(0, 10);
    final savedDate = data['rouletteDate'] as String? ?? '';
    final spinsToday =
        savedDate == today ? (data['rouletteSpinsToday'] as int? ?? 0) : 0;
    return (dailyLimit - spinsToday).clamp(0, dailyLimit);
  }

  Future<bool> incrementRouletteSpins(
      String userId, int dailyLimit) async {
    final userRef = _db.collection('users').doc(userId);
    bool allowed = false;

    await _db.runTransaction((tx) async {
      final snap = await tx.get(userRef);
      final data = snap.data() ?? {};
      final today = DateTime.now().toIso8601String().substring(0, 10);
      final savedDate = data['rouletteDate'] as String? ?? '';
      final spinsToday =
          savedDate == today ? (data['rouletteSpinsToday'] as int? ?? 0) : 0;

      if (spinsToday >= dailyLimit) return;

      tx.update(userRef, {
        'rouletteDate': today,
        'rouletteSpinsToday': spinsToday + 1,
      });
      allowed = true;
    });

    return allowed;
  }
}

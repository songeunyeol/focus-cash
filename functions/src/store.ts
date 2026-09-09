import { randomInt } from "node:crypto";
import { onCall, HttpsError } from "firebase-functions/v2/https";
import { db, REGION, requireUid, requireString, requireInt, ledgerEntry, isoLocal, Timestamp } from "./common";
import { Economy, dateKey, pickWeightedIndex } from "./rules";

/**
 * 기프티콘 교환 — 잔액 확인 + 차감 + 코드 1개 발급을 한 트랜잭션으로.
 *
 * 클라이언트 구현은 spendCredits → redeemGifticon 두 단계라 사이에 앱이 죽으면
 * 크레딧만 사라졐다. 그리고 gifticon_codes 를 모든 사용자가 읽을 수 있어
 * 미사용 코드 문자열이 그대로 노출됐다. 이제 코드는 발급된 사람만 읽는다 (rules).
 *
 * 입력: { storeItemId }  출력: { code, imageBase64, storeItemName, cost }
 */
export const redeemGifticon = onCall({ region: REGION }, async (req) => {
  const uid = requireUid(req);
  const storeItemId = requireString((req.data as Record<string, unknown>).storeItemId, "storeItemId", 64);

  // 후보 코드는 트랜잭션 밖에서 1개 고르고, 안에서 다시 확인한다 (경합 시 재시도).
  const candidates = await db
    .collection("gifticon_codes")
    .where("storeItemId", "==", storeItemId)
    .where("isUsed", "==", false)
    .limit(5)
    .get();
  if (candidates.empty) throw new HttpsError("resource-exhausted", "재고가 없습니다.");

  const itemRef = db.collection("store_items").doc(storeItemId);
  const userRef = db.collection("users").doc(uid);

  for (const candidate of candidates.docs) {
    try {
      return await db.runTransaction(async (tx) => {
        const [itemSnap, userSnap, codeSnap] = await Promise.all([
          tx.get(itemRef),
          tx.get(userRef),
          tx.get(candidate.ref),
        ]);
        if (!itemSnap.exists || itemSnap.data()!.isActive === false) {
          throw new HttpsError("not-found", "판매 중인 상품이 아닙니다.");
        }
        if (!userSnap.exists) throw new HttpsError("not-found", "사용자가 없습니다.");
        if (!codeSnap.exists || codeSnap.data()!.isUsed) {
          throw new HttpsError("aborted", "retry"); // 다른 사람이 먼저 가져감 → 다음 후보
        }

        const cost = Number(itemSnap.data()!.cost);
        const balance = Number(userSnap.data()!.totalCredits ?? 0);
        if (balance < cost) throw new HttpsError("failed-precondition", "크레딧이 부족합니다.");

        const now = Timestamp.now();
        tx.update(userRef, { totalCredits: balance - cost });
        tx.update(candidate.ref, { isUsed: true, usedBy: uid, usedAt: isoLocal(now.toDate()) });
        const e = ledgerEntry(uid, -cost, "spend", `${itemSnap.data()!.name} 교환`);
        tx.set(db.collection("credit_transactions").doc(e.id), e);

        const c = codeSnap.data()!;
        return {
          id: candidate.id,
          code: c.code,
          imageBase64: c.imageBase64 ?? "",
          storeItemName: c.storeItemName ?? itemSnap.data()!.name,
          cost,
        };
      });
    } catch (e) {
      if (e instanceof HttpsError && e.code === "aborted") continue;
      throw e;
    }
  }
  throw new HttpsError("resource-exhausted", "재고가 방금 소진됐습니다.");
});

/**
 * 룰렛 — 난수는 서버에서만 뽑는다.
 * 입력: {}  출력: { prizeIndex, prizeName, credits, gifticon?: {...} }
 */
export const spinRoulette = onCall({ region: REGION }, async (req) => {
  const uid = requireUid(req);
  const configSnap = await db.collection("roulette_config").doc("config").get();
  if (!configSnap.exists) throw new HttpsError("failed-precondition", "룰렛이 준비 중입니다.");
  const config = configSnap.data()!;
  const cost = Number(config.cost);
  const dailyLimit = Number(config.dailySpinLimit ?? Economy.rouletteDailyLimit);
  const prizes: Array<{ name: string; credits: number; probability: number; gifticonStoreItemId?: string | null; imageBase64?: string }> =
    config.prizes ?? [];

  // 기프티콘 상품은 재고가 있는 것만 후보에 넣는다.
  const stock = new Map<string, number>();
  for (const p of prizes) {
    if (p.gifticonStoreItemId) {
      const n = await db
        .collection("gifticon_codes")
        .where("storeItemId", "==", p.gifticonStoreItemId)
        .where("isUsed", "==", false)
        .count()
        .get();
      stock.set(p.gifticonStoreItemId, n.data().count);
    }
  }
  const eligible = prizes
    .map((p, i) => ({ p, i }))
    .filter(({ p }) => !p.gifticonStoreItemId || (stock.get(p.gifticonStoreItemId) ?? 0) > 0);
  const totalWeight = eligible.reduce((a, { p }) => a + Number(p.probability), 0);
  if (eligible.length === 0 || totalWeight <= 0) throw new HttpsError("failed-precondition", "현재 교환 가능한 상품이 없습니다.");

  const userRef = db.collection("users").doc(uid);
  const todayKey = dateKey(new Date());

  return db.runTransaction(async (tx) => {
    const userSnap = await tx.get(userRef);
    if (!userSnap.exists) throw new HttpsError("not-found", "사용자가 없습니다.");
    const u = userSnap.data()!;

    const spins = u.rouletteDate === todayKey ? Number(u.rouletteSpinsToday ?? 0) : 0;
    if (spins >= dailyLimit) throw new HttpsError("resource-exhausted", "오늘 횟수를 모두 사용했습니다.");
    const balance = Number(u.totalCredits ?? 0);
    if (balance < cost) throw new HttpsError("failed-precondition", "크레딧이 부족합니다.");

    const roll = randomInt(0, totalWeight);
    const pick = pickWeightedIndex(eligible.map(({ p }) => Number(p.probability)), roll) ?? eligible.length - 1;
    const { p: prize, i: prizeIndex } = eligible[pick];

    let newBalance = balance - cost;
    const spendEntry = ledgerEntry(uid, -cost, "spend", "룰렛 사용");
    tx.set(db.collection("credit_transactions").doc(spendEntry.id), spendEntry);

    let gifticon: Record<string, unknown> | null = null;
    if (prize.gifticonStoreItemId) {
      const codeSnap = await db
        .collection("gifticon_codes")
        .where("storeItemId", "==", prize.gifticonStoreItemId)
        .where("isUsed", "==", false)
        .limit(1)
        .get();
      if (codeSnap.empty) {
        // 방금 소진 → 100 크레딧 대체 (클라이언트 정책과 동일)
        newBalance += Economy.rouletteStockFallbackCredits;
        const e = ledgerEntry(uid, Economy.rouletteStockFallbackCredits, "earn", "룰렛 기프티콘 재고 부족 보상");
        tx.set(db.collection("credit_transactions").doc(e.id), e);
      } else {
        const codeDoc = codeSnap.docs[0];
        tx.update(codeDoc.ref, { isUsed: true, usedBy: uid, usedAt: isoLocal() });
        gifticon = { id: codeDoc.id, ...codeDoc.data(), isUsed: true, usedBy: uid };
      }
    } else {
      newBalance += Number(prize.credits);
      const e = ledgerEntry(uid, Number(prize.credits), "earn", `룰렛 당첨: ${prize.name}`);
      tx.set(db.collection("credit_transactions").doc(e.id), e);
      const recId = `roulette_${uid}_${Date.now()}`;
      tx.set(db.collection("gifticon_codes").doc(recId), {
        id: recId,
        storeItemId: "roulette_win",
        storeItemName: prize.name,
        code: "",
        imageBase64: prize.imageBase64 ?? "",
        isUsed: true,
        usedBy: uid,
        usedAt: isoLocal(),
        createdAt: isoLocal(),
        prizeType: "roulette",
      });
    }

    tx.update(userRef, {
      totalCredits: newBalance,
      rouletteDate: todayKey,
      rouletteSpinsToday: spins + 1,
    });

    return { prizeIndex, prizeName: prize.name, credits: prize.gifticonStoreItemId ? 0 : Number(prize.credits), gifticon };
  });
});

/**
 * 응모방 티켓 투입 — 차감 + 티켓 + (마감 시) 서버 추첨을 한 트랜잭션으로.
 * 입력: { roomId, tickets }  출력: { actualTickets, closed, winnerId? }
 */
export const enterRaffle = onCall({ region: REGION }, async (req) => {
  const uid = requireUid(req);
  const data = req.data as Record<string, unknown>;
  const roomId = requireString(data.roomId, "roomId", 64);
  const tickets = requireInt(data.tickets, "tickets", 1, 100_000);

  const roomRef = db.collection("raffle_rooms").doc(roomId);
  const entryRef = db.collection("raffle_entries").doc(`${uid}_${roomId}`);
  const userRef = db.collection("users").doc(uid);

  const result = await db.runTransaction(async (tx) => {
    const [roomSnap, entrySnap, userSnap] = await Promise.all([tx.get(roomRef), tx.get(entryRef), tx.get(userRef)]);
    if (!roomSnap.exists) throw new HttpsError("not-found", "방을 찾을 수 없습니다.");
    if (!userSnap.exists) throw new HttpsError("not-found", "사용자가 없습니다.");
    const room = roomSnap.data()!;
    const currentPool = Number(room.currentCreditsPool ?? 0);
    const totalPool = Number(room.totalCreditsPool);
    if (room.isActive === false || currentPool >= totalPool) throw new HttpsError("failed-precondition", "이미 종료된 응모방입니다.");

    const actual = Math.min(tickets, totalPool - currentPool);
    const balance = Number(userSnap.data()!.totalCredits ?? 0);
    if (balance < actual) throw new HttpsError("failed-precondition", "크레딧이 부족합니다.");

    const newPool = currentPool + actual;
    const closed = newPool >= totalPool;

    tx.update(userRef, { totalCredits: balance - actual });
    const e = ledgerEntry(uid, -actual, "spend", `${room.title} 응모`);
    tx.set(db.collection("credit_transactions").doc(e.id), e);
    tx.set(
      entryRef,
      {
        userId: uid,
        roomId,
        ticketCount: (entrySnap.exists ? Number(entrySnap.data()!.ticketCount ?? 0) : 0) + actual,
        updatedAt: isoLocal(),
      },
      { merge: true },
    );
    tx.update(roomRef, {
      currentCreditsPool: newPool,
      ...(closed ? { isActive: false, closedAt: isoLocal() } : {}),
    });
    return { actualTickets: actual, closed, totalPool, prize: room.prize, prizeType: room.prizeType ?? "manual", prizeImageBase64: room.prizeImageBase64 ?? "", title: room.title };
  });

  if (!result.closed) return { actualTickets: result.actualTickets, closed: false };

  // ── 추첨 (마감 직후, 서버 난수) ───────────────────────
  const entries = await db.collection("raffle_entries").where("roomId", "==", roomId).get();
  const weights = entries.docs.map((d) => Number(d.data().ticketCount ?? 0));
  const total = weights.reduce((a, b) => a + b, 0);
  const idx = pickWeightedIndex(weights, randomInt(0, Math.max(total, 1))) ?? entries.docs.length - 1;
  const winnerId = entries.docs[idx].data().userId as string;

  const winnerSnap = await db.collection("users").doc(winnerId).get();
  const winnerName = (winnerSnap.data()?.displayName as string | undefined) || "집중러";
  await roomRef.update({ winner: winnerId, winnerName });

  const now = isoLocal();
  const docId = `raffle_${roomId}_${winnerId}`;
  await db.collection("gifticon_codes").doc(docId).set({
    id: docId,
    storeItemId: `raffle_${roomId}`,
    storeItemName: result.prize,
    code: "",
    imageBase64: result.prizeImageBase64,
    isUsed: true,
    usedBy: winnerId,
    usedAt: now,
    createdAt: now,
    prizeType: result.prizeType === "gifticon" ? "gifticon" : "direct",
    ...(result.prizeType === "gifticon"
      ? {}
      : { deliveryStatus: "pending", deliveryName: "", deliveryPhone: "", deliveryAddress: "", _roomTitle: result.title }),
  });

  return { actualTickets: result.actualTickets, closed: true, winnerId };
});

import * as functionsV1 from "firebase-functions/v1";
import { onDocumentUpdated } from "firebase-functions/v2/firestore";
import { defineSecret } from "firebase-functions/params";
import { db, REGION } from "./common";

const TELEGRAM_BOT_TOKEN = defineSecret("TELEGRAM_BOT_TOKEN");
const TELEGRAM_CHAT_ID = defineSecret("TELEGRAM_CHAT_ID");

/**
 * 계정 삭제 시 개인정보 정리. 클라이언트 deleteAccount 가 실패해도 서버가 마무리한다.
 * (auth 삭제 트리거는 v2 에 없어 v1 을 쓴다)
 */
export const onUserDeleted = functionsV1
  .region(REGION)
  .auth.user()
  .onDelete(async (user) => {
    const uid = user.uid;
    const wipe = async (col: string, field: string) => {
      const snap = await db.collection(col).where(field, "==", uid).get();
      for (let i = 0; i < snap.docs.length; i += 400) {
        const batch = db.batch();
        snap.docs.slice(i, i + 400).forEach((d) => batch.delete(d.ref));
        await batch.commit();
      }
    };
    await wipe("focus_sessions", "userId");
    await wipe("credit_transactions", "userId");
    await wipe("user_notes", "userId");
    await wipe("raffle_entries", "userId");
    await wipe("friend_requests", "from");
    await wipe("friend_requests", "to");

    const gifticons = await db.collection("gifticon_codes").where("usedBy", "==", uid).get();
    const batch = db.batch();
    gifticons.docs.forEach((d) => batch.update(d.ref, { deliveryName: "", deliveryPhone: "", deliveryAddress: "" }));
    await batch.commit();

    await db.collection("users").doc(uid).delete().catch(() => undefined);
  });

/**
 * 직접배송 배송지 제출 → 운영자 텔레그램 알림.
 * 봇 토큰이 APK 안에 들어가지 않게 서버로 옮겼다.
 */
export const onDeliverySubmitted = onDocumentUpdated(
  { document: "gifticon_codes/{codeId}", region: REGION, secrets: [TELEGRAM_BOT_TOKEN, TELEGRAM_CHAT_ID] },
  async (event) => {
    const before = event.data?.before.data();
    const after = event.data?.after.data();
    if (!before || !after) return;
    if (after.prizeType !== "direct") return;
    if (before.deliveryStatus === "submitted" || after.deliveryStatus !== "submitted") return;

    const text = [
      "🎉 *응모방 당첨자 배송지 제출*",
      "",
      `📦 응모방: ${after._roomTitle ?? ""}`,
      `🎁 상품: ${after.storeItemName ?? ""}`,
      `👤 수령인: ${after.deliveryName ?? ""}`,
      `📱 연락처: ${after.deliveryPhone ?? ""}`,
      `🏠 배송지: ${after.deliveryAddress ?? ""}`,
      `🆔 UID: ${after.usedBy ?? ""}`,
    ].join("\n");

    await fetch(`https://api.telegram.org/bot${TELEGRAM_BOT_TOKEN.value()}/sendMessage`, {
      method: "POST",
      headers: { "Content-Type": "application/json" },
      body: JSON.stringify({ chat_id: TELEGRAM_CHAT_ID.value(), text, parse_mode: "Markdown" }),
    }).catch(() => undefined);
  },
);

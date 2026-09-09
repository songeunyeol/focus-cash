import { initializeApp, getApps } from "firebase-admin/app";
import { getFirestore, FieldValue, Timestamp } from "firebase-admin/firestore";
import { getAuth } from "firebase-admin/auth";
import { HttpsError, CallableRequest } from "firebase-functions/v2/https";

if (getApps().length === 0) initializeApp();

export const db = getFirestore();
export const auth = getAuth();
export { FieldValue, Timestamp };

/** Firestore 서울 리전. 앱 데이터와 같은 곳에 둬야 왕복 지연이 안 생긴다. */
export const REGION = "asia-northeast3";

/** 호출자 uid. 미인증이면 즉시 거절. */
export function requireUid(req: CallableRequest<unknown>): string {
  const uid = req.auth?.uid;
  if (!uid) throw new HttpsError("unauthenticated", "로그인이 필요합니다.");
  return uid;
}

export function requireInt(value: unknown, name: string, min: number, max: number): number {
  if (typeof value !== "number" || !Number.isInteger(value) || value < min || value > max) {
    throw new HttpsError("invalid-argument", `${name} 값이 올바르지 않습니다.`);
  }
  return value;
}

export function requireString(value: unknown, name: string, maxLen = 200): string {
  if (typeof value !== "string" || value.length === 0 || value.length > maxLen) {
    throw new HttpsError("invalid-argument", `${name} 값이 올바르지 않습니다.`);
  }
  return value;
}

/** 크레딧 원장 한 줄. 모든 잔액 변동은 이 함수를 통해서만 기록한다. */
export function ledgerEntry(
  userId: string,
  amount: number,
  type: "earn" | "spend" | "penalty" | "refund",
  description: string,
) {
  return {
    id: db.collection("credit_transactions").doc().id,
    userId,
    amount,
    type,
    description,
    createdAt: Timestamp.now(),
    source: "server",
  };
}

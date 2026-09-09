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

/** 한국 사용자 기준 하루 경계. 클라이언트도 기기 시각(KST)으로 날짜 키를 만든다. */
export const KST_OFFSET_MINUTES = 540;

/**
 * 클라이언트(Dart `DateTime.now().toIso8601String()`)와 같은 형태의 문자열 시각.
 * 오프셋 없는 KST 로컬 시각 — 예: `2026-09-09T14:03:21.123`.
 *
 * 왜 이렇게 하는가: v1 클라이언트가 `usedAt`·`createdAt`·`closedAt` 등을 이 형식으로 써 왔고,
 * 화면은 그 필드로 `orderBy` 한다. 서버가 `Z` 붙은 UTC 문자열이나 Timestamp 를 섞어 쓰면
 * 문자열 정렬이 9시간 어긋나거나 타입이 달라 정렬 자체가 깨진다. 새 필드는 Timestamp 를 쓰되,
 * 기존 문자열 필드는 이 형식을 유지한다.
 */
export function isoLocal(d: Date = new Date()): string {
  return new Date(d.getTime() + KST_OFFSET_MINUTES * 60_000).toISOString().slice(0, -1);
}

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

export type LedgerType = "earn" | "spend" | "penalty" | "refund";

/**
 * 크레딧 원장 한 줄. 모든 잔액 변동은 이 함수를 통해서만 기록한다.
 *
 * `createdAt` 은 클라이언트 원장과 같은 문자열 형식(정렬 호환), `createdAtTs` 는 서버 Timestamp.
 * `source: "server"` 로 클라이언트가 쓴 옛 원장과 구분한다 (이관 검증 단계에서 확인용).
 */
export function ledgerEntry(userId: string, amount: number, type: LedgerType, description: string) {
  const now = new Date();
  return {
    id: db.collection("credit_transactions").doc().id,
    userId,
    amount,
    type,
    description,
    createdAt: isoLocal(now),
    createdAtTs: Timestamp.fromDate(now),
    source: "server",
  };
}

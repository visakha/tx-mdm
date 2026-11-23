// ONE status-poll interval for the whole UI (Vamsi 2026-11-22 23:56 CST: "poll every 15
// seconds"). MDM and CDI run results, the taskflow run view, the CDI Monitor and the Business
// 360 Currently running view all use this constant - change it here only.

export const POLL_SECONDS = 15;
export const POLL_MS = POLL_SECONDS * 1000;

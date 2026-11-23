// Loads one run by key, then polls every 15 s until it reaches a final state.
// Works for deep links (/mdm/runs/:runKey) as long as the backend still holds the run.
// Never restarts a run.

import { useEffect, useState } from "react";
import { ApiError, errorText, getJson } from "./api";
import { isTerminal, type RunView } from "./run";

export const RUN_POLL_SECONDS = 15;
const POLL_MS = RUN_POLL_SECONDS * 1000;

export function useRunPolling(
  runKey: string | null,
  runUrl: (runKey: string) => string,
): { run: RunView | null; pollError: string | null; polls: number } {
  const [run, setRun] = useState<RunView | null>(null);
  const [pollError, setPollError] = useState<string | null>(null);
  /** How many status checks have answered (drives the poll clock). */
  const [polls, setPolls] = useState<number>(0);

  useEffect(() => {
    if (runKey === null) {
      setRun(null);
      return;
    }
    let cancelled = false;
    let timer: number | undefined;

    const check = (): void => {
      getJson<RunView>(runUrl(runKey))
        .then((next) => {
          if (cancelled) return;
          setRun(next);
          setPolls((n) => n + 1);
          setPollError(null);
          if (!isTerminal(next.status)) timer = window.setTimeout(check, POLL_MS);
        })
        .catch((err: unknown) => {
          if (cancelled) return;
          setPollError(errorText(err));
          // Reading status again is safe; a 429 or a 404 (run unknown) is a hard stop.
          const hardStop = err instanceof ApiError && (err.status === 429 || err.status === 404);
          if (!hardStop) timer = window.setTimeout(check, POLL_MS);
        });
    };

    setRun(null);
    setPolls(0);
    setPollError(null);
    check();
    return () => {
      cancelled = true;
      window.clearTimeout(timer);
    };
  }, [runKey, runUrl]);

  return { run, pollError, polls };
}

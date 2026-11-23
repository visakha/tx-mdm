// Polls one run until it reaches a final state. Never restarts a run.

import { useEffect, useState } from "react";
import { errorText, getJson } from "./api";
import { isTerminal, type RunView } from "./run";

const POLL_MS = 5000;

export function useRunPolling(
  initial: RunView | null,
  runUrl: (runKey: string) => string,
): { run: RunView | null; pollError: string | null } {
  const [run, setRun] = useState<RunView | null>(initial);
  const [pollError, setPollError] = useState<string | null>(null);

  useEffect(() => {
    setRun(initial);
    setPollError(null);
  }, [initial]);

  const runKey = run?.run_key ?? null;
  const done = run === null || isTerminal(run.status);

  useEffect(() => {
    if (runKey === null || done) return;
    const timer = window.setTimeout(() => {
      getJson<RunView>(runUrl(runKey))
        .then((next) => {
          setRun(next);
          setPollError(null);
        })
        .catch((err: unknown) => setPollError(errorText(err)));
    }, POLL_MS);
    return () => window.clearTimeout(timer);
  }, [runKey, done, run, runUrl]);

  return { run, pollError };
}

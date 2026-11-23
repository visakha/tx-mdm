// Run progress + "alive" poll clock, shared by the MDM (Business 360) and CDI results panes and
// the taskflow run view (Vamsi 2026-11-22 23:40 CST).
//
// Honest progress: IDMC does not report a percent complete for an ingress/egress job or a
// taskflow, so while a run is not final the bar is INDETERMINATE (a sweeping highlight). Once
// final it fills to 100% and takes the outcome colour (ok / warn / bad). Row counts, when IDMC
// sends them, are shown as text next to the bar - never turned into a fake percentage.
//
// Poll clock: a small inline SVG clock whose background colour changes on every status poll,
// so a person can see the page is still checking. It stops (grey) once the run is final.

import { Progress, ProgressIndicator, ProgressLabel, ProgressTrack } from "@ui-sdk/react/progress";

export type Tone = "ok" | "warn" | "bad" | "busy";

const CLOCK_COLOURS = ["#2b6fc2", "#7719aa", "#11808a", "#c8641a"] as const;

/** Background colour for the n-th poll; cycles so each refresh visibly changes it. */
export function clockColour(polls: number): string {
  return CLOCK_COLOURS[((polls % CLOCK_COLOURS.length) + CLOCK_COLOURS.length) % CLOCK_COLOURS.length] ?? "#2b6fc2";
}

export function PollClock({
  polls,
  final,
  everySeconds,
}: {
  polls: number;
  final: boolean;
  everySeconds: number;
}): React.JSX.Element {
  const title = final
    ? `Run is final - status checks stopped after ${String(polls)} checks`
    : `Status checked ${String(polls)} times, every ${String(everySeconds)} s`;
  return (
    <span
      className="poll-clock"
      data-testid="poll-clock"
      data-polls={String(polls)}
      data-final={final ? "true" : "false"}
      title={title}
      style={{ background: final ? "#9aa0aa" : clockColour(polls) }}
    >
      <svg viewBox="0 0 16 16" width="14" height="14" fill="none" stroke="#fff" strokeWidth="1.6"
        strokeLinecap="round" aria-hidden="true" focusable="false">
        <circle cx="8" cy="8" r="6" />
        {/* the minute hand turns a quarter per poll */}
        <path d="M8 8V4" transform={`rotate(${String((polls % 4) * 90)} 8 8)`} />
        <path d="M8 8l2.5 1.5" />
      </svg>
      <span className="sr-only">{title}</span>
    </span>
  );
}

export function RunProgress({
  final,
  tone,
  label,
  detail,
  polls,
  everySeconds,
}: {
  final: boolean;
  tone: Tone;
  /** Accessible name, e.g. "Run progress". */
  label: string;
  /** Plain text beside the bar, e.g. "20 rows read so far". */
  detail: string;
  polls: number;
  everySeconds: number;
}): React.JSX.Element {
  return (
    <div className="run-progress-row">
      <Progress
        value={final ? 100 : null}
        className={`run-progress tone-${final ? tone : "busy"}`}
        data-testid="run-progress"
        data-final={final ? "true" : "false"}
        data-tone={final ? tone : "busy"}
      >
        <ProgressLabel className="sr-only">{label}</ProgressLabel>
        <ProgressTrack className="run-progress-track">
          <ProgressIndicator className="run-progress-fill" />
        </ProgressTrack>
      </Progress>
      <PollClock polls={polls} final={final} everySeconds={everySeconds} />
      <span className="run-progress-text" data-testid="run-progress-text">
        {final ? "Finished" : "Running"}
        {detail !== "" ? ` - ${detail}` : ""}
      </span>
    </div>
  );
}

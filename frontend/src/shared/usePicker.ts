// Picker + starter hooks used by both panels. Each panel passes its own loader and runner,
// so CDI and MDM never share state. Selection comes from the URL (see routes.ts).

import { useCallback, useEffect, useMemo, useState } from "react";
import { errorText } from "./api";
import type { RunView } from "./run";

export interface PickerState<T> {
  items: T[];
  loading: boolean;
  loadError: string | null;
  filter: string;
  setFilter: (value: string) => void;
  visible: T[];
  selected: T | undefined;
  reload: () => void;
}

export function usePicker<T>(
  /** fresh=false may answer from the shared catalog copy; Refresh passes fresh=true. */
  load: (fresh: boolean) => Promise<T[]>,
  idOf: (item: T) => string,
  textOf: (item: T) => string,
  selectedId: string | null,
): PickerState<T> {
  const [items, setItems] = useState<T[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [filter, setFilter] = useState<string>("");

  const fetchItems = useCallback((fresh: boolean) => {
    setLoading(true);
    setLoadError(null);
    load(fresh)
      .then(setItems)
      .catch((err: unknown) => setLoadError(errorText(err)))
      .finally(() => setLoading(false));
  }, [load]);

  useEffect(() => fetchItems(false), [fetchItems]);
  const reload = useCallback(() => fetchItems(true), [fetchItems]);

  const visible = useMemo(() => {
    const needle = filter.trim().toLowerCase();
    return needle === "" ? items : items.filter((i) => textOf(i).toLowerCase().includes(needle));
  }, [items, filter, textOf]);

  const selected = selectedId === null ? undefined : items.find((i) => idOf(i) === selectedId);

  return { items, loading, loadError, filter, setFilter, visible, selected, reload };
}

export function useStarter(onStarted: (run: RunView) => void): {
  starting: boolean;
  startError: string | null;
  start: (call: () => Promise<RunView>) => void;
} {
  const [starting, setStarting] = useState<boolean>(false);
  const [startError, setStartError] = useState<string | null>(null);

  const start = useCallback(
    (call: () => Promise<RunView>) => {
      setStarting(true);
      setStartError(null);
      call()
        .then(onStarted)
        .catch((err: unknown) => setStartError(errorText(err)))
        .finally(() => setStarting(false));
    },
    [onStarted],
  );

  return { starting, startError, start };
}

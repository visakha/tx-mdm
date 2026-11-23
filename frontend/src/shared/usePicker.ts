// Generic picker + run hook used by both panels. Each panel passes its own loader and runner,
// so CDI and MDM never share state.

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
  select: (id: string) => void;
  reload: () => void;
}

export function usePicker<T>(
  load: () => Promise<T[]>,
  idOf: (item: T) => string,
  textOf: (item: T) => string,
): PickerState<T> {
  const [items, setItems] = useState<T[]>([]);
  const [loading, setLoading] = useState<boolean>(true);
  const [loadError, setLoadError] = useState<string | null>(null);
  const [filter, setFilter] = useState<string>("");
  const [selectedId, setSelectedId] = useState<string | null>(null);

  const reload = useCallback(() => {
    setLoading(true);
    setLoadError(null);
    load()
      .then(setItems)
      .catch((err: unknown) => setLoadError(errorText(err)))
      .finally(() => setLoading(false));
  }, [load]);

  useEffect(reload, [reload]);

  const visible = useMemo(() => {
    const needle = filter.trim().toLowerCase();
    return needle === "" ? items : items.filter((i) => textOf(i).toLowerCase().includes(needle));
  }, [items, filter, textOf]);

  const selected = visible.find((i) => idOf(i) === selectedId);

  return {
    items,
    loading,
    loadError,
    filter,
    setFilter,
    visible,
    selected,
    select: setSelectedId,
    reload,
  };
}

export function useStarter(): {
  started: RunView | null;
  starting: boolean;
  startError: string | null;
  start: (call: () => Promise<RunView>) => void;
} {
  const [started, setStarted] = useState<RunView | null>(null);
  const [starting, setStarting] = useState<boolean>(false);
  const [startError, setStartError] = useState<string | null>(null);

  const start = useCallback((call: () => Promise<RunView>) => {
    setStarting(true);
    setStartError(null);
    call()
      .then(setStarted)
      .catch((err: unknown) => setStartError(errorText(err)))
      .finally(() => setStarting(false));
  }, []);

  return { started, starting, startError, start };
}

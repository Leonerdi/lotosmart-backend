import { selectAllItems, selectForgeableItems, selectSnapshot, useGameStore } from "./useGameStore";

export function useMirrorStore() {
  const snapshot = useGameStore(selectSnapshot);
  const setSnapshot = useGameStore((state) => state.applySnapshot);
  const allItems = useGameStore(selectAllItems);
  const forgeableItems = useGameStore(selectForgeableItems);

  return { snapshot, setSnapshot, allItems, forgeableItems };
}

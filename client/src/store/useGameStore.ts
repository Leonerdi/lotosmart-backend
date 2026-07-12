import { create } from "zustand";
import type { CombatLogsPayload, CombatRoundLog, InventoryItem, InventoryTabs, ServerViewModel } from "../types/protocol";

type ProfileState = Pick<
  ServerViewModel,
  | "ato_atual"
  | "rua_atual"
  | "tema_geografico"
  | "boss_ready"
  | "ouro"
  | "xp"
  | "mmr"
  | "kits_reparo"
  | "character_level"
  | "hero_id"
  | "talent_nodes"
  | "materials"
  | "last_campaign_outcome"
  | "matchmaking_bracket"
>;

type ProfileSlice = {
  profile: ProfileState;
  applyProfileSnapshot: (snapshot: ServerViewModel) => void;
  resetProfile: () => void;
};

type InventorySlice = {
  inventoryTabs: InventoryTabs;
  applyInventorySnapshot: (snapshot: ServerViewModel) => void;
  setInventoryTabs: (tabs: InventoryTabs) => void;
  resetInventory: () => void;
};

type CombatSlice = {
  combatSource: string | null;
  combatSummary: Record<string, unknown> | null;
  combatLogs: CombatRoundLog[];
  currentTick: number;
  isPlaying: boolean;
  playbackSpeed: number;
  setCombatPayload: (payload: CombatLogsPayload) => void;
  setCurrentTick: (next: number | ((previous: number) => number)) => void;
  seekTick: (tick: number) => void;
  play: () => void;
  pause: () => void;
  setPlaybackSpeed: (speed: number) => void;
  skipToEnd: () => void;
  resetCombat: () => void;
};

export type GameStore = ProfileSlice &
  InventorySlice &
  CombatSlice & {
    applySnapshot: (snapshot: ServerViewModel) => void;
  };

const EMPTY_PROFILE: ProfileState = {
  ato_atual: 1,
  rua_atual: 1,
  tema_geografico: undefined,
  boss_ready: false,
  ouro: 0,
  xp: 0,
  mmr: 0,
  kits_reparo: 0,
  character_level: 1,
  hero_id: undefined,
  talent_nodes: {},
  materials: {},
  last_campaign_outcome: null,
  matchmaking_bracket: undefined
};

const EMPTY_INVENTORY_TABS: InventoryTabs = {
  equipados: [],
  equipamentos: [],
  consumiveis: [],
  runas: [],
  materiais: []
};

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

export const useGameStore = create<GameStore>((set, get) => ({
  profile: EMPTY_PROFILE,
  applyProfileSnapshot: (snapshot) => {
    set({
      profile: {
        ato_atual: snapshot.ato_atual,
        rua_atual: snapshot.rua_atual,
        tema_geografico: snapshot.tema_geografico,
        boss_ready: snapshot.boss_ready,
        ouro: snapshot.ouro,
        xp: snapshot.xp,
        mmr: snapshot.mmr,
        kits_reparo: snapshot.kits_reparo,
        character_level: snapshot.character_level,
        hero_id: snapshot.hero_id,
        talent_nodes: snapshot.talent_nodes,
        materials: snapshot.materials,
        last_campaign_outcome: snapshot.last_campaign_outcome,
        matchmaking_bracket: snapshot.matchmaking_bracket
      }
    });
  },
  resetProfile: () => {
    set({ profile: EMPTY_PROFILE });
  },

  inventoryTabs: EMPTY_INVENTORY_TABS,
  applyInventorySnapshot: (snapshot) => {
    set({ inventoryTabs: snapshot.inventory_tabs });
  },
  setInventoryTabs: (tabs) => {
    set({ inventoryTabs: tabs });
  },
  resetInventory: () => {
    set({ inventoryTabs: EMPTY_INVENTORY_TABS });
  },

  combatSource: null,
  combatSummary: null,
  combatLogs: [],
  currentTick: 0,
  isPlaying: false,
  playbackSpeed: 1,
  setCombatPayload: (payload) => {
    const nextLogs = Array.isArray(payload.logs) ? payload.logs : [];
    set({
      combatSource: payload.source ?? null,
      combatSummary: payload.summary ?? null,
      combatLogs: nextLogs,
      currentTick: 0,
      isPlaying: false
    });
  },
  setCurrentTick: (next) => {
    set((state) => {
      const maxTick = Math.max(0, state.combatLogs.length - 1);
      const resolved = typeof next === "function" ? next(state.currentTick) : next;
      return { currentTick: clamp(Math.floor(resolved), 0, maxTick) };
    });
  },
  seekTick: (tick) => {
    const maxTick = Math.max(0, get().combatLogs.length - 1);
    set({ currentTick: clamp(Math.floor(tick), 0, maxTick) });
  },
  play: () => {
    if (get().combatLogs.length === 0) {
      return;
    }
    set({ isPlaying: true });
  },
  pause: () => {
    set({ isPlaying: false });
  },
  setPlaybackSpeed: (speed) => {
    const normalized = Number.isFinite(speed) ? speed : 1;
    set({ playbackSpeed: clamp(normalized, 0.25, 8) });
  },
  skipToEnd: () => {
    const maxTick = Math.max(0, get().combatLogs.length - 1);
    set({ currentTick: maxTick, isPlaying: false });
  },
  resetCombat: () => {
    set({
      combatSource: null,
      combatSummary: null,
      combatLogs: [],
      currentTick: 0,
      isPlaying: false,
      playbackSpeed: 1
    });
  },

  applySnapshot: (snapshot) => {
    get().applyProfileSnapshot(snapshot);
    get().applyInventorySnapshot(snapshot);
  }
}));

export const selectSnapshot = (state: GameStore): ServerViewModel => ({
  ...state.profile,
  inventory_tabs: state.inventoryTabs,
  ouro: state.profile.ouro,
  xp: state.profile.xp
});

export const selectAllItems = (state: GameStore): InventoryItem[] => {
  const tabs = state.inventoryTabs;
  return [...tabs.equipados, ...tabs.equipamentos, ...tabs.consumiveis, ...tabs.runas, ...tabs.materiais];
};

export const selectForgeableItems = (state: GameStore): InventoryItem[] => {
  const tabs = state.inventoryTabs;
  return [...tabs.equipamentos, ...tabs.runas].filter((item) => item.raridade !== "SINGULAR");
};

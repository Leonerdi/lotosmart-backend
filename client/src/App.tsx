import { useEffect, useRef, useState } from "react";
import { getCurrentWindow } from "@tauri-apps/api/window";
import { InventoryPanel } from "./components/InventoryPanel";
import { OfflineRewardModal } from "./components/OfflineRewardModal";
import { PinButton } from "./components/PinButton";
import { SynthesisPanel } from "./components/SynthesisPanel";
import { ArenaComponent } from "./components/ArenaComponent";
import { useWindowPersistence } from "./hooks/useWindowPersistence";
import { MirrorSocketClient } from "./services/socketClient";
import { useMirrorStore } from "./store/useMirrorStore";
import { useGameStore } from "./store/useGameStore";
import type { MirrorIntent, OfflineReward } from "./types/protocol";

const WS_ENDPOINT = import.meta.env.VITE_SERVER_WS_URL ?? "ws://localhost:8080/ws";
const SESSION_TICKET = import.meta.env.VITE_STEAM_SESSION_TICKET;

function preventContextMenu() {
  window.addEventListener("contextmenu", (event) => {
    event.preventDefault();
  });
}

export default function App() {
  const { snapshot, setSnapshot, forgeableItems } = useMirrorStore();
  const setCombatPayload = useGameStore((state) => state.setCombatPayload);
  const playCombat = useGameStore((state) => state.play);
  const wsRef = useRef<MirrorSocketClient | null>(null);
  const [offlineReward, setOfflineReward] = useState<OfflineReward | null>(null);

  useWindowPersistence();

  useEffect(() => {
    preventContextMenu();
    wsRef.current = new MirrorSocketClient(
      WS_ENDPOINT,
      setSnapshot,
      (authData) => {
        if (authData.offline_reward && (authData.offline_reward.gold_earned > 0 || authData.offline_reward.xp_earned > 0)) {
          setOfflineReward(authData.offline_reward);
        }
      },
      (payload) => {
        setCombatPayload(payload);
        playCombat();
      },
      SESSION_TICKET
    );

    return () => {
      wsRef.current?.dispose();
      wsRef.current = null;
    };
  }, [playCombat, setCombatPayload, setSnapshot]);

  const sendIntent = (intent: MirrorIntent) => {
    wsRef.current?.sendIntent(intent);
  };

  const startResizeDragging = async () => {
    const appWindow = getCurrentWindow();
    await appWindow.startResizeDragging("SouthEast");
  };

  return (
    <main className="app-shell relative flex h-full w-full flex-col p-2 text-white">
      <header
        data-tauri-drag-region
        className="flex items-center justify-between rounded-md border border-amber-900/60 bg-zinc-900/70 px-2 py-1"
      >
        <div className="min-w-0">
          <h1 className="truncate text-[11px] font-bold tracking-wide text-amber-200">UNDERWORLD BAR MIRROR</h1>
          <p className="truncate text-[9px] text-zinc-400">
            Ato {snapshot.ato_atual ?? 1} | Rua {snapshot.rua_atual ?? 1} | Ouro {snapshot.ouro} | XP {snapshot.xp}
          </p>
        </div>
        <PinButton
          onPinnedChange={(isPinned) => {
            sendIntent({ acao: "TOGGLE_PIN", payload: { isPinned } });
          }}
        />
      </header>

      <section className="mt-1 rounded-md border border-amber-900/50 bg-zinc-900/60 px-2 py-1 text-[9px] text-zinc-300">
        {snapshot.tema_geografico ?? "Submundo"} | Bracket: {snapshot.matchmaking_bracket ?? "BRONZE"} | Boss: {snapshot.boss_ready ? "Pronto" : "Bloqueado"}
      </section>

      <ArenaComponent />

      <InventoryPanel tabs={snapshot.inventory_tabs} />
      <SynthesisPanel items={forgeableItems} dispatchIntent={sendIntent} />

      <footer className="mt-auto flex items-center justify-between gap-2 pt-1 text-[9px] text-zinc-400">
        <button
          type="button"
          className="rounded border border-amber-800/60 px-2 py-1 hover:bg-amber-900/40"
          onClick={() => sendIntent({ acao: "ENTRAR_FILA_CASUAL" })}
        >
          PvP Casual
        </button>
        <button
          type="button"
          className="rounded border border-amber-800/60 px-2 py-1 hover:bg-amber-900/40"
          onClick={() => sendIntent({ acao: "ENTRAR_FILA_RANKEADA" })}
        >
          PvP Rankeado
        </button>
        <button
          type="button"
          className="rounded border border-zinc-700 px-2 py-1 hover:bg-zinc-800"
          onClick={() => {
            void startResizeDragging();
          }}
        >
          Redimensionar
        </button>
      </footer>

      <OfflineRewardModal reward={offlineReward} onClose={() => setOfflineReward(null)} />
    </main>
  );
}

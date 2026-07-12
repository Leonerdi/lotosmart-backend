import { useEffect, useMemo, useRef } from "react";
import type { CombatRoundLog, CombatVisualState } from "../types/protocol";
import { useGameStore } from "../store/useGameStore";

const TICK_DURATION_MS = 100;

function extractActorId(log: CombatRoundLog | undefined): string | undefined {
  if (!log) {
    return undefined;
  }

  return String(log.attacker_id ?? log.attackerId ?? "").trim() || undefined;
}

function extractTargetId(log: CombatRoundLog | undefined): string | undefined {
  if (!log) {
    return undefined;
  }

  const firstTargetFromArray = Array.isArray(log.target_ids) ? log.target_ids[0] : undefined;
  return String(firstTargetFromArray ?? log.targetId ?? "").trim() || undefined;
}

function extractDamage(log: CombatRoundLog | undefined): number {
  if (!log) {
    return 0;
  }

  const raw = Number(log.dano_mitigado ?? log.damage ?? 0);
  return Number.isFinite(raw) ? raw : 0;
}

export type CombatTickEvent = {
  tickIndex: number;
  log: CombatRoundLog;
  isLast: boolean;
};

type UseCombatPlaybackOptions = {
  onTickEvent?: (event: CombatTickEvent) => void;
  onPlaybackEnd?: () => void;
};

export function useCombatPlayback(options: UseCombatPlaybackOptions = {}) {
  const { onTickEvent, onPlaybackEnd } = options;

  const combatLogs = useGameStore((state) => state.combatLogs);
  const currentTick = useGameStore((state) => state.currentTick);
  const playbackSpeed = useGameStore((state) => state.playbackSpeed);
  const isPlaying = useGameStore((state) => state.isPlaying);
  const play = useGameStore((state) => state.play);
  const pause = useGameStore((state) => state.pause);
  const skipToEnd = useGameStore((state) => state.skipToEnd);
  const setCurrentTick = useGameStore((state) => state.setCurrentTick);
  const setPlaybackSpeed = useGameStore((state) => state.setPlaybackSpeed);

  const rafIdRef = useRef<number | null>(null);
  const lastNowRef = useRef<number | null>(null);
  const accumulatorRef = useRef<number>(0);
  const onTickEventRef = useRef(onTickEvent);
  const onPlaybackEndRef = useRef(onPlaybackEnd);

  useEffect(() => {
    onTickEventRef.current = onTickEvent;
  }, [onTickEvent]);

  useEffect(() => {
    onPlaybackEndRef.current = onPlaybackEnd;
  }, [onPlaybackEnd]);

  useEffect(() => {
    if (!isPlaying || combatLogs.length === 0) {
      return;
    }

    const step = (now: number) => {
      const previousNow = lastNowRef.current ?? now;
      const deltaMs = Math.max(0, now - previousNow);
      lastNowRef.current = now;

      accumulatorRef.current += deltaMs * playbackSpeed;

      const state = useGameStore.getState();
      const maxTick = Math.max(0, state.combatLogs.length - 1);
      let nextTick = state.currentTick;

      while (accumulatorRef.current >= TICK_DURATION_MS && nextTick < maxTick) {
        accumulatorRef.current -= TICK_DURATION_MS;
        nextTick += 1;
      }

      if (nextTick !== state.currentTick) {
        setCurrentTick(nextTick);
      }

      if (nextTick >= maxTick) {
        pause();
        onPlaybackEndRef.current?.();
        return;
      }

      rafIdRef.current = requestAnimationFrame(step);
    };

    rafIdRef.current = requestAnimationFrame(step);

    return () => {
      if (rafIdRef.current !== null) {
        cancelAnimationFrame(rafIdRef.current);
      }
      rafIdRef.current = null;
      lastNowRef.current = null;
      accumulatorRef.current = 0;
    };
  }, [combatLogs.length, isPlaying, pause, playbackSpeed, setCurrentTick]);

  useEffect(() => {
    const log = combatLogs[currentTick];
    if (!log) {
      return;
    }

    onTickEventRef.current?.({
      tickIndex: currentTick,
      log,
      isLast: currentTick >= combatLogs.length - 1
    });
  }, [combatLogs, currentTick]);

  const currentLog = combatLogs[currentTick];

  const visualState: CombatVisualState = useMemo(() => {
    const actor = extractActorId(currentLog);
    const target = extractTargetId(currentLog);
    const damage = extractDamage(currentLog);

    return {
      is_animating: isPlaying && Boolean(currentLog),
      actor_pose: isPlaying && actor ? "ATTACK" : "IDLE",
      target_pose: isPlaying && target ? "HIT" : "IDLE",
      actor_id: actor,
      target_id: target,
      last_damage: damage,
      floating_damage_text: damage > 0 ? `-${damage}` : null
    };
  }, [currentLog, isPlaying]);

  return {
    currentTick,
    totalTicks: combatLogs.length,
    currentLog,
    playbackSpeed,
    isPlaying,
    visualState,
    play,
    pause,
    skipToEnd,
    setPlaybackSpeed,
    seekTick: setCurrentTick
  };
}

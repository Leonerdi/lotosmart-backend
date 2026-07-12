import { memo, useCallback, useEffect, useMemo, useRef } from "react";
import { useCombatPlayback } from "../hooks/useCombatPlayback";
import { useGameStore } from "../store/useGameStore";
import type { CombatRoundLog } from "../types/protocol";

type UnitStats = {
  hp: number;
  maxHp: number;
};

type CooldownState = {
  current: number;
  max: number;
};

type FxParticle = {
  x: number;
  y: number;
  vx: number;
  vy: number;
  ageMs: number;
  ttlMs: number;
  text: string;
  color: string;
  size: number;
  baseScale: number;
  popMs: number;
};

const ARENA_COOLDOWN_TICKS = 30;

function clamp(value: number, min: number, max: number) {
  return Math.min(max, Math.max(min, value));
}

function parseDamage(log: CombatRoundLog): number {
  const raw = Number(log.dano_mitigado ?? log.damage ?? 0);
  return Number.isFinite(raw) ? Math.max(0, Math.round(raw)) : 0;
}

function parseTick(log: CombatRoundLog): number {
  const raw = Number(log.tick ?? 0);
  return Number.isFinite(raw) ? Math.max(0, Math.floor(raw)) : 0;
}

function parseTargetIds(log: CombatRoundLog): string[] {
  if (Array.isArray(log.target_ids)) {
    return log.target_ids.map((id) => String(id));
  }
  if (log.targetId) {
    return [String(log.targetId)];
  }
  return [];
}

function parseAttackerId(log: CombatRoundLog): string {
  return String(log.attacker_id ?? log.attackerId ?? "UNKNOWN");
}

function parseSkillName(log: CombatRoundLog): string {
  return String(log.habilidade ?? log.kind ?? "");
}

function detectDoT(log: CombatRoundLog): boolean {
  const skill = parseSkillName(log).toUpperCase();
  const statuses = Array.isArray(log.status_aplicado) ? log.status_aplicado.join("|").toUpperCase() : "";
  return skill.includes("DOT") || statuses.includes("DOT") || statuses.includes("SANGRAMENTO_TICK");
}

function detectCrit(log: CombatRoundLog): boolean {
  const statuses = Array.isArray(log.status_aplicado) ? log.status_aplicado : [];
  return statuses.some((status) => String(status).toUpperCase().includes("CRIT"));
}

function detectCastPerk(log: CombatRoundLog): boolean {
  const skill = parseSkillName(log).toUpperCase();
  if (!skill || skill === "ATAQUE_BASICO" || skill === "ATAQUE_INIMIGO") {
    return false;
  }
  if (skill.includes(":DOT") || skill.includes(":SANGRAMENTO") || skill.includes(":TRUE_DOT")) {
    return false;
  }
  return true;
}

function resolveDamageColor(log: CombatRoundLog): string {
  const elemental = String(log.tipo_elemental ?? "").toUpperCase();
  if (elemental === "ACIDO") {
    return "#9b5cff";
  }
  if (elemental === "SANGRAMENTO") {
    return "#8b1e2b";
  }
  if (detectCrit(log)) {
    return "#ff3b3b";
  }
  return "#f8e27a";
}

function resolveFlashColor(attackerId: string): string {
  const key = String(attackerId).toUpperCase();
  if (key.includes("CHICAO")) {
    return "rgba(90, 230, 140, 0.45)";
  }
  if (key.includes("JHENY")) {
    return "rgba(200, 45, 65, 0.45)";
  }
  if (key.includes("ZECA")) {
    return "rgba(255, 200, 110, 0.45)";
  }
  return "rgba(255, 255, 255, 0.35)";
}

function resolveUnitStates(logs: CombatRoundLog[], tickIndex: number): Map<string, UnitStats> {
  const state = new Map<string, UnitStats>();
  const end = Math.min(tickIndex, logs.length - 1);

  for (let i = 0; i <= end; i += 1) {
    const log = logs[i];
    const hpRemaining = Array.isArray(log.hp_restante) ? log.hp_restante : [];
    for (const entry of hpRemaining) {
      const unitId = String(entry.id ?? "");
      const hp = Number(entry.hp ?? 0);
      if (!unitId || !Number.isFinite(hp)) {
        continue;
      }

      const previous = state.get(unitId);
      const nextMax = previous ? Math.max(previous.maxHp, hp) : hp;
      state.set(unitId, { hp, maxHp: Math.max(1, nextMax) });
    }
  }

  return state;
}

function resolveLastCastTicks(logs: CombatRoundLog[], tickIndex: number): Map<string, number> {
  const map = new Map<string, number>();
  const end = Math.min(tickIndex, logs.length - 1);

  for (let i = 0; i <= end; i += 1) {
    const log = logs[i];
    if (!detectCastPerk(log)) {
      continue;
    }
    map.set(parseAttackerId(log), parseTick(log));
  }

  return map;
}

function hpPct(stats: UnitStats | undefined): number {
  if (!stats) {
    return 100;
  }
  return clamp((stats.hp / Math.max(1, stats.maxHp)) * 100, 0, 100);
}

function cooldownFromLastCast(currentTick: number, lastCastTick: number | undefined): CooldownState {
  if (lastCastTick === undefined) {
    return { current: ARENA_COOLDOWN_TICKS, max: ARENA_COOLDOWN_TICKS };
  }

  const elapsed = Math.max(0, currentTick - lastCastTick);
  const remaining = clamp(ARENA_COOLDOWN_TICKS - elapsed, 0, ARENA_COOLDOWN_TICKS);
  return {
    current: ARENA_COOLDOWN_TICKS - remaining,
    max: ARENA_COOLDOWN_TICKS
  };
}

export const ArenaComponent = memo(function ArenaComponent() {
  const profile = useGameStore((state) => state.profile);
  const combatLogs = useGameStore((state) => state.combatLogs);

  const arenaRef = useRef<HTMLDivElement | null>(null);
  const heroRef = useRef<HTMLDivElement | null>(null);
  const enemyRef = useRef<HTMLDivElement | null>(null);
  const canvasRef = useRef<HTMLCanvasElement | null>(null);
  const fxQueueRef = useRef<FxParticle[]>([]);
  const fxRafRef = useRef<number | null>(null);
  const lastFxNowRef = useRef<number | null>(null);
  const flashUntilRef = useRef<number>(0);
  const flashColorRef = useRef<string>("rgba(255,255,255,0)");

  const getTargetCenter = useCallback((targetId: string) => {
    const isHeroTarget = String(targetId).toUpperCase() === String(profile.hero_id ?? "").toUpperCase();
    const node = isHeroTarget ? heroRef.current : enemyRef.current;
    const arenaNode = arenaRef.current;
    if (!node || !arenaNode) {
      return { x: 120, y: 90 };
    }

    const rect = node.getBoundingClientRect();
    const arenaRect = arenaNode.getBoundingClientRect();
    return {
      x: rect.left - arenaRect.left + rect.width / 2,
      y: rect.top - arenaRect.top + rect.height / 2
    };
  }, [profile.hero_id]);

  const {
    visualState,
    currentTick,
    totalTicks,
    playbackSpeed,
    isPlaying,
    play,
    pause,
    skipToEnd,
    setPlaybackSpeed
  } = useCombatPlayback({
    onTickEvent: ({ log, isLast }) => {
      const damage = parseDamage(log);
      if (damage > 0) {
        const targets = parseTargetIds(log);
        const targetId = targets[0] ?? String(profile.hero_id ?? "");
        const center = getTargetCenter(targetId);
        const isDot = detectDoT(log);
        const isCrit = detectCrit(log);

        fxQueueRef.current.push({
          x: center.x,
          y: center.y - 12,
          vx: (Math.random() - 0.5) * 10,
          vy: isDot ? -18 : -24,
          ageMs: 0,
          ttlMs: isDot ? 650 : 780,
          text: `-${damage}`,
          color: resolveDamageColor(log),
          size: isDot ? 14 : isCrit ? 26 : 20,
          baseScale: isCrit ? 2 : 1,
          popMs: isCrit ? 110 : 40
        });
      }

      if (detectCastPerk(log)) {
        flashUntilRef.current = performance.now() + 120;
        flashColorRef.current = resolveFlashColor(parseAttackerId(log));
      }

      if (isLast) {
        flashUntilRef.current = performance.now() + 90;
        flashColorRef.current = "rgba(255,255,255,0.25)";
      }
    }
  });

  useEffect(() => {
    const canvas = canvasRef.current;
    const arena = arenaRef.current;
    if (!canvas || !arena) {
      return;
    }

    const resize = () => {
      const ratio = window.devicePixelRatio || 1;
      const rect = arena.getBoundingClientRect();
      canvas.width = Math.max(1, Math.floor(rect.width * ratio));
      canvas.height = Math.max(1, Math.floor(rect.height * ratio));
      canvas.style.width = `${rect.width}px`;
      canvas.style.height = `${rect.height}px`;
      const ctx = canvas.getContext("2d");
      if (ctx) {
        ctx.setTransform(ratio, 0, 0, ratio, 0, 0);
      }
    };

    resize();
    const ro = new ResizeObserver(() => resize());
    ro.observe(arena);

    const draw = (now: number) => {
      const ctx = canvas.getContext("2d");
      if (!ctx) {
        fxRafRef.current = requestAnimationFrame(draw);
        return;
      }

      const last = lastFxNowRef.current ?? now;
      const delta = Math.max(0, now - last);
      lastFxNowRef.current = now;

      const rect = arena.getBoundingClientRect();
      ctx.clearRect(0, 0, rect.width, rect.height);

      if (now < flashUntilRef.current) {
        ctx.fillStyle = flashColorRef.current;
        ctx.fillRect(0, 0, rect.width, rect.height);
      }

      const alive: FxParticle[] = [];
      for (const particle of fxQueueRef.current) {
        particle.ageMs += delta;
        const t = particle.ageMs / particle.ttlMs;
        if (t >= 1) {
          continue;
        }

        particle.x += (particle.vx * delta) / 1000;
        particle.y += (particle.vy * delta) / 1000;

        const alpha = 1 - t;
        const popRatio = particle.popMs > 0 ? clamp(1 - particle.ageMs / particle.popMs, 0, 1) : 0;
        const scale = 1 + popRatio * (particle.baseScale - 1);

        ctx.save();
        ctx.globalAlpha = alpha;
        ctx.fillStyle = particle.color;
        ctx.font = `700 ${Math.max(10, particle.size * scale)}px sans-serif`;
        ctx.textAlign = "center";
        ctx.textBaseline = "middle";
        ctx.fillText(particle.text, particle.x, particle.y);
        ctx.restore();

        alive.push(particle);
      }

      fxQueueRef.current = alive;
      fxRafRef.current = requestAnimationFrame(draw);
    };

    fxRafRef.current = requestAnimationFrame(draw);

    return () => {
      ro.disconnect();
      if (fxRafRef.current !== null) {
        cancelAnimationFrame(fxRafRef.current);
      }
      fxRafRef.current = null;
      lastFxNowRef.current = null;
      fxQueueRef.current = [];
      const ctx = canvas.getContext("2d");
      if (ctx) {
        ctx.clearRect(0, 0, canvas.width, canvas.height);
      }
    };
  }, []);

  const visibleLogs = useMemo(() => {
    if (combatLogs.length === 0) {
      return [];
    }
    return combatLogs.slice(0, Math.max(1, currentTick + 1));
  }, [combatLogs, currentTick]);

  const unitStateMap = useMemo(() => resolveUnitStates(combatLogs, currentTick), [combatLogs, currentTick]);
  const lastCastMap = useMemo(() => resolveLastCastTicks(combatLogs, currentTick), [combatLogs, currentTick]);

  const heroId = String(profile.hero_id ?? "HERO");
  const enemyId = useMemo(() => {
    for (const log of visibleLogs) {
      const attacker = parseAttackerId(log);
      if (attacker && attacker !== heroId) {
        return attacker;
      }

      const targets = parseTargetIds(log);
      const enemyTarget = targets.find((id) => id !== heroId);
      if (enemyTarget) {
        return enemyTarget;
      }
    }
    return "RIVAL";
  }, [heroId, visibleLogs]);

  const heroStats = unitStateMap.get(heroId);
  const enemyStats = unitStateMap.get(enemyId);
  const heroHp = hpPct(heroStats);
  const enemyHp = hpPct(enemyStats);

  const heroCd = cooldownFromLastCast(currentTick, lastCastMap.get(heroId));
  const enemyCd = cooldownFromLastCast(currentTick, lastCastMap.get(enemyId));

  const heroDead = heroStats ? heroStats.hp <= 0 : false;
  const enemyDead = enemyStats ? enemyStats.hp <= 0 : false;

  return (
    <section className="mt-2 rounded-md border border-zinc-700 bg-zinc-900/65 p-2">
      <header className="mb-2 flex items-center justify-between text-[10px] text-zinc-300">
        <h3 className="font-semibold tracking-wide text-amber-200">Arena</h3>
        <span>
          Tick {Math.min(currentTick + 1, Math.max(totalTicks, 1))}/{Math.max(totalTicks, 1)}
        </span>
      </header>

      <div ref={arenaRef} className="relative overflow-hidden rounded border border-zinc-700 bg-zinc-950/70 p-3">
        <canvas ref={canvasRef} className="pointer-events-none absolute inset-0 z-10" />

        <div className="relative z-0 grid grid-cols-2 gap-3">
          <div
            ref={heroRef}
            className={`rounded border border-emerald-700/60 bg-emerald-900/15 p-2 transition ${heroDead ? "opacity-40 grayscale" : "opacity-100"}`}
          >
            <p className="truncate text-[10px] font-semibold text-emerald-200">{heroId}</p>
            <div className="mt-1 h-2 w-full overflow-hidden rounded bg-zinc-800">
              <div className="h-full bg-emerald-400 transition-all" style={{ width: `${heroHp}%` }} />
            </div>
            <p className="mt-1 text-[9px] text-zinc-300">
              HP: {heroStats ? `${heroStats.hp}/${heroStats.maxHp}` : "--"}
            </p>

            <div className="mt-1 h-1.5 w-full overflow-hidden rounded bg-zinc-800">
              <div
                className="h-full bg-cyan-400 transition-all"
                style={{ width: `${(heroCd.current / Math.max(1, heroCd.max)) * 100}%` }}
              />
            </div>
            <p className="mt-1 text-[8px] text-zinc-400">Cooldown</p>
          </div>

          <div
            ref={enemyRef}
            className={`rounded border border-rose-700/60 bg-rose-900/15 p-2 transition ${enemyDead ? "opacity-40 grayscale" : "opacity-100"}`}
          >
            <p className="truncate text-[10px] font-semibold text-rose-200">{enemyId}</p>
            <div className="mt-1 h-2 w-full overflow-hidden rounded bg-zinc-800">
              <div className="h-full bg-rose-400 transition-all" style={{ width: `${enemyHp}%` }} />
            </div>
            <p className="mt-1 text-[9px] text-zinc-300">
              HP: {enemyStats ? `${enemyStats.hp}/${enemyStats.maxHp}` : "--"}
            </p>

            <div className="mt-1 h-1.5 w-full overflow-hidden rounded bg-zinc-800">
              <div
                className="h-full bg-cyan-400 transition-all"
                style={{ width: `${(enemyCd.current / Math.max(1, enemyCd.max)) * 100}%` }}
              />
            </div>
            <p className="mt-1 text-[8px] text-zinc-400">Cooldown</p>
          </div>
        </div>
      </div>

      <div className="mt-2 flex flex-wrap items-center gap-1 rounded border border-zinc-700 bg-zinc-900/60 px-2 py-1 text-[9px] text-zinc-300">
        <button
          type="button"
          className="rounded border border-zinc-600 px-1.5 py-0.5 hover:bg-zinc-800"
          onClick={() => {
            if (isPlaying) {
              pause();
            } else {
              play();
            }
          }}
          disabled={totalTicks === 0}
        >
          {isPlaying ? "Pause" : "Play"}
        </button>

        <button
          type="button"
          className="rounded border border-zinc-600 px-1.5 py-0.5 hover:bg-zinc-800"
          onClick={() => skipToEnd()}
          disabled={totalTicks === 0}
        >
          Skip
        </button>

        <button type="button" className="rounded border border-zinc-600 px-1.5 py-0.5 hover:bg-zinc-800" onClick={() => setPlaybackSpeed(1)}>
          1x
        </button>
        <button type="button" className="rounded border border-zinc-600 px-1.5 py-0.5 hover:bg-zinc-800" onClick={() => setPlaybackSpeed(2)}>
          2x
        </button>
        <button type="button" className="rounded border border-zinc-600 px-1.5 py-0.5 hover:bg-zinc-800" onClick={() => setPlaybackSpeed(4)}>
          4x
        </button>
        <span className="ml-1 text-zinc-400">Velocidade: {playbackSpeed.toFixed(2)}x</span>
      </div>

      <p className="mt-1 text-[9px] text-zinc-400">
        Estado visual: {visualState.is_animating ? "ATIVO" : "IDLE"} | Atacante: {visualState.actor_id ?? "-"} | Alvo: {visualState.target_id ?? "-"}
      </p>
    </section>
  );
});

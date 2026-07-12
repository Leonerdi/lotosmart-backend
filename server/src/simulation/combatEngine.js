import { calculateItemPower } from "../utils/balancer.js";
import {
  DAMAGE_TYPE,
  HERO_IDS,
  getBasicSkill,
  getHeroDefinition,
  getUnlockedActiveSkills
} from "../../config/heroCatalog.js";
import { CAMPAIGN_ACTS } from "../../config/campaign.js";
import { resolvePassiveTalentModifiers } from "./talentEngine.js";
import { inferHeroOwnerFromItem } from "../inventory/inventoryService.js";

const MAX_ROUNDS_DEFAULT = 24;
const STRESS_TEST_ACTS = [1, 5, 10];
const TICK_DURATION = 0.1;
const TICKS_PER_SECOND = 10;
const BASIC_ATTACK_INTERVAL_TICKS = 10;
const CRIT_MULTIPLIER = 1.5;

function parseEnvNumber(key, fallback) {
  const raw = process.env[key];
  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) {
    return fallback;
  }
  return parsed;
}

function parseOptionalEnvNumber(key) {
  const raw = process.env[key];
  if (raw === undefined || raw === null || String(raw).trim() === "") {
    return null;
  }

  const parsed = Number(raw);
  if (!Number.isFinite(parsed)) {
    return null;
  }

  return parsed;
}

const RANKED_CAPS = {
  evasion: 0.45,
  critico_efetivo: 0.55,
  red_def: 0.3,
  red_attack_speed: 0.35,
  sangramento_por_segundo: 0.12
};

const CAMPAIGN_CLASS_MODIFIERS = {
  [HERO_IDS.ZECA_MARRETA]: {
    impactDamagePct: parseEnvNumber("PVE_ZECA_IMPACT_DAMAGE_PCT", 0.4),
    physicalLifestealPct: parseEnvNumber("PVE_ZECA_PHYSICAL_LIFESTEAL_PCT", 0.35),
    incomingDamageMultiplier: parseEnvNumber("PVE_ZECA_INCOMING_DAMAGE_MULTIPLIER", 0.65),
    bonusDamageFromMaxHpPctVsBoss: parseEnvNumber("PVE_ZECA_BONUS_DAMAGE_FROM_MAX_HP_PCT_VS_BOSS", 0.082)
  },
  [HERO_IDS.CHICAO_DO_GAS]: {
    passiveTrueDotPctMaxHpPerTick: parseEnvNumber("PVE_CHICAO_TRUE_DOT_PCT_PER_STACK", 0.0075)
  }
};

const HERO_PERK_CATALOG = {
  [HERO_IDS.ZECA_MARRETA]: [
    {
      id: "GRITO_DE_INTIMIDACAO",
      nome: "Grito de Intimidacao",
      cooldownTicks: 120,
      castTicks: 4,
      priority: 1,
      kind: "DEBUFF_PHYSICAL_DAMAGE",
      durationTicks: 40,
      value: 0.2
    },
    {
      id: "PANCADA_DE_CHOQUE",
      nome: "Pancada de Choque",
      cooldownTicks: 80,
      castTicks: 5,
      priority: 2,
      kind: "DIRECT_DAMAGE_STUN",
      type: DAMAGE_TYPE.RAIO,
      flat: 50,
      atkScale: 1.5,
      stunTicks: 15,
      targetCount: 1
    },
    {
      id: "TERREMOTO_DO_BECO",
      nome: "Terremoto do Beco",
      cooldownTicks: 150,
      castTicks: 8,
      priority: 2,
      kind: "DIRECT_DAMAGE_DEF_BREAK_DOT",
      type: DAMAGE_TYPE.FISICO,
      flat: 20,
      atkScale: 0.8,
      durationTicks: 50,
      intervalTicks: 10,
      defBreakPerTick: 0.1,
      defBreakCap: 0.3,
      targetCount: 1
    },
    {
      id: "CASCA_GROSSA",
      nome: "Casca Grossa",
      cooldownTicks: 0,
      castTicks: 0,
      priority: 4,
      kind: "PASSIVE_CASCA_GROSSA"
    }
  ],
  [HERO_IDS.CHICAO_DO_GAS]: [
    {
      id: "COQUETEL_MOLOTOV",
      nome: "Coquetel Molotov",
      cooldownTicks: 100,
      castTicks: 4,
      priority: 2,
      kind: "APPLY_DOT",
      dotType: DAMAGE_TYPE.FOGO,
      flat: 15,
      atkScale: 0.4,
      durationTicks: 50,
      intervalTicks: 10,
      maxStacks: 1,
      targetCount: 1
    },
    {
      id: "ACIDO_DE_BATERIA",
      nome: "Acido de Bateria",
      cooldownTicks: 120,
      castTicks: 4,
      priority: 2,
      kind: "APPLY_DOT_DEF_BREAK",
      dotType: DAMAGE_TYPE.ACIDO,
      flat: 10,
      atkScale: 0.25,
      durationTicks: 60,
      intervalTicks: 5,
      maxStacks: 3,
      defBreakPerStack: 0.1,
      targetCount: 1
    },
    {
      id: "EXPLOSAO_DE_BOTIJAO",
      nome: "Explosao de Botijao",
      cooldownTicks: 180,
      castTicks: 10,
      priority: 1,
      kind: "DIRECT_DAMAGE_STUN",
      type: DAMAGE_TYPE.FOGO,
      flat: 100,
      atkScale: 2.0,
      stunTicks: 20,
      targetCount: 99
    },
    {
      id: "MESTRE_DOS_GASES",
      nome: "Mestre dos Gases",
      cooldownTicks: 0,
      castTicks: 0,
      priority: 3,
      kind: "PASSIVE_INTERVAL_TOXIN",
      intervalTicks: 10,
      durationTicks: 80,
      maxStacks: 5,
      flat: 5,
      atkScale: 0.12,
      attackSpeedSlowPerStack: 0.07,
      attackSpeedSlowCap: 0.35
    }
  ],
  [HERO_IDS.JHENY_NAVALHA]: [
    {
      id: "ESTILINGUE_DE_CHUMBINHO",
      nome: "Estilingue de Chumbinho",
      cooldownTicks: 60,
      castTicks: 2,
      priority: 2,
      kind: "DIRECT_DAMAGE",
      type: DAMAGE_TYPE.PERFURACAO,
      flat: 30,
      atkScale: 1.1,
      targetCount: 1
    },
    {
      id: "PISTOLA_DE_PREGO_TASER",
      nome: "Pistola de Prego Taser",
      cooldownTicks: 110,
      castTicks: 3,
      priority: 1,
      kind: "DIRECT_DAMAGE_STUN_CANCEL",
      type: DAMAGE_TYPE.RAIO,
      flat: 20,
      atkScale: 0.7,
      stunTicks: 10,
      targetCount: 1
    },
    {
      id: "CHUVA_DE_ESTILHACOS",
      nome: "Chuva de Estilhacos",
      cooldownTicks: 140,
      castTicks: 5,
      priority: 2,
      kind: "APPLY_DOT_BLEED",
      dotType: DAMAGE_TYPE.PERFURACAO,
      flat: 8,
      atkScale: 0.2,
      durationTicks: 60,
      intervalTicks: 5,
      maxStacks: 5,
      bleedPctMaxHpPerSecond: 0.02,
      targetCount: 1
    },
    {
      id: "FOCO_ASSASSINO",
      nome: "Foco Assassino",
      cooldownTicks: 0,
      castTicks: 0,
      priority: 4,
      kind: "PASSIVE_FOCUS_CRIT",
      maxStacks: 5,
      durationTicks: 40,
      critPerStack: 0.08
    }
  ]
};

function slotToBalancerSlot(slot) {
  const raw = String(slot ?? "").trim().toUpperCase();
  const map = {
    WEAPON_PRIMARY: "ARMA_PRIMARIA",
    WEAPON_SECONDARY: "ARMA_SECUNDARIA",
    HEAD: "CABECA",
    CHEST: "PEITORAL",
    LEGS: "CALCA",
    HANDS: "MAO",
    FEET: "BOTAS",
    TALISMAN: "AMULETO_DA_SORTE"
  };
  return map[raw] ?? raw;
}

function buildRankedEnemyWaveFromSnapshot(rivalSquad) {
  const heroId = String(rivalSquad?.heroId ?? HERO_IDS.CHICAO_DO_GAS).toUpperCase();
  const level = Math.max(1, Number(rivalSquad?.characterLevel ?? 1));
  const hpMultiplier = Math.max(0.1, Number(rivalSquad?.hpMultiplier ?? 1));
  const hero = getHeroDefinition(heroId);

  const equippedItems = (rivalSquad?.items ?? []).filter((item) => item?.equipped);
  const itemPower = equippedItems.reduce(
    (acc, item) =>
      acc +
      calculateItemPower({
        nivelItem: item.nivel ?? item.item_level ?? level,
        slot: slotToBalancerSlot(item.slot),
        raridade: item.raridade ?? "RARO"
      }),
    0
  );

  const maxHp = Math.round((220 + level * 58 + itemPower * 2.7) * hpMultiplier);
  const attack = Math.round(14 + level * 5.2 + Math.pow(itemPower, 0.7) * 1.8);
  const defense = Math.round(8 + level * 2.2 + itemPower * 0.04);

  return [
    createEnemyUnit({
      id: `ranked-${hero.id}`,
      nome: `Rival ${hero.nome}`,
      hp: maxHp,
      attack,
      defense,
      enemyType: hero.heroClass === "BRUCUTU" ? "ARMADURA" : "AGIL",
      elementType: hero.nativeDamage ?? DAMAGE_TYPE.FISICO
    })
  ];
}

const EQUIP_SLOTS = [
  "CABECA",
  "PEITORAL",
  "CALCA",
  "BOTAS",
  "MAO",
  "ARMA_PRIMARIA",
  "ARMA_SECUNDARIA",
  "AMULETO_DA_SORTE"
];

function clamp(value, min, max) {
  return Math.min(max, Math.max(min, value));
}

function randomRange(min, max, rng) {
  return min + (max - min) * rng();
}

function getActiveEquippedItems(items, heroId) {
  const targetHeroId = String(heroId ?? "").trim().toUpperCase();

  return (items ?? []).filter((item) => {
    if (!item?.equipped || item?.durabilidade <= 0) {
      return false;
    }

    const owner = inferHeroOwnerFromItem(item);
    if (!owner) {
      return true;
    }

    return owner === targetHeroId;
  });
}

function buildHeroBaseStats({ heroId, characterLevel, items }) {
  const equippedItems = getActiveEquippedItems(items, heroId);
  const itemPower = equippedItems.reduce(
    (acc, item) =>
      acc +
      calculateItemPower({
        nivelItem: item.nivel,
        slot: item.slot,
        raridade: item.raridade
      }),
    0
  );
  const itemBonus = equippedItems.reduce((acc, item) => acc + Number(item.bonus ?? 0), 0);
  const level = Math.max(1, characterLevel ?? 1);

  return {
    maxHp: Math.round(260 + level * 72 + itemPower * 4.2 + itemBonus * 2.1),
    attack: Math.round(16 + level * 7.4 + Math.pow(itemPower, 0.72) * 2.8 + itemBonus * 0.8),
    defense: Math.round(10 + level * 3 + itemPower * 0.05),
    level,
    equippedItems
  };
}

function levelDamageAttenuation(level) {
  const overflow = Math.max(0, level - 15);
  return 1 / (1 + overflow * 0.012);
}

function createHeroUnit({ heroId, characterLevel, items, talentNodes }) {
  const hero = getHeroDefinition(heroId ?? HERO_IDS.ZECA_MARRETA);
  const base = buildHeroBaseStats({ heroId: hero.id, characterLevel, items });
  const passive = resolvePassiveTalentModifiers(talentNodes);

  const maxHp = Math.round(base.maxHp * passive.vida);
  const attack = Math.round(base.attack * passive.dano);
  const defense = Math.round(base.defense * passive.armadura);

  return {
    id: hero.id,
    nome: hero.nome,
    level: base.level,
    heroClass: hero.heroClass,
    nativeDamage: hero.nativeDamage,
    maxHp,
    hp: maxHp,
    attack,
    defense,
    fury: 0,
    cooldowns: {},
    buffs: {
      defensePct: 0,
      defenseTurns: 0,
      attackPct: 0,
      attackTurns: 0,
      cadencePct: 0,
      cadenceTurns: 0
    },
    resistances: passive.resistances,
    status: {
      stunnedTurns: 0,
      bleed: []
    }
  };
}

function createEnemyUnit({
  id,
  nome,
  hp,
  attack,
  defense,
  enemyType = "PADRAO",
  elementType = DAMAGE_TYPE.FISICO,
  pveDamageCoefficients = null
}) {
  return {
    id,
    nome,
    maxHp: Math.max(1, Math.round(hp)),
    hp: Math.max(1, Math.round(hp)),
    attack: Math.max(1, Math.round(attack)),
    defense: Math.max(0, Math.round(defense)),
    enemyType,
    elementType,
    pveDamageCoefficients,
    debuffs: {
      defenseReductionPct: 0,
      defenseReductionTurns: 0,
      attackReductionPct: 0,
      attackReductionTurns: 0
    },
    status: {
      stunnedTurns: 0,
      bleed: []
    }
  };
}

function createLogEntry({
  round,
  attackerId,
  targetIds,
  skill,
  elementalType,
  rawDamage,
  mitigatedDamage,
  statusApplied,
  hpRemaining
}) {
  return {
    round,
    attacker_id: attackerId,
    target_ids: targetIds,
    habilidade: skill,
    tipo_elemental: elementalType,
    dano_bruto: Math.round(rawDamage),
    dano_mitigado: Math.round(mitigatedDamage),
    status_aplicado: statusApplied,
    hp_restante: hpRemaining
  };
}

function decrementDurations(hero, enemies) {
  if (hero.buffs.defenseTurns > 0) {
    hero.buffs.defenseTurns -= 1;
    if (hero.buffs.defenseTurns === 0) {
      hero.buffs.defensePct = 0;
    }
  }
  if (hero.buffs.attackTurns > 0) {
    hero.buffs.attackTurns -= 1;
    if (hero.buffs.attackTurns === 0) {
      hero.buffs.attackPct = 0;
    }
  }
  if (hero.buffs.cadenceTurns > 0) {
    hero.buffs.cadenceTurns -= 1;
    if (hero.buffs.cadenceTurns === 0) {
      hero.buffs.cadencePct = 0;
    }
  }

  for (const [skillId, cooldown] of Object.entries(hero.cooldowns)) {
    if (cooldown > 0) {
      hero.cooldowns[skillId] = cooldown - 1;
    }
  }

  for (const enemy of enemies) {
    if (enemy.debuffs.defenseReductionTurns > 0) {
      enemy.debuffs.defenseReductionTurns -= 1;
      if (enemy.debuffs.defenseReductionTurns === 0) {
        enemy.debuffs.defenseReductionPct = 0;
      }
    }

    if (enemy.debuffs.attackReductionTurns > 0) {
      enemy.debuffs.attackReductionTurns -= 1;
      if (enemy.debuffs.attackReductionTurns === 0) {
        enemy.debuffs.attackReductionPct = 0;
      }
    }
  }
}

function processBleedTick(unit, round, logs, targetName = "TARGET") {
  if (!unit.status.bleed.length || unit.hp <= 0) {
    return;
  }

  const nextBleed = [];
  for (const effect of unit.status.bleed) {
    const damage = Math.max(1, Math.round(effect.damagePerTurn));
    unit.hp = Math.max(0, unit.hp - damage);

    logs.push(
      createLogEntry({
        round,
        attackerId: effect.sourceId,
        targetIds: [unit.id],
        skill: `${effect.sourceSkill}:DOT`,
        elementalType: DAMAGE_TYPE.SANGRAMENTO,
        rawDamage: damage,
        mitigatedDamage: damage,
        statusApplied: ["SANGRAMENTO_TICK"],
        hpRemaining: [{ id: unit.id, nome: targetName, hp: unit.hp }]
      })
    );

    if (effect.remainingTurns - 1 > 0 && unit.hp > 0) {
      nextBleed.push({ ...effect, remainingTurns: effect.remainingTurns - 1 });
    }
  }

  unit.status.bleed = nextBleed;
}

function elementalMultiplier(type, target) {
  if (type === DAMAGE_TYPE.FOGO && target.elementType === DAMAGE_TYPE.GELO) {
    return 1.5;
  }
  if (type === DAMAGE_TYPE.ACIDO && target.enemyType === "ARMADURA") {
    return 1.5;
  }

  return 1;
}

function effectiveDefenseAgainst(type, target) {
  const baseDefense = Math.max(0, target.defense * (1 - target.debuffs.defenseReductionPct));

  if (
    type === DAMAGE_TYPE.PERFURACAO &&
    (target.enemyType === "AGIL" || target.enemyType === "AGEL")
  ) {
    return baseDefense * 0.5;
  }

  return baseDefense;
}

function applyResistance(target, type, damage) {
  const resistance = Number(target.resistances?.[type] ?? 0);
  return damage * (1 - clamp(resistance, 0, 0.4));
}

function pickTargets(enemies, count) {
  const living = enemies.filter((enemy) => enemy.hp > 0);
  return living.slice(0, Math.max(1, count));
}

function evaluateImpactScore(skill) {
  const targetFactor = Math.max(1, skill.targetCount ?? 1);
  const power = Math.max(0.1, skill.powerMultiplier ?? 1);
  const controlBonus =
    (skill.tags?.includes("STUN_25") ? 0.25 : 0) +
    (skill.tags?.includes("DEFENSE_BREAK_40_3") ? 0.2 : 0) +
    (skill.tags?.includes("BLEED_DOT_10_3") ? 0.2 : 0) +
    (skill.tags?.includes("BUFF_ATTACK_30_3") ? 0.2 : 0);

  return power * targetFactor + controlBonus;
}

function getCooldownCycleLength(heroId, characterLevel) {
  const skills = getUnlockedActiveSkills(heroId, characterLevel).filter(
    (skill) => (skill.cooldownTurns ?? 0) > 0
  );

  if (!skills.length) {
    return 1;
  }

  const maxCooldown = skills.reduce(
    (acc, skill) => Math.max(acc, Number(skill.cooldownTurns ?? 0)),
    1
  );
  return Math.max(1, maxCooldown);
}

function chooseHeroSkill(hero, heroId, characterLevel) {
  const active = getUnlockedActiveSkills(heroId, characterLevel)
    .filter((skill) => Number(hero.cooldowns[skill.id] ?? 0) <= 0)
    .sort((a, b) => evaluateImpactScore(b) - evaluateImpactScore(a));

  if (active.length) {
    return active[0];
  }

  return getBasicSkill(heroId, characterLevel);
}

function applyHeroSelfSkillEffects(hero, skill) {
  if (skill.tags?.includes("BUFF_DEFENSE_30_2")) {
    hero.buffs.defensePct = 0.3;
    hero.buffs.defenseTurns = 2;
  }

  const healTag = skill.tags?.find((tag) => /^HEAL_\d+_PERCENT$/.test(tag));
  if (healTag) {
    const healPercent = Number(healTag.split("_")[1]) / 100;
    const heal = Math.round(hero.maxHp * healPercent);
    hero.hp = Math.min(hero.maxHp, hero.hp + heal);
  }

  if (skill.tags?.includes("BUFF_ATTACK_30_3")) {
    hero.buffs.attackPct = 0.3;
    hero.buffs.attackTurns = 3;
  }

  if (skill.tags?.includes("BUFF_CADENCE_30_3")) {
    hero.buffs.cadencePct = 0.3;
    hero.buffs.cadenceTurns = 3;
  }

  if (skill.tags?.includes("GENERATE_FURY_5")) {
    hero.fury = clamp(hero.fury + 5, 0, 100);
  }
}

function computeHeroAttackValue(hero) {
  const buffed = hero.attack * (1 + hero.buffs.attackPct);
  return buffed * levelDamageAttenuation(hero.level);
}

function applyStatusFromSkill({ skill, rawDamage, target, sourceId, rng }) {
  const statuses = [];

  if (skill.type === DAMAGE_TYPE.RAIO || skill.tags?.includes("STUN_25")) {
    if (rng() < 0.25) {
      target.status.stunnedTurns = Math.max(target.status.stunnedTurns, 1);
      statuses.push("ATORDOADO");
    }
  }

  if (skill.type === DAMAGE_TYPE.SANGRAMENTO || skill.tags?.includes("BLEED_DOT_10_3")) {
    const bleedDamage = Math.max(1, Math.round(rawDamage * 0.1));
    target.status.bleed.push({
      damagePerTurn: bleedDamage,
      remainingTurns: 3,
      sourceId,
      sourceSkill: skill.nome
    });
    statuses.push("SANGRAMENTO_3T");
  }

  if (skill.tags?.includes("DEFENSE_BREAK_40_3")) {
    target.debuffs.defenseReductionPct = 0.4;
    target.debuffs.defenseReductionTurns = 3;
    statuses.push("DEFESA_-40%_3T");
  }

  if (skill.tags?.includes("ATK_REDUCE_25_2")) {
    target.debuffs.attackReductionPct = 0.25;
    target.debuffs.attackReductionTurns = 2;
    statuses.push("ATAQUE_-25%_2T");
  }

  return statuses;
}

function applyHeroSkillToTargets({ hero, enemies, skill, round, logs, rng }) {
  if ((skill.targetCount ?? 0) === 0) {
    applyHeroSelfSkillEffects(hero, skill);
    logs.push(
      createLogEntry({
        round,
        attackerId: hero.id,
        targetIds: [hero.id],
        skill: skill.nome,
        elementalType: skill.type,
        rawDamage: 0,
        mitigatedDamage: 0,
        statusApplied: ["AUTO_BUFF_OR_HEAL"],
        hpRemaining: [{ id: hero.id, nome: hero.nome, hp: hero.hp }]
      })
    );
    return;
  }

  const targets = pickTargets(enemies, skill.targetCount ?? 1);
  const attackerValue = computeHeroAttackValue(hero);

  for (const target of targets) {
    if (target.hp <= 0) {
      continue;
    }

    const baseRaw = attackerValue * (skill.powerMultiplier ?? 1);
    const withElemental = baseRaw * elementalMultiplier(skill.type, target);
    const defense = skill.type === DAMAGE_TYPE.SANGRAMENTO ? 0 : effectiveDefenseAgainst(skill.type, target);
    const mitigated = Math.max(1, Math.round(withElemental - defense));
    target.hp = Math.max(0, target.hp - mitigated);

    const statuses = applyStatusFromSkill({
      skill,
      rawDamage: withElemental,
      target,
      sourceId: hero.id,
      rng
    });

    logs.push(
      createLogEntry({
        round,
        attackerId: hero.id,
        targetIds: [target.id],
        skill: skill.nome,
        elementalType: skill.type,
        rawDamage: withElemental,
        mitigatedDamage: mitigated,
        statusApplied: statuses,
        hpRemaining: [{ id: target.id, nome: target.nome, hp: target.hp }]
      })
    );

    if (skill.secondaryType && target.hp > 0) {
      const secondaryRaw = attackerValue * 0.35 * elementalMultiplier(skill.secondaryType, target);
      const secondaryMitigated = Math.max(
        1,
        Math.round(secondaryRaw - effectiveDefenseAgainst(skill.secondaryType, target))
      );
      target.hp = Math.max(0, target.hp - secondaryMitigated);
      logs.push(
        createLogEntry({
          round,
          attackerId: hero.id,
          targetIds: [target.id],
          skill: `${skill.nome}:Secundario`,
          elementalType: skill.secondaryType,
          rawDamage: secondaryRaw,
          mitigatedDamage: secondaryMitigated,
          statusApplied: [],
          hpRemaining: [{ id: target.id, nome: target.nome, hp: target.hp }]
        })
      );
    }
  }

  applyHeroSelfSkillEffects(hero, skill);
}

function runEnemyTurn({ hero, enemies, round, logs, rng }) {
  for (const enemy of enemies) {
    if (enemy.hp <= 0 || hero.hp <= 0) {
      continue;
    }

    if (enemy.status.stunnedTurns > 0) {
      enemy.status.stunnedTurns -= 1;
      logs.push(
        createLogEntry({
          round,
          attackerId: enemy.id,
          targetIds: [hero.id],
          skill: "ATORDOADO_SKIP",
          elementalType: enemy.elementType,
          rawDamage: 0,
          mitigatedDamage: 0,
          statusApplied: ["ATORDOADO"],
          hpRemaining: [{ id: hero.id, nome: hero.nome, hp: hero.hp }]
        })
      );
      continue;
    }

    const enemyAtk = enemy.attack * (1 - enemy.debuffs.attackReductionPct);
    const raw = enemyAtk * randomRange(0.92, 1.08, rng);
    const heroDefense = hero.defense * (1 + hero.buffs.defensePct);
    const preResist = Math.max(1, Math.round(raw - heroDefense));
    const finalDamage = Math.max(1, Math.round(applyResistance(hero, enemy.elementType, preResist)));
    hero.hp = Math.max(0, hero.hp - finalDamage);

    logs.push(
      createLogEntry({
        round,
        attackerId: enemy.id,
        targetIds: [hero.id],
        skill: "ATAQUE_INIMIGO",
        elementalType: enemy.elementType,
        rawDamage: raw,
        mitigatedDamage: finalDamage,
        statusApplied: [],
        hpRemaining: [{ id: hero.id, nome: hero.nome, hp: hero.hp }]
      })
    );
  }
}

function secondsFromTicks(ticks) {
  return Number((ticks * TICK_DURATION).toFixed(1));
}

function computeRoundsFromTicks(ticks) {
  return Number((ticks / TICKS_PER_SECOND).toFixed(1));
}

function isRankedQueue(queueType) {
  return String(queueType ?? "CASUAL").trim().toUpperCase() === "RANKEADA";
}

function createTickLogEntry({ tick, attackerId, targetIds, skill, elementalType, rawDamage, mitigatedDamage, statusApplied, hpRemaining }) {
  return {
    tick,
    tempo_s: secondsFromTicks(tick),
    round: computeRoundsFromTicks(tick),
    attacker_id: attackerId,
    target_ids: targetIds,
    habilidade: skill,
    tipo_elemental: elementalType,
    dano_bruto: Math.round(rawDamage),
    dano_mitigado: Math.round(mitigatedDamage),
    status_aplicado: statusApplied,
    hp_restante: hpRemaining
  };
}

function ensureRuntimeFields(unit, side) {
  const baseCrit = side === "HERO" ? 0.12 : 0.06;
  return {
    ...unit,
    side,
    evasionChance: 0,
    critChance: baseCrit,
    stunRemainingTicks: 0,
    cooldowns: {},
    casting: null,
    basicAttackTimer: BASIC_ATTACK_INTERVAL_TICKS,
    passives: {
      nextGasTick: TICKS_PER_SECOND,
      focusTargetId: null,
      focusStacks: 0,
      focusRemainingTicks: 0
    },
    campaignModifiers: {
      impactDamagePct: 0,
      physicalLifestealPct: 0,
      passiveTrueDotPctMaxHpPerTick: 0,
      incomingDamageMultiplier: 1,
      bonusDamageFromMaxHpPctVsBoss: 0
    },
    effects: {
      outgoingPhysicalReductionPct: 0,
      outgoingPhysicalReductionTicks: 0,
      attackSpeedSlowPct: 0,
      attackSpeedSlowTicks: 0,
      temporaryDefenseBreakPct: 0,
      dots: [],
      isBossUnit: false
    }
  };
}

function getAliveUnits(units) {
  return units.filter((unit) => unit.hp > 0);
}

function pickCombatTargets(source, opponents, targetCount) {
  const alive = getAliveUnits(opponents);
  if (!alive.length) {
    return [];
  }

  if (targetCount >= 99) {
    return alive;
  }

  return alive.slice(0, Math.max(1, targetCount));
}

function applyRankedCaps(unit, isRankedMode) {
  if (!isRankedMode) {
    return;
  }

  unit.evasionChance = clamp(unit.evasionChance, 0, RANKED_CAPS.evasion);
  unit.critChance = clamp(unit.critChance, 0, RANKED_CAPS.critico_efetivo);
  unit.effects.temporaryDefenseBreakPct = clamp(unit.effects.temporaryDefenseBreakPct, 0, RANKED_CAPS.red_def);
  unit.effects.attackSpeedSlowPct = clamp(unit.effects.attackSpeedSlowPct, 0, RANKED_CAPS.red_attack_speed);
}

function isBossStage(enemies) {
  return (enemies ?? []).some((enemy) => String(enemy?.id ?? "").toLowerCase().includes("boss"));
}

function applyHeroCampaignModifiers(hero) {
  const cfg = CAMPAIGN_CLASS_MODIFIERS[hero.id];
  if (!cfg) {
    return;
  }

  hero.campaignModifiers.impactDamagePct = clamp(Number(cfg.impactDamagePct ?? 0), 0, 2);
  hero.campaignModifiers.physicalLifestealPct = clamp(Number(cfg.physicalLifestealPct ?? 0), 0, 1);
  hero.campaignModifiers.incomingDamageMultiplier = clamp(Number(cfg.incomingDamageMultiplier ?? 1), 0.1, 2);
  hero.campaignModifiers.bonusDamageFromMaxHpPctVsBoss = clamp(
    Number(cfg.bonusDamageFromMaxHpPctVsBoss ?? 0),
    0,
    1
  );
  hero.campaignModifiers.passiveTrueDotPctMaxHpPerTick = clamp(
    Number(cfg.passiveTrueDotPctMaxHpPerTick ?? 0),
    0,
    0.5
  );
}

function baseAttackBySource(unit) {
  return Math.max(1, unit.attack * levelDamageAttenuation(unit.level ?? 1));
}

function defenseAfterDebuffs(target) {
  const totalBreak = clamp((target.debuffs?.defenseReductionPct ?? 0) + target.effects.temporaryDefenseBreakPct, 0, RANKED_CAPS.red_def);
  return Math.max(0, target.defense * (1 - totalBreak));
}

function normalizeDamageTypeKey(type) {
  const raw = String(type ?? "").trim().toUpperCase();
  if (raw === "PERFURACAO" || raw === "FISICO" || raw === "FOGO" || raw === "ACIDO") {
    return raw;
  }
  return null;
}

function resolveCoefficientDamageKey({ source, target, fallbackType }) {
  if (source?.side === "HERO" && target?.effects?.isBossUnit) {
    if (source.id === HERO_IDS.ZECA_MARRETA) {
      return DAMAGE_TYPE.FISICO;
    }
    if (source.id === HERO_IDS.JHENY_NAVALHA) {
      return DAMAGE_TYPE.PERFURACAO;
    }
    if (source.id === HERO_IDS.CHICAO_DO_GAS) {
      return DAMAGE_TYPE.ACIDO;
    }
  }

  return fallbackType;
}

function getTargetDamageCoefficient({ source, target, type }) {
  const coefficientType = resolveCoefficientDamageKey({ source, target, fallbackType: type });
  const key = normalizeDamageTypeKey(coefficientType);
  if (!key) {
    return 1;
  }

  const envKey = `PVE_BOSS_COEF_${key}`;
  const envOverride = parseOptionalEnvNumber(envKey);
  if (envOverride !== null) {
    return clamp(envOverride, 0.1, 2);
  }

  const coeffTable = target.pveDamageCoefficients ?? target.effects?.pveDamageCoefficients;
  if (!coeffTable || typeof coeffTable !== "object") {
    return 1;
  }

  const value = Number(coeffTable[key]);
  if (!Number.isFinite(value)) {
    return 1;
  }

  return clamp(value, 0.1, 2);
}

function computeDamage({
  source,
  target,
  flat = 0,
  atkScale = 1,
  type = DAMAGE_TYPE.FISICO,
  rng = Math.random,
  attackTag = "HIT"
}) {
  const baseAtk = baseAttackBySource(source);
  let rawBase = flat + baseAtk * atkScale;
  if (attackTag === "HIT") {
    rawBase *= 1 + Number(source.campaignModifiers?.impactDamagePct ?? 0);

    if (source.id === HERO_IDS.ZECA_MARRETA && target.effects?.isBossUnit) {
      rawBase += source.maxHp * Number(source.campaignModifiers?.bonusDamageFromMaxHpPctVsBoss ?? 0);
    }
  }
  const elemental = rawBase * elementalMultiplier(type, target);

  const defense = type === DAMAGE_TYPE.SANGRAMENTO ? 0 : defenseAfterDebuffs(target);
  let mitigated = Math.max(1, elemental - defense);

  if (type === DAMAGE_TYPE.PERFURACAO) {
    mitigated = Math.max(1, mitigated + defense * 0.25);
  }

  const effectiveCrit = clamp(source.critChance ?? 0, 0, RANKED_CAPS.critico_efetivo);
  const isCrit = rng() < effectiveCrit;
  const withCrit = isCrit ? mitigated * CRIT_MULTIPLIER : mitigated;

  const evadeChance = clamp(target.evasionChance ?? 0, 0, RANKED_CAPS.evasion);
  if (rng() < evadeChance) {
    return {
      rawDamage: elemental,
      finalDamage: 0,
      isCrit,
      avoided: true
    };
  }

  const finalDamage = Math.max(1, Math.round(applyResistance(target, type, withCrit)));
  const damageCoefficient = getTargetDamageCoefficient({ source, target, type });
  const coefficientAdjustedDamage = Math.max(1, Math.round(finalDamage * damageCoefficient));
  const reducedByCampaign = Math.max(
    1,
    Math.round(coefficientAdjustedDamage * Number(target.campaignModifiers?.incomingDamageMultiplier ?? 1))
  );
  return {
    rawDamage: elemental,
    finalDamage: reducedByCampaign,
    isCrit,
    avoided: false
  };
}

function applyDamageAndLog({
  tick,
  attacker,
  target,
  skillName,
  damageType,
  flat,
  atkScale,
  logs,
  rng,
  statusApplied = [],
  attackTag = "HIT"
}) {
  const result = computeDamage({ source: attacker, target, flat, atkScale, type: damageType, rng, attackTag });
  target.hp = Math.max(0, target.hp - result.finalDamage);

  const flags = [...statusApplied];
  if (result.isCrit) {
    flags.push("CRITICO");
  }
  if (result.avoided) {
    flags.push("ESQUIVA");
  }

  logs.push(
    createTickLogEntry({
      tick,
      attackerId: attacker.id,
      targetIds: [target.id],
      skill: skillName,
      elementalType: damageType,
      rawDamage: result.rawDamage,
      mitigatedDamage: result.finalDamage,
      statusApplied: flags,
      hpRemaining: [{ id: target.id, nome: target.nome, hp: target.hp }]
    })
  );

  if (damageType === DAMAGE_TYPE.FISICO && attackTag === "HIT") {
    const lifestealPct = Number(attacker.campaignModifiers?.physicalLifestealPct ?? 0);
    if (lifestealPct > 0 && result.finalDamage > 0 && attacker.hp > 0) {
      const heal = Math.max(1, Math.round(result.finalDamage * lifestealPct));
      attacker.hp = Math.min(attacker.maxHp, attacker.hp + heal);
      logs.push(
        createTickLogEntry({
          tick,
          attackerId: attacker.id,
          targetIds: [attacker.id],
          skill: "VAMPIRISMO_FISICO",
          elementalType: DAMAGE_TYPE.FISICO,
          rawDamage: 0,
          mitigatedDamage: 0,
          statusApplied: ["CURA_POR_DANO"],
          hpRemaining: [{ id: attacker.id, nome: attacker.nome, hp: attacker.hp }]
        })
      );
    }
  }

  return result;
}

function refreshFocusPassive(attacker, targetId) {
  if (attacker.id !== HERO_IDS.JHENY_NAVALHA) {
    return;
  }

  if (attacker.passives.focusTargetId === targetId && attacker.passives.focusRemainingTicks > 0) {
    attacker.passives.focusStacks = clamp(attacker.passives.focusStacks + 1, 0, 5);
  } else {
    attacker.passives.focusTargetId = targetId;
    attacker.passives.focusStacks = 1;
  }

  attacker.passives.focusRemainingTicks = 40;
}

function updatePassiveStats(unit) {
  if (unit.id === HERO_IDS.ZECA_MARRETA) {
    const hpLostPct = clamp((unit.maxHp - unit.hp) / Math.max(1, unit.maxHp), 0, 1);
    const stacks = clamp(Math.floor(hpLostPct / 0.1), 0, 5);
    unit.buffs.defensePct = stacks * 0.06;
  }

  if (unit.id === HERO_IDS.JHENY_NAVALHA) {
    const focusBonus = (unit.passives.focusStacks ?? 0) * 0.08;
    unit.critChance = 0.12 + focusBonus;
  }
}

function addOrRefreshDot(target, dot) {
  const sameKind = target.effects.dots.filter((effect) => effect.id === dot.id);
  if (sameKind.length < (dot.maxStacks ?? 1)) {
    target.effects.dots.push(dot);
    return;
  }

  let oldestIndex = -1;
  let oldestEndTick = Number.POSITIVE_INFINITY;
  for (let i = 0; i < target.effects.dots.length; i += 1) {
    const effect = target.effects.dots[i];
    if (effect.id !== dot.id) {
      continue;
    }

    if (effect.endTick < oldestEndTick) {
      oldestEndTick = effect.endTick;
      oldestIndex = i;
    }
  }

  if (oldestIndex >= 0) {
    target.effects.dots[oldestIndex] = dot;
  }
}

function applyPerkEffect({ tick, caster, targets, perk, logs, rng, isRankedMode }) {
  if (!targets.length) {
    return;
  }

  if (perk.kind === "DEBUFF_PHYSICAL_DAMAGE") {
    const target = targets[0];
    target.effects.outgoingPhysicalReductionPct = Math.max(target.effects.outgoingPhysicalReductionPct, perk.value);
    target.effects.outgoingPhysicalReductionTicks = Math.max(target.effects.outgoingPhysicalReductionTicks, perk.durationTicks);
    logs.push(
      createTickLogEntry({
        tick,
        attackerId: caster.id,
        targetIds: [target.id],
        skill: perk.nome,
        elementalType: DAMAGE_TYPE.FISICO,
        rawDamage: 0,
        mitigatedDamage: 0,
        statusApplied: ["RED_DANO_FISICO_-20%"],
        hpRemaining: [{ id: target.id, nome: target.nome, hp: target.hp }]
      })
    );
    return;
  }

  for (const target of targets) {
    if (target.hp <= 0) {
      continue;
    }

    if (perk.kind === "DIRECT_DAMAGE" || perk.kind === "DIRECT_DAMAGE_STUN" || perk.kind === "DIRECT_DAMAGE_STUN_CANCEL") {
      const statuses = [];
      const result = applyDamageAndLog({
        tick,
        attacker: caster,
        target,
        skillName: perk.nome,
        damageType: perk.type,
        flat: perk.flat,
        atkScale: perk.atkScale,
        logs,
        rng,
        statusApplied: statuses
      });

      if (result.finalDamage > 0 && caster.side === "HERO") {
        refreshFocusPassive(caster, target.id);
      }

      if (perk.stunTicks) {
        target.stunRemainingTicks = Math.max(target.stunRemainingTicks, perk.stunTicks);
        if (perk.kind === "DIRECT_DAMAGE_STUN_CANCEL" && target.casting) {
          target.casting = null;
        }
      }

      continue;
    }

    if (perk.kind === "DIRECT_DAMAGE_DEF_BREAK_DOT") {
      const result = applyDamageAndLog({
        tick,
        attacker: caster,
        target,
        skillName: perk.nome,
        damageType: perk.type,
        flat: perk.flat,
        atkScale: perk.atkScale,
        logs,
        rng,
        statusApplied: []
      });

      if (result.finalDamage > 0 && caster.side === "HERO") {
        refreshFocusPassive(caster, target.id);
      }

      addOrRefreshDot(target, {
        id: `${caster.id}_${perk.id}`,
        sourceId: caster.id,
        sourceName: perk.nome,
        type: "DEF_BREAK_PULSE",
        maxStacks: 1,
        nextTick: tick + perk.intervalTicks,
        intervalTicks: perk.intervalTicks,
        endTick: tick + perk.durationTicks,
        defBreakPerTick: perk.defBreakPerTick,
        defBreakCap: perk.defBreakCap
      });
      continue;
    }

    if (perk.kind === "APPLY_DOT" || perk.kind === "APPLY_DOT_DEF_BREAK" || perk.kind === "APPLY_DOT_BLEED") {
      addOrRefreshDot(target, {
        id: `${caster.id}_${perk.id}`,
        sourceId: caster.id,
        sourceName: perk.nome,
        type: perk.dotType,
        maxStacks: perk.maxStacks ?? 1,
        nextTick: tick + perk.intervalTicks,
        intervalTicks: perk.intervalTicks,
        endTick: tick + perk.durationTicks,
        flat: perk.flat,
        atkScale: perk.atkScale,
        defBreakPerStack: perk.defBreakPerStack ?? 0,
        bleedPctMaxHpPerSecond: perk.bleedPctMaxHpPerSecond ?? 0
      });
      logs.push(
        createTickLogEntry({
          tick,
          attackerId: caster.id,
          targetIds: [target.id],
          skill: perk.nome,
          elementalType: perk.dotType,
          rawDamage: 0,
          mitigatedDamage: 0,
          statusApplied: ["DOT_APLICADO"],
          hpRemaining: [{ id: target.id, nome: target.nome, hp: target.hp }]
        })
      );
      continue;
    }
  }

  if (isRankedMode) {
    for (const unit of [...targets, caster]) {
      applyRankedCaps(unit, true);
    }
  }
}

function selectNextPerk(hero) {
  const activePerks = (HERO_PERK_CATALOG[hero.id] ?? [])
    .filter((perk) => !perk.kind.startsWith("PASSIVE_"))
    .filter((perk) => Number(hero.cooldowns[perk.id] ?? 0) <= 0)
    .sort((a, b) => a.priority - b.priority || a.cooldownTicks - b.cooldownTicks);

  return activePerks[0] ?? null;
}

function tickDownRuntime(actor) {
  actor.basicAttackTimer = Math.max(0, actor.basicAttackTimer - 1);

  if (actor.stunRemainingTicks > 0) {
    actor.stunRemainingTicks -= 1;
  }

  if (actor.effects.outgoingPhysicalReductionTicks > 0) {
    actor.effects.outgoingPhysicalReductionTicks -= 1;
    if (actor.effects.outgoingPhysicalReductionTicks === 0) {
      actor.effects.outgoingPhysicalReductionPct = 0;
    }
  }

  if (actor.effects.attackSpeedSlowTicks > 0) {
    actor.effects.attackSpeedSlowTicks -= 1;
    if (actor.effects.attackSpeedSlowTicks === 0) {
      actor.effects.attackSpeedSlowPct = 0;
    }
  }

  if (actor.passives.focusRemainingTicks > 0) {
    actor.passives.focusRemainingTicks -= 1;
    if (actor.passives.focusRemainingTicks === 0) {
      actor.passives.focusStacks = 0;
      actor.passives.focusTargetId = null;
    }
  }

  for (const skillId of Object.keys(actor.cooldowns)) {
    actor.cooldowns[skillId] = Math.max(0, Number(actor.cooldowns[skillId] ?? 0) - 1);
  }
}

function processDotTimers({ tick, sourceUnit, target, logs, rng }) {
  const remainingDots = [];
  const appliedStackScaledTrueDots = new Set();

  for (const effect of target.effects.dots) {
    let keep = true;
    while (effect.nextTick <= tick && effect.nextTick <= effect.endTick && target.hp > 0) {
      if (effect.type === "DEF_BREAK_PULSE") {
        target.effects.temporaryDefenseBreakPct = clamp(
          target.effects.temporaryDefenseBreakPct + effect.defBreakPerTick,
          0,
          effect.defBreakCap ?? RANKED_CAPS.red_def
        );

        logs.push(
          createTickLogEntry({
            tick,
            attackerId: effect.sourceId,
            targetIds: [target.id],
            skill: `${effect.sourceName}:DEF_BREAK`,
            elementalType: DAMAGE_TYPE.FISICO,
            rawDamage: 0,
            mitigatedDamage: 0,
            statusApplied: ["DEF_REDUZIDA"],
            hpRemaining: [{ id: target.id, nome: target.nome, hp: target.hp }]
          })
        );
      } else {
        const attacker = sourceUnit(effect.sourceId);
        if (attacker) {
          applyDamageAndLog({
            tick,
            attacker,
            target,
            skillName: `${effect.sourceName}:DOT`,
            damageType: effect.type,
            flat: effect.flat,
            atkScale: effect.atkScale,
            logs,
            rng,
            statusApplied: ["DOT_TICK"],
            attackTag: "DOT"
          });
        }

        if (effect.defBreakPerStack > 0) {
          target.effects.temporaryDefenseBreakPct = clamp(
            target.effects.temporaryDefenseBreakPct + effect.defBreakPerStack,
            0,
            RANKED_CAPS.red_def
          );
        }

        if (effect.bleedPctMaxHpPerSecond > 0) {
          const bleedPerSecond = clamp(effect.bleedPctMaxHpPerSecond, 0, RANKED_CAPS.sangramento_por_segundo);
          const bleedDamage = Math.max(1, Math.round((target.maxHp * bleedPerSecond) * 0.5));
          target.hp = Math.max(0, target.hp - bleedDamage);
          logs.push(
            createTickLogEntry({
              tick,
              attackerId: effect.sourceId,
              targetIds: [target.id],
              skill: `${effect.sourceName}:SANGRAMENTO`,
              elementalType: DAMAGE_TYPE.SANGRAMENTO,
              rawDamage: bleedDamage,
              mitigatedDamage: bleedDamage,
              statusApplied: ["SANGRAMENTO_TICK"],
              hpRemaining: [{ id: target.id, nome: target.nome, hp: target.hp }]
            })
          );
        }

        if (effect.truePctMaxHpPerTick > 0) {
          const stackKey = `${effect.sourceId}:${effect.id}`;
          if (!appliedStackScaledTrueDots.has(stackKey)) {
            const activeStacks = target.effects.dots.filter(
              (dot) => dot.id === effect.id && dot.endTick >= tick
            ).length;
            const trueDamage = Math.max(
              1,
              Math.round(target.maxHp * effect.truePctMaxHpPerTick * Math.max(1, activeStacks))
            );
            target.hp = Math.max(0, target.hp - trueDamage);
            logs.push(
              createTickLogEntry({
                tick,
                attackerId: effect.sourceId,
                targetIds: [target.id],
                skill: `${effect.sourceName}:TRUE_DOTxSTACK`,
                elementalType: DAMAGE_TYPE.ACIDO,
                rawDamage: trueDamage,
                mitigatedDamage: trueDamage,
                statusApplied: [`DOT_VERDADEIRO_STACKS_${Math.max(1, activeStacks)}`],
                hpRemaining: [{ id: target.id, nome: target.nome, hp: target.hp }]
              })
            );
            appliedStackScaledTrueDots.add(stackKey);
          }
        }
      }

      effect.nextTick += effect.intervalTicks;
    }

    if (effect.nextTick <= effect.endTick && target.hp > 0) {
      keep = true;
    } else {
      keep = false;
    }

    if (keep) {
      remainingDots.push(effect);
    }
  }

  target.effects.dots = remainingDots;
}

function queueHeroAction(hero, enemies, tick, logs, rng, isRankedMode) {
  if (hero.hp <= 0 || hero.stunRemainingTicks > 0 || hero.casting) {
    return;
  }

  const perk = selectNextPerk(hero);
  if (perk) {
    hero.cooldowns[perk.id] = perk.cooldownTicks;
    if (perk.castTicks > 0) {
      hero.casting = {
        perk,
        executeTick: tick + perk.castTicks
      };
      return;
    }

    const targets = pickCombatTargets(hero, enemies, perk.targetCount ?? 1);
    applyPerkEffect({ tick, caster: hero, targets, perk, logs, rng, isRankedMode });
    return;
  }

  if (hero.basicAttackTimer <= 0) {
    const target = pickCombatTargets(hero, enemies, 1)[0];
    if (!target) {
      return;
    }

    const physicalPenalty = hero.effects.outgoingPhysicalReductionPct;
    const basicScale = Math.max(0.1, 1 - physicalPenalty);
    applyDamageAndLog({
      tick,
      attacker: hero,
      target,
      skillName: "ATAQUE_BASICO",
      damageType: hero.nativeDamage ?? DAMAGE_TYPE.FISICO,
      flat: 0,
      atkScale: basicScale,
      logs,
      rng,
      statusApplied: []
    });

    refreshFocusPassive(hero, target.id);
    hero.basicAttackTimer = BASIC_ATTACK_INTERVAL_TICKS;
  }
}

function resolveCastIfReady(caster, opponents, tick, logs, rng, isRankedMode) {
  if (!caster.casting) {
    return;
  }

  if (caster.stunRemainingTicks > 0) {
    return;
  }

  if (tick < caster.casting.executeTick) {
    return;
  }

  const { perk } = caster.casting;
  const targets = pickCombatTargets(caster, opponents, perk.targetCount ?? 1);
  applyPerkEffect({ tick, caster, targets, perk, logs, rng, isRankedMode });
  caster.casting = null;
}

function runEnemyTickActions({ tick, hero, enemies, logs, rng }) {
  for (const enemy of enemies) {
    if (enemy.hp <= 0 || hero.hp <= 0 || enemy.stunRemainingTicks > 0) {
      continue;
    }

    if (enemy.basicAttackTimer > 0) {
      continue;
    }

    const slowPct = clamp(enemy.effects.attackSpeedSlowPct, 0, RANKED_CAPS.red_attack_speed);
    const atkScale = Math.max(0.2, 1 - enemy.effects.outgoingPhysicalReductionPct);
    applyDamageAndLog({
      tick,
      attacker: enemy,
      target: hero,
      skillName: "ATAQUE_INIMIGO",
      damageType: enemy.elementType,
      flat: 0,
      atkScale,
      logs,
      rng,
      statusApplied: []
    });

    enemy.basicAttackTimer = Math.max(1, Math.round(BASIC_ATTACK_INTERVAL_TICKS * (1 + slowPct)));
  }
}

function processPassiveIntervals({ tick, hero, enemies, logs, rng, isRankedMode }) {
  if (hero.id !== HERO_IDS.CHICAO_DO_GAS) {
    return;
  }

  const passive = HERO_PERK_CATALOG[HERO_IDS.CHICAO_DO_GAS].find((perk) => perk.kind === "PASSIVE_INTERVAL_TOXIN");
  if (!passive || tick < hero.passives.nextGasTick) {
    return;
  }

  const target = pickCombatTargets(hero, enemies, 1)[0];
  if (!target) {
    return;
  }

  addOrRefreshDot(target, {
    id: `${hero.id}_${passive.id}`,
    sourceId: hero.id,
    sourceName: passive.nome,
    type: DAMAGE_TYPE.ACIDO,
    maxStacks: passive.maxStacks,
    nextTick: tick + passive.intervalTicks,
    intervalTicks: passive.intervalTicks,
    endTick: tick + passive.durationTicks,
    flat: passive.flat,
    atkScale: passive.atkScale,
    defBreakPerStack: 0,
    bleedPctMaxHpPerSecond: 0,
    truePctMaxHpPerTick: Number(hero.campaignModifiers?.passiveTrueDotPctMaxHpPerTick ?? 0)
  });

  const currentSlow = target.effects.attackSpeedSlowPct;
  target.effects.attackSpeedSlowPct = clamp(
    currentSlow + passive.attackSpeedSlowPerStack,
    0,
    passive.attackSpeedSlowCap
  );
  target.effects.attackSpeedSlowTicks = Math.max(target.effects.attackSpeedSlowTicks, passive.durationTicks);

  if (isRankedMode) {
    applyRankedCaps(target, true);
  }

  hero.passives.nextGasTick = tick + passive.intervalTicks;

  logs.push(
    createTickLogEntry({
      tick,
      attackerId: hero.id,
      targetIds: [target.id],
      skill: passive.nome,
      elementalType: DAMAGE_TYPE.ACIDO,
      rawDamage: 0,
      mitigatedDamage: 0,
      statusApplied: ["TOXINA_PASSIVA"],
      hpRemaining: [{ id: target.id, nome: target.nome, hp: target.hp }]
    })
  );
}

export function getHeroActiveSkillBar({ heroId, characterLevel }) {
  const hero = getHeroDefinition(heroId);
  const activeSkills = (HERO_PERK_CATALOG[heroId] ?? []).map((skill) => ({
    id: skill.id,
    nome: skill.nome,
    cooldown_turnos: Number((skill.cooldownTicks / TICKS_PER_SECOND).toFixed(1)),
    cast_time_s: Number((skill.castTicks / TICKS_PER_SECOND).toFixed(1)),
    alcance_alvos: skill.targetCount ?? 1,
    tipo: skill.type ?? skill.dotType ?? DAMAGE_TYPE.FISICO,
    unlock_level: 1,
    prioridade: skill.priority
  }));

  return {
    hero,
    characterLevel: Math.max(1, characterLevel ?? 1),
    barra_de_habilidades: activeSkills
  };
}

export function createIdleWaveEnemies(stage) {
  const baseHp = Math.max(1, Number(stage.enemy_base_vida ?? 100));
  const baseAtk = Math.max(1, Number(stage.enemy_base_dano ?? 10));
  const act = Number(stage.ato ?? 1);
  const hpScale = act <= 3 ? 1.25 : act <= 7 ? 0.8 : act === 10 ? 0.08 : 0.18;
  const defenseScale = act <= 3 ? 0.11 : act <= 7 ? 0.085 : act === 10 ? 0.012 : 0.038;

  return [
    createEnemyUnit({
      id: `mob-${stage.ato}-1`,
      nome: "Capanga Linha de Frente",
      hp: baseHp * hpScale,
      attack: baseAtk * 0.85,
      defense: baseHp * defenseScale,
      enemyType: "ARMADURA",
      elementType: DAMAGE_TYPE.FISICO
    }),
    createEnemyUnit({
      id: `mob-${stage.ato}-2`,
      nome: "Capanga Tatico",
      hp: baseHp * hpScale * 1.08,
      attack: baseAtk,
      defense: baseHp * defenseScale * 1.08,
      enemyType: "AGIL",
      elementType: DAMAGE_TYPE.GELO
    }),
    createEnemyUnit({
      id: `mob-${stage.ato}-3`,
      nome: "Capanga Pesado",
      hp: baseHp * hpScale * 1.18,
      attack: baseAtk * 1.15,
      defense: baseHp * defenseScale * 1.15,
      enemyType: "ARMADURA",
      elementType: DAMAGE_TYPE.FOGO
    })
  ];
}

export function createBossWaveEnemy(stage) {
  const boss = stage.boss;
  const act = Number(stage.ato ?? 1);
  const bossHpScale = act <= 3 ? 1.2 : act <= 7 ? 1.7 : act === 10 ? 0.55 : 0.72;
  const bossDefenseScale = act <= 3 ? 0.1 : act <= 7 ? 0.13 : act === 10 ? 0.035 : 0.058;

  const baseDamageCoefficients =
    boss && typeof boss.pve_damage_coefficients === "object" ? boss.pve_damage_coefficients : null;

  return [
    createEnemyUnit({
      id: `boss-${stage.ato}`,
      nome: boss.nome,
      hp: boss.vida * bossHpScale,
      attack: boss.dano,
      defense: boss.vida * bossDefenseScale,
      enemyType: stage.ato >= 8 ? "ARMADURA" : "AGIL",
      elementType: stage.ato >= 8 ? DAMAGE_TYPE.FOGO : DAMAGE_TYPE.GELO,
      pveDamageCoefficients: baseDamageCoefficients
    })
  ];
}

function createEquivalentHeroItems(level, actNumber) {
  const rarityByAct =
    actNumber >= 10 ? "COSMICO" : actNumber >= 7 ? "MITICO" : actNumber >= 4 ? "ULTRA_RARO" : "RARO";

  return EQUIP_SLOTS.map((slot, index) => ({
    id: `stress-${actNumber}-${slot}-${index}`,
    slot,
    raridade: rarityByAct,
    nivel: Math.max(1, level),
    bonus: Math.round(level * 0.5),
    durabilidade: 100,
    equipped: true
  }));
}

function createEquivalentTalentNodes(level) {
  const points = Math.floor(level / 5);
  return {
    vida: Math.floor(points * 0.8),
    armadura: Math.floor(points * 0.7),
    dano: Math.floor(points * 0.75),
    resistencia_fogo: Math.floor(points * 0.4),
    resistencia_acido: Math.floor(points * 0.4),
    resistencia_raio: Math.floor(points * 0.4),
    resistencia_gelo: Math.floor(points * 0.4)
  };
}

function createEquivalentScenario(actNumber) {
  const act = CAMPAIGN_ACTS.find((candidate) => candidate.ato === actNumber);
  if (!act) {
    throw new Error(`Ato inexistente para stress test: ${actNumber}`);
  }

  const level = act.enemyLevelRange.max;
  const heroByAct = actNumber >= 10 ? HERO_IDS.JHENY_NAVALHA : actNumber >= 5 ? HERO_IDS.CHICAO_DO_GAS : HERO_IDS.ZECA_MARRETA;

  return {
    actNumber,
    level,
    heroId: heroByAct,
    stage: {
      ato: act.ato,
      enemy_base_vida: act.enemyBaseHealthRange.max,
      enemy_base_dano: act.enemyBaseDamageRange.max,
      boss: act.boss
    },
    items: createEquivalentHeroItems(level, actNumber),
    talentNodes: createEquivalentTalentNodes(level)
  };
}

function aggregateRounds(samples) {
  if (!samples.length) {
    return 0;
  }

  return samples.reduce((acc, value) => acc + value, 0) / samples.length;
}

export function runCombatStressTest({ totalTurns = 1000, rng = Math.random } = {}) {
  const scenarios = STRESS_TEST_ACTS.map((actNumber) => createEquivalentScenario(actNumber));
  const report = [];

  for (const scenario of scenarios) {
    const waveRounds = [];
    const bossRounds = [];
    let waveTurnBudget = 0;
    let bossTurnBudget = 0;

    while (waveTurnBudget < totalTurns) {
      const waveResult = simulateWaveCombat({
        heroId: scenario.heroId,
        characterLevel: scenario.level,
        items: scenario.items,
        talentNodes: scenario.talentNodes,
        enemies: createIdleWaveEnemies(scenario.stage),
        rng
      });
      waveRounds.push(waveResult.rounds);
      waveTurnBudget += waveResult.rounds;
    }

    while (bossTurnBudget < totalTurns) {
      const bossResult = simulateWaveCombat({
        heroId: scenario.heroId,
        characterLevel: scenario.level,
        items: scenario.items,
        talentNodes: scenario.talentNodes,
        enemies: createBossWaveEnemy(scenario.stage),
        maxRounds: 80,
        rng
      });
      bossRounds.push(bossResult.rounds);
      bossTurnBudget += bossResult.rounds;
    }

    const avgWaveRounds = aggregateRounds(waveRounds);
    const avgBossRounds = aggregateRounds(bossRounds);
    const cooldownCycle = getCooldownCycleLength(scenario.heroId, scenario.level);

    report.push({
      ato: scenario.actNumber,
      heroId: scenario.heroId,
      level: scenario.level,
      wave_avg_rounds: Number(avgWaveRounds.toFixed(2)),
      wave_target_ok: avgWaveRounds >= 3 && avgWaveRounds <= 5,
      boss_avg_rounds: Number(avgBossRounds.toFixed(2)),
      boss_cooldown_cycles: Number((avgBossRounds / cooldownCycle).toFixed(2)),
      boss_target_ok: avgBossRounds / cooldownCycle >= 3 && avgBossRounds / cooldownCycle <= 4,
      samples: {
        wave: waveRounds.length,
        boss: bossRounds.length
      }
    });
  }

  return {
    totalTurns,
    scenarios: report,
    summary: {
      wave_target_all_ok: report.every((item) => item.wave_target_ok),
      boss_target_all_ok: report.every((item) => item.boss_target_ok)
    }
  };
}

export function simulateWaveCombat({
  heroId = HERO_IDS.ZECA_MARRETA,
  characterLevel = 1,
  items = [],
  talentNodes = {},
  enemies,
  rivalSquad = null,
  maxRounds = MAX_ROUNDS_DEFAULT,
  queueType = "CASUAL",
  rng = Math.random
}) {
  const resolvedEnemies =
    Array.isArray(enemies) && enemies.length > 0 ? enemies : rivalSquad ? buildRankedEnemyWaveFromSnapshot(rivalSquad) : [];

  const hero = ensureRuntimeFields(createHeroUnit({ heroId, characterLevel, items, talentNodes }), "HERO");
  const waveEnemies = resolvedEnemies.map((enemy) => ensureRuntimeFields({ ...enemy }, "ENEMY"));
  const logs = [];
  const isRankedMode = isRankedQueue(queueType);
  const bossStage = isBossStage(waveEnemies);

  if (bossStage) {
    for (const enemy of waveEnemies) {
      enemy.effects.isBossUnit = String(enemy.id ?? "").toLowerCase().includes("boss");
      enemy.effects.pveDamageCoefficients = enemy.pveDamageCoefficients ?? null;
    }
  }

  if (!isRankedMode && bossStage) {
    applyHeroCampaignModifiers(hero);
  }

  const maxTicks = Math.max(1, Math.round(maxRounds * TICKS_PER_SECOND));
  let currentTick = 0;

  const unitById = (unitId) => {
    if (hero.id === unitId) {
      return hero;
    }

    return waveEnemies.find((enemy) => enemy.id === unitId) ?? null;
  };

  while (hero.hp > 0 && waveEnemies.some((enemy) => enemy.hp > 0) && currentTick < maxTicks) {
    currentTick += 1;

    tickDownRuntime(hero);
    for (const enemy of waveEnemies) {
      tickDownRuntime(enemy);
    }

    processPassiveIntervals({ tick: currentTick, hero, enemies: waveEnemies, logs, rng, isRankedMode });

    processDotTimers({ tick: currentTick, sourceUnit: unitById, target: hero, logs, rng });
    for (const enemy of waveEnemies) {
      processDotTimers({ tick: currentTick, sourceUnit: unitById, target: enemy, logs, rng });
    }

    updatePassiveStats(hero);
    applyRankedCaps(hero, isRankedMode);
    for (const enemy of waveEnemies) {
      applyRankedCaps(enemy, isRankedMode);
    }

    resolveCastIfReady(hero, waveEnemies, currentTick, logs, rng, isRankedMode);
    for (const enemy of waveEnemies) {
      resolveCastIfReady(enemy, [hero], currentTick, logs, rng, isRankedMode);
    }

    queueHeroAction(hero, waveEnemies, currentTick, logs, rng, isRankedMode);
    runEnemyTickActions({ tick: currentTick, hero, enemies: waveEnemies, logs, rng });
  }

  const rounds = computeRoundsFromTicks(currentTick);

  return {
    heroWon: hero.hp > 0 && waveEnemies.every((enemy) => enemy.hp <= 0),
    rounds,
    hero,
    enemies: waveEnemies,
    logs,
    summary: {
      hero_hp_restante: hero.hp,
      inimigos_restantes: waveEnemies.filter((enemy) => enemy.hp > 0).length,
      rounds,
      ticks: currentTick,
      duracao_segundos: secondsFromTicks(currentTick)
    }
  };
}

export type MirrorIntent = {
  acao:
    | "COMPRAR_ITEM"
    | "SELECIONAR_HEROI"
    | "EQUIPAR_ITEM"
    | "DESEQUIPAR_ITEM"
    | "REPARAR_ITEM"
    | "ENTRAR_FILA_CASUAL"
    | "ENTRAR_FILA_RANKEADA"
    | "DESAFIAR_CHEFE"
    | "DESAFIAR_RANQUEADO"
    | "MELHORAR_ITEM"
    | "SIMULAR_CUSTO_SINTESE"
    | "CONFIRMAR_ANIMACAO_PVP"
    | "SINTETIZAR_ITENS"
    | "TOGGLE_PIN";
  slot?: number;
  payload?: Record<string, unknown>;
};

export type Rarity =
  | "COMUM"
  | "INCOMUM"
  | "RARO"
  | "ULTRA_RARO"
  | "MITICO"
  | "COSMICO"
  | "SINGULAR";

export type InventoryTabKey = "equipados" | "equipamentos" | "consumiveis" | "runas" | "materiais";

export type EquipSlot =
  | "CABECA"
  | "PEITORAL"
  | "CALCA"
  | "BOTAS"
  | "MAO"
  | "ARMA_PRIMARIA"
  | "ARMA_SECUNDARIA"
  | "AMULETO"
  | "CONTAINER"
  | "MATERIAL"
  | string;

export type InventoryItem = {
  id: string;
  nome?: string;
  slot: EquipSlot;
  raridade: Rarity;
  item_category?: "EQUIPAMENTO" | "CONSUMIVEL" | "RUNA" | "MATERIAL" | string;
  item_type?: string;
  sprite_slug?: string;
  item_level?: number;
  nivel: number;
  durabilidade: number;
  durabilidade_max?: number;
  equipped?: boolean;
  bonus: number;
};

export type InventoryTabs = Record<InventoryTabKey, InventoryItem[]>;

export type OfflineReward = {
  seconds_offline: number;
  cycles: number;
  gold_earned: number;
  xp_earned: number;
};

export type ServerViewModel = {
  ato_atual?: number;
  rua_atual?: number;
  tema_geografico?: string;
  boss_ready?: boolean;
  ouro: number;
  xp: number;
  mmr?: number;
  kits_reparo?: number;
  character_level?: number;
  hero_id?: string;
  talent_nodes?: Record<string, number>;
  inventory_tabs: InventoryTabs;
  materials?: Record<string, number>;
  last_campaign_outcome?: Record<string, unknown> | null;
  matchmaking_bracket?: string;
};

export type AuthOkData = {
  steamId64: string;
  offline_reward?: OfflineReward;
};

export type CombatRoundLog = {
  tick?: number;
  tempo_s?: number;
  round?: number;
  attackerId?: string;
  attacker_id?: string;
  targetId?: string;
  target_ids?: string[];
  damage?: number;
  dano_mitigado?: number;
  source?: string;
  habilidade?: string;
  kind?: string;
  [key: string]: unknown;
};

export type CombatLogsPayload = {
  source?: string;
  summary?: Record<string, unknown> | null;
  logs: CombatRoundLog[];
};

export type CombatPose = "IDLE" | "ATTACK" | "HIT";

export type CombatVisualState = {
  is_animating: boolean;
  actor_pose: CombatPose;
  target_pose: CombatPose;
  actor_id?: string;
  target_id?: string;
  last_damage: number;
  floating_damage_text: string | null;
};

export type WsIncomingMessage =
  | { type: "SNAPSHOT"; data: ServerViewModel }
  | { type: "AUTH_OK"; data: AuthOkData }
  | { type: "INTENT_OK"; data: Record<string, unknown> }
  | { type: "COMBAT_LOGS"; data: CombatLogsPayload }
  | { type: "ERROR"; data: { reason: string } };

export type WsOutgoingMessage =
  | { type: "AUTH"; data: { sessionTicket: string } }
  | { type: "INTENT"; data: MirrorIntent };

export const INVENTORY_TAB_LABEL: Record<InventoryTabKey, string> = {
  equipados: "Equipados",
  equipamentos: "Equipamentos",
  consumiveis: "Consumiveis",
  runas: "Runas",
  materiais: "Materiais"
};

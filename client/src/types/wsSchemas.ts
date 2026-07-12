import { z } from "zod";

const mirrorIntentActionSchema = z.enum([
  "COMPRAR_ITEM",
  "EQUIPAR_ITEM",
  "DESEQUIPAR_ITEM",
  "REPARAR_ITEM",
  "ENTRAR_FILA_CASUAL",
  "ENTRAR_FILA_RANKEADA",
  "DESAFIAR_RANQUEADO",
  "DESAFIAR_CHEFE",
  "SELECIONAR_HEROI",
  "MELHORAR_ITEM",
  "SIMULAR_CUSTO_SINTESE",
  "SINTETIZAR_ITENS",
  "CONFIRMAR_ANIMACAO_PVP",
  "TOGGLE_PIN"
]);

export const mirrorIntentSchema = z.object({
  acao: mirrorIntentActionSchema,
  slot: z.number().int().optional(),
  payload: z.record(z.string(), z.unknown()).optional()
});

const inventoryItemSchema = z.object({
  id: z.string(),
  nome: z.string().optional(),
  slot: z.string(),
  raridade: z.enum(["COMUM", "INCOMUM", "RARO", "ULTRA_RARO", "MITICO", "COSMICO", "SINGULAR"]),
  item_category: z.string().optional(),
  item_type: z.string().optional(),
  sprite_slug: z.string().optional(),
  item_level: z.number().optional(),
  nivel: z.number(),
  durabilidade: z.number(),
  durabilidade_max: z.number().optional(),
  equipped: z.boolean().optional(),
  bonus: z.number()
});

const inventoryTabsSchema = z.object({
  equipados: z.array(inventoryItemSchema),
  equipamentos: z.array(inventoryItemSchema),
  consumiveis: z.array(inventoryItemSchema),
  runas: z.array(inventoryItemSchema),
  materiais: z.array(inventoryItemSchema)
});

const snapshotDataSchema = z.object({
  ato_atual: z.number().optional(),
  rua_atual: z.number().optional(),
  tema_geografico: z.string().optional(),
  boss_ready: z.boolean().optional(),
  ouro: z.number(),
  xp: z.number(),
  mmr: z.number().optional(),
  kits_reparo: z.number().optional(),
  character_level: z.number().optional(),
  hero_id: z.string().optional(),
  talent_nodes: z.record(z.string(), z.number()).optional(),
  inventory_tabs: inventoryTabsSchema,
  materials: z.record(z.string(), z.number()).optional(),
  last_campaign_outcome: z.record(z.string(), z.unknown()).nullable().optional(),
  matchmaking_bracket: z.string().optional()
});

const authOkDataSchema = z.object({
  steamId64: z.string(),
  offline_reward: z
    .object({
      seconds_offline: z.number(),
      cycles: z.number(),
      gold_earned: z.number(),
      xp_earned: z.number()
    })
    .optional()
});

const combatLogSchema = z.object({
  tick: z.number().optional(),
  tempo_s: z.number().optional(),
  round: z.number().optional(),
  attacker_id: z.string().optional(),
  target_ids: z.array(z.string()).optional(),
  habilidade: z.string().optional(),
  tipo_elemental: z.string().optional(),
  dano_bruto: z.number().optional(),
  dano_mitigado: z.number().optional(),
  status_aplicado: z.array(z.string()).optional(),
  hp_restante: z
    .array(
      z.object({
        id: z.string(),
        nome: z.string().optional(),
        hp: z.number()
      })
    )
    .optional()
});

const combatLogsDataSchema = z.object({
  source: z.string().optional(),
  summary: z.record(z.string(), z.unknown()).nullable().optional(),
  logs: z.array(combatLogSchema)
});

export const wsIncomingMessageSchema = z.discriminatedUnion("type", [
  z.object({ type: z.literal("SNAPSHOT"), data: snapshotDataSchema }),
  z.object({ type: z.literal("AUTH_OK"), data: authOkDataSchema }),
  z.object({ type: z.literal("INTENT_OK"), data: z.unknown() }),
  z.object({ type: z.literal("COMBAT_LOGS"), data: combatLogsDataSchema }),
  z.object({
    type: z.literal("ERROR"),
    data: z.object({ reason: z.string() })
  })
]);

export const wsOutgoingMessageSchema = z.discriminatedUnion("type", [
  z.object({
    type: z.literal("AUTH"),
    data: z.object({ sessionTicket: z.string() })
  }),
  z.object({
    type: z.literal("INTENT"),
    data: mirrorIntentSchema
  })
]);

export function parseWsIncomingMessage(raw: string) {
  let json: unknown;
  try {
    json = JSON.parse(raw);
  } catch {
    return { success: false as const, error: "JSON_INVALIDO" };
  }

  const parsed = wsIncomingMessageSchema.safeParse(json);
  if (!parsed.success) {
    return {
      success: false as const,
      error: "WS_INCOMING_SCHEMA_INVALIDO",
      details: parsed.error.flatten()
    };
  }

  return { success: true as const, data: parsed.data };
}

export type MirrorIntentAction = z.infer<typeof mirrorIntentActionSchema>;
export type MirrorIntentSchema = z.infer<typeof mirrorIntentSchema>;
export type WsIncomingMessageSchema = z.infer<typeof wsIncomingMessageSchema>;
export type WsOutgoingMessageSchema = z.infer<typeof wsOutgoingMessageSchema>;

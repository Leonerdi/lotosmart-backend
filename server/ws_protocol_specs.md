# PROTOCOLO DE COMUNICACAO WEBSOCKET: UNDERWORLD BAR (v1.0.0)

Este documento especifica os contratos de mensagens (intents) trafegados via WebSocket entre o Frontend e o Servidor Autoritativo.

## Convencoes Gerais

- Todas as mensagens usam JSON.
- `intent` identifica a acao enviada pelo cliente.
- `event` identifica a resposta/evento emitido pelo servidor.
- O servidor pode responder com `TRANSACAO_REJEITADA` para violacoes de regra de negocio.

## 1. Fluxo de Inventario e Crafting

### 1.1 SIMULAR_CUSTO_SINTESE

Permite obter custo de sintese sem debito (preview/simulacao).

Request (cliente -> servidor):

```json
{
  "intent": "SIMULAR_CUSTO_SINTESE",
  "payload": {
    "set_element": "set2_quimico",
    "targetPowerBudget": 175,
    "itemIds": []
  }
}
```

Response (servidor -> cliente):

```json
{
  "event": "SIMULACAO_CUSTO_RETORNADA",
  "payload": {
    "recipe": {
      "ouro_exigido": 25000,
      "materiais_exigidos": [
        { "material": "ACIDO_DE_BATERIA", "quantidade": 5 },
        { "material": "LACRE_DE_CONTRABANDO", "quantidade": 1 }
      ]
    },
    "affordability": {
      "can_afford": false,
      "missingOuro": 5000,
      "missingMaterials": [
        { "material": "LACRE_DE_CONTRABANDO", "quantidade_faltante": 1 }
      ]
    },
    "next_rarity": "LENDARIO"
  }
}
```

### 1.2 EXECUTAR_UPGRADE

Aprimora nivel de item com base na matriz canonica de upgrade (+1 a +10).

Request (cliente -> servidor):

```json
{
  "intent": "EXECUTAR_UPGRADE",
  "payload": {
    "item_id": "ZECA_DEMOLIDOR_ARMOR_BODY"
  }
}
```

Response de sucesso:

```json
{
  "event": "UPGRADE_CONCLUIDO",
  "payload": {
    "success": true,
    "item_id": "ZECA_DEMOLIDOR_ARMOR_BODY",
    "new_level": 8,
    "base_attributes": {
      "armor": 188,
      "hp_bonus": 50
    }
  }
}
```

Response de falha:

```json
{
  "event": "UPGRADE_FALHOU",
  "payload": {
    "success": false,
    "item_id": "ZECA_DEMOLIDOR_ARMOR_BODY",
    "failureMode": "RESET_TO_7",
    "current_level": 7
  }
}
```

Valores esperados em `failureMode`: `SEM_PERDA_ZONA_SEGURA`, `DOWNGRADE_TO_3`, `DOWNGRADE_TO_4`, `DOWNGRADE_TO_5`, `DOWNGRADE_TO_6`, `RESET_TO_7`.

## 2. Fluxo de Combate Rankeado Async

### 2.1 DESAFIAR_RANQUEADO

Dispara simulacao em ticks de 0.1s contra rival snapshot (queue competitiva).

Request (cliente -> servidor):

```json
{
  "intent": "DESAFIAR_RANQUEADO",
  "payload": {
    "heroId": "JHENY_NAVALHA"
  }
}
```

Response (servidor -> cliente):

```json
{
  "event": "COMBATE_RANQUEADO_RESOLVIDO",
  "payload": {
    "heroWon": true,
    "rounds": 6.8,
    "total_ticks": 68,
    "combat_summary": {
      "dano_causado_total": 4500,
      "dano_mitigado_total": 1200,
      "dots_aplicados": 14
    },
    "combat_logs": [
      {
        "tick": 1,
        "source": "JHENY_NAVALHA",
        "target": "RIVAL_CHICAO",
        "action": "AUTO_ATTACK",
        "damage": 45,
        "is_crit": false
      },
      {
        "tick": 5,
        "source": "SANGRAMENTO_BUFF",
        "target": "RIVAL_CHICAO",
        "action": "DOT_TICK",
        "damage": 12,
        "current_stacks": 2
      },
      {
        "tick": 12,
        "source": "JHENY_NAVALHA",
        "target": "RIVAL_CHICAO",
        "action": "CAST_PERK",
        "perk_name": "Pistola de Prego Taser",
        "effect": "MICRO_STUN",
        "duration_ticks": 10
      }
    ]
  }
}
```

## 3. Padronizacao de Erros de Negocio

Quando uma regra autoritativa falha, o servidor deve responder com evento de rejeicao.

Exemplo de ownership:

```json
{
  "event": "TRANSACAO_REJEITADA",
  "payload": {
    "errorCode": "VALIDACAO_PROPRIEDADE_FALHOU",
    "message": "Este item pertence estritamente ao heroi JHENY_NAVALHA e nao pode ser equipado por ZECA_MARRETA."
  }
}
```

## 4. Notas de Compatibilidade

- O backend opera em ticks de 0.1s (`TICK_DURATION=0.1`).
- A fila ranqueada aplica caps competitivos no motor de combate.
- A simulacao de custo de sintese nao debita recursos.
- O boss do Ato 10 suporta mitigacao seletiva por tipo de dano em campanha solo.

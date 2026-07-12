# PROTOCOLO DE COMUNICACAO WEBSOCKET: UNDERWORLD BAR (v1.0.1)

Este documento define os contratos canonicamente suportados pelo servidor em `server/src/realtime/wsServer.js` e `server/src/realtime/messageRouter.js`.

## 1. Envelope de Transporte

### 1.1 Cliente -> Servidor

Envelope padrao para intents:

```json
{
  "type": "INTENT",
  "data": {
    "acao": "SELECIONAR_HEROI",
    "payload": {
      "heroId": "JHENY_NAVALHA"
    }
  }
}
```

Observacao de compatibilidade:

- Este backend usa `data.acao` (nao `intent`) para roteamento.

### 1.2 Servidor -> Cliente

- Sucesso de intent: `type = INTENT_OK`, com `data` contendo resultado da acao.
- Erro de processamento: `type = ERROR`, com `data.reason`.
- Snapshot de estado: `type = SNAPSHOT`, com estado consolidado de conta/campanha/inventario.
- Stream de combate: `type = COMBAT_LOGS`, com `data.summary` e `data.logs`.

## 2. Ledger de Intents (v1.0.1)

## 2.1 SELECIONAR_HEROI

Seleciona heroi ativo da sessao.

Campos de request (`data.payload`):

| Campo | Tipo | Obrigatorio | Regra |
|---|---|---|---|
| `heroId` | string | Sim | Deve estar em `ZECA_MARRETA`, `CHICAO_DO_GAS`, `JHENY_NAVALHA` |

Exemplo request:

```json
{
  "type": "INTENT",
  "data": {
    "acao": "SELECIONAR_HEROI",
    "payload": { "heroId": "ZECA_MARRETA" }
  }
}
```

Exemplo response (`INTENT_OK`):

```json
{
  "type": "INTENT_OK",
  "data": {
    "ok": true,
    "selected_hero_id": "ZECA_MARRETA"
  }
}
```

## 2.2 EQUIPAR_ITEM

Equipa item em heroi alvo, respeitando ownership canonicamente.

Campos de request (`data.payload`):

| Campo | Tipo | Obrigatorio | Regra |
|---|---|---|---|
| `itemId` | string | Sim | Item existente no inventario |
| `heroId` | string | Nao | Se ausente, usa `selectedHeroId` da sessao |

Exemplo request:

```json
{
  "type": "INTENT",
  "data": {
    "acao": "EQUIPAR_ITEM",
    "payload": {
      "itemId": "ZECA_DEMOLIDOR_ARMOR_BODY",
      "heroId": "ZECA_MARRETA"
    }
  }
}
```

Exemplo response (`INTENT_OK`):

```json
{
  "type": "INTENT_OK",
  "data": {
    "ok": true,
    "equip": {
      "hero_id": "ZECA_MARRETA",
      "equipped_item": { "id": "ZECA_DEMOLIDOR_ARMOR_BODY" },
      "unequipped_item_ids": [],
      "hero_owner": "ZECA_MARRETA",
      "set_element": "set1_brutamontes"
    }
  }
}
```

## 2.3 DESEQUIPAR_ITEM

Remove estado de equipado do item.

Campos de request (`data.payload`):

| Campo | Tipo | Obrigatorio | Regra |
|---|---|---|---|
| `itemId` | string | Sim | Item existente no inventario |

Exemplo response (`INTENT_OK`):

```json
{
  "type": "INTENT_OK",
  "data": {
    "ok": true,
    "unequip": {
      "changed": true,
      "item": {
        "id": "ZECA_DEMOLIDOR_ARMOR_BODY",
        "equipped": false,
        "hero_owner": "ZECA_MARRETA",
        "set_element": "set1_brutamontes"
      }
    }
  }
}
```

## 2.4 MELHORAR_ITEM (EXECUTAR_UPGRADE)

Intent implementada no backend: `MELHORAR_ITEM`.

Alias funcional de produto: `EXECUTAR_UPGRADE`.

Campos de request (`data.payload`):

| Campo | Tipo | Obrigatorio | Regra |
|---|---|---|---|
| `itemId` | string | Sim | Item base para upgrade |
| `sacrificialItemId` | string/null | Nao | Item opcional de sacrificio |

Exemplo response (`INTENT_OK`):

```json
{
  "type": "INTENT_OK",
  "data": {
    "ok": true,
    "upgrade": {
      "success": false,
      "chance": 0.25,
      "failure_mode": "RESET_TO_7",
      "updated_item": {
        "id": "ZECA_DEMOLIDOR_ARMOR_BODY",
        "upgrade_level": 7
      },
      "destroyed_item_ids": [],
      "materials_consumed": {
        "SUCATA_DE_ZINCO": 12
      },
      "ouro_gasto": 18000
    }
  }
}
```

Failure modes esperados:

- `SEM_PERDA_ZONA_SEGURA`
- `DOWNGRADE_TO_3`
- `DOWNGRADE_TO_4`
- `DOWNGRADE_TO_5`
- `DOWNGRADE_TO_6`
- `RESET_TO_7`

## 2.5 SIMULAR_CUSTO_SINTESE

Preview sem debito para sintese (modo livre ou por itens do inventario).

Campos de request (`data.payload`):

| Campo | Tipo | Obrigatorio | Regra |
|---|---|---|---|
| `itemIds` | array<string> | Nao | Se presente, sintetiza por itens concretos |
| `targetPowerBudget` | number | Nao | Usado em simulacao livre |
| `setElement` | string | Nao | Modo livre |
| `itemLevel` | number | Nao | Modo livre |
| `baseRarity` | string | Nao | Modo livre |

Exemplo response (`INTENT_OK`):

```json
{
  "type": "INTENT_OK",
  "data": {
    "ok": true,
    "simulation": {
      "recipe": {
        "ouro_exigido": 25000,
        "materiais_exigidos": [
          { "material": "ACIDO_DE_BATERIA", "quantidade": 5 },
          { "material": "LACRE_DE_CONTRABANDO", "quantidade": 1 }
        ]
      },
      "next_rarity": "LENDARIO",
      "base_rarity": "EPICO",
      "base_level": 50,
      "set_element": "set2_quimico",
      "affordability": {
        "can_afford": false,
        "missingOuro": 5000,
        "missingMaterials": [
          { "material": "LACRE_DE_CONTRABANDO", "quantidade_faltante": 1 }
        ]
      }
    }
  }
}
```

## 2.6 DESAFIAR_RANQUEADO

Executa simulacao competitiva em ticks de 0.1s.

Campos de request (`data.payload`):

| Campo | Tipo | Obrigatorio | Regra |
|---|---|---|---|
| `heroId` | string | Nao | Se ausente, usa heroi selecionado da sessao |

Fluxo de resposta:

1. `INTENT_OK` com resumo do combate em `data`.
2. Se houver logs, emissao adicional de `COMBAT_LOGS`.
3. Emissao de `SNAPSHOT` atualizado.

Schema de `COMBAT_LOGS`:

```json
{
  "type": "COMBAT_LOGS",
  "data": {
    "source": "DESAFIAR_RANQUEADO",
    "summary": {
      "heroWon": true,
      "rounds": 6.8,
      "ticks": 68,
      "duracao_segundos": 6.8
    },
    "logs": [
      {
        "tick": 12,
        "tempo_s": 1.2,
        "round": 1.2,
        "attacker_id": "JHENY_NAVALHA",
        "target_ids": ["ranked-CHICAO_DO_GAS"],
        "habilidade": "Pistola de Prego Taser",
        "tipo_elemental": "RAIO",
        "dano_bruto": 84,
        "dano_mitigado": 62,
        "status_aplicado": ["ATORDOADO"],
        "hp_restante": [{ "id": "ranked-CHICAO_DO_GAS", "hp": 1210 }]
      }
    ]
  }
}
```

## 3. Dicionario de Erros por Intent

Erros sao enviados via:

```json
{
  "type": "ERROR",
  "data": {
    "reason": "mensagem"
  }
}
```

Matriz de erros frequentes:

| Intent | Erro (`data.reason`) | Causa |
|---|---|---|
| `SELECIONAR_HEROI` | `Heroi invalido para selecao` | Hero nao esta no elenco jogavel |
| `EQUIPAR_ITEM` | `VALIDACAO_PROPRIEDADE_FALHOU: item pertence a ...` | `hero_owner` divergente |
| `EQUIPAR_ITEM` | `Item invalido para equipar` | `itemId` ausente/invalido |
| `EQUIPAR_ITEM` | `Heroi alvo invalido para equipar` | `heroId` fora do elenco |
| `DESEQUIPAR_ITEM` | `Item invalido para desequipar` | `itemId` ausente/invalido |
| `MELHORAR_ITEM` | `Item base nao encontrado para upgrade` | item inexistente |
| `MELHORAR_ITEM` | `Item ja esta no nivel maximo de upgrade` | item em cap maximo |
| `MELHORAR_ITEM` | `Ouro insuficiente para upgrade` | saldo insuficiente |
| `SIMULAR_CUSTO_SINTESE` | Erros de consistencia de sintese | parametros ou inventario invalidos |
| `DESAFIAR_RANQUEADO` | erros de estado de sessao | autenticacao/sessao invalida |

Guardrail de ownership (canonica):

```json
{
  "type": "ERROR",
  "data": {
    "reason": "VALIDACAO_PROPRIEDADE_FALHOU: item pertence a JHENY_NAVALHA"
  }
}
```

## 4. Notas de Integracao Frontend

- Tick de combate: 0.1s.
- A UI deve animar a linha do tempo com base em `logs[].tick`.
- `INTENT_OK` e `COMBAT_LOGS` podem chegar em mensagens separadas para a mesma acao.
- O cliente deve tratar `ERROR` como resposta terminal da intent atual.
- Campos extras podem surgir em `SNAPSHOT` sem quebra de compatibilidade, mantendo semantica aditiva.

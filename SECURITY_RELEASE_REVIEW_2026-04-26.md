# Security Release Review - 2026-04-26

## Escopo

- App Flutter/Android em `lotofacil_app/`
- Backend FastAPI em `main.py`
- Fluxo de release Android / Play Console
- Configuracao de operacao do backend em producao

## Resumo executivo

Decisao atual: `GO COM RESSALVAS`

Leitura de risco:

- Nao foi identificado vetor forte para comprometimento direto do aparelho do usuario apenas pela instalacao do app.
- O principal risco remanescente e de `supply chain / release signing`, nao de exploracao local no dispositivo.
- O backend publico estava mais exposto do que o necessario, mas recebeu endurecimentos relevantes nesta revisao.

## Achados por severidade

### Alto

#### 1. Material de assinatura presente no workspace local

Evidencia:

- `lotofacil_app/android/key.properties`
- `lotofacil_app/android/app/upload-keystore.jks`

Impacto:

- Se a maquina de desenvolvimento, backup local ou compartilhamento indevido desse workspace for comprometido, a upload key pode entrar em risco.
- Isso afeta a cadeia de release e a confianca do artefato publicado.

Status:

- Mitigado parcialmente por configuracao nova no build para aceitar `SIGNING_*` via ambiente.
- Ainda requer acao operacional: mover keystore e credenciais para fora do workspace.

#### Acao obrigatoria antes de endurecimento final de release

- Mover `upload-keystore.jks` para pasta segura fora do projeto.
- Mover `key.properties` real para fora do workspace ou deixar de usa-lo.
- Preferir build com:
  - `SIGNING_STORE_FILE`
  - `SIGNING_STORE_PASSWORD`
  - `SIGNING_KEY_ALIAS`
  - `SIGNING_KEY_PASSWORD`

### Medio

#### 2. Rotas operacionais do backend antes expostas sem autenticacao

Evidencia:

- `main.py` em `/admin/sync` e `/ops/metrics`

Impacto:

- Abuso de sincronizacao manual.
- Exposicao de telemetria operacional.
- Possivel degradacao de disponibilidade para usuarios finais.

Status:

- Corrigido nesta revisao com `X-Admin-Token` e `ADMIN_API_TOKEN`.

#### 3. Endpoints publicos custosos sem controle de abuso

Evidencia:

- `main.py` em `/diagnostico`, `/gerar-combinacoes`, `/gerar-jogos`, `/similaridade`

Impacto:

- Abuso por IP pode gerar custo computacional e indisponibilidade.

Status:

- Corrigido nesta revisao com rate limiting simples por IP e janela configuravel.

#### 4. CORS antes permissivo por padrao

Evidencia:

- `main.py` usando origem aberta como default.

Impacto:

- Facilita abuso web dos endpoints publicos.

Status:

- Corrigido nesta revisao com allowlist padrao conservadora.
- Ainda recomenda-se definir `ALLOWED_ORIGINS` explicitamente em producao.

### Baixo

#### 5. Texto de interface sugerindo login processado pela Caixa

Evidencia:

- Mensagem antiga em `lotofacil_app/lib/main.dart`

Impacto:

- Risco de mensagem tecnicamente imprecisa / compliance.

Status:

- Corrigido nesta revisao. O texto agora descreve que qualquer autenticacao ocorre apenas no servico externo de terceiros, quando aberto pelo usuario.

#### 6. Sem certificate pinning para a API

Evidencia:

- Consumo HTTPS padrao do backend em `lotofacil_app/lib/main.dart`

Impacto:

- Em aparelho comprometido ou ambiente com CA maliciosa instalada, respostas podem ser adulteradas.

Status:

- Nao bloqueia release neste momento.
- Pode ser tratado como endurecimento adicional futuro.

## Sinais positivos

- `AndroidManifest.xml` enxuto, sem deep links publicos desnecessarios.
- `android:allowBackup="false"` ativo.
- Receiver de PiP marcado com `RECEIVER_NOT_EXPORTED` em Android suportado.
- `PendingIntent.FLAG_IMMUTABLE` em acoes de PiP.
- Abertura de fontes oficiais feita externamente, sem WebView ativa no fluxo principal do app.
- Nao foram encontrados tokens de usuario, senha ou segredo de sessao persistidos no app.

## Mudancas implementadas nesta revisao

### Backend

- Protecao das rotas administrativas com token de header.
- `healthz` publico reduzido ao minimo necessario.
- CORS default sem coringa.
- Headers HTTP de endurecimento:
  - `X-Content-Type-Options: nosniff`
  - `X-Frame-Options: DENY`
  - `Referrer-Policy: no-referrer`
  - `Cache-Control: no-store` nas rotas operacionais
- Rate limiting simples por IP para endpoints publicos mais custosos.

### Android / Release

- `build.gradle.kts` preparado para signing por variaveis de ambiente.
- `SIGNING_GUIDE.md` atualizado com fluxo seguro.
- `key.properties.example` criado sem segredos.
- Mensagem de UI ajustada para refletir o comportamento real do app.

## Go / No-Go para publicacao

### Go, desde que as acoes abaixo sejam executadas

1. Definir no ambiente de producao do backend:
   - `ADMIN_API_TOKEN`
   - `ALLOWED_ORIGINS`
2. Remover o uso rotineiro de segredos de assinatura dentro do workspace.
3. Manter a upload key fora do repositorio e fora de backups inseguros.

### No-Go se qualquer um destes pontos ocorrer

1. `upload-keystore.jks` ou `key.properties` forem compartilhados, sincronizados indevidamente ou copiados para ambiente nao confiavel.
2. `ADMIN_API_TOKEN` nao for configurado em producao.
3. `ALLOWED_ORIGINS` permanecer incorreto em ambiente publico real.

## Checklist operacional de fechamento

### Backend / Railway

- Definir `ADMIN_API_TOKEN` com valor forte e unico.
- Definir `ALLOWED_ORIGINS` com domínios reais separados por virgula.
- Opcional: ajustar limites de abuso se necessario:
  - `PUBLIC_RATE_LIMIT_WINDOW_SECONDS`
  - `PUBLIC_RATE_LIMIT_MAX_REQUESTS`

### Validacao manual apos deploy

- `GET /healthz` deve responder sem metricas internas.
- `GET /ops/metrics` sem `X-Admin-Token` deve retornar `403`.
- `GET /admin/sync` sem `X-Admin-Token` deve retornar `403`.
- Chamadas repetidas a `/gerar-combinacoes` devem eventualmente retornar `429` acima do limite configurado.

### Android signing

- Usar preferencialmente variaveis de ambiente para release.
- Manter `key.properties` real fora de sincronizacao e fora do Git.
- Guardar a upload key em local seguro com backup controlado.

## Parecer final

O app esta em condicao de lancamento com ressalvas controladas. O risco mais importante deixou de ser exposicao publica do backend e continua sendo a higiene operacional da chave de assinatura Android.

Se a disciplina de signing for corrigida, o conjunto atual e compativel com um lancamento seguro sob um padrao pragmatico de AppSec para app Android independente.
# Production Security Playbook

## Objetivo

Checklist operacional para colocar o backend e o fluxo de release Android em um estado seguro o suficiente para lancamento.

---

## 1. Railway - variaveis obrigatorias

Defina estas variaveis no servico do backend:

### Obrigatorias

- `ADMIN_API_TOKEN`
  - valor: token forte, aleatorio, unico
  - sugestao: 40+ caracteres com letras, numeros e simbolos

- `ALLOWED_ORIGINS`
  - valor: lista separada por virgula dos dominios reais permitidos
  - exemplo:

```text
https://leonerdi.github.io,http://localhost:3000,http://localhost:5173
```

- `DATABASE_URL`
  - manter configurada no ambiente de producao

### Opcionais de endurecimento

- `PUBLIC_RATE_LIMIT_WINDOW_SECONDS`
  - default atual: `60`

- `PUBLIC_RATE_LIMIT_MAX_REQUESTS`
  - default atual: `30`

### Recomendacao pratica de valores iniciais

```text
ADMIN_API_TOKEN=<gerar valor forte>
ALLOWED_ORIGINS=https://leonerdi.github.io,http://localhost:3000,http://localhost:5173
PUBLIC_RATE_LIMIT_WINDOW_SECONDS=60
PUBLIC_RATE_LIMIT_MAX_REQUESTS=30
```

---

## 2. Como gerar um token forte

No PowerShell:

```powershell
[guid]::NewGuid().ToString() + [guid]::NewGuid().ToString()
```

Ou melhor, usando Python local:

```powershell
c:/Users/Leonardo/LotoApp/.venv/Scripts/python.exe -c "import secrets; print(secrets.token_urlsafe(48))"
```

---

## 3. Validacao manual do backend apos deploy

Substitua `https://lotosmart-api-production.up.railway.app` pelo dominio ativo, se mudar.

### 3.1 Healthcheck publico

Esperado:

- responde `200`
- contem apenas estado basico
- nao expoe metricas internas detalhadas

```powershell
Invoke-WebRequest -Uri "https://lotosmart-api-production.up.railway.app/healthz"
```

### 3.2 Rotas administrativas sem token

Esperado:

- `403 Forbidden`

```powershell
Invoke-WebRequest -Uri "https://lotosmart-api-production.up.railway.app/ops/metrics"
Invoke-WebRequest -Uri "https://lotosmart-api-production.up.railway.app/admin/sync"
```

### 3.3 Rotas administrativas com token

Esperado:

- `200`

```powershell
$headers = @{ "X-Admin-Token" = "SEU_TOKEN_REAL" }
Invoke-WebRequest -Uri "https://lotosmart-api-production.up.railway.app/ops/metrics" -Headers $headers
Invoke-WebRequest -Uri "https://lotosmart-api-production.up.railway.app/admin/sync" -Headers $headers
```

### 3.4 Rate limit nas rotas pesadas

Esperado:

- depois de varias chamadas rapidas, alguma resposta `429`

```powershell
1..40 | ForEach-Object {
  try {
    $r = Invoke-WebRequest -Uri "https://lotosmart-api-production.up.railway.app/gerar-combinacoes" -TimeoutSec 15
    Write-Host $_ $r.StatusCode
  } catch {
    if ($_.Exception.Response) {
      Write-Host $_ $_.Exception.Response.StatusCode.value__
    } else {
      Write-Host $_ "erro sem resposta"
    }
  }
}
```

---

## 4. Assinatura Android - fluxo seguro

## Regra principal

Nao use o keystore de release como arquivo residente do workspace por padrao.

### Recomendado

- mover `upload-keystore.jks` para pasta segura fora do projeto
- nao depender rotineiramente de `android/key.properties`
- fazer release usando variaveis de ambiente

### Variaveis de ambiente aceitas pelo build

- `SIGNING_STORE_FILE`
- `SIGNING_STORE_PASSWORD`
- `SIGNING_KEY_ALIAS`
- `SIGNING_KEY_PASSWORD`

### Exemplo PowerShell local

```powershell
$env:SIGNING_STORE_FILE="C:/segredos/lotosmart/upload-keystore.jks"
$env:SIGNING_STORE_PASSWORD="SUA_SENHA_DO_STORE"
$env:SIGNING_KEY_ALIAS="upload"
$env:SIGNING_KEY_PASSWORD="SUA_SENHA_DA_CHAVE"
```

### Build de release

Na raiz de `lotofacil_app`:

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

---

## 5. Higiene operacional de segredos

### Fazer

- guardar o keystore em pasta segura fora do repo
- manter backup controlado da upload key
- usar variaveis de ambiente para release
- manter `key.properties.example` como referencia sem segredo

### Nao fazer

- enviar `key.properties` por chat
- subir keystore para drive publico
- incluir senha em screenshot
- deixar segredo persistido em CI sem rotacao ou controle

---

## 6. Checklist final de Go / No-Go

### GO se todos forem verdadeiros

- `ADMIN_API_TOKEN` configurado em producao
- `ALLOWED_ORIGINS` configurado com dominios corretos
- `ops/metrics` e `admin/sync` protegidos por token
- `healthz` sem dados internos sensiveis
- rate limit funcionando nas rotas pesadas
- keystore fora do workspace ou sob controle estrito

### NO-GO se qualquer um ocorrer

- upload key exposta ou compartilhada indevidamente
- rotas admin respondendo sem token
- `ALLOWED_ORIGINS` incorreto ou amplo demais para o uso real
- release sendo gerada com credenciais espalhadas em arquivos inseguros

---

## 7. Estado atual esperado do projeto

Depois desta rodada de hardening, o estado-alvo e:

- backend publico reduzido ao minimo necessario
- rotas operacionais autenticadas
- mitigacao basica de abuso por IP
- resposta HTTP endurecida
- fluxo de signing preparado para segredo fora do workspace

Esse e o baseline minimo recomendavel para publicar o app com um padrao pragmatico de AppSec.
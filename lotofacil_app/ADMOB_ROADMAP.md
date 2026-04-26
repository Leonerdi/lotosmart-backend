# Roadmap de Monetizacao com AdMob

## Etapa 1: infraestrutura segura para testes

Objetivo: validar integracao sem ativar anuncios reais nem atrapalhar o teste fechado.

- Dependencia `google_mobile_ads` integrada no app.
- AndroidManifest configurado com App ID oficial de teste do Google por padrao.
- Banner opcional controlado por flags de build.
- Nada aparece por padrao se `ADS_ENABLED` nao for informado.

### Como testar no ambiente fechado/interno

Use apenas anuncios de teste:

```powershell
flutter run --dart-define=ADS_ENABLED=true --dart-define=ADS_TEST_MODE=true
```

Ou para gerar bundle de homologacao com test ads:

```powershell
flutter build appbundle --release --dart-define=ADS_ENABLED=true --dart-define=ADS_TEST_MODE=true
```

Comportamento esperado:

- Se `ADS_ENABLED=false`, nenhuma inicializacao de anuncio acontece.
- Se `ADS_ENABLED=true` e `ADS_TEST_MODE=true`, o app usa `BannerAd.testAdUnitId`.
- O banner exibe a faixa "Anuncio em modo de teste" para evitar confusao durante homologacao.

## Etapa 2: ativacao para producao

So execute esta etapa quando a release de producao estiver pronta.

### 1. Criar App ID e unidades reais no AdMob

- Crie o app no painel do AdMob.
- Gere o App ID Android real.
- Gere pelo menos uma unidade de banner real.

### 2. Ajustar o Android App ID

Passe o App ID real no build Android:

```powershell
flutter build appbundle --release -PADMOB_APP_ID=ca-app-pub-XXXXXXXXXXXXXXXX~YYYYYYYYYY --dart-define=ADS_ENABLED=true --dart-define=ADS_TEST_MODE=false --dart-define=ANDROID_BANNER_AD_UNIT_ID=ca-app-pub-XXXXXXXXXXXXXXXX/ZZZZZZZZZZ
```

### 3. Antes de enviar para producao

- Revisar Politica de Privacidade para refletir anuncios reais e parceiros de publicidade.
- Revisar declaracoes do Play Console sobre publicidade, dados e Advertising ID.
- Validar novamente em teste interno com uma build espelhando a configuracao de producao.

## Recomendacao operacional

- Fechado/interno: somente test ads.
- Producao inicial: ativar real ads apenas depois de revisar manifest, politica e formularios do Play.
- Nunca clique em anuncios reais do proprio app durante homologacao.
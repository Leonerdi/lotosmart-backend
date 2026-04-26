# Signing de Release (Android)

## Recomendacao de seguranca

Prefira manter o keystore e as credenciais fora do workspace do app.

- Opcao recomendada: variaveis de ambiente `SIGNING_STORE_FILE`, `SIGNING_STORE_PASSWORD`, `SIGNING_KEY_ALIAS`, `SIGNING_KEY_PASSWORD`
- Opcao local: `android/key.properties`, somente para uso manual e sem versionar no Git

O `build.gradle.kts` aceita os dois modos, mas variaveis de ambiente devem ser a escolha padrao para release.

## 1) Gerar o keystore
No terminal, dentro de `lotofacil_app/android`:

```powershell
keytool -genkeypair -v -keystore app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## 2) Configurar as credenciais

### Opcao recomendada: variaveis de ambiente

```powershell
$env:SIGNING_STORE_FILE="C:/caminho-seguro/upload-keystore.jks"
$env:SIGNING_STORE_PASSWORD="SUA_SENHA_DO_STORE"
$env:SIGNING_KEY_ALIAS="upload"
$env:SIGNING_KEY_PASSWORD="SUA_SENHA_DA_CHAVE"
```

### Opcao local: key.properties

Use `lotofacil_app/android/key.properties.example` como modelo e crie `lotofacil_app/android/key.properties` com este conteúdo:

```properties
storePassword=SUA_SENHA_DO_STORE
keyPassword=SUA_SENHA_DA_CHAVE
keyAlias=upload
storeFile=app/upload-keystore.jks
```

## 3) Segurança no Git
Estes arquivos já estão no `.gitignore`:
- `android/key.properties`
- `android/app/upload-keystore.jks`

Recomendacao operacional:
- mantenha o keystore fora da pasta do projeto quando possivel
- nunca compartilhe `key.properties` em chat, backup publico ou screenshot
- se houver suspeita de vazamento da upload key, inicie rotacao no Google Play

## 4) Build final para Play Console
Na raiz de `lotofacil_app`:

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

O arquivo final será gerado em:
`build/app/outputs/bundle/release/app-release.aab`

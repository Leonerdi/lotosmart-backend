# Signing de Release (Android)

## 1) Gerar o keystore
No terminal, dentro de `lotofacil_app/android`:

```powershell
keytool -genkeypair -v -keystore app/upload-keystore.jks -keyalg RSA -keysize 2048 -validity 10000 -alias upload
```

## 2) Criar o arquivo key.properties
Crie `lotofacil_app/android/key.properties` com este conteúdo:

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

## 4) Build final para Play Console
Na raiz de `lotofacil_app`:

```powershell
flutter clean
flutter pub get
flutter build appbundle --release
```

O arquivo final será gerado em:
`build/app/outputs/bundle/release/app-release.aab`

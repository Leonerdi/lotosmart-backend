# 🌐 Ativação de GitHub Pages - Política de Privacidade

## Objetivo
Publicar o arquivo `PRIVACY_POLICY.html` em um URL público para que o Google Play Console aceite a política de privacidade do LotoSmart.

**URL Final Esperada**:
```
https://leonerdi.github.io/lotosmart-backend/PRIVACY_POLICY.html
```

---

## Passo a Passo

### Passo 1: Verifique se o arquivo está no repositório

1. Abra seu repositório GitHub: https://github.com/Leonerdi/lotosmart-backend
2. Clique em **"master"** (branch principal)
3. Verifique se o arquivo **`PRIVACY_POLICY.html`** está na raiz

Se não estiver:
- Ele foi commitado em 09/04/2026 com o commit "Finalize go-live production config"
- Clique em **"Refresh"** ou faça um `git pull` local para sincronizar

---

### Passo 2: Ativar GitHub Pages

1. Dentro do repositório, clique em **"Settings"** (engrenagem canto superior direito)
2. Na barra lateral esquerda, clique em **"Pages"**
   - Se não vir, scrolle para baixo em "Code and automation"

3. Em **"Build and deployment"** → **"Source"**, selecione:
   - **Branch**: `master` (ou `main`, conforme seu repo)
   - **Folder**: `/ (root)`
4. Clique em **"Save"**

---

### Passo 3: Aguardar Deployment

1. A página atualizará e mostrará:
   ```
   Your site is live at https://leonerdi.github.io/lotosmart-backend/
   ```

2. **Tempo**: Costuma levar 30 segundos a 2 minutos

3. Você verá um status amarelo/verde indicando sucesso

---

### Passo 4: Validar o Link Público

Abra em seu navegador:
```
https://leonerdi.github.io/lotosmart-backend/PRIVACY_POLICY.html
```

Se você vir a página com fundo branco/azul e os textos sobre Política de Privacidade, está funcionando! ✅

---

## Troubleshooting

### "GitHub Pages não aparece em Settings"

1. Verifique se o repositório é **público** (não privado)
   - Settings → Visibility → Mudar para "Public" se necessário

2. Se ainda não aparecer, vá para: https://github.com/Leonerdi/lotosmart-backend/settings/pages

### "Página mostra 404"

1. Confirme que o arquivo realmente está em `/PRIVACY_POLICY.html` (raiz)
2. Verifique o nome do arquivo (case-sensitive no Linux)
3. Espere 5 minutos para GitHub processar o deploy

### "HTTPS não está funcionando"

- O GitHub Pages fornece HTTPS automaticamente
- Espere 5+ minutos pela primeira vez
- Recarregue a página (Ctrl+F5)

---

## Para Use no Google Play Console

Após confirmar que o link funciona:

1. Acesse Google Play Console
2. Vá em **"Store Presence"** → **"App details"**
3. Role para baixo até **"Links"** → **"Política de Privacidade"**
4. Cole a URL:
   ```
   https://leonerdi.github.io/lotosmart-backend/PRIVACY_POLICY.html
   ```
5. Salve e continue com a submissão

---

## Dúvidas?

- **URL base** é sempre: `https://{seu-usuario}.github.io/{seu-repositorio}/`
- **Arquivo** deve estar na raiz do repo (não em subpasta)
- **SSL/HTTPS** é automático no GitHub Pages

Se precisar de mais ajuda: https://docs.github.com/en/pages


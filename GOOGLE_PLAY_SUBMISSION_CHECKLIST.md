# 📋 Checklist de Submissão - Google Play Console

## Pré-requisitos
- [x] Conta Google Play Developer (custa $25 única vez)
- [x] App LotoSmart com AAB assinado: `build/app/outputs/bundle/release/app-release.aab` (45.3 MB)
- [x] Política de Privacidade pública (em GitHub Pages)
- [x] Keystore backup seguro em C:\Users\Leonardo\Documents\LotoSmart-Release-Keys\

---

## ETAPA 1: Criar Aplicativo no Play Console

1. Acesse: https://play.google.com/console
2. Clique em **"Criar aplicativo"**
3. Preencha:
   - **Nome do app**: LotoSmart
   - **Categoria**: Casual / Simuladores / Loteria
   - **Classificação indicativa**: definida pelo questionário IARC (pode variar por país)
4. Aceite as políticas e clique **"Criar"**

---

## ETAPA 2: Informações do App (Obrigatório)

### 2.1 – Detalhes do App
- **Nome exibido**: LotoSmart
- **Descrição breve**: "Simulador estatístico para análise de combinações da Lotofácil"
- **Descrição completa**: 
  ```
  LotoSmart é um aplicativo mobile que funciona como um simulador 
  estatístico para apoio informativo na análise de combinações numéricas 
  da Lotofácil. Utiliza inteligência artificial e análise histórica dos 
  últimos concursos para gerar sugestões baseadas em padrões estatísticos.
  
  ⚠️ IMPORTANTE: Este aplicativo é apenas um simulador. Não garante prêmios 
  e não representa promessa de ganho. Jogue com responsabilidade.
  
   Uso recomendado para maiores de 18 anos. A classificação indicativa oficial pode variar por região.
  ```
- **Idioma**: Português (Brasil)

### 2.2 – Categoria e Classificação
- **Categoria principal**: Casual
- **Subcategoria**: Simuladores
- **Classificação indicativa**: definida pelo resultado do IARC em cada país/região

### 2.3 – Email de Contato
- Use seu email Google (leonardo.fernandes.silva.lol@gmail.com)

---

## ETAPA 3: Gráficos e Screenshots

Prepare 4-8 screenshots que mostrem:
1. Tela inicial com o diagnóstico
2. Tela de estratégias
3. Tela de resultados com números gerados
4. Tela de PDF com compartilhamento

**Dicas**:
- Mínimo 320x569px (celular)
- Máximo 3440x1440px (no máximo)
- Evitar texto pequeno; use fontes ≥ 12pt

---

## ETAPA 4: Ícone do App

- **Arquivo**: Use o ícone adaptativo que Flutter gerou
- **Tamanho**: 512x512 px
- **Formato**: PNG com fundo transparente
- **Obrigatório**: Play Console requer este arquivo explicitamente

---

## ETAPA 5: Política de Privacidade (CRÍTICO)

**Campo obrigatório no Play Console**: "URL da Política de Privacidade"

Copie esta URL para o campo:
```
https://leonerdi.github.io/lotosmart-backend/PRIVACY_POLICY.html
```

⚠️ **Antes disso, você DEVE ativar GitHub Pages** (veja instruções abaixo)

---

## ETAPA 6: Conformidade e Classificação

### 6.1 – Classificação (IARC)
- Clique em **"Formulário IARC"**
- Preencha o questionnaire simples:
  - "Seu app coleta dados pessoais?" → **Não**
  - "Seu app contém publicidade?" → **Sim** (AdMob)
   - "Seu app é destinado a crianças?" → **Não** (app não infantil)
- Submit e aguarde a classificação (costuma ser em minutos)

### 6.2 – Proteção de Dados
- **Dados de localização**: Não coletamos
- **Dados financeiros**: Não coletamos
- **Dados de contato**: Não coletamos
- **Cookies/Rastreadores**: Apenas AdMob (padrão)

---

## ETAPA 7: Upload do AAB

1. Clique em **"Internal Testing"** ou **"Alpha"** (comece aqui!)
2. Clique em **"Create new release"**
3. Selecione o arquivo:
   ```
   C:\Users\Leonardo\LotoApp\lotofacil_app\build\app\outputs\bundle\release\app-release.aab
   ```
4. Preencha **Release notes**:
   ```
   Versão 1.0.1 - Lançamento Inicial
   - Simulador estatístico da Lotofácil
   - Análise de padrões históricos
   - Geração de combinações IA-otimizadas
   - PDF com timestamp sincronizado
   - Suporte a compartilhamento direto
   ```
5. Clique **"Review"** e depois **"Release to testing"**

---

## ETAPA 8: Dispositivos de Teste (Importante!)

Se quiser testar antes de subir para Production:
1. Vá em **"Internal Testing"** → **"Manage testers"**
2. Adicione seu email Google: leonardo.fernandes.silva.lol@gmail.com
3. Copie o link de convite
4. Use esse link para instalar a versão de teste no seu POCO
5. Teste fluxo completo: geração de jogos, PDF, compartilhamento

---

## ETAPA 9: Validação de Pricing e Distribuição

- **Preço**: Gratuito (recomendado)
- **Países**: Ativar vendas em "Todos os países"
- **Idade/restrições**: seguir classificação IARC por país (ex.: Livre no Brasil, 18+ em outras regiões)

---

## ETAPA 10: Revisão Final e Submissão

Checklist antes de clicar "Submit":
- [ ] Nome: LotoSmart
- [ ] Descrição: Preenchida
- [ ] Categoria: Casual/Simuladores
- [ ] Screenshots: 4+ anexados
- [ ] Ícone 512x512: Anexado
- [ ] Política de Privacidade: URL ativa (GitHub Pages)
- [ ] Classificação IARC: Completada
- [ ] AAB: Upload realizado
- [ ] Release notes: Preenchidas
- [ ] Classificação etária/IARC revisada por região

---

## PRÓXIMOS PASSOS APÓS SUBMISSÃO

1. **Aguardar revisão** (costuma levar 2-4 horas)
2. **Conferir status** em Play Console → Store Presence
3. **Se aprovado**: Seu app estará live para download
4. **Se rejeitado**: Corrija pontos sinalizados e resubmeta

---

## CONTATO SUPORTE GOOGLE PLAY

Se precisar de ajuda durante submissão:
- Email: support@google.com/play
- Chat: Disponível dentro do Play Console

---

**Estado Atual da Aplicação**:
- ✅ Backend: Online em Railway
- ✅ AAB: Gerado e assinado
- ✅ Política de Privacidade: Pronta (GitHub Pages)
- ✅ Versão: 1.0.1+2
- ✅ GitHub Pages: Ativo
- ⏳ Play Console: Submeter


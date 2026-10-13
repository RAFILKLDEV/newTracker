---
name: firecast-floating-popup
description: 'Regras para os popups flutuantes do plugin Firecast newTracker (timer de Turno e Atenção). Use ao mexer em popupForm, tamanho do fundo cinza (esticado/cortado/estreito), arraste, posição salva, applyFloatingPopupSize, applyAttentionPopupSize, createLocalTurnTimerPopup, createAttentionPopup ou windowPositions.'
---

# Popups flutuantes (Turno e Atenção) no Firecast

Arquivos: `trackerMain.lua` (popups) e `trackerWindowPositions.lua` (posição).
Receita validada pelo usuário no Firecast para os DOIS popups. Não improvise: copie esta receita.

## Receita (validada)
1. `gui.newPopupForm()` criado em Lua. Só ele arrasta (`movable=true`) e sai da janela do tracker. `gui.newPopup` é modal e não arrasta. LFM para esses popups esticou o fundo: não use.
2. Fundo cinza = cartão + 2px em cada lado. Defina `popup._cardMargin = FLOATING_PADDING` ANTES de `applyFloatingPopupSize`/`applyAttentionPopupSize`. O tamanho externo é interno + 2*margem, e só `popup.width`/`popup.height` são definidos.
3. Cartão: `gui.newRectangle`, `parent=popup`, `align="none"`, `left=top=FLOATING_PADDING`, largura/altura fixas, `popup._fixedSizeCard = card`, `hitTest=false`, `registerPopupControl`.
4. Propriedades do popup, nesta ordem: tamanho, `drawContainer=false`, `backOpacity=0` em `pcall`, `cancelable=false`, `resizable=false`, `movable=true`, `hitTest=false`, `placement` (timer `bottomRight`, Atenção `bottomLeft`), `_dynamicCtrls={}`.
5. Conteúdo interno com `align="none"` e posições fixas (padding 2px, gap 2px). Sem `padding`/`margins` no cartão.
6. `applyFloatingPopupSize` com `_cardMargin` só grava `width`/`height` e reposiciona o cartão. Altura dinâmica (lista do Atenção): chame `applyAttentionPopupSize(popup, altura)` dentro de `beginUpdate`/`endUpdate`, comparando só `popup.width`/`popup.height` e a altura do cartão.

## Proibido (cada item já quebrou o tamanho)
- `popup.theme` (ex.: "dark"), `popup.padding`, `popup.margins`, `card.padding`, `card.margins`.
- `minWidth`/`maxWidth` (só valem em flowLayout/recordList) e `gui.Control.setWidth/Height/getWidth/getHeight` no popup.
- Reaplicar o tamanho depois de `gui.showPopup` (nem direto, nem em `setTimeout`).
- `windowPositions.bind`, `beginLayout`/`endLayout` nesses popups: escrever `left`/`top` fez o host esticar ou estreitar o cinza. Constantes `TURN_TIMER_SAVE_POSITION = false` (existe no código do timer); o Atenção não tem bind.
- Escrever `popup.left`/`popup.top` em qualquer momento (inclusive "devolver a posição" depois de redimensionar): voltou ao canto E aumentou o cinza (testado no Atenção).
- Forçar tamanho com +1 e voltar; trocar a ordem das propriedades sem testar.

## Posição ao mudar a altura (Atenção)
- Fechar/recriar o popup a cada refresh o devolve ao canto: `refreshFloatingRoot` fecha se `popup._positionRoot ~= root`; no Atenção use `popup._attentionRoot` (definido em `createAttentionPopup`).
- Quando OUTRO jogador clica, a lista muda, a altura muda e o host reposiciona o popup (volta ao canto). Tentativas que NÃO funcionaram: gravar só a altura, guardar/devolver left/top, fechar e reabrir com a posição lida/guardada.
- Solução adotada: altura FIXA do Atenção (`ATTENTION_POPUP_HEIGHT + FLOATING_GAP + ATTENTION_LIST_VIEWPORT_HEIGHT`), nunca muda; só o conteúdo da lista varia. Regra geral: nunca mude a altura/largura de um popupForm já aberto.

## Sintomas e causa
- Cinza esticado até a borda da tela: `windowPositions.bind`, tema ou `minWidth`/`maxWidth`.
- Cinza estreito/cortado: reaplicação do tamanho após o show, ou mistura de Control size com form size.

## Processo
- Não dá para rodar o Firecast: o usuário recompila/reinstala o `.rpk` e reporta (peça captura se ambíguo).
- Para testar hipóteses, crie variantes empilhadas (A/B/C/D), compare com a receita e remova depois.
- Quando algo falhar, compare linha a linha com `createLocalTurnTimerPopup` (referência) antes de inventar correção.
- O menu de contexto do timer (`openTurnTimerContextMenu`) segue a mesma receita (validada): `_cardMargin`, cartão `align="none"` deslocado 2px, botões `align="none"` com `left=2` e largura = cartão − 4, sem tema/padding e sem reaplicar tamanho após o show.
- Releia o trecho antes de editar (evita "no match"); arquivos em LF, UTF-8 sem BOM.

## Pendente
- Salvar posição arrastada sem esticar o cinza (hoje não salva): tentar aplicar `left`/`top` uma única vez, sem `setInterval`, e testar.
- Posição reseta ao reinstalar o plugin (não investigado).

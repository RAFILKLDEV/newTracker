---
name: firecast-floating-popup
description: 'Preservar e corrigir os popups flutuantes de Turno, Atenção e o menu do timer no plugin newTracker do Firecast. Use ao alterar fundo cinza, dimensões, arraste, posição, ciclo de abertura ou helpers compartilhados; contém a receita de referência e as regressões observadas.'
---

# Popups de Turno e Atenção do newTracker

Esta é a fonte mantida das regras. O `AGENTS.md` da raiz destaca sua leitura;
o caminho antigo em `.github/skills/firecast-floating-popup/SKILL.md` apenas
redireciona para cá. A receita se aplica a estes componentes do Firecast, não a
todos os controles ou formulários do SDK.

## Escopo e evidência

Antes de editar, leia no `trackerMain.lua` os trechos envolvidos e todos os
chamadores de um helper compartilhado. Os pontos principais são
`applyFloatingPopupSize`, `applyLocalTurnTimerSize`, `createLocalTurnTimerPopup`,
`syncLocalTurnTimer`, `applyAttentionPopupSize`, `createAttentionPopup`,
`renderAttentionPopup`, `refreshFloatingRoot` e `openTurnTimerContextMenu`.
`trackerWindowPositions.lua` contém a persistência, mas não deve voltar a escrever
coordenadas nesses popups durante uma correção de outra funcionalidade.

A receita abaixo já estava documentada como validada pelo usuário no Firecast.
Em 13/10/2026, mudanças fora dela provocaram relatos de fundo cinza incorreto
primeiro no Turno e depois no Atenção. A receita foi restaurada nas versões 2.2
e 2.3. Essas versões foram compiladas; o teste visual da versão 2.3 pelo usuário
ainda não foi registrado nesta conversa. Não confundir compilação, revisão do
código ou valores calculados com confirmação visual.

Pedidos sobre permissões, passagem de turno, rolagens, nomes ou mensagens não
justificam alterar os popups. Preserve a geometria e o ciclo existentes nesses
casos. Se o usuário pedir uma mudança de layout ou posição, trabalhe nessa mudança
usando as evidências abaixo e registre o resultado. A skill não cria uma etapa de
aprovação adicional nem substitui a instrução do usuário.

## Receita de referência

1. Criar em Lua com `gui.newPopupForm()`. O popup nativo usa `movable=true` e pode
   sair da janela do tracker. A troca para `gui.newPopup` ou um popup definido em
   LFM já prejudicou esse comportamento e o tamanho do fundo.
2. Definir `popup._cardMargin = FLOATING_PADDING` antes de aplicar o tamanho.
   `FLOATING_PADDING=2` e `FLOATING_GAP=2`. A largura/altura externa é a do cartão
   mais 4px: 2px de cinza em cada lado. Esses 2px externos são distintos dos 2px
   de espaço interno obtidos pelas posições dos filhos.
3. No ramo com `_cardMargin`, `applyFloatingPopupSize` escreve apenas
   `popup.width`/`popup.height` e a geometria do cartão. Esse ramo retorna antes
   do código legado de `minWidth`/`maxWidth` e `gui.Control`. Todos os chamadores
   atuais deste helper usam `_cardMargin`; não remover essa configuração nem
   encaminhar um deles para o ramo legado.
4. Após aplicar o tamanho, configurar nesta ordem: `drawContainer=false`,
   `backOpacity=0` em `pcall`, `cancelable=false`, `resizable=false`,
   `movable=true`, `hitTest=false`, `placement` e `_dynamicCtrls={}`. O Turno
   usa `bottomRight`; o Atenção usa `bottomLeft`. Manter os ajustes existentes
   de janela superior em `pcall`.
5. Criar o cartão com `gui.newRectangle()`, `parent=popup`, `align="none"`,
   `left=2`, `top=2` e dimensões fixas. Guardar em `popup._fixedSizeCard`, usar
   `hitTest=false` e `registerPopupControl(popup, card)`. Não definir `padding`
   nem `margins` no cartão.
6. Posicionar os filhos com `align="none"`, coordenadas explícitas, espaço
   interno de 2px e intervalos de 2px. O arraste pertence ao container nativo:
   fundo, cartão, grip `≡` e ícones deixam o mouse passar com `hitTest=false`.
   Botões e edição usam `hitTest=true`. O nome do Turno captura o menu de contexto;
   o relógio deixa o mouse passar.
7. Aplicar o tamanho durante a criação, antes de `gui.showPopup`. Não repetir
   essa aplicação no caminho de abertura nem agendá-la em `setTimeout` após o show.

O menu do timer segue a mesma geometria: `_cardMargin=2`, cartão em `(2,2)` e
botões com `align="none"`, `left=2`, largura do cartão menos 4px e intervalo de
2px. Suas diferenças existentes são `cancelable=true`, `movable=false` e
`placement="mouse"`. Na 4.0, seu cartão tem 280px para comportar os textos;
isso não muda os 200px dos componentes Turno/Atenção. Não introduzir tema,
padding ou reaplicação após abrir.

## Dimensões atuais de referência

Valores calculados do código: Turno/Atenção conservam a geometria da 2.3; o
menu de contexto foi ampliado na 4.0 por relato de textos sem largura. A 4.0
aguarda teste visual do usuário.

| Componente | Cartão | Popup nativo com margem | Conteúdo |
| --- | --- | --- | --- |
| Turno normal | 200 × 70px | 204 × 74px | Nome 196 × 32px; relógio 196 × 32px; intervalo 2px |
| Turno compacto | 200 × 48px | 204 × 52px | Nome 196 × 16px; relógio 196 × 26px; intervalo 2px |
| Atenção | 200 × 216px | 204 × 220px | Área fixa da lista 196 × 136px; até 3 linhas antes da rolagem |
| Menu do timer | 280 × 66px | 284 × 70px | Dois botões 276 × 30px; intervalo 2px |

No Atenção, os três botões têm 64px e dois intervalos de 2px: cabem nos 196px
internos. O grip tem 18px, a linha de botões 28px e o campo de nome 24px.
Na 4.0, o grip ocupa 176px e deixa 2px de intervalo para o botão × de 18px
no canto superior direito; o restante da geometria do Atenção permanece igual.
Os 204px do popup são os 200px do cartão mais as margens externas; não reduzir
esses 4px para compensar uma suposta largura incorreta.

## Atenção: janela fixa e lista variável

`ATTENTION_POPUP_FIXED_HEIGHT = ATTENTION_POPUP_HEIGHT + FLOATING_GAP +
ATTENTION_LIST_VIEWPORT_HEIGHT`, atualmente 216px. Essa reserva existe inclusive
sem solicitações; evita redimensionar o host quando qualquer participante clica.

`applyAttentionPopupSize(popup)` é chamado somente na criação. Compara apenas
`popup.width`, `popup.height` e altura do cartão, considerando a margem; aplica
o tamanho em `beginUpdate`/`endUpdate`. A orientação antiga para calcular uma
altura a partir do número de entradas foi substituída pela altura fixa.

`renderAttentionPopup` atualiza linhas, nomes, contagens, visibilidade da lista e
rolagem. Não altera largura/altura externa, não escreve coordenadas, não reaplica
tamanho e não fecha/recria a janela a cada atualização. A lista mantém 136px de
altura; acima de três entradas, as linhas reservam espaço para a barra de rolagem.

Manter `popup._attentionRoot`: é definido na criação, atualizado ao renderizar e
usado no teste da mesa em `refreshFloatingRoot`. Não substituir por
`_positionRoot`, pois o Atenção não tem vínculo de posição e seria fechado
indevidamente a cada atualização.

## Atenção: cargas e fechamento local — 4.0

A pedido do usuário, a lista perde uma carga de todos os participantes a cada
3 segundos do mesmo ciclo. Cada clique soma uma carga ao saldo ainda válido,
sem adiar o ciclo. `getAttentionCount` calcula o saldo pelo relógio do servidor
e pelos campos `cargaCicloInicio`/`cargaTick`, sem clientes concorrendo para
gravar decrementos. Não ler `contagem` como saldo atual: é o valor base.
`getAttentionEntries` também retorna o mapa de saldos no segundo resultado.
O ciclo reinicia quando não existe mais solicitação ativa; cada entrada mantém
sua própria origem do ciclo para solicitações antigas não ressuscitarem.

O botão × chama `closeAttention`: grava `attentionClosed` no armazenamento
individual de preferências e fecha a janela. Renderização e novos pedidos
respeitam esse estado. Pedir atenção no chat não reabre a janela. Somente
`openAttention`, acionado por Abrir atenção no chat, desfaz a preferência.
Essa preferência não salva nem restaura coordenadas e não pertence ao NDB
público. Usar o root real da iniciativa; nunca o node público do Chat Avançado.

Uma janela reaberta explicitamente observa a lista mesmo com o Tracker fechado.
Seu único timer atualiza a apresentação; onHide remove timer/listeners. A
assinatura de nomes/saldos evita reconstruir linhas sem mudança. Uma abertura
explícita de outra mesa não deve ser tomada por atualizações do Tracker anterior.
Fechar/reabrir continua sendo ação explícita; decrementos não recriam nem
reposicionam o popup. Leitura estática e compilação não confirmam o resultado
visual ou a sincronização: a validação no Firecast fica com o usuário.

Em 15/10/2026, o usuário confirmou que a 4.1 funcionou e pediu uma barra
animada para o ciclo. Na 4.2, ela ocupa somente o intervalo existente abaixo
do nome: 196 × 2px, sem alterar cartão, lista, margens ou posição do popup.
Usar dois retângulos sem hitTest; animar somente a largura do preenchimento.
A barra enche em 3 segundos pelo mesmo `cicloInicio`/relógio do saldo e volta
ao início na redução das cargas. Novos pedidos não reiniciam o progresso.
Ocultar quando não houver cargas. O único timer do observador alterna entre
50ms enquanto anima e 1000ms em repouso; onHide continua removendo-o.
Não reconstruir linhas por frame: atualizar a lista na mudança de ciclo e no
refresh de 1 segundo. A animação da 4.2 ainda depende do teste do usuário;
a confirmação da 4.1 não valida esta mudança visual.

Na 4.3, o nome de cada solicitação segue `nick - jogador`, com o apelido da
mesa (ou nick personalizado) e o login real do autor. O campo Nick e Salvar
alteram somente o apelido; `jogadorLogin` conserva a identificação na entrada.
Usar nomes sem códigos de formatação nas labels e atualizar também a assinatura
de renderização quando o apelido mudar. Esse pedido não altera geometria,
arraste, barra de progresso nem ciclo das cargas. Aguarda teste manual.

## Turno: atualização e tamanho compacto

O relógio atualiza texto; troca de jogador atualiza o nome e o estado do turno.
Preservar a janela existente durante essas atualizações. Não acrescentar
reaplicação de dimensões ou posição ao tick do relógio nem à troca de turno.

A opção explícita de diminuir/restaurar tamanho já usa `applyLocalTurnTimerSize`;
`syncLocalTurnTimer` também a usa quando a preferência de tamanho muda. Preservar
essa alternância existente, sem generalizá-la para todo refresh. Ela é distinta
da reaplicação de tamanho imediatamente após `gui.showPopup`. Qualquer alteração
nesse comportamento precisa de verificação visual pelo usuário.

## Mudanças que causaram regressões

Estas restrições são locais aos popups descritos, não afirmações sobre a validade
geral das propriedades no SDK.

| Mudança observada | Problema registrado |
| --- | --- |
| `popup.theme`, `popup.padding`/`margins`, `card.padding`/`margins` | Alteração da área cinza; a receita funciona sem essas propriedades |
| `minWidth`/`maxWidth` no popup | Fundo esticado; não usar para corrigir largura desses componentes |
| `gui.Control.setWidth`/`setHeight`/`getWidth`/`getHeight` no popup | Mistura do tamanho do controle e do formulário; fundo estreito ou cortado |
| Reaplicar tamanho após `gui.showPopup`, inclusive em timeout | Fundo incorreto ou nova aplicação do posicionamento |
| `windowPositions.bind`, `beginLayout`/`endLayout` e escrita de `popup.left`/`top` | Fundo esticado/estreito e retorno ao canto |
| Altura do Atenção proporcional às entradas | Cliques de outros jogadores redimensionavam e reposicionavam a janela |
| Fechar e reabrir Atenção a cada refresh, inclusive comparando `_positionRoot` | Retorno ao posicionamento inicial |

Guardar e devolver coordenadas após redimensionar, fechar/reabrir com coordenadas
salvas e alterar tamanho em +1px para depois voltar não constituem uma solução
validada. Não reintroduzir essas tentativas numa correção de outro assunto.

## Posição: estado atual e trabalho pendente

Manter `TURN_TIMER_SAVE_POSITION = false`. O Atenção não chama
`windowPositions.bind`; os dois popups não chamam `beginLayout`/`endLayout` nem
escrevem `popup.left`/`popup.top`. O arraste nativo continua disponível.

Salvar e restaurar coordenadas entre reinícios/reinstalações continua pendente.
`trackerWindowPositions.lua` já contém snapshots locais alternados e um NDB por
usuário/mesa, mas esses dados não são aplicados aos popups atuais. A preferência
`turnCompact` continua sendo armazenada. Existência de coordenadas em arquivo ou
no servidor não prova que a janela as restaure sem deformar o fundo.

Se um pedido abordar essa persistência, investigue um caminho que preserve a
receita e informe o que ainda depende do teste visual do usuário. Não reativar o
bind periódico nem as escritas de posição como se já estivessem validados. A
sugestão antiga de aplicar `left`/`top` uma vez também permanece hipótese sem
confirmação. Preservar as posições antigas armazenadas durante essa investigação.

## Revisão e entrega

- Ao mudar um helper, conferir seus chamadores no Turno normal, Turno compacto,
  Atenção e menu do timer. Corrigir apenas um deles deixou o outro com a regressão.
- Para tarefas fora de layout/posição, conferir que o diff não alterou estes
  trechos por efeito indireto de uma refatoração.
- Por preferência do usuário, ele testa a aplicação: não abrir o Firecast,
  instalar o pacote ou executar testes da aplicação. Compilar Lua/LFM com
  `rdk -c` quando houver mudança de código; entregar `output/newTracker.rpk`
  informando que o teste visual cabe ao usuário. Documentação sozinha não exige
  nova compilação do plugin.
- Manter os arquivos em UTF-8 sem BOM e LF. Atualizar esta skill após um novo
  resultado observado, identificando o que foi confirmado e o que segue pendente.

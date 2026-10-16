# newTracker — instruções do projeto

## Leia antes de editar Turno ou Atenção

A skill [firecast-floating-popup](.agents/skills/firecast-floating-popup/SKILL.md)
é a referência obrigatória para os popups de Turno, Atenção e o menu do timer.
Leia-a antes de alterar criação, tamanho, arraste, posição, ciclo de abertura ou
os helpers compartilhados em `trackerMain.lua` e `trackerWindowPositions.lua`.

O fundo cinza do Firecast já sofreu regressões com tema, tamanho de `gui.Control`,
reaplicação do tamanho após abrir e escrita de coordenadas. Preserve a receita
documentada: `_cardMargin=2`, cartão deslocado 2px, altura fixa do Atenção e
restauração de posição desativada. Uma alteração no helper exige revisar os três
componentes, incluindo o Turno compacto.

Pedidos sobre permissões, passagem de turno, iniciativas, nomes ou mensagens
devem preservar essa geometria e o ciclo dos popups. Quando o pedido incluir
layout ou posição, use a skill para orientar a mudança e registre a evidência
obtida; a instrução do usuário prevalece e não exige uma nova confirmação.

## Entrega e validação

Por preferência do usuário, ele testa o Firecast: não abrir, instalar nem executar
testes da aplicação. Para alterações Lua/LFM, compilar com `rdk -c` e entregar
`output/newTracker.rpk`. Compilação não comprova funcionamento visual.
Para alterações apenas de documentação, revisar os arquivos sem recompilar o plugin.
Manter UTF-8 sem BOM e LF.

## Chat Avançado

Leia [CHAT_AVANCADO.md](CHAT_AVANCADO.md) ao alterar o chat. A captura usa o chat
nativo e seus IDs; correções, observações e fixações ficam nos módulos
`trackerChat*.lua`. A branch `chatAdvanced` é separada da iniciativa, com escrita
do mestre. Dados particulares nunca passam pelo broadcast ou NDB público.
O chat é um `tablesDock` (`br.com.rafilkl.newTracker.chat`); seu node público
nunca recebe mensagens privadas. A lista usa NDB em memória e uma lista nativa
por conversa, preservando cache e rolagem ao ocultar/trocar abas. Não tratar
`onHide` como destruição do chat ou dos fixados. `/>>` delega ao tracker da
iniciativa, nunca ao node do chat; `/fixados` abre o popup independente.
O painel de fixados segue a receita de popup em módulo próprio; não refatorar
os helpers de Turno/Atenção para modificar o chat. O usuário usou 3.0/3.1; sua
imagem da 3.1 confirmou nomes cortados, barras nos cabeçalhos e espaço excessivo.
A 3.2 usa Label com autoSize/wordWrap nos nomes e corpos simples; não voltar
a usar RichEdit curto para nomes ou a estimar a altura de texto simples por
quantidade de caracteres. RichEdit permanece para Talemark com formatação.
Renderizar somente o corpo no componente da mensagem, sem duplicar nome/data.
Filtrar propriedades internas apenas na lista visual: retornar nil em normalize
para esses registros produziria tombstones e perda de metadados no controlador.
O usuário usou a 3.2 e relatou lag; a imagem mostrou avatar ausente em mensagens
de um jogador que já tinha saído da mesa. A 3.3 conserva avatares conhecidos,
usa o login/ID real como alternativa à foto do personagem e limita a primeira
montagem às 100 mensagens visíveis mais recentes, mantendo o histórico em cache.
Histórico revela mais 50 mensagens do cache antes de consultar o servidor.
Preservar os caches de registros/ordenação/estado: detectar mudanças por valores,
incluindo mutações de visibilidade/exclusão no mesmo objeto nativo.
Não voltar a escrever dimensões/fontes inalteradas, agendar um timer por linha,
recalcular todas as conversas ocultas ou copiar todo o armazenamento para uma
mensagem sem metadados. Reunir os ajustes de labels e rolagem por lista.
O design da 3.3 segue a imagem do chat original: grupos por autor/personificação,
avatar circular, data junto ao apelido, separadores e compositor com ícones.
Manter cores distintas dentro do nick via trackerChatInline.lua; não colocar
editores curtos nos cabeçalhos. A mesma lista mantém cada mensagem com ID/menu.
trackerChatComposer.lua mantém rascunho/estilo/modo em memória por conversa;
formatação é enviada por TalemarkOptions, sem exportar RichEdit como texto e
perder estilos. Anexos entram no rascunho; não publicar automaticamente.
O botão de áudio envia arquivo, pois o SDK não oferece captura de microfone.
Eventos conhecidos de barras/modos são humanos; propriedades desconhecidas
seguem omitidas. Títulos personalizados das barras não são expostos pelo SDK.
O usuário confirmou que a 3.3 melhorou bastante. Na 3.4 o chat captura somente
a mesa: preservar a remoção do seletor e a recusa de privados/canais na captura.
Na 4.0, a faixa acima das mensagens contém Fixados/Histórico/Última/Permissões
e Pedir atenção/Abrir atenção. A partir de 448px, os quatro primeiros mostram
títulos; a partir de 632px, todos mostram. Abaixo disso ficam ícones com dicas.
Última usa seta para baixo. Pedir atenção e reabrir são ações distintas.
A escrita agrupa
formatação, anexos/ações e dados, em até duas linhas de 26px, com botões de
24px. O cartão cresce de 124px para 150px com a segunda linha para conservar
a altura do editor. Enviar e ⋯ ficam à direita da última linha. Overflow
mantém todas as ações acessíveis; rolagens escolhidas por ícones ocultos usam
a barra visível como âncora. O layout não altera cache, rascunho ou captura.
Não reunir novamente os atalhos da conversa e os dados numa única fila
disputando a mesma largura. A organização aguarda teste visual do usuário.
Cada mensagem tem horário numa coluna à direita, inclusive continuações;
eventos mantêm o prefixo à esquerda. Reservar a coluna ao dimensionar o texto.
trackerChatDice.lua é um popup independente de montagem de dados. Não tocar
nos helpers ou coordenadas do Turno/Atenção para mudar esse popup. Nunca executar
rolarLocalmente ou gerar números para representar uma rolagem recebida.
Normal usa asyncRoll; vantagem/desvantagem publicam duas execuções da expressão
e um resumo com o maior/menor total. Falha parcial não repete a primeira rolagem.
Ordenação é visual, por grupo, em cópias dos resultados; não altera ops ou total.
Na 3.5, por pedido do usuário, o menu de dados usa gui.newPopup contextual ao
compositor: cancelable=true, fecha ao clicar fora/Esc e não tem botão Fechar.
Essa escolha é exclusiva deste menu; fixados, Turno e Atenção conservam seus
popups e helpers. Cada ação de abertura pelo compositor cria uma montagem nova,
com um dado do ícone clicado, modificadores vazios, Normal e Original ativos.
Cliques nos ícones dentro do menu acumulam dados; não restaurar rollDraft.
Modo e ordem usam botões com destaque persistente e seleção exclusiva por grupo,
sem comboBox. Os vetores em trackerChatDiceIcons.lua são compartilhados com a
barra. Modificadores aceitam sequências +5-3+10; manter os termos na expressão,
mostrar sua soma e enviar exatamente a prévia. Nunca substituir texto inválido
por zero ou avaliar código. Campos sem field usam onChange: o onUserChange do
SDK exige vínculo com NDB e foi a causa do relato de modificadores inoperantes.
Quantidades também usam onChange; não reconstruir a lista durante a edição
de um modificador. O usuário relatou o erro na 3.4; a 3.5 aguarda teste manual.
Na 3.5 o usuário relatou erro ao rolar com vantagem. O log local de 14/10/2026
às 13:37:57 registra uma asserção em TRectPopupLock.TornarInvisivel; o texto do
erro da interface ainda não foi fornecido. Na 3.6 o menu fecha antes de asyncRoll
e inicia o envio no próximo ciclo da UI; onClose marca o handle encerrado e
adia destroy para deixar o fechamento nativo liberar o bloqueio. Não destruir
um popup contextual dentro do seu próprio onClose nem atualizar seus controles
após Rolar. O fluxo completo usa Async.execute/Async.pawait, observa falhas
da execução, serializa rolagens por sessão e preserva resultados já enviados.
Mensagens e rolagens usam a mesma coluna/formatação de hora independentemente
de iniciar/continuar um grupo. Descrição e resultado pertencem à mesma linha,
com quebra nativa se faltar espaço; preservar Talemark, notas e IDs distintos.
A 3.6 foi preparada para teste manual; o log não confirma sozinho a causa de
todo erro de vantagem nem o resultado da correção.
O usuário enviou a imagem da asserção Globals.pas:631 ao rolar 1d20. O pacote
instalado foi identificado como 3.6 e o log de 14:08:01 mostra a recorrência
durante FMX.Anima.ProcessarAnimacoes. Adiar destroy por 1ms não resolveu esse
caminho. A 3.7 mantém uma única instância nativa de menu por compositor; onClose
apenas muda o estado de abertura, sem destruir o popup nem seus controles.
A cada abertura, resetar dados/modificadores/modo/ordem/descrição; reutilizar a
instância não significa restaurar montagem antiga. Enviar a rolagem após o
onClose nativo. Manter o popup como filho do compositor até a destruição do pai,
sem timer arbitrário para destruir uma janela que ainda está sendo animada.
O fundo contextual usa opacidade 0.12, evitando a transição com opacidade zero.
Enter no menu, inclusive campos de quantidade/modificador/expressão/descrição,
aciona a mesma função do botão Rolar e consome a tecla antes do fechamento.
O compositor também redireciona Enter se o menu estiver aberto. Enter em botões
de dados/modo/ordem deve rolar; Espaço mantém a ação daquele botão. Dar foco ao
modificador ao abrir. A 3.7 depende do teste do usuário para confirmar a asserção.
Na 4.0, o aviso “Digite uma mensagem...” aparece sempre que o editor está
vazio, inclusive focado. onChange/setText/foco recalculam; teclado e alteração
também agendam uma única atualização após o evento nativo para ler o texto
atualizado. O label não recebe foco nem cliques. Não adicionar polling.
Renderizar expressão = total {dados + modificador}, sem duplicar Resultado.
Preservar caches de apresentação e labels/flowLayout com medidas nativas.
F3 volta para entradas mais antigas; F4 avança e restaura o rascunho no fim.
Não circular do mais antigo para o mais recente. ↑/↓ preservam o mesmo fluxo;
↑ começa com campo vazio e continua enquanto o texto foi recuperado.
Rolagens personalizadas confirmadas acrescentam /r seguido da fórmula uma
única vez por operação; vantagem não produz duas entradas. O envio de /r
continua no interpretador original. O histórico conserva o limite de 200.
Avatares usam a foto explícita da personificação, depois a ficha principal
atual do jogador (personagemPrincipal/mesa:findBibliotecaItem/avatar) e, por
último, a foto do usuário. Reaproveitar o cache de 5 segundos; não abrir NDBs
de fichas ou percorrer a biblioteca por mensagem. A máscara circular de 44px
avança 2px sobre a imagem de 40px e recorta 1px interno para cobrir a moldura;
desativar showProgress para não expor o indicador quadrado de carregamento.
A imagem de erro enviada pelo usuário em 15/10/2026 confirmou que
URLWhileLoading, embora exposta pelo SDK, aponta para a propriedade nativa
NoImageURL indisponível no cliente dele. A 4.1 remove essa atribuição da
criação de mensagens. Não reintroduzir URLWhileLoading/getURLWhileLoading
nos avatares nem alterar o SDK empacotado para contornar essa incompatibilidade.
Manter showProgress=false, a máscara circular e a prioridade da foto da ficha.
Compilação não valida propriedades aceitas pelo cliente nativo em execução.
Na 4.0, o botão Chat foi removido do tracker; attach/detach permanecem.
Fixar/desafixar posição fica no contexto do item, somente para mestres.
Menus de itens e contexto do timer têm cartões de 280px e botões de 276px;
não ampliar o componente Turno nem o Atenção ao ajustar os menus.
Não reaplicar tamanho do contexto depois de showPopup nem usar gui.Control
para misturar largura de conteúdo e janela. A skill registra as regras de
fechamento individual e de redução automática das cargas da Atenção.
Na 4.2, o progresso de 3 segundos ocupa o intervalo de 196 × 2px abaixo do
nome, com dois retângulos sem hitTest. Só a largura do preenchimento muda;
cartão/lista/posição permanecem iguais. O observador usa um timer: 50ms ativo,
1000ms sem cargas. Recalcular linhas na virada do ciclo/refresh de 1 segundo,
nunca por frame. Clique adicional não reinicia a barra, e fechar remove o timer.
O usuário confirmou a 4.1 funcionando; a barra da 4.2 aguarda seu teste visual.
Na 4.3, a lista da Atenção mostra `nick - jogador`: apelido da mesa (ou o nick
personalizado salvo) seguido do login real. O campo Nick edita só o apelido.
Consultar os participantes uma vez por render e incluir o nome apresentado
na assinatura; não alterar o getPlayerDisplayName geral, que atende ao tracker.
Guardar jogadorLogin na própria solicitação para manter a identificação offline.
Remover códigos de formatação dos nomes antes de apresentá-los em Label simples.
O SDK não expõe a lista interna de entradas do chat original, incluindo comandos
que não geraram mensagens. Não afirmar acesso a esse histórico completo.
Compilar não confirma desempenho real, fidelidade visual ou sincronização.

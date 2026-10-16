# Chat Avançado — newTracker 4.3

Versão 4.3 preparada em 15/10/2026. A lista da Atenção passa a mostrar
`nick - jogador`: apelido da mesa ou nick personalizado, seguido do login real.
O campo Nick altera só o apelido, e a solicitação guarda o login para conservar
a identificação mesmo após a saída do jogador. Aguarda teste manual.

A versão 4.2 foi preparada em 15/10/2026. O usuário confirmou que a 4.1 funcionou e
pediu uma barra de progresso animada para os três segundos da Atenção. A barra
foi acrescentada abaixo do nome, no intervalo já existente, sem redimensionar
a janela. A animação acompanha o mesmo ciclo das cargas e aguarda teste manual.

A versão 4.1 foi preparada em 15/10/2026. A imagem enviada pelo usuário aponta erro
`Unknown property: "NoImageURL"` em `trackerChatView.lua:436`, na criação de
mensagens. A configuração `URLWhileLoading` introduzida na 4.0 chama esse setter
nativo pelo SDK, mas o cliente do usuário não o aceita. A 4.1 remove a
atribuição e conserva `showProgress=false`, o recorte e a escolha dos avatares.
O usuário confirmou o funcionamento após essa correção; o SDK empacotado não
foi alterado.

A versão 4.0 foi preparada em 14/10/2026. O usuário confirmou a abertura e o uso do
chat 3.0 e relatou cortes de texto e recarga ao alternar abas. O dock da versão
3.1 foi usado, mas a imagem enviada pelo usuário mostrou nomes cortados,
barras de rolagem nos nomes, intervalos excessivos e propriedades internas
aparecendo como mensagens. A 3.2 corrige esses caminhos de apresentação; seu
resultado visual foi mostrado na nova imagem, mas o usuário relatou lag e foto
ausente em mensagens de jogador já desconectado. A 3.3 reduz processamento e
atualizações repetidas e conserva avatares conhecidos. A mesma entrega também
adota o layout do chat original a partir da imagem: grupos por autor, avatares
circulares, data junto ao nome, separadores e compositor com ícones e
personificação. O usuário confirmou que a 3.3 melhorou bastante. A 3.4 remove
o seletor de conversas, compacta os botões, melhora o espaço de escrita e alinha
o horário de cada mensagem. Acrescenta popup de montagem de dados e recuperação
de mensagens próprias com F3/↑. O usuário usou o menu da 3.4 e relatou que os
modificadores não funcionavam. A 3.5 troca combos por botões ativos, usa ícones
de dados, fecha ao clicar fora e reinicia a montagem em cada abertura. Corrige
os eventos de edição e permite acumular bônus/penalidades. O usuário relatou
erro ao rolar com vantagem na 3.5. A 3.6 encerra o menu antes de rolar e adia sua
destruição até terminar o fechamento nativo; protege a sequência assíncrona e
padroniza horários e descrição ao lado do resultado. O usuário enviou a imagem
da mesma asserção ao rolar 1d20; o pacote instalado foi identificado como 3.6.
A 3.7 conserva o menu nativo durante a vida do compositor, reinicia seus campos
a cada abertura e acrescenta Enter para rolar. O usuário relatou que o aviso
“Digite uma mensagem...” continuava sobre o texto digitado. A 3.8 oculta o
aviso ao focar a escrita e o mostra somente com campo vazio e sem foco,
sem depender do momento em que onChange é disparado. O usuário pediu uma
distribuição melhor dos botões. A 3.9 separa navegação e escrita: Fixados,
Histórico, Última e Permissões ficam acima das mensagens; formatação, anexos
e dados ficam na escrita, em até duas linhas conforme a largura. Enviar fica
à direita. A 4.0 amplia os contextos do tracker, move Fixar para o contexto do
item e remove seu botão Chat. Ajusta o recorte dos avatares e prioriza a ficha
principal atual antes da foto do usuário. F3 volta e F4 avança; fórmulas de
rolagens personalizadas entram no histórico como `/r fórmula`. O aviso de
digitação reaparece sempre que o editor está vazio. Atenção perde cargas a
cada três segundos e pode ser fechada localmente, com reabertura explícita
pelo chat. As alterações aguardam teste manual.
Validação por leitura estática e
compilação com o Firecast Development Kit 3.7b. **O Firecast não foi aberto,
o pacote não foi instalado e os testes da aplicação não foram executados.**

## Uso

Adicione **Chat Avançado** pelo menu de janelas acopláveis da mesa. O formulário
agora está registrado como `tablesDock`, com o dataType próprio e estável
`br.com.rafilkl.newTracker.chat`. A abertura é feita pela interface nativa do
Firecast. O atalho do chat nativo foca uma instância já aberta; caso ela ainda
não exista, mostra como adicioná-la. O botão Chat do tracker foi removido.
Não cria um
popup substituto.

O dock mostra **somente o chat da mesa**, sem combobox de conversas. Privados
e canais são recusados pela captura. Uma faixa compacta acima das mensagens
reúne **Fixados, Histórico, Última e Permissões**, alinhados à direita, com
ícones e títulos, além de **Pedir atenção** e **Abrir atenção**. A partir de
448px os quatro primeiros mostram títulos; a partir de 632px, todos mostram.
Em larguras menores, ficam ícones com dicas. **Última** usa seta para baixo.
A barra de escrita agrupa formatação, anexos/ações e dados, com
botões de 24px e intervalos entre grupos. Os dados passam juntos à segunda
linha quando cabe o grupo inteiro; a área de escrita cresce 26px para manter
o espaço de digitação. Enviar e **⋯** ocupam o canto direito da última linha.
Em docks muito estreitos, ações secundárias e ícones excedentes continuam
acessíveis no menu **⋯**, que também oferece os seis atalhos do chat.
Uma rolagem escolhida pelo menu usa a barra visível como âncora se seu ícone
estiver oculto. Essa organização não abre nem fecha conversas ou recarrega o
histórico ao redimensionar. A primeira
visualização monta até 100 mensagens visíveis recentes e rola até a última,
sem criar controles para todo o histórico local. **Histórico** revela mais 50
mensagens anteriores já em cache; quando elas acabam, busca mais 50 registros
no servidor, sem mover você novamente para o fim;
**Última** volta à mensagem mais recente e retoma seu acompanhamento. Ao trocar
abas da mesa, a sessão, os nós da lista, as páginas carregadas e a
posição de leitura são conservados. Novas mensagens são combinadas sem duplicar
seus IDs nativos. Somente o botão Histórico solicita mais páginas antigas.
O histórico completo continua no cache; a faixa aberta cresce com novas
mensagens e com o botão Histórico, sem retirar linhas durante a leitura.

O cache de mensagens e o estado visual das listas ficam em NDBs
**somente em memória**, separados do NDB público do dock. Fechar todos os
componentes desliga listeners/timers e conserva páginas de até quatro mesas
na memória do plugin, identificadas pelo usuário, para reaproveitar ao reabrir.

O campo principal envia ao chat original. **Enter**, Ctrl+Enter ou **➤** envia;
Shift+Enter quebra a linha. O rascunho permanece até a confirmação do servidor.
A linha **Personificar** tem Ninguém (F5), Narrador (F6) e NPC (F7), com nome
do NPC no campo ao lado. O ícone de ação alterna o envio como ação. As
permissões de narração continuam sendo verificadas pelo Firecast.
Comandos começando com `/` passam pelo interpretador original.

O aviso **Digite uma mensagem...** é um label sem interação nem foco sobre o
editor multilinha. Fica oculto quando há texto e reaparece vazio, inclusive
enquanto o editor tem foco ou após enviar a mensagem. Rascunhos, anexos e
histórico também atualizam essa regra. Uma atualização reunida após os eventos
de teclado/alteração lê o texto já atualizado, sem consultas periódicas.

Negrito, itálico, sublinhado e cor definem a formatação da mensagem inteira,
usando TalemarkOptions nativo. A formatação acompanha o rascunho de cada
mesa. Anexos oferecem imagem, arquivo e link; o arquivo é enviado ao
FireDrive e seu link é colocado no rascunho, sem publicação automática.
Os ícones d4, d6, d8, d10, d12, d20 e d100 da barra **abrem uma nova montagem**
com um dado do tipo clicado. Cada abertura reinicia dados, modificadores, modo
Normal e ordem Original. O menu é contextual ao ícone, acima da barra; clicar
fora ou pressionar Esc o fecha. Não tem botão Fechar e não conserva a montagem
anterior. A descrição inicialmente aproveita o texto atual do campo do chat.
Uma única instância de popup é reutilizada por compositor, sem destruir os
controles quando o menu fecha. Isso permite à animação nativa terminar sobre
controles vivos. Reabrir ainda limpa a montagem, incluindo seleção e campos.

Dentro do menu, clicar nos **ícones de dados** acumula dados. A lista mostra
ícone, quantidade editável e botões −/+/× para diminuir, aumentar ou remover
cada grupo. dF e faces personalizadas também ficam disponíveis no próprio menu.
O campo **Modificadores** aceita `+5-3+10` e mostra `Total: +12`; cada termo
acompanha a expressão enviada. O campo Expressão permite também sintaxe nativa
personalizada; os modificadores são acrescentados a ela. Entradas incompletas
ou inválidas impedem o envio e não viram zero silenciosamente.
**Vai rolar** apresenta a expressão completa, com dados e modificadores, antes
do envio. **Rolar** ou **Enter**, com o menu aberto, fecha o menu e envia essa
prévia ao Firecast depois do evento nativo de fechamento. O atalho funciona
nos campos de quantidade, modificadores, expressão e descrição e nos botões;
a tecla é consumida para não enviar uma mensagem pelo compositor ou rolar
duas vezes. Abrir o menu dá foco ao campo de modificadores. **Espaço** mantém a
ação do botão de dados/opção que estiver focado. Clicar num dado não rola
imediatamente. **Zerar** limpa a montagem e restaura as opções iniciais.

Modo e ordem usam **botões com destaque da opção ativa**, com uma seleção por
grupo, sem comboboxes. **Normal** executa a expressão uma vez via `asyncRoll`. **Vantagem** e
**Desvantagem** executam a expressão inteira duas vezes no servidor, publicam
ambas as rolagens com identificação 1/2 e 2/2 e publicam um resumo com o
maior/menor total. Isso também funciona com dados mistos. Se a segunda falhar,
a primeira permanece publicada e não é repetida automaticamente. A sequência
inteira é acompanhada por uma execução Async, incluindo falhas ao processar a
confirmação ou publicar o resumo. A sessão aceita uma operação de cada vez;
reabrir o menu durante a operação não permite iniciar uma segunda sequência.
**Original/Crescente/Decrescente** ordena a apresentação dos valores dentro de
cada grupo de dados neste cliente, em memória por mesa/usuário. Não altera o
registro original ou o total; os outros clientes recebem o registro nativo.
A ordenação local é conservada ao reabrir o dock durante a sessão do plugin.

Descrição e rolagem aparecem juntas: `Ataque — 2d6 + 3 = 10 {[2, 5] + 3}`.
O texto quebra com a largura disponível; descrições não ocupam uma linha
separada por padrão. Descrições ricas continuam usando Talemark nativo e as
notas ficam abaixo. Os resultados usam o formato do Firecast, com
expressão, total destacado e valores individuais. O total vem do servidor,
inclusive em operações especiais; não é recalculado a partir dos dados.
As correções aditivas compatíveis aparecem na expressão e nos detalhes, sem
rolar novamente e sem uma segunda linha redundante de Resultado.

**F3** volta para entradas mais antigas, até o limite de 200. Para no fim,
sem circular. **F4** avança para entradas mais recentes e depois restaura o
rascunho anterior. **↑** inicia o mesmo histórico se o campo estiver
vazio; enquanto o texto ainda for uma entrada recuperada, continua percorrendo.
**↓** volta para entradas mais recentes e recupera o rascunho anterior. Editar
o texto encerra a navegação. As entradas incluem mensagens próprias disponíveis
no log da mesa, enviadas pelo chat original ou pelo novo, além de mensagens e
comandos digitados neste componente. O login real determina a autoria, inclusive
NPC/narrador; notificações automáticas de turno não entram. O histórico de
entradas do componente é conservado em memória ao reabrir o dock. A primeira
confirmação de cada rolagem personalizada acrescenta `/r expressão`, inclusive
dados mistos e modificadores. Vantagem/desvantagem acrescentam uma entrada por
operação. A entrada recuperada representa a fórmula; descrição, vantagem e
ordenação do popup não são recuperadas por esse comando. Enviá-lo usa o
interpretador original, sem criar resultados locais ou executar ao navegar.
O SDK público **não expõe a lista interna de entradas do Firecast**: comandos
digitados no chat original que não produziram mensagem, rascunhos e envios
nativos com falha não podem ser recuperados por esse caminho.

**Pedir atenção** acrescenta uma carga sem abrir a janela. **Abrir atenção**
reabre a lista. O Tracker da iniciativa precisa ter sido aberto nesta mesa para
fornecer o banco correto; o node público do chat nunca é usado como iniciativa.
O botão **×** no Atenção fecha somente neste cliente e conserva a preferência
por usuário/mesa entre reinícios. Solicitações recebidas não reabrem a janela.
Somente Abrir atenção desfaz essa preferência. A lista reaberta explicitamente
mantém seu observador mesmo depois de fechar o Tracker.

Na lista, o formato é **nick - jogador**, por exemplo `SaSa - LaliHo`.
O padrão usa o apelido da mesa, sem códigos de formatação. O campo **Nick** e
**Salvar** personalizam somente a parte à esquerda; o login do jogador é
acrescentado automaticamente. Solicitações novas e reutilizadas conservam esse
login para exibição após a desconexão. Nomes antigos de participantes online
também são apresentados no novo formato ao abrir, sem alterar suas cargas.

Cada clique soma uma carga ao saldo válido. A cada três segundos do ciclo,
todos os participantes perdem uma carga, até zero; pedir novamente não adia o
ciclo. A primeira solicitação após a lista esvaziar inicia um ciclo novo. O
saldo é calculado pelo horário do servidor, sem múltiplos clientes descontarem
a mesma carga. Entradas zeradas deixam de aparecer e conservam o nome salvo.
Decaimento e novos pedidos não alteram tamanho nem posição da janela.

Uma barra fina dourada abaixo do nome preenche ao longo dos três segundos e
recomeça quando as cargas diminuem. Ela desaparece ao zerar a lista e retoma
o ponto atual do ciclo ao reabrir a janela; novos cliques não reiniciam a barra.
O preenchimento usa retângulos já suportados e compartilha o observador da
janela: intervalo de 50ms com cargas e 1 segundo em repouso, sem timer por linha
ou escritas no banco a cada frame. Fechar interrompe a animação e o observador.

O botão de áudio escolhe e envia **um arquivo de áudio**: o SDK público não
expõe captura do microfone. A barra foi reconstruída com controles públicos;
não é a interface interna do Firecast embutida. O SDK também não exporta
Talemark a partir do conteúdo formatado de RichEdit; por isso a barra envia
estilos da mensagem, evitando perder a formatação ao extrair texto simples.

- `/>>`: passa o turno pelo sistema existente de iniciativa. O Tracker da
  iniciativa precisa estar aberto nesta mesa (sua aba pode estar oculta).
  Jogadores continuam limitados ao próprio turno ou ao de ficha compartilhada.
- `/fixados`: abre o painel independente de mensagens fixadas da mesa.

Esses comandos são interceptados diretamente no Chat Avançado antes do envio,
inclusive em contas gratuitas. Também foram registrados no interpretador do
chat original e em `/help`; esses eventos nativos dependem da assinatura do
Firecast. Os comandos não publicam uma mensagem no chat.

Clique com o botão direito na mensagem para fixar, adicionar observação,
copiar, visualizar o original e abrir seu histórico. Nas rolagens compatíveis,
o menu também permite corrigir, editar e desfazer correções. Informe um
modificador positivo ou negativo e um motivo. **Detalhes** mostra o resultado
original, o modificador total, o resultado apresentado e o histórico com
autor, data e motivos, inclusive os valores anteriores de uma edição.

As correções são visuais: não alteram o registro no chat original nem sorteiam
dados novamente. A representação usa os resultados individuais registrados
pelo SDK. Comparações, Storyteller e operações desconhecidas ficam sem a opção
de correção aditiva. Correções particulares se somam às compartilhadas somente
na visualização de quem as criou.

Escolha **particular** ou **compartilhada** ao fixar, corrigir ou anotar mensagens
públicas. Em privados ou mensagens com destinatários restritos/blacklist, estas
alterações ficam **somente particulares**: seu conteúdo não é enviado à mesa.
Uma mensagem pode ter várias observações, cada uma com autor e horário.

**Fixados** abre um painel independente, com rolagem, botão para desafixar e
controles para minimizar/expandir. Ele permanece aberto ao fechar o chat ou o
tracker. O painel é único por mesa e a captura é compartilhada pelas instâncias
do dock. Ocultar uma aba não destrói o chat nem o painel. As mensagens e
resultados corrigidos usam o mesmo renderizador. Nomes e notificações usam
labels em flowLayout, preservando cores dentro do apelido e quebra nativa.
Mensagens consecutivas do mesmo autor/personificação, em até cinco minutos,
compartilham cabeçalho e avatar, mantendo nós e menus individuais. Cada mensagem,
inclusive continuação, tem horário alinhado numa coluna fixa à direita. O
horário mostra também a data quando há largura, em todas as mensagens/rolagens,
inclusive continuações. Em docks estreitos aparece HH:MM, com data completa
no hint. Eventos mostram [HH:MM] à esquerda. O espaço do retrato
fica alinhado nas continuações; fotos usam máscara vetorial circular.

## Permissões e sincronização

Por padrão, jogadores corrigem suas próprias rolagens, identificadas pelo
**login real** de `LogRec.entity`, mesmo quando o nome exibido é de NPC ou
narrador. Mestres corrigem qualquer rolagem visível. Uma correção só pode ser
editada ou desfeita por seu criador ou por um mestre.

Em **Permissões**, o mestre pode permitir correções de terceiros e escolher
quem cria ou remove fixações compartilhadas. O padrão permite que jogadores
criem fixações e que o criador ou os mestres as removam. As anotações públicas
ficam disponíveis aos participantes da mesa.

Alterações compartilhadas precisam de pelo menos um mestre com o tracker,
Chat Avançado ou painel de fixados aberto. A descoberta desses mestres usa
presença autenticada por broadcast; entre os ativos, um deles processa os
pedidos. Há um pequeno intervalo inicial de conexão. O processador confirma a
mensagem original por seus IDs e revalida a permissão antes de salvar. Pedidos
têm identificação, tentativas, resposta e limite de espera de 18 segundos.

Metadados públicos ficam na **nova branch `chatAdvanced`**, com ACL própria e
escrita dos mestres. Não foi concedida escrita aos jogadores na raiz do
tracker, nos itens ou nas fichas. Quando disponível, um Room NDB separado
`newTracker.chatAdvanced.v1` espelha estes dados e pode recuperá-los caso a
branch precise ser recriada. O dock independente usa esse Room NDB quando
disponível. Os pedidos são recebidos nos dois bancos, com deduplicação, e a
réplica mais recente é preservada ao abrir o Tracker posteriormente. Sem acesso
a Room NDB, abra o Tracker em cada cliente que usará funções compartilhadas;
particulares e leitura do chat continuam independentes. Para recuperar dados
da 3.0 existentes somente na branch antiga, abra o Tracker uma vez na mesa.

Dados particulares ficam num arquivo do HD virtual identificado por usuário e
mesa. O User Room NDB, quando disponível, oferece uma cópia no servidor. Ao
abrir, a versão mais recente de cada mensagem é combinada com a cópia local.
O arquivo é fechado após gravar. Remover os dados locais do plugin pode apagar
a cópia particular quando não houver cópia no servidor.

## Compatibilidade e limites

- `ChatMessageEx` e o evento legado dependem da assinatura. Uma leitura de
  `readLogRecs()` a cada 1,5 segundo oferece a alternativa oficial para
  mensagens já carregadas pelo cliente. O histórico do servidor é consultado
  por Promise; falhas são apresentadas sem esconder o histórico local.
  Registros iguais são comparados com snapshots da origem antes de normalizar;
  exclusões, conteúdo e visibilidade alterados no mesmo objeto continuam sendo
  detectados. Ordenação e estado dos metadados são reutilizados até mudarem.
  Atualizações de presença sem mensagem não repintam a conversa.
- O atalho na barra do chat nativo também depende da assinatura. O acesso ao
  dock é pelo menu nativo de janelas acopláveis. O SDK não expõe um método
  público para criar/selecionar essa aba por Lua; o foco de teclado não garante
  que o Firecast selecione uma aba oculta.
- A renderização usa labels com wordWrap/autoSize para cabeçalhos e corpos
  simples. Talemark com formatação, imagens ou links continua em RichEdit nativo
  quando a versão oferece essa API; a alternativa é texto somente leitura.
  A altura de RichEdit permanece estimada: o SDK não expõe sua altura de
  conteúdo ou uma opção de esconder a barra de rolagem. Avatares históricos sem
  avatar de impersonação usam primeiro a foto da ficha principal atual do
  jogador (personagemPrincipal) e depois a foto do usuário, pelo login/ID real.
  URLs vazias e placeholders de foto não bloqueiam essa alternativa.
  O cadastro de fotos é atualizado a cada 5 segundos e mantém URLs observadas
  após o jogador sair; fotos recebidas no registro ou já presentes em snapshots
  também são aproveitadas. O SDK não oferece consulta pública de foto para
  jogadores offline nunca observados e sem URL conhecida.
  Não existe acesso ao código completo da interface interna: tema, espaçamento
  e detalhes de renderização precisam de comparação visual no Firecast.
- Arquivos exibem nome e URL; o envio de anexos continua na interface nativa.
  O dock acompanha somente o chat principal da mesa; privados e canais
  continuam na interface original. Comandos e erros assíncronos do interpretador podem ser
  apresentados pelo chat nativo.
- Mensagens locais sem IDs de servidor recebem chave somente local para a
  interface/fixação particular. Não sustentam alterações compartilhadas.
  Registros invisíveis, sinais e digitação não são apresentados. Propriedades
  desconhecidas são omitidas somente da lista visual; registros/IDs permanecem
  no cache para paginação. Entrada/saída, mudanças conhecidas de modos e valores
  de barras recebem texto humano, com cores e aritmética. Os títulos configurados
  das barras não são expostos pelo SDK; aparecem como Barra 1–4.
  Notificações têm corpo e horário uma vez, sem um segundo cabeçalho do ator.
  Valores internos de tabelas não viram texto de mensagem. Exclusões ou
  mudanças de visibilidade recebidas pela captura removem os snapshots e
  anotações associados que não podem mais ser exibidos.
- As linhas do chat crescem com o texto, sem o limite fixo de altura do
  visualizador anterior. Nos fixados, textos simples longos crescem dentro da
  lista com rolagem; conteúdos ricos usam uma área de até 160px com rolagem
  interna. O painel mantém a altura fixa.
  Reajustes nativos de texto são reunidos em um agendamento por lista/painel;
  propriedades inalteradas não são reescritas. A rolagem ao fim também é
  reunida e respeita a pausa de leitura. Conversas ocultas guardam seu estado
  sem recalcular todas as linhas. As cópias do armazenamento ocorrem somente
  quando a mensagem realmente possui metadados.
  Os limites de metadados são 2000 mensagens, 256 correções e 1024 eventos de
  histórico por mensagem, e 2 MiB serializados por armazenamento. Ao atingir
  um limite, a alteração é recusada com mensagem; o histórico não é cortado.
- O painel usa cartão de 360×420 px e margem nativa de 2 px; minimizado fica
  com 32 px de altura. Atualizações de conteúdo não redimensionam a janela.
  Não foi introduzida restauração de coordenadas ou modificado o comportamento
  de posição dos popups de Turno e Atenção.

## Arquivos

| Arquivo | Responsabilidade |
| --- | --- |
| `trackerChat.lua` | Sessões, listeners, leitura/paginação, envio, menus e integração |
| `trackerChatModel.lua` | IDs, visibilidade, UTC, autoria, snapshots e dados registrados |
| `trackerChatStore.lua` | Persistência, permissões, pedidos autenticados e auditoria |
| `trackerChatView.lua` | Grupos visuais, renderizador e controle da janela principal |
| `trackerChatInline.lua` | Apelidos e notificações com cores e altura nativa |
| `trackerChatComposer.lua` | Barra de escrita, anexos, histórico de entrada e personificação |
| `trackerChatDice.lua` | Menu contextual de montagem, modificadores acumulados e botões ativos |
| `trackerChatDiceIcons.lua` | Vetores de dados compartilhados entre barra e menu |
| `trackerChatView.lfm` | Estrutura do dock da mesa, lista e área de escrita |
| `trackerChatMessage.lfm` | Painel de mensagem com altura adaptável na lista nativa |
| `trackerChatCommands.lua` | `/>>`, `/fixados` e ajuda, com listeners únicos |
| `trackerChatFloating.lua` | Painel independente de fixados, com receita isolada de popup |
| `newTracker-chat.svg`, `newTracker-chat.png` | Fonte vetorial e ícone PNG do atalho nativo |
| `newTracker.lfm` | Attach/detach do chat; botão Chat removido na 4.0 |
| `trackerMain.lua` | Contextos ampliados e ciclo/fechamento local da Atenção |
| `trackerMenu.lua`, `trackerItemMenu.lfm` | Contexto de 280px com fixar/desafixar posição |
| `trackerWindowPositions.lua` | Preferência individual attentionClosed, sem reativar posições |
| `module.xml` | Versão 4.3 |
| `AGENTS.md` | Referência visível para manutenção deste recurso |
| `output/newTracker.rpk` | Pacote compilado para teste manual |

A 4.0 altera o contexto do timer e o ciclo/fechamento da Atenção por pedido do
usuário. A geometria dos componentes Turno/Atenção e a restauração de posições
continuam conforme a skill. Alterações anteriores do workspace foram preservadas.

## Roteiro de testes manuais — pendente

Use mestre e jogador em clientes distintos, ambos com a versão 4.3. Estes
passos **não foram executados** no ambiente de desenvolvimento.

| Caso | Procedimento e resultado esperado |
| --- | --- |
| 1. Histórico | Abrir Chat; comparar ordem, horários locais, nicks formatados, NPC, narrador, ações, texto, links e avatares. Usar Histórico várias vezes; nenhum ID duplicado. |
| 2. Tempo real | Enviar pelo chat original e pelo novo em ambos os clientes. Ver uma ocorrência em cada interface. Repetir em conta sem os eventos Premium; a leitura local deve atualizar a janela. |
| 3. Dados | Rolar `2d6 + 1d20 - 3`; comparar cada dado, expressão e total com o original. Usar rolagem especial/Storyteller; ela deve ser exibida e ficar sem correção aditiva. |
| 4. Correção própria | Jogador acrescenta `+2` e motivo à própria rolagem pública, em modo compartilhado. Todos veem a soma original+2; o chat original e os dados individuais permanecem iguais. |
| 5. Mestre | Corrigir a mesma rolagem como mestre com `-1`; verificar autoria e horário na auditoria e atualização em ambos os clientes. |
| 6. Terceiros | Jogador tenta corrigir rolagem alheia com a configuração padrão. Bloqueada. Mestre habilita terceiros: permitida. Outro jogador não deve editar/desfazer correção que não criou. |
| 7. Histórico de correções | Aplicar `+2`, `-3` e `+5`, editar uma delas e desfazer outra. Conferir total, detalhes e os valores/motivos anteriores. Desfazer todas deve retirar Corrigida. |
| 8. Fixados | Fixar rolagem particular e compartilhada, acrescentar correção e observação. Conferir atualizações no painel, desafixar individualmente e rolar a lista. Fechar chat e tracker: painel continua. |
| 9. Persistência | Criar dados particulares e compartilhados; reiniciar/reinstalar preservando dados. Reabrir Chat/Fixados e conferir conteúdo. Repetir com User Room NDB indisponível para exercitar a cópia local. |
| 10. Sincronização | Alterar simultaneamente em mestre/jogador e observar resposta, dedup e auditoria. Fechar o último cliente de mestre: operação compartilhada deve informar indisponibilidade; particulares funcionam. Reabrir e tentar novamente. Repetir com dois mestres ativos. |
| 11. Abas e ciclo | Abrir outras abas do tracker e acionar Chat/Fixados repetidamente. Deve existir uma janela de cada por mesa e apenas uma captura global. Fechar tudo, reabrir e conferir que listeners/timers antigos não atuam. |
| 12. Regressão | Usar iniciativa individual, rerrolagem, próximo turno do jogador autorizado, cronômetro normal/compacto, grupos, menus e solicitações de atenção entre clientes. Arrastar Turno/Atenção, clicar e conferir que a geometria/ciclo anteriores foram preservados. |

Para a 3.3, conferir ainda: adicionar o dock Chat Avançado pelo menu nativo;
estreitar/expandir o dock e comparar nomes longos, horários, descrições,
observações, mensagens com várias linhas e Talemark com imagens/títulos; abrir
com o histórico mostrando a última mensagem; usar Histórico e alternar abas
sem nova consulta nem retorno ao fim; usar Última; executar `/>>` como mestre,
jogador autorizado e jogador sem permissão; executar `/fixados` em conta
gratuita pelo Chat Avançado e no chat nativo em uma conta com o evento disponível.

Comparar com a imagem do chat original: mensagens agrupadas por autor, fotos
circulares, cores dentro do apelido, horários alinhados por mensagem, separadores e barra
de escrita compacta. Notificações conhecidas de entrada/saída, barras e modos
devem ser humanas, sem mainCharBar*, tabelas ou endereços internos. Conferir
texto simples com altura proporcional, inclusive após estreitar
o dock. Conferir mensagens ricas com títulos/imagens e fixados com texto longo.
Labels recalculam a linha após o layout nativo; esse ajuste mantém a última
mensagem à vista apenas enquanto o acompanhamento estiver ativo.

Desempenho: abrir uma mesa com histórico extenso, digitar, receber mensagens,
rolar, trocar abas e abrir fixados. Conferir que a montagem inicial fica nas
100 mensagens visíveis recentes e que Histórico revela as anteriores do cache
sem baixar de novo. Verificar fotos do personagem/narrador, fallback do jogador
com foto vazia e após sair da mesa, mudança da foto enquanto conectado e
atualização dos fixados. Não houve medição de FPS/tempo ou teste da aplicação.
Conferir ainda Enter/Shift+Enter, F5/F6/F7, nome de NPC, B/I/U/cor em toda a
mensagem, popup de dados e expressão personalizada, uploads no rascunho e
cancelamento de arquivo. Fechar/reabrir o dock durante upload/picker e verificar
que o retorno não altera um rascunho de outra instância/mesa.

Acrescente a verificação de privacidade: envie PVT e mensagem de destinatários
restritos. Fixações, observações e correções dessas mensagens devem oferecer
apenas modo particular, sem dados no painel de outro usuário. Compare exclusão
de uma mensagem pública fixada e confirme a retirada de seu snapshot.

Para a 3.4, conferir os atalhos em dock largo/estreito e a área de escrita
multilinha; comparar horários em cabeçalhos, continuações, rolagens e eventos.
Montar `2d6 + 1d20 - 3` pelos botões, aumentar/remover grupos, editar expressão,
usar faces personalizadas/dF e limpar a montagem. Conferir
normal, vantagem e desvantagem nos dois clientes; comparar os resultados
individuais e o resumo com o chat original. Ordenar crescente/decrescente sem
mudar o total. Conferir erro de expressão, modo NPC sem nome, falta de permissão
para rolar e falha parcial da segunda execução. Recuperar com F3 mensagens
próprias enviadas no chat original; testar ↑ vazio, ↑ com texto escrito, ↓ para
restaurar rascunho, NPC/narrador, comandos digitados neste componente e recusa de
mensagens de outros usuários. Este roteiro não foi executado no Firecast.

Para a 3.5, abrir por um ícone da barra, acumular dados pelos ícones internos,
digitar quantidades e `+5-3+10` (total +12), conferir a expressão da prévia e
o registro original do servidor. Repetir com modificador negativo, zero,
campo vazio, sequência incompleta e uma expressão personalizada. Selecionar
Modo/Ordem e conferir um único botão ativo em cada grupo. Clicar fora ou usar
Esc; abrir por outro dado e conferir montagem nova, sem dados/modificadores
anteriores. Verificar o fechamento durante uma rolagem pendente: a resposta
do servidor não deve tentar atualizar controles destruídos. Compilação e
revisão não confirmam esses comportamentos na aplicação.

Para a 3.6, conferir vantagem/desvantagem em mestre e jogador, com e sem
descrição; o menu deve fechar antes do envio e os dois registros devem usar os
totais confirmados, seguidos do resumo. Conferir cancelamento, reabertura durante
uma sequência, falta de permissão e falha parcial, sem repetir dados já enviados.
Comparar a mesma formatação e coluna de horário em mensagens, rolagens,
cabeçalhos e continuações; estreitar o dock. Conferir descrição ao lado de
expressão/total, descrição longa/formatada, cores, observações e fixados.

O log local de 14/10/2026 13:37:57 registrou uma asserção no fechamento nativo,
em `TRectPopupLock.TornarInvisivel`. O usuário depois enviou a imagem da asserção
em `LUAFireMonkeyControls.Globals.pas:631`, com 1d20. O pacote instalado foi
identificado como 3.6; o log de 14:08:01 contém a mesma falha e uma chamada de
`FMX.Anima.ProcessarAnimacoes`. A destruição adiada por 1ms foi insuficiente.
A 3.7 mantém a instância viva e reutiliza seus controles até destruir o
compositor, sem destroy no fechamento, e usa fundo com opacidade 0.12.
Ainda precisa de teste manual; essa leitura não reproduziu a aplicação.

Para a 3.7, abrir d20 e pressionar Enter diretamente, nos modificadores, na
quantidade, na expressão, na descrição e em botões de dados/modo/ordem. Conferir
uma única rolagem, sem mensagem duplicada do campo do chat. Repetir com vantagem,
desvantagem, `+5-3+10`, expressão incompleta e cliques em Rolar. Cancelar por fora
e Esc, reabrir e conferir montagem zerada. Repetir aberturas/fechamentos rápidos
e conferir ausência da asserção 631 durante a animação. Fora do menu, Enter
continua enviando mensagens e Shift+Enter continua quebrando linhas.

Para a 3.8, conferir que o aviso desaparece ao focar o campo; digitar e colar
texto, apagar tudo e sair do campo. Deve reaparecer somente vazio e sem foco.
Recuperar mensagem com F3/↑ e restaurar rascunho: o aviso não deve cobrir texto.
Após enviar, manter o campo focado vazio sem aviso. Este roteiro fica para o
teste manual do usuário; somente revisão estática e compilação foram realizadas.

Para a 3.9, conferir a faixa superior com Fixados/Histórico/Última/Permissões,
seus cliques e dicas. Estreitar e ampliar o dock: títulos viram ícones, os
grupos da escrita não se sobrepõem e os dados passam para a segunda linha
quando necessário. A digitação deve conservar a mesma altura disponível e
Enviar deve permanecer à direita. Conferir ações secundárias e dados ocultos
pelo menu ⋯, abertura de rolagem a partir do menu, F3/↑, Enter/Shift+Enter e
personificação. Redimensionar não deve recarregar mensagens nem perder o
rascunho. Este roteiro não foi executado na aplicação.

Para a 4.0, conferir F3/F4 com rascunho, ↑/↓ e edição de entrada recuperada;
rolagens personalizadas confirmadas devem aparecer como /r fórmula apenas uma
vez, inclusive vantagem. A navegação não deve executar nem publicar mensagens.
Apagar ou enviar texto deve restaurar o placeholder mesmo com foco; digitar e
colar devem ocultá-lo. Conferir a seta para baixo de Última.

Conferir avatar da personificação, ficha principal com foto, ficha sem foto,
usuário sem foto, troca da ficha principal, jogador desconectado e fixados.
Comparar moldura/cantos durante o carregamento e após a imagem abrir.
Abrir os contextos de item, grupo, barra e timer; os textos devem caber.
Fixar/desafixar pelo contexto deve conservar a ordenação e ser exclusivo de
mestre. O botão Chat e o botão de fixação da linha não devem aparecer.

Em dois clientes, acumular cargas da Atenção para vários jogadores; todas
devem perder uma carga a cada três segundos do ciclo, sem desconto duplicado.
Esperar zerar, pedir novamente e conferir que cargas antigas não reaparecem.
Fechar a janela em um cliente, pedir atenção no outro e pelo chat fechado:
ela deve continuar fechada somente naquele cliente. Reabrir pelo chat,
reiniciar/reinstalar preservando os dados e conferir a preferência. Conferir
troca de mesa, arraste, tamanho fixo, digitação do nome e lista com rolagem.
Nenhum desses passos foi executado no Firecast.

Para a 4.1, abrir o chat com mensagens já existentes e receber novas mensagens;
conferir também os fixados, que usam o mesmo renderizador. A criação das linhas
não deve mais chamar o setter NoImageURL. Conferir avatar da ficha, alternativa
do usuário e recorte circular. Somente revisão estática e compilação foram
realizadas; este roteiro permanece para o usuário no Firecast.

Para a 4.2, acumular cargas e conferir a barra preenchendo a cada três segundos,
com a redução das contagens na virada. Pedir mais atenção durante o ciclo não
deve reiniciá-la. Ao zerar/limpar, a barra desaparece; reabrir com cargas retoma
o ponto atual, sem reiniciar a contagem. Conferir arraste e fechamento enquanto
anima e comparar tamanho/posição antes e depois. Nenhum teste de aplicação foi
executado pelo desenvolvimento.

Para a 4.3, pedir atenção em mestre e jogador e conferir `apelido - login`.
Salvar um nick personalizado: o login deve continuar ao lado, e o campo deve
conter só o apelido. Conferir entrada anterior, alteração do apelido da mesa,
nome com formatação e jogador desconectado após pedir atenção nesta versão.
Barra, cargas, arraste e fechamento devem conservar o comportamento anterior.
Este roteiro não foi executado no Firecast.

## Referências oficiais examinadas

Os módulos foram escritos a partir dos contratos do SDK e dos padrões do
projeto, sem copiar implementações internas do Firecast. A lógica de detalhar
os resultados registrados segue a abordagem do exemplo Autolog e foi adaptada
para preservar operadores e bloquear correções incompatíveis.

- [Autolog/main.lua](https://github.com/rrpgfirecast/firecast/blob/master/Plugins/ChatMods/Autolog/main.lua)
- [Autolog/auxiliar.lua](https://github.com/rrpgfirecast/firecast/blob/master/Plugins/ChatMods/Autolog/auxiliar.lua)
- [NickSaver](https://github.com/rrpgfirecast/firecast/blob/master/Plugins/ChatMods/NickSaver/nicksaver.lua)
- [MacroButtons](https://github.com/rrpgfirecast/firecast/blob/master/Plugins/ChatMods/MacroButtons/macrobuttons.lua)
- [SDK rrpg.lua](https://github.com/rrpgfirecast/firecast/blob/master/SDK3/API/rrpg.lua)
- [Eventos](https://github.com/rrpgfirecast/firecast/blob/master/SDK3/API/rrpgEventMessages.lua)
- [Adapters](https://github.com/rrpgfirecast/firecast/blob/master/SDK3/API/rrpgEventMessagesAdapters.lua)
- [Chat e seus métodos](https://firecast.app/sdk3/ObjetoChat.html)
- [Async.execute e pawait](https://firecast.app/sdk3/Asynclibrary.html)
- [Promises e erros de continuações](https://firecast.app/sdk3/Promiseobject.html)
- [LogRec, medium, autoria e visibilidade](https://firecast.app/sdk3/Chatmessagingstructures.html)
- [Jogador e avatar](https://firecast.app/sdk3/ObjetoJogador.html)
- [Personagem e avatar da ficha](https://firecast.app/sdk3/ObjetoPersonagem.html)
- [Eventos de chat e disponibilidade](https://firecast.app/sdk3/MensagensdeChat.html)
- [RichEdit](https://firecast.app/sdk3/TagrichEdit.html)
- [Label e autoSize](https://firecast.app/sdk3/Taglabel.html)
- [Edit e eventos onChange/onUserChange](https://firecast.app/sdk3/Tagedit.html)
- [TextEditor multilinha](https://firecast.app/sdk3/TagtextEditor.html)
- [Popup contextual e cancelamento](https://firecast.app/sdk3/Tagpopup.html)
- [NDB, permissões e broadcast](https://firecast.app/sdk3/BibliotecaNDB.html)
- [NodeObserver](https://firecast.app/sdk3/ObjetoNodeObserver.html)
- [Registro de janela acoplável](https://firecast.app/sdk3/Criarumajanelaacoplaveldemesa.html)
- [Lista nativa e scrollToNode](https://firecast.app/sdk3/TagrecordList.html)
- [Skill local de popups](.agents/skills/firecast-floating-popup/SKILL.md)

O código oficial consultado estava no commit
`50084787138e89cb158fc1fa6ea4d059916f3b5a`; o repositório oficial usa
[Apache 2.0](https://github.com/rrpgfirecast/firecast/blob/master/LICENSE).

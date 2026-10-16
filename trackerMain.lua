local ndb = require("ndb.lua");
local rrpg = require("rrpg.lua");
local dialogs = require("dialogs.lua");
local gui = require("gui.lua");
local utils = require("utils.lua");
local windowPositions = require("trackerWindowPositions.lua");
local turnAccess = require("trackerTurnAccess.lua");
local turnRequests = require("trackerTurnRequests.lua");

local M = {};
local FLOATING_PADDING = 2;
local FLOATING_GAP = 2;
local TURN_TIMER_INTERVAL_MS = 1000;
-- A receita validada do popup nao escreve left/top: isso estica o fundo nativo.
local TURN_TIMER_SAVE_POSITION = false;
local TURN_TIMER_POPUP_WIDTH = 200;
local CONTEXT_MENU_WIDTH = 280;
local TURN_TIMER_NAME_HEIGHT = 32;
local TURN_TIMER_CLOCK_HEIGHT = 32;
local TURN_TIMER_POPUP_HEIGHT = 2 * FLOATING_PADDING + TURN_TIMER_NAME_HEIGHT
    + FLOATING_GAP + TURN_TIMER_CLOCK_HEIGHT;
local TURN_TIMER_COMPACT_WIDTH = 200;
local TURN_TIMER_COMPACT_NAME_HEIGHT = 16;
local TURN_TIMER_COMPACT_CLOCK_HEIGHT = 26;
local TURN_TIMER_COMPACT_HEIGHT = 2 * FLOATING_PADDING + TURN_TIMER_COMPACT_NAME_HEIGHT
    + FLOATING_GAP + TURN_TIMER_COMPACT_CLOCK_HEIGHT;
local NDB_UNIX_EPOCH_OFFSET_DAYS = 25569;
local DEFAULT_INITIATIVE_FORMULA = "1d20";
local ITEM_HISTORY_MAX = 10;
local DEFAULT_ITEM_COLOR = "#2A2A2A";
local POPUP_ROW_HEIGHT = 30;
local POPUP_ROW_SPACING = 4;
local POPUP_PADDING = 8;
local COLOR_SWATCH_SIZE = 22;
local COLOR_SWATCH_SPACING = 4;
local COLOR_SWATCH_COLUMNS = 8;
local ATTENTION_POPUP_WIDTH = 200;
local ATTENTION_DECAY_SECONDS = 3;
local ATTENTION_ANIMATION_INTERVAL_MS = 50;
local ATTENTION_BUTTON_WIDTH = 64;
local ATTENTION_BUTTON_GAP = FLOATING_GAP;
local ATTENTION_POPUP_PLACEMENT = "bottomLeft";
local TURN_TIMER_POPUP_PLACEMENT = "bottomRight";
local ATTENTION_DRAG_HANDLE_HEIGHT = 18;
local ATTENTION_HEADER_HEIGHT = 28;
local ATTENTION_NAME_HEIGHT = 24;
local ATTENTION_CARD_VERTICAL_PADDING = 2 * FLOATING_PADDING;
local ATTENTION_ROW_HEIGHT = 44;
local ATTENTION_ROW_LINE_HEIGHT = 22;
local ATTENTION_ROW_SPACING = FLOATING_GAP;
local ATTENTION_MAX_FONT_SIZE = 14;
local ATTENTION_MIN_FONT_SIZE = 10;
local ATTENTION_VISIBLE_ROWS = 3;
local ATTENTION_SCROLLBAR_WIDTH = 16;
local ATTENTION_LIST_VIEWPORT_HEIGHT = ATTENTION_VISIBLE_ROWS * ATTENTION_ROW_HEIGHT
    + (ATTENTION_VISIBLE_ROWS - 1) * ATTENTION_ROW_SPACING;
local ATTENTION_POPUP_HEIGHT = ATTENTION_CARD_VERTICAL_PADDING + ATTENTION_DRAG_HANDLE_HEIGHT
    + ATTENTION_HEADER_HEIGHT + ATTENTION_NAME_HEIGHT + 2 * FLOATING_GAP;
local ATTENTION_POPUP_FIXED_HEIGHT = ATTENTION_POPUP_HEIGHT + FLOATING_GAP
    + ATTENTION_LIST_VIEWPORT_HEIGHT;
local GROUP_COLOR_OPTIONS = {
    {name = "Preto", color = "#1F1F1F"},
    {name = "Cinza", color = "#4D5A6A"},
    {name = "Cinza Claro", color = "#7B8794"},
    {name = "Vinho", color = "#7A3B4B"},
    {name = "Azul", color = "#3A6EA5"},
    {name = "Azul Escuro", color = "#355C9A"},
    {name = "Azul Ceu", color = "#5A97D6"},
    {name = "Verde", color = "#3D8C52"},
    {name = "Verde Lima", color = "#6F9A2E"},
    {name = "Menta", color = "#5CA97A"},
    {name = "Turquesa", color = "#2F8B7C"},
    {name = "Petroleo", color = "#2F7280"},
    {name = "Vermelho", color = "#A54B4B"},
    {name = "Coral", color = "#C76A58"},
    {name = "Rosa", color = "#B55C8A"},
    {name = "Roxo", color = "#6F56A6"},
    {name = "Lavanda", color = "#8A79C9"},
    {name = "Magenta", color = "#9850A8"},
    {name = "Laranja", color = "#B56A2D"},
    {name = "Terracota", color = "#A7603F"},
    {name = "Marrom", color = "#7D5A43"},
    {name = "Ocre", color = "#A3842D"},
    {name = "Dourado", color = "#C29A2E"},
    {name = "Oliva", color = "#6B7A36"}
};
local closePopup;
local refreshFloatingRoot;
local renderAttentionPopup;
local getPlayerDisplayName;
local getPinnedPosition;

-- O estado dos popups fica no módulo, e não em cada formulário do tracker.
-- Assim, abrir o mesmo tracker em várias abas reutiliza a mesma janela e os
-- mesmos listeners.
local sharedFloating = {
    primaryForm = nil,
    activeRoot = nil,
    forms = setmetatable({}, {__mode = "k"}),
    roots = setmetatable({}, {__mode = "k"}),
    turnPopup = nil,
    attentionPopup = nil,
    attentionShowing = false,
    attentionRows = {},
    attentionNameEdit = nil,
    attentionClearButton = nil,
    attentionListPanel = nil
};

local function trimmed(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "");
end

local function safeBoolean(value)
    if type(value) == "boolean" then
        return value;
    end

    local text = trimmed(value):lower();
    return text == "true" or text == "1" or text == "yes" or text == "sim";
end

local function getLocalPlayer(root)
    if root == nil then
        return nil;
    end

    local mesa = rrpg.getMesaDe(root);

    if mesa == nil then
        return nil;
    end

    local player = mesa.meuJogador;

    if player == nil and mesa.getMeuJogador ~= nil then
        local ok, result = pcall(function()
            return mesa:getMeuJogador();
        end);

        if ok then
            player = result;
        end
    end

    return player;
end

function M.isMaster(root)
    local player = getLocalPlayer(root);

    if player ~= nil then
        return safeBoolean(player.isMestre);
    end

    local mesa = root ~= nil and rrpg.getMesaDe(root) or nil;
    return mesa ~= nil and safeBoolean(mesa.isMestre);
end

local function getPlayerIdentity(player)
    if player == nil then
        return "local";
    end

    local candidates = {
        player.codigoInterno or "",
        player.login or "",
        player.nick or "",
        player.objectID or player.objectId or ""
    };

    for _, candidate in ipairs(candidates) do
        local value = trimmed(candidate);

        if value ~= "" then
            return value;
        end
    end

    return "local";
end

local function isFlagEnabled(value)
    if value == nil then
        return true;
    end

    if type(value) == "boolean" then
        return value;
    end

    if type(value) == "number" then
        return value ~= 0;
    end

    local text = trimmed(value):lower();

    if text == "" then
        return true;
    end

    return text ~= "false"
        and text ~= "0"
        and text ~= "no"
        and text ~= "nao";
end

local function getInitiativeFormula(itemNode)
    local formula = DEFAULT_INITIATIVE_FORMULA;

    if itemNode == nil then
        return DEFAULT_INITIATIVE_FORMULA;
    end

    formula = trimmed(itemNode.teste);

    if formula == "" then
        formula = DEFAULT_INITIATIVE_FORMULA;
    else
        local ok, normalizedFormula = pcall(function()
            local roll = rrpg.interpretarRolagem(DEFAULT_INITIATIVE_FORMULA);
            local interpreted = roll:interpretarString(formula);
            local parsedFormula = trimmed(roll.asString);

            if interpreted == true and parsedFormula ~= "" then
                return parsedFormula;
            end

            return nil;
        end);

        if ok and normalizedFormula ~= nil then
            formula = normalizedFormula;
        else
            formula = DEFAULT_INITIATIVE_FORMULA;
        end
    end

    itemNode.teste = formula;
    return formula;
end

local function publishTurnChatMessage(root, itemNode)
    if root == nil or itemNode == nil or not M.isMaster(root) then
        return;
    end

    local mesa = rrpg.getMesaDe(root);

    if mesa == nil or mesa.chat == nil then
        return;
    end

    local turnName = M.getVisibilityState(itemNode) > 0
        and "???"
        or trimmed(itemNode.nome);

    if turnName == "" then
        turnName = "Sem nome";
    end

    local caption = "Turno de " .. turnName;
    root.turnChatCaption = caption;
    root.turnChatAnnouncedId = tostring(root.turnTimerId or "");
    mesa.chat:enviarNarracao(caption);
end

local function clamp(value, minValue, maxValue)
    if value < minValue then
        return minValue;
    end

    if value > maxValue then
        return maxValue;
    end

    return value;
end

local function canRollItemInitiative(root, itemNode)
    if root == nil or itemNode == nil or not M.isItemNode(itemNode) then
        return false;
    end

    local groupId = tostring(itemNode.grupoId or "");

    if groupId == "" then
        return true;
    end

    local groupNode = M.getGroupById(root, groupId);

    if groupNode == nil then
        return true;
    end

    return M.isGroupActive(groupNode);
end

local function normalizeColor(color, fallback)
    local colorText = tostring(color or ""):upper();

    if colorText:match("^#%x%x%x%x%x%x$") then
        return colorText;
    end

    return tostring(fallback or DEFAULT_ITEM_COLOR);
end

local function shadeColor(color, factor)
    local safeColor = normalizeColor(color, DEFAULT_ITEM_COLOR);
    local safeFactor = tonumber(factor) or 1;
    local red = tonumber(safeColor:sub(2, 3), 16) or 0;
    local green = tonumber(safeColor:sub(4, 5), 16) or 0;
    local blue = tonumber(safeColor:sub(6, 7), 16) or 0;

    red = clamp(math.floor(red * safeFactor), 0, 255);
    green = clamp(math.floor(green * safeFactor), 0, 255);
    blue = clamp(math.floor(blue * safeFactor), 0, 255);

    return string.format("#%02X%02X%02X", red, green, blue);
end

local function getDefaultGroupColor(order)
    local paletteIndex = ((math.max(1, tonumber(order) or 1) - 1) % #GROUP_COLOR_OPTIONS) + 1;
    return GROUP_COLOR_OPTIONS[paletteIndex].color;
end

local function getItemHistoryContainer(root)
    if root == nil then
        return nil;
    end

    local container = root.historicoItens;

    if container == nil then
        container = ndb.createChildNode(root, "historicoItens");
    end

    return container;
end

local function getItemHistoryEntries(root)
    local container = getItemHistoryContainer(root);

    if container == nil then
        return {};
    end

    local entries = ndb.getChildNodes(container);

    table.sort(entries,
        function(a, b)
            return (tonumber(a.ordemHistoricoItem) or 0) > (tonumber(b.ordemHistoricoItem) or 0);
        end);

    return entries;
end

local function trimItemHistory(root)
    local entries = getItemHistoryEntries(root);

    for i = ITEM_HISTORY_MAX + 1, #entries, 1 do
        ndb.deleteNode(entries[i]);
    end
end

local function registerPopupControl(popup, ctrl)
    if popup == nil or ctrl == nil then
        return;
    end

    if popup._dynamicCtrls == nil then
        popup._dynamicCtrls = {};
    end

    popup._dynamicCtrls[#popup._dynamicCtrls + 1] = ctrl;
end

local function clearPopupControls(popup)
    if popup == nil or popup._dynamicCtrls == nil then
        return;
    end

    for _, ctrl in ipairs(popup._dynamicCtrls) do
        if ctrl ~= nil then
            ctrl:destroy();
        end
    end

    popup._dynamicCtrls = {};
end

local function setPopupRowsHeight(popup, rowCount)
    local rows = math.max(1, tonumber(rowCount) or 0);
    popup.height = POPUP_PADDING + (rows * POPUP_ROW_HEIGHT) + ((rows - 1) * POPUP_ROW_SPACING);
end

local function setColorPopupHeight(popup, itemCount)
    local total = math.max(1, tonumber(itemCount) or 0);
    local rows = math.ceil(total / COLOR_SWATCH_COLUMNS);
    popup.height = POPUP_PADDING + (rows * COLOR_SWATCH_SIZE) + ((rows - 1) * COLOR_SWATCH_SPACING);
end

local function getColorPopupWidth(itemCount)
    local total = math.max(1, tonumber(itemCount) or 0);
    local columns = math.min(total, COLOR_SWATCH_COLUMNS);
    return POPUP_PADDING + (columns * COLOR_SWATCH_SIZE) + ((columns - 1) * COLOR_SWATCH_SPACING);
end

local function getTemporaryContainer(itemNode, createIfMissing)
    if itemNode == nil then
        return nil;
    end

    local container = itemNode.temporarios;

    if container == nil and createIfMissing == true then
        container = ndb.createChildNode(itemNode, "temporarios");
    end

    return container;
end

local function getTemporaryEntriesRaw(itemNode)
    local container = getTemporaryContainer(itemNode, false);

    if container == nil then
        return {};
    end

    local entries = ndb.getChildNodes(container);

    table.sort(entries,
        function(a, b)
            local nameA = trimmed(a.nome):lower();
            local nameB = trimmed(b.nome):lower();

            if nameA ~= nameB then
                return nameA < nameB;
            end

            return (tonumber(a.contagem) or 0) > (tonumber(b.contagem) or 0);
        end);

    return entries;
end

local function nextSyncEventId(root)
    M.ensureRootDefaults(root);
    root.proximoSyncEventId = (tonumber(root.proximoSyncEventId) or 0) + 1;

    return string.format("%d-%d", tonumber(os.time()) or 0, tonumber(root.proximoSyncEventId) or 0);
end

local function getCurrentTurnTimestamp(root)
    local serverUtcDays = nil;

    if root ~= nil and ndb.getServerUTCTime ~= nil then
        serverUtcDays = tonumber(ndb.getServerUTCTime(root));
    end

    if serverUtcDays ~= nil and serverUtcDays > NDB_UNIX_EPOCH_OFFSET_DAYS then
        return math.floor((serverUtcDays - NDB_UNIX_EPOCH_OFFSET_DAYS) * 86400);
    end

    return tonumber(os.time()) or 0;
end

local function getElapsedTurnSeconds(root, startedAt)
    local now = getCurrentTurnTimestamp(root);
    local elapsed = now - (tonumber(startedAt) or 0);

    if elapsed < 0 then
        return 0;
    end

    return math.floor(elapsed);
end

local function formatTurnTimerElapsed(elapsedSeconds)
    local totalSeconds = math.max(0, math.floor(tonumber(elapsedSeconds) or 0));
    local hours = math.floor(totalSeconds / 3600);
    local minutes = math.floor((totalSeconds % 3600) / 60);
    local remainingSeconds = totalSeconds % 60;

    if hours > 0 then
        return string.format("%02d:%02d:%02d", hours, minutes, remainingSeconds);
    end

    return string.format("%02d:%02d", minutes, remainingSeconds);
end

local function findCurrentTurnItem(root)
    for _, itemNode in ipairs(M.getAllNodes(root)) do
        if M.isItemNode(itemNode) and itemNode.turnoAtual == true then
            return itemNode;
        end
    end

    return nil;
end

local function clearLocalTurnTimerInterval(form)
    if form == nil then
        return;
    end

    if form._turnTimerIntervalId ~= nil then
        clearInterval(form._turnTimerIntervalId);
        form._turnTimerIntervalId = nil;
    end
end

local function applyFloatingPopupSize(popup, width, height)
    local margin = popup._cardMargin or 0;
    local outerWidth = width + 2 * margin;
    local outerHeight = height + 2 * margin;

    if popup.width ~= outerWidth then
        popup.width = outerWidth;
    end
    if popup.height ~= outerHeight then
        popup.height = outerHeight;
    end

    if popup._cardMargin ~= nil then
        -- Receita validada: so o tamanho da janela e o cartao deslocado.
        -- Control size, tema e limites de largura alteram o fundo nativo.
        local card = popup._fixedSizeCard;
        if card ~= nil then
            card.align = "none";
            card.left = margin;
            card.top = margin;
            card.width = width;
            card.height = height;
        end
        return;
    end

    if popup.minWidth ~= outerWidth then
        popup.minWidth = outerWidth;
    end
    if popup.maxWidth ~= outerWidth then
        popup.maxWidth = outerWidth;
    end

    -- O tamanho do controle (Width/Height) e o tamanho da janela
    -- (FormWidth/FormHeight) sao propriedades diferentes no SDK.
    if gui.Control.getWidth(popup) ~= outerWidth then
        gui.Control.setWidth(popup, outerWidth);
    end
    if gui.Control.getHeight(popup) ~= outerHeight then
        gui.Control.setHeight(popup, outerHeight);
    end

    local card = popup._fixedSizeCard;

    if card ~= nil then
        card.align = "none";
        card.left = 0;
        card.top = 0;
        card.width = width;
        card.height = height;
    end
end

local function applyLocalTurnTimerSize(form)
    if form == nil or form._activeTurnTimerPopup == nil then
        return;
    end

    local popup = form._activeTurnTimerPopup;
    local card = form._turnTimerCard;
    local nameLabel = form._turnTimerNameLabel;
    local timerLabel = form._turnTimerLabel;
    local compact = form._turnTimerCompact == true;

    popup:beginUpdate();
    applyFloatingPopupSize(popup,
        compact and TURN_TIMER_COMPACT_WIDTH or TURN_TIMER_POPUP_WIDTH,
        compact and TURN_TIMER_COMPACT_HEIGHT or TURN_TIMER_POPUP_HEIGHT);

    if card ~= nil then
        card.xradius = compact and 5 or 6;
        card.yradius = compact and 5 or 6;
    end

    local nameHeight = compact and TURN_TIMER_COMPACT_NAME_HEIGHT or TURN_TIMER_NAME_HEIGHT;
    local clockHeight = compact and TURN_TIMER_COMPACT_CLOCK_HEIGHT or TURN_TIMER_CLOCK_HEIGHT;
    local innerWidth = (compact and TURN_TIMER_COMPACT_WIDTH or TURN_TIMER_POPUP_WIDTH)
        - 2 * FLOATING_PADDING;

    if nameLabel ~= nil then
        nameLabel.left = FLOATING_PADDING;
        nameLabel.top = FLOATING_PADDING;
        nameLabel.width = innerWidth;
        nameLabel.height = nameHeight;
        nameLabel.fontSize = compact and 11 or 12;
        nameLabel.wordWrap = not compact;

        if form._turnTimerFullCaption ~= nil then
            nameLabel.text = form._turnTimerFullCaption:gsub("^Turno de ",
                compact and "" or "Turno de\n");
        end
    end

    if timerLabel ~= nil then
        timerLabel.left = FLOATING_PADDING;
        timerLabel.top = FLOATING_PADDING + nameHeight + FLOATING_GAP;
        timerLabel.width = innerWidth;
        timerLabel.height = clockHeight;
        timerLabel.fontSize = compact and 18 or 22;
    end

    popup:endUpdate();
    popup:needRepaint();
end

local function destroyLocalTurnTimerContextPopup(contextMenu)
    if contextMenu == nil or contextMenu._turnTimerContextDestroyed == true then
        return;
    end

    contextMenu._turnTimerContextDestroyed = true;
    clearPopupControls(contextMenu);

    if contextMenu.handle ~= nil and contextMenu.handle ~= 0 then
        contextMenu:destroy();
    end
end

local function closeLocalTurnTimerContextMenu(form)
    if form == nil then
        return;
    end

    local contextMenu = form._activeTurnTimerContextPopup;
    form._activeTurnTimerContextPopup = nil;
    form._turnTimerContextRoot = nil;
    form._turnTimerContextStateId = nil;

    if contextMenu ~= nil and contextMenu.handle ~= nil and contextMenu.handle ~= 0 then
        if contextMenu.isShowing == true then
            contextMenu:close();
        else
            destroyLocalTurnTimerContextPopup(contextMenu);
        end
    end
end

local function stopLocalTurnTimer(form)
    if form == nil then
        return;
    end

    local popup = form._activeTurnTimerPopup;
    windowPositions.stop(popup, true);
    clearLocalTurnTimerInterval(form);
    closeLocalTurnTimerContextMenu(form);

    form._activeTurnTimerPopup = nil;
    form._turnTimerCard = nil;
    form._turnTimerLabel = nil;
    form._turnTimerNameLabel = nil;
    form._turnTimerFullCaption = nil;
    form._turnTimerRoot = nil;
    form._turnTimerStateId = nil;
    form._turnTimerStartedAt = nil;

    if popup ~= nil then
        popup:close();
    end

    if sharedFloating.turnPopup == popup then
        sharedFloating.turnPopup = nil;
    end
end

local function dismissLocalTurnTimerUntilNextTurn(form)
    if form == nil then
        return;
    end

    local root = form._turnTimerRoot;
    local stateId = tostring(form._turnTimerStateId or "");

    if root ~= nil and stateId ~= "" then
        form._turnTimerDismissedRoot = root;
        form._turnTimerDismissedStateId = stateId;
    end

    stopLocalTurnTimer(form);
end

local function toggleLocalTurnTimerSize(form)
    if form == nil then
        return;
    end

    form._turnTimerCompact = not (form._turnTimerCompact == true);
    if form._turnTimerRoot ~= nil then
        windowPositions.set(form._turnTimerRoot, "turnCompact", form._turnTimerCompact);
    end
    applyLocalTurnTimerSize(form);
end

local function createLocalTurnTimerPopup(form)
    local popup = gui.newPopupForm();
    popup._cardMargin = FLOATING_PADDING;
    applyFloatingPopupSize(popup, TURN_TIMER_POPUP_WIDTH, TURN_TIMER_POPUP_HEIGHT);
    popup.drawContainer = false;
    pcall(function()
        popup.backOpacity = 0;
    end);
    popup.cancelable = false;
    popup.resizable = false;
    popup.movable = true;
    popup.hitTest = false;
    popup.placement = TURN_TIMER_POPUP_PLACEMENT;
    popup._dynamicCtrls = {};

    -- PopupForm já usa a pilha superior do Firecast. Algumas versões expõem
    -- também uma propriedade explícita; use-a somente quando disponível.
    pcall(function()
        popup.alwaysOnTop = true;
    end);
    pcall(function()
        popup.topMost = true;
    end);

    local card = gui.newRectangle();
    card.parent = popup;
    card.align = "none";
    card.left = FLOATING_PADDING;
    card.top = FLOATING_PADDING;
    card.width = TURN_TIMER_POPUP_WIDTH;
    card.height = TURN_TIMER_POPUP_HEIGHT;
    popup._fixedSizeCard = card;
    card.color = "#181C21";
    card.strokeColor = "#63F28E";
    card.strokeSize = 1;
    card.xradius = 6;
    card.yradius = 6;
    card.hitTest = false;
    registerPopupControl(popup, card);

    local nameLabel = gui.newLabel();
    nameLabel.parent = card;
    nameLabel.align = "none";
    nameLabel.left = FLOATING_PADDING;
    nameLabel.top = FLOATING_PADDING;
    nameLabel.width = TURN_TIMER_POPUP_WIDTH - 2 * FLOATING_PADDING;
    nameLabel.height = TURN_TIMER_NAME_HEIGHT;
    nameLabel.fontStyle = "bold";
    nameLabel.fontSize = 12;
    nameLabel.fontColor = "#C6D0DA";
    nameLabel.horzTextAlign = "center";
    nameLabel.vertTextAlign = "center";
    nameLabel.textTrimming = "character";
    nameLabel.hitTest = false;
    registerPopupControl(popup, nameLabel);

    local timerLabel = gui.newLabel();
    timerLabel.parent = card;
    timerLabel.align = "none";
    timerLabel.left = FLOATING_PADDING;
    timerLabel.top = FLOATING_PADDING + TURN_TIMER_NAME_HEIGHT + FLOATING_GAP;
    timerLabel.width = TURN_TIMER_POPUP_WIDTH - 2 * FLOATING_PADDING;
    timerLabel.height = TURN_TIMER_CLOCK_HEIGHT;
    timerLabel.fontStyle = "bold";
    timerLabel.fontSize = 22;
    timerLabel.fontColor = "#63F28E";
    timerLabel.horzTextAlign = "center";
    timerLabel.vertTextAlign = "center";
    timerLabel.hitTest = false;
    registerPopupControl(popup, timerLabel);

    -- O fundo (container movel do Firecast) arrasta o popup; o cartao e os
    -- textos deixam o mouse passar. O menu de contexto fica no nome.
    nameLabel.hitTest = true;
    nameLabel.onMenu = function(x, y, event)
        M.openTurnTimerContextMenu(sharedFloating.primaryForm or form);
    end;

    popup.onHide = function()
        popup._shown = false;
        windowPositions.stop(popup);
        if form._activeTurnTimerPopup == popup then
            clearLocalTurnTimerInterval(form);
            closeLocalTurnTimerContextMenu(form);
            form._activeTurnTimerPopup = nil;
            form._turnTimerCard = nil;
            form._turnTimerLabel = nil;
            form._turnTimerNameLabel = nil;
            form._turnTimerFullCaption = nil;
            form._turnTimerRoot = nil;
            form._turnTimerStateId = nil;
            form._turnTimerStartedAt = nil;
        end

        clearPopupControls(popup);
        popup:destroy();

        if sharedFloating.turnPopup == popup then
            sharedFloating.turnPopup = nil;
        end
    end;

    form._activeTurnTimerPopup = popup;
    sharedFloating.turnPopup = popup;
    form._turnTimerCard = card;
    form._turnTimerLabel = timerLabel;
    form._turnTimerNameLabel = nameLabel;
    applyLocalTurnTimerSize(form);
    return popup;
end

local function updateLocalTurnTimer(form)
    if form == nil then
        stopLocalTurnTimer(form);
        return false;
    end

    local root = form._turnTimerRoot;
    local stateId = tostring(form._turnTimerStateId or "");
    local startedAt = tonumber(form._turnTimerStartedAt) or 0;
    local stateItemId = tostring(root ~= nil and root.turnTimerItemId or "");

    if root == nil
        or form._activeTurnTimerPopup == nil
        or form._turnTimerLabel == nil
        or stateId == ""
        or startedAt <= 0
        or tostring(root.turnTimerId or "") ~= stateId then
        stopLocalTurnTimer(form);
        return false;
    end

    local currentTurnItem = findCurrentTurnItem(root);
    local currentTurnName = trimmed(root.turnTimerName);

    if currentTurnItem ~= nil
        and (stateItemId == "" or tostring(currentTurnItem.itemId or "") == stateItemId) then
        currentTurnName = M.getTurnDisplayName(root, currentTurnItem);
    elseif not M.isMaster(root) and stateItemId ~= "" then
        currentTurnName = "???";
    end

    if currentTurnName == "" then
        currentTurnName = "Sem nome";
    end

    local fullCaption = "Turno de " .. currentTurnName;

    form._turnTimerNameLabel.text = form._turnTimerCompact == true
        and currentTurnName or "Turno de\n" .. currentTurnName;

    if form._turnTimerFullCaption ~= fullCaption then
        form._turnTimerNameLabel.hint = fullCaption;
        form._turnTimerFullCaption = fullCaption;
    end

    form._turnTimerLabel.text = formatTurnTimerElapsed(getElapsedTurnSeconds(root, startedAt));
    return true;
end

local function syncLocalTurnTimer(form, root)
    if form == nil or root == nil then
        stopLocalTurnTimer(form);
        return;
    end

    local wasCompact = form._turnTimerCompact == true;
    form._turnTimerCompact = safeBoolean(windowPositions.get(root, "turnCompact"));
    local stateId = tostring(root.turnTimerId or "");
    local turnName = trimmed(root.turnTimerName);
    local startedAt = tonumber(root.turnTimerStartedAt) or 0;
    local timerItem = M.findItemById(root, root.turnTimerItemId);

    if timerItem ~= nil then
        turnName = M.getTurnDisplayName(root, timerItem);
    elseif not M.isMaster(root) and tostring(root.turnTimerItemId or "") ~= "" then
        turnName = "???";
    end

    if form._activeTurnTimerContextPopup ~= nil
        and (form._turnTimerContextRoot ~= root
            or tostring(form._turnTimerContextStateId or "") ~= stateId) then
        closeLocalTurnTimerContextMenu(form);
    end

    if form._turnTimerDismissedRoot ~= nil then
        if form._turnTimerDismissedRoot == root
            and tostring(form._turnTimerDismissedStateId or "") == stateId then
            stopLocalTurnTimer(form);
            return;
        end

        form._turnTimerDismissedRoot = nil;
        form._turnTimerDismissedStateId = nil;
    end

    if stateId == "" or turnName == "" or startedAt <= 0 then
        stopLocalTurnTimer(form);
        return;
    end

    local popup = form._activeTurnTimerPopup;

    if popup == nil then
        popup = createLocalTurnTimerPopup(form);
    elseif wasCompact ~= form._turnTimerCompact then
        applyLocalTurnTimerSize(form);
    end

    form._turnTimerRoot = root;
    form._turnTimerStateId = stateId;
    form._turnTimerStartedAt = startedAt;
    form._turnTimerNameLabel.text = "Turno de " .. turnName;

    if updateLocalTurnTimer(form) == false then
        return;
    end

    if popup.isShowing ~= true then
        local wasShown = gui.showPopup(popup, {placement = TURN_TIMER_POPUP_PLACEMENT});

        if wasShown == false then
            stopLocalTurnTimer(form);

            if popup.handle ~= nil and popup.handle ~= 0 then
                clearPopupControls(popup);
                popup:destroy();
            end

            return;
        end
    end

    if TURN_TIMER_SAVE_POSITION then
        windowPositions.bind(popup, root, "turn");
    end
    if form._turnTimerIntervalId == nil then
        form._turnTimerIntervalId = setInterval(
            function()
                local currentForm = sharedFloating.primaryForm or form;
                return updateLocalTurnTimer(currentForm);
            end,
            TURN_TIMER_INTERVAL_MS);
    end
end

local function finishTurnChatMessage(root)
    if not M.isMaster(root) then return; end

    local stateId = tostring(root.turnTimerId or "");
    local announcedId = tostring(root.turnChatAnnouncedId or "");
    local startedAt = tonumber(root.turnTimerStartedAt) or 0;
    local caption = trimmed(root.turnChatCaption);

    if stateId == "" or announcedId ~= stateId or startedAt <= 0 or caption == ""
        or tostring(root.turnChatFinishedId or "") == stateId then
        return;
    end

    local mesa = rrpg.getMesaDe(root);
    if mesa == nil or mesa.chat == nil then return; end

    local itemNode = M.findItemById(root, root.turnTimerItemId);
    if itemNode ~= nil and M.getVisibilityState(itemNode) > 0 then
        caption = "Turno de ???";
    end

    local duration = formatTurnTimerElapsed(getElapsedTurnSeconds(root, startedAt));
    -- O SDK nao edita mensagens anteriores; registra o encerramento com o
    -- mesmo titulo do anuncio, seguido da duracao medida antes de trocar turno.
    root.turnChatFinishedId = stateId;
    mesa.chat:enviarNarracao(caption .. " - " .. duration);
end

local function publishTurnTimerState(root, itemNode, options)
    if root == nil then
        return;
    end

    local preserveChat = options ~= nil and options.preserveChat == true;
    local previousStateId = tostring(root.turnTimerId or "");

    if not preserveChat then
        finishTurnChatMessage(root);
    end

    local turnName = "";
    local turnItemId = "";
    local startedAt = 0;

    if itemNode ~= nil then
        turnName = trimmed(itemNode.nome);

        if turnName == "" then
            turnName = "Sem nome";
        end

        turnItemId = tostring(itemNode.itemId or "");
        startedAt = tonumber(options ~= nil and options.startedAt) or getCurrentTurnTimestamp(root);
    end

    ndb.beginUpdate(root);
    root.turnTimerName = turnName;
    root.turnTimerItemId = turnItemId;
    root.turnTimerStartedAt = startedAt;
    root.turnTimerId = nextSyncEventId(root);

    if preserveChat and itemNode ~= nil then
        if tostring(root.turnChatAnnouncedId or "") == previousStateId then
            root.turnChatAnnouncedId = tostring(root.turnTimerId);
        end
    else
        root.turnChatCaption = "";
        root.turnChatAnnouncedId = "";
    end

    -- Mantém o horário legível por clientes antigos, mas limpa seus gatilhos de toast.
    root.turnToastName = turnName;
    root.turnToastStartedAt = startedAt;
    root.turnToastId = "";
    root.turnToastAnnounceId = "";
    root.turnToastAnnounceDelayMs = 0;
    root.toastMsg = "";
    root.toastId = "";
    ndb.endUpdate(root);
end

local function ensureListNode(root)
    if root == nil then
        return nil;
    end

    local listNode = root.itens;

    if listNode == nil then
        listNode = ndb.createChildNode(root, "itens");
    end

    return listNode;
end

function M.isGroupNode(node)
    return tostring(node.tipo or "") == "grupo";
end

function M.isItemNode(node)
    return not M.isGroupNode(node);
end

function M.getVisibilityState(node)
    local state = tonumber(node ~= nil and (node.ocultacaoEstado or node.estadoOcultacao) or nil) or 0;
    state = math.floor(state);

    if state < 0 or state > 2 then
        return 0;
    end

    return state;
end

function M.getViewerVisibilityState(root, node)
    if node == nil or M.isMaster(root) then
        return 0;
    end

    return M.getVisibilityState(node);
end

function M.getTurnDisplayName(root, itemNode)
    if itemNode == nil then
        return "";
    end

    if M.getViewerVisibilityState(root, itemNode) > 0 then
        return "???";
    end

    local name = trimmed(itemNode.nome);
    return name ~= "" and name or "Sem nome";
end

function M.getPublicItemName(itemNode)
    if itemNode == nil then
        return "???";
    end

    return M.getVisibilityState(itemNode) > 0
        and "???"
        or (trimmed(itemNode.nome) ~= "" and trimmed(itemNode.nome) or "Sem nome");
end

function M.toggleItemVisibility(itemNode)
    if itemNode == nil then
        return;
    end

    local root = ndb.getRoot(itemNode);

    if root == nil or not M.isMaster(root) then
        return;
    end

    local state = (M.getVisibilityState(itemNode) + 1) % 3;
    itemNode.ocultacaoEstado = state;
end

function M.toggleItemPin(itemNode)
    if itemNode == nil or M.isGroupNode(itemNode) then
        return;
    end

    local root = ndb.getRoot(itemNode);

    if root == nil or not M.isMaster(root) then
        return;
    end

    if getPinnedPosition(itemNode) ~= nil then
        itemNode.posicaoFixada = nil;
        return;
    end

    local position = nil;

    for index, node in ipairs(M.getOrderedListNodes(root)) do
        if node == itemNode then
            position = index;
            break
        end
    end

    itemNode.posicaoFixada = position or (#M.getAllNodes(root));
end

function M.isItemPinned(itemNode)
    return getPinnedPosition(itemNode) ~= nil;
end

function M.compareIniciativa(nodeA, nodeB)
    local initA = tonumber(nodeA.iniciativa) or 0;
    local initB = tonumber(nodeB.iniciativa) or 0;

    if initA ~= initB then
        return initB - initA;
    end

    return 0;
end

local function shouldItemComeBefore(nodeA, nodeB)
    local initA = tonumber(nodeA ~= nil and nodeA.iniciativa or nil) or 0;
    local initB = tonumber(nodeB ~= nil and nodeB.iniciativa or nil) or 0;

    if initA ~= initB then
        return initA > initB;
    end

    local idA = tonumber(nodeA ~= nil and nodeA.itemId or nil);
    local idB = tonumber(nodeB ~= nil and nodeB.itemId or nil);

    if idA ~= nil and idB ~= nil and idA ~= idB then
        return idA < idB;
    end

    local nameA = trimmed(nodeA ~= nil and nodeA.nome or ""):lower();
    local nameB = trimmed(nodeB ~= nil and nodeB.nome or ""):lower();

    if nameA ~= nameB then
        return nameA < nameB;
    end

    return tostring(nodeA) < tostring(nodeB);
end

function M.getAllNodes(root)
    if root == nil or root.itens == nil then
        return {};
    end

    return ndb.getChildNodes(root.itens);
end

function M.getGroupHeaders(root)
    local groups = {};

    for _, node in ipairs(M.getAllNodes(root)) do
        if M.isGroupNode(node) then
            groups[#groups + 1] = node;
        end
    end

    table.sort(groups,
        function(a, b)
            return (tonumber(a.ordemGrupo) or 0) < (tonumber(b.ordemGrupo) or 0);
        end);

    return groups;
end

function M.isGroupActive(groupNode)
    return groupNode ~= nil and isFlagEnabled(groupNode.grupoAtivo);
end

function M.getGroupById(root, groupId)
    local idAsText = tostring(groupId or "");

    for _, group in ipairs(M.getGroupHeaders(root)) do
        if tostring(group.grupoId or "") == idAsText then
            return group;
        end
    end

    return nil;
end

function M.getItemGroupOrder(root, node)
    local groupId = tostring(node.grupoId or "");
    local group = M.getGroupById(root, groupId);

    if group ~= nil then
        return tonumber(group.ordemGrupo) or 0;
    end

    return 1000000;
end

local function compareBaseListNodes(root, nodeA, nodeB)
    local orderA = M.isGroupNode(nodeA)
        and (tonumber(nodeA.ordemGrupo) or 0)
        or M.getItemGroupOrder(root, nodeA);
    local orderB = M.isGroupNode(nodeB)
        and (tonumber(nodeB.ordemGrupo) or 0)
        or M.getItemGroupOrder(root, nodeB);

    if orderA ~= orderB then
        return orderA < orderB;
    end

    local kindA = M.isGroupNode(nodeA) and 0 or 1;
    local kindB = M.isGroupNode(nodeB) and 0 or 1;

    if kindA ~= kindB then
        return kindA < kindB;
    end

    if kindA == 0 then
        local idA = tostring(nodeA.grupoId or "");
        local idB = tostring(nodeB.grupoId or "");
        return idA < idB;
    end

    return shouldItemComeBefore(nodeA, nodeB);
end

getPinnedPosition = function(node)
    local position = tonumber(node ~= nil and node.posicaoFixada or nil);

    if position == nil or position < 1 then
        return nil;
    end

    return math.floor(position);
end

function M.getOrderedListNodes(root)
    if root == nil then
        return {};
    end

    local base = {};

    for _, node in ipairs(M.getAllNodes(root)) do
        base[#base + 1] = node;
    end

    table.sort(base, function(a, b)
        return compareBaseListNodes(root, a, b);
    end);

    local pinned = {};
    local unpinned = {};

    for _, node in ipairs(base) do
        if getPinnedPosition(node) ~= nil and M.isItemNode(node) then
            pinned[#pinned + 1] = node;
        else
            unpinned[#unpinned + 1] = node;
        end
    end

    if #pinned == 0 then
        return base;
    end

    table.sort(pinned, function(a, b)
        local positionA = getPinnedPosition(a) or 1;
        local positionB = getPinnedPosition(b) or 1;

        if positionA ~= positionB then
            return positionA < positionB;
        end

        return tostring(a.itemId or "") < tostring(b.itemId or "");
    end);

    local result = {};
    local occupied = {};
    local total = #base;

    for _, node in ipairs(pinned) do
        local position = math.max(1, math.min(total, getPinnedPosition(node) or total));

        while occupied[position] == true and position < total do
            position = position + 1;
        end

        if occupied[position] == true then
            for candidate = total, 1, -1 do
                if occupied[candidate] ~= true then
                    position = candidate;
                    break
                end
            end
        end

        occupied[position] = true;
        result[position] = node;
    end

    local unpinnedIndex = 1;

    for position = 1, total do
        if result[position] == nil then
            result[position] = unpinned[unpinnedIndex];
            unpinnedIndex = unpinnedIndex + 1;
        end
    end

    return result;
end

function M.compareListNodes(root, nodeA, nodeB)
    local ordered = M.getOrderedListNodes(root);
    local positions = {};

    for index, node in ipairs(ordered) do
        positions[node] = index;
    end

    local positionA = positions[nodeA] or #ordered + 1;
    local positionB = positions[nodeB] or #ordered + 1;

    if positionA == positionB and nodeA ~= nodeB then
        if compareBaseListNodes(root, nodeA, nodeB) then
            return -1;
        end

        if compareBaseListNodes(root, nodeB, nodeA) then
            return 1;
        end
    end

    return positionA - positionB;
end

function M.redrawList(control)
    if control == nil then
        return;
    end

    local list = control:findControlByName("rclLista");

    if list ~= nil then
        list:beginUpdate();
        list:sort();
        list:endUpdate();
        list:needRepaint();
    end

    if control.needRepaint ~= nil then
        control:needRepaint();
    end
end

function M.sortList(control)
    M.redrawList(control);
end

function M.ensureRootDefaults(root)
    if root == nil then
        return;
    end

    if tonumber(root.rodada) == nil then
        root.rodada = 1;
    end

    if tonumber(root.proximoGrupoId) == nil then
        root.proximoGrupoId = 0;
    end

    if tonumber(root.proximaOrdemGrupo) == nil then
        root.proximaOrdemGrupo = 0;
    end

    if tonumber(root.proximoItemId) == nil then
        root.proximoItemId = 0;
    end

    if tonumber(root.proximoHistoricoId) == nil then
        root.proximoHistoricoId = 0;
    end

    if tonumber(root.proximoSyncEventId) == nil then
        root.proximoSyncEventId = 0;
    end

    if tonumber(root.proximoHistoricoItemId) == nil then
        root.proximoHistoricoItemId = 0;
    end
end

function M.getGroupColor(groupNode)
    if groupNode == nil then
        return getDefaultGroupColor(1);
    end

    return normalizeColor(groupNode.grupoCor, getDefaultGroupColor(groupNode.ordemGrupo));
end

function M.setGroupColor(groupNode, color)
    if groupNode == nil then
        return;
    end

    groupNode.grupoCor = normalizeColor(color, getDefaultGroupColor(groupNode.ordemGrupo));
end

function M.getItemCustomColor(itemNode)
    if itemNode == nil then
        return "";
    end

    return normalizeColor(itemNode.itemCor, "");
end

function M.setItemColor(itemNode, color)
    if itemNode == nil then
        return;
    end

    itemNode.itemCor = normalizeColor(color, "");
end

function M.clearItemColor(itemNode)
    if itemNode ~= nil then
        itemNode.itemCor = "";
    end
end

function M.getItemColor(root, itemNode)
    if root == nil or itemNode == nil then
        return DEFAULT_ITEM_COLOR;
    end

    local customColor = trimmed(M.getItemCustomColor(itemNode));

    if customColor ~= "" then
        return customColor;
    end

    local group = M.getGroupById(root, itemNode.grupoId);

    if group == nil then
        return DEFAULT_ITEM_COLOR;
    end

    return shadeColor(M.getGroupColor(group), 0.75);
end

function M.getGroupColorOptions()
    return GROUP_COLOR_OPTIONS;
end

function M.saveItemHistoryData(root, nome, iniciativa, teste)
    if root == nil then
        return;
    end

    local safeName = trimmed(nome);

    if safeName == "" then
        return;
    end

    M.ensureRootDefaults(root);

    local safeTest = trimmed(teste);
    local safeInit = tonumber(iniciativa) or 0;
    local existing = nil;
    local duplicateEntries = {};
    local safeNameKey = safeName:lower();

    for _, entry in ipairs(getItemHistoryEntries(root)) do
        if trimmed(entry.nome):lower() == safeNameKey then
            if existing == nil then
                existing = entry;
            else
                duplicateEntries[#duplicateEntries + 1] = entry;
            end
        end
    end

    root.proximoHistoricoItemId = (tonumber(root.proximoHistoricoItemId) or 0) + 1;

    if existing == nil then
        existing = ndb.createChildNode(getItemHistoryContainer(root), "item");
    end

    existing.nome = safeName;
    existing.iniciativa = safeInit;
    existing.teste = safeTest;
    existing.ordemHistoricoItem = root.proximoHistoricoItemId;

    for _, duplicateEntry in ipairs(duplicateEntries) do
        ndb.deleteNode(duplicateEntry);
    end

    trimItemHistory(root);
end

function M.saveItemHistory(itemNode)
    if itemNode == nil or M.isGroupNode(itemNode) then
        return;
    end

    local root = ndb.getRoot(itemNode);

    if root == nil then
        return;
    end

    M.saveItemHistoryData(root, itemNode.nome, itemNode.iniciativa, itemNode.teste);
end

function M.deleteItemHistoryEntry(entryNode)
    if entryNode ~= nil then
        ndb.deleteNode(entryNode);
    end
end

function M.normalizeTemporaries(itemNode)
    if itemNode == nil or M.isGroupNode(itemNode) then
        return;
    end

    local legacyName = trimmed(itemNode.efeitoTemporarioNome);
    local legacyCount = math.floor(tonumber(itemNode.efeitoTemporarioContagem) or 0);
    local hasLegacyValues = (legacyName ~= "" and legacyCount > 0);

    if hasLegacyValues then
        local container = getTemporaryContainer(itemNode, true);
        local existing = nil;

        for _, entry in ipairs(ndb.getChildNodes(container)) do
            if trimmed(entry.nome):lower() == legacyName:lower() then
                existing = entry;
                break
            end
        end

        if existing == nil then
            existing = ndb.createChildNode(container, "item");
        end

        existing.nome = legacyName;
        existing.contagem = legacyCount;
    end

    if itemNode.efeitoTemporarioNome ~= nil and itemNode.efeitoTemporarioNome ~= "" then
        itemNode.efeitoTemporarioNome = "";
    end

    if tonumber(itemNode.efeitoTemporarioContagem) ~= nil and tonumber(itemNode.efeitoTemporarioContagem) ~= 0 then
        itemNode.efeitoTemporarioContagem = 0;
    end
end

function M.getTemporaryEntries(itemNode)
    M.normalizeTemporaries(itemNode);
    return getTemporaryEntriesRaw(itemNode);
end

function M.hasTemporary(itemNode)
    return #M.getTemporaryEntries(itemNode) > 0;
end

function M.addTemporary(itemNode, nome, quantidade)
    if itemNode == nil or M.isGroupNode(itemNode) then
        return nil;
    end

    local nomeLimpo = trimmed(nome);
    local qtd = math.floor(tonumber(quantidade) or 0);

    if nomeLimpo == "" or qtd <= 0 then
        return nil;
    end

    M.normalizeTemporaries(itemNode);

    local container = getTemporaryContainer(itemNode, true);
    local existing = nil;

    for _, entry in ipairs(ndb.getChildNodes(container)) do
        if trimmed(entry.nome):lower() == nomeLimpo:lower() then
            existing = entry;
            break
        end
    end

    if existing == nil then
        existing = ndb.createChildNode(container, "item");
    end

    existing.nome = nomeLimpo;
    existing.contagem = qtd;
    return existing;
end

function M.removeTemporary(temporaryNode)
    if temporaryNode ~= nil then
        ndb.deleteNode(temporaryNode);
    end
end

local function getAttentionContainer(root, create)
    if root == nil then
        return nil;
    end

    local container = root.atencoes;

    if container == nil and create == true then
        if ndb.testPermission(root, "createChild") then
            container = ndb.createChildNode(root, "atencoes");
        end
    end

    return container;
end

local function configureAttentionPermissions(root)
    local container = getAttentionContainer(root, false);
    local permissionNode = container or root;

    if permissionNode == nil or not ndb.testPermission(permissionNode, "writePermissions") then
        return;
    end

    container = container or getAttentionContainer(root, true);

    if container == nil then
        return;
    end

    local function grant(node, group, permission)
        if ndb.getPermission(node, "group", group, permission) ~= "strongAllow" then
            ndb.setPermission(node, "group", group, permission, "strongAllow");
        end
    end

    local function configure(node)
        if not ndb.testPermission(node, "writePermissions") then
            return;
        end

        -- A janela acoplavel ja usa o NDB compartilhado da mesa. Libera
        -- somente a lista de atencao; os demais dados mantem suas permissoes.
        grant(node, "todos", "read");

        for _, group in ipairs({"mestres", "mestresAux", "jogadores"}) do
            grant(node, group, "write");
            grant(node, group, "createChild");
        end

        grant(node, "mestres", "delete");
        grant(node, "mestresAux", "delete");
    end

    configure(container);

    -- Corrige tambem solicitacoes antigas com permissoes proprias.
    for _, entry in ipairs(ndb.getChildNodes(container)) do
        configure(entry);
    end
end

local function getAttentionTimestamp(root)
    if root ~= nil and ndb.getServerUTCTime ~= nil then
        local days = tonumber(ndb.getServerUTCTime(root));
        if days ~= nil and days > NDB_UNIX_EPOCH_OFFSET_DAYS then
            return (days - NDB_UNIX_EPOCH_OFFSET_DAYS) * 86400;
        end
    end
    return os.time();
end

local function getAttentionEntries(root, timestamp)
    local container = getAttentionContainer(root, false);

    if container == nil then
        return {}, {};
    end

    local byKey, counts = {}, {};
    local entries = {};
    local now = timestamp or getAttentionTimestamp(root);

    for _, entry in ipairs(ndb.getChildNodes(container)) do
        local key = trimmed(entry.participanteId or entry.jogadorId or entry.id);
        local count = M.getAttentionCount(root, entry, now);
        counts[entry] = count;

        if key ~= "" and count > 0 then
            local previous = byKey[key];

            if previous == nil or count > (counts[previous] or 0) then
                byKey[key] = entry;
            end
        end
    end

    for _, entry in pairs(byKey) do
        entries[#entries + 1] = entry;
    end

    table.sort(entries, function(a, b)
        local countA = counts[a] or 0;
        local countB = counts[b] or 0;

        if countA ~= countB then
            return countA > countB;
        end

        return trimmed(a.nome):lower() < trimmed(b.nome):lower();
    end);

    return entries, counts;
end

-- Derive decay from server time. Every client sees the same charges without
-- multiple clients racing to subtract from the shared node.
function M.getAttentionCount(root, entry, now)
    local count = math.max(0, math.floor(tonumber(entry.contagem) or 0));
    now = now or getAttentionTimestamp(root);
    local cycle = tonumber(entry.cargaCicloInicio);
    local tick = tonumber(entry.cargaTick);
    local elapsed;
    if cycle ~= nil and tick ~= nil then
        elapsed = math.max(0, math.floor((now - cycle) / ATTENTION_DECAY_SECONDS) - tick);
    else
        local requested = tonumber(entry.ultimaSolicitacao) or now;
        elapsed = math.floor(math.max(0, now - requested) / ATTENTION_DECAY_SECONDS);
    end
    return math.max(0, count - elapsed);
end

local function getLocalAttentionKey(root)
    return getPlayerIdentity(getLocalPlayer(root));
end

local function attentionPlainName(value)
    local text = trimmed(value);
    local ok, plain = pcall(utils.removerFmtChat, text, false);
    return ok and type(plain) == "string" and trimmed(plain) or text;
end

local function getLocalAttentionName(root)
    local player = getLocalPlayer(root);
    if player ~= nil then
        local nick = attentionPlainName(player.nick);
        if nick ~= "" then return nick; end
        local login = trimmed(player.login);
        if login ~= "" then return login; end
    end
    return "Jogador";
end

local function getAttentionDisplayName(entry, players)
    local key = trimmed(entry.participanteId or entry.jogadorId or entry.id);
    local player = players[key] or players[trimmed(entry.jogadorLogin):lower()];
    local login = player ~= nil and trimmed(player.login) or "";
    if login == "" then login = trimmed(entry.jogadorLogin); end
    if login == "" and key ~= "local" and tonumber(key) == nil then login = key; end
    local nick = attentionPlainName(entry.nome);
    if not safeBoolean(entry.personalizado) and player ~= nil then
        nick = attentionPlainName(player.nick);
        if nick == "" then nick = login; end
    end
    if nick == "" then nick = login ~= "" and login or "Jogador"; end
    return nick .. " - " .. (login ~= "" and login or "Jogador"), nick;
end

local function findAttentionEntry(root, key)
    local container = getAttentionContainer(root, false);

    if container == nil then
        return nil;
    end

    for _, entry in ipairs(ndb.getChildNodes(container)) do
        if trimmed(entry.participanteId or entry.jogadorId or entry.id) == tostring(key or "") then
            return entry;
        end
    end

    return nil;
end

local function ensureAttentionEntry(root, key, defaultName)
    configureAttentionPermissions(root);
    local entry = findAttentionEntry(root, key);
    local player = getLocalPlayer(root);
    local login = player ~= nil and trimmed(player.login) or "";

    if entry ~= nil then
        if not ndb.testPermission(entry, "write") then
            return nil;
        end

        if (trimmed(entry.nome) == "" or not safeBoolean(entry.personalizado)) and entry.nome ~= defaultName then
            entry.nome = defaultName;
        end
        if login ~= "" and entry.jogadorLogin ~= login then entry.jogadorLogin = login; end

        return entry;
    end

    local container = getAttentionContainer(root, true);

    if container == nil or not ndb.testPermission(container, "createChild") then
        return nil;
    end

    entry = ndb.createChildNode(container, "atencao");

    if entry == nil then
        return nil;
    end

    entry.participanteId = tostring(key or "local");
    entry.jogadorId = tostring(key or "local");
    entry.jogadorLogin = login;
    entry.nome = trimmed(defaultName) ~= "" and defaultName or "Jogador";
    entry.nomePadrao = entry.nome;
    entry.personalizado = false;
    entry.contagem = 0;
    return entry;
end

local function requestAttention(root)
    if root == nil then
        return;
    end

    local key = getLocalAttentionKey(root);
    local entry = ensureAttentionEntry(root, key, getLocalAttentionName(root));

    if entry == nil then
        dialogs.alert("O mestre precisa abrir o tracker para liberar as solicitações de atenção.");
        return;
    end

    local now = getAttentionTimestamp(root);
    local count = M.getAttentionCount(root, entry, now);
    local container = getAttentionContainer(root, false);
    local cycle = tonumber(container.cicloInicio);
    if cycle == nil or cycle > now or #getAttentionEntries(root) == 0 then
        cycle = now;
        container.cicloInicio = cycle;
    end
    ndb.beginUpdate(entry);
    entry.contagem = count + 1;
    entry.cargaCicloInicio = cycle;
    entry.cargaTick = math.floor((now - cycle) / ATTENTION_DECAY_SECONDS);
    entry.ultimaSolicitacao = now;
    ndb.endUpdate(entry);
end

local function removeAttentionEntry(entry)
    if entry ~= nil and ndb.testPermission(entry, "delete") then
        ndb.deleteNode(entry);
    end
end

local function clearOwnAttention(root)
    local entry = findAttentionEntry(root, getLocalAttentionKey(root));

    if entry ~= nil and ndb.testPermission(entry, "write") then
        entry.contagem = 0;
    end
end

local function clearAllAttention(root)
    if root == nil or not M.isMaster(root) then
        return;
    end

    local container = getAttentionContainer(root, false);

    if container ~= nil then
        for _, entry in ipairs(ndb.getChildNodes(container)) do
            removeAttentionEntry(entry);
        end
    end
end

M.requestAttention = requestAttention;
M.clearOwnAttention = clearOwnAttention;
M.clearAllAttention = clearAllAttention;
M.getAttentionEntries = getAttentionEntries;

local function saveAttentionName(root, name)
    if root == nil then
        return;
    end

    local cleanName = attentionPlainName(name);

    if cleanName == "" then
        cleanName = getLocalAttentionName(root);
    end

    local entry = ensureAttentionEntry(root, getLocalAttentionKey(root), cleanName);

    if entry == nil then
        dialogs.alert("O mestre precisa abrir o tracker para liberar as solicitações de atenção.");
        return;
    end

    entry.nome = cleanName;
    entry.personalizado = true;
end

local function clearAttentionRows()
    for _, row in ipairs(sharedFloating.attentionRows) do
        if row ~= nil then
            row:destroy();
        end
    end

    sharedFloating.attentionRows = {};
end

local function setPopupTopmost(popup)
    if popup == nil then
        return;
    end

    pcall(function()
        popup.alwaysOnTop = true;
    end);
    pcall(function()
        popup.topMost = true;
    end);
end

-- A janela mantem altura fixa: redimensionar ou escrever left/top no host
-- durante uma solicitacao de atencao altera o fundo e reposiciona o popup.
local function applyAttentionPopupSize(popup)
    if popup == nil then
        return;
    end

    local margin = popup._cardMargin or 0;
    if popup.width == ATTENTION_POPUP_WIDTH + 2 * margin
        and popup.height == ATTENTION_POPUP_FIXED_HEIGHT + 2 * margin
        and (popup._fixedSizeCard == nil
            or popup._fixedSizeCard.height == ATTENTION_POPUP_FIXED_HEIGHT) then
        return;
    end
    popup:beginUpdate();
    applyFloatingPopupSize(popup, ATTENTION_POPUP_WIDTH, ATTENTION_POPUP_FIXED_HEIGHT);
    popup:endUpdate();
    popup:needRepaint();
end

local function showAttentionPopup(popup)
    if popup == nil then
        return false;
    end

    if popup.isShowing == true then
        return true;
    end

    local shown = gui.showPopup(popup, {placement = ATTENTION_POPUP_PLACEMENT});

    return shown;
end

function M.closeAttention(root)
    if root == nil then return; end
    if sharedFloating.attentionRequestedRoot == root then sharedFloating.attentionRequestedRoot = nil; end
    windowPositions.set(root, "attentionClosed", true);
    local popup = sharedFloating.attentionPopup;
    if popup ~= nil and popup._attentionRoot == root then popup:close(); end
end

function M.openAttention(root)
    if root == nil then return; end
    sharedFloating.attentionRequestedRoot = root;
    windowPositions.set(root, "attentionClosed", false);
    renderAttentionPopup(root);
end

local function updateAttentionProgress(popup, now)
    local track, fill = popup._attentionProgressTrack, popup._attentionProgressFill;
    if track == nil or fill == nil then return nil; end
    local cycle = popup._attentionProgressCycle;
    local active = cycle ~= nil;
    if track.visible ~= active then track.visible = active; end
    if not active then return nil; end
    local elapsed = math.max(0, now - cycle);
    local tick = math.floor(elapsed / ATTENTION_DECAY_SECONDS);
    local phase = (elapsed - tick * ATTENTION_DECAY_SECONDS) / ATTENTION_DECAY_SECONDS;
    local width = math.max(0, math.min(track.width, math.floor(track.width * phase + 0.5)));
    if fill.width ~= width then fill.width = width; end
    if fill.visible ~= (width > 0) then fill.visible = width > 0; end
    return tick;
end

local function setAttentionWatchRate(popup, active)
    local watch = popup._attentionWatch;
    if watch == nil then return; end
    local interval = active and ATTENTION_ANIMATION_INTERVAL_MS or 1000;
    if watch.intervalMs == interval then return; end
    if watch.interval ~= nil then clearInterval(watch.interval); end
    watch.intervalMs, watch.elapsedMs = interval, 0;
    watch.interval = setInterval(watch.tick, interval);
end

local function stopAttentionWatch(popup)
    local watch = popup._attentionWatch;
    if watch == nil then return; end
    popup._attentionWatch = nil;
    if watch.interval ~= nil then clearInterval(watch.interval); end
    if watch.pending ~= nil then clearTimeout(watch.pending); end
    for _, id in ipairs(watch.listeners) do watch.observer:removeEventListener(id); end
end

local function watchAttention(popup, root)
    local watch = popup._attentionWatch;
    if watch ~= nil and watch.root == root then return; end
    stopAttentionWatch(popup);
    watch = {root = root, observer = ndb.newObserver(root), listeners = {}};
    popup._attentionWatch = watch;
    local function refresh()
        if sharedFloating.attentionPopup == popup and popup._attentionWatch == watch then
            renderAttentionPopup(root);
        end
    end
    watch.tick = function()
        if sharedFloating.attentionPopup ~= popup or popup._attentionWatch ~= watch
            or popup.isShowing ~= true then return; end
        if popup._attentionProgressCycle == nil then refresh(); return; end
        local tick = updateAttentionProgress(popup, getAttentionTimestamp(root));
        watch.elapsedMs = (watch.elapsedMs or 0) + watch.intervalMs;
        -- Animate only the small fill. Rebuild rows at a charge boundary or
        -- the existing one-second refresh, never for each animation frame.
        if tick ~= watch.progressTick or watch.elapsedMs >= 1000 then
            watch.progressTick, watch.elapsedMs = tick, 0;
            refresh();
        end
    end;
    local function changed()
        if watch.pending ~= nil then return; end
        watch.pending = setTimeout(function() watch.pending = nil; refresh(); end, 1);
    end
    for _, event in ipairs({"onDeepChanged", "onDeepChildAdded", "onDeepChildRemoved"}) do
        watch.listeners[#watch.listeners + 1] = watch.observer:addEventListener(event, changed);
    end
end

local function newAttentionIconButton(parent, pathData, color, hint, callback)
    local button = gui.newButton();
    button.parent = parent;
    button.align = "none";
    button.top = 0;
    button.width = ATTENTION_BUTTON_WIDTH;
    button.height = ATTENTION_HEADER_HEIGHT;
    button.text = "";
    button.hitTest = true;
    button.hint = hint;
    button.onClick = callback;

    local icon = gui.newPath();
    icon.parent = button;
    icon.align = "none";
    icon.left = (ATTENTION_BUTTON_WIDTH - 16) / 2;
    icon.top = 6;
    icon.width = 16;
    icon.height = 16;
    icon.pathData = pathData;
    icon.mode = "fit";
    icon.color = "transparent";
    icon.strokeColor = color;
    icon.strokeSize = 2;
    icon.hitTest = false;
    return button;
end

local function createAttentionPopup(root)
    local popup = gui.newPopupForm();
    popup._cardMargin = FLOATING_PADDING;
    popup._attentionRoot = root;
    applyAttentionPopupSize(popup);
    popup.drawContainer = false;
    pcall(function()
        popup.backOpacity = 0;
    end);
    popup.cancelable = false;
    popup.resizable = false;
    popup.movable = true;
    popup.hitTest = false;
    popup.placement = ATTENTION_POPUP_PLACEMENT;
    popup._dynamicCtrls = {};
    setPopupTopmost(popup);

    local card = gui.newRectangle();
    card.parent = popup;
    card.align = "none";
    card.left = FLOATING_PADDING;
    card.top = FLOATING_PADDING;
    card.width = ATTENTION_POPUP_WIDTH;
    card.height = ATTENTION_POPUP_FIXED_HEIGHT;
    popup._fixedSizeCard = card;
    card.color = "#181C21";
    card.strokeColor = "#D7A84B";
    card.strokeSize = 1;
    card.xradius = 6;
    card.yradius = 6;
    card.hitTest = false;
    registerPopupControl(popup, card);

    local dragHandle = gui.newLabel();
    dragHandle.parent = card;
    dragHandle.align = "none";
    dragHandle.left = FLOATING_PADDING;
    dragHandle.top = FLOATING_PADDING;
    dragHandle.width = ATTENTION_POPUP_WIDTH - 2 * FLOATING_PADDING - 20;
    dragHandle.height = ATTENTION_DRAG_HANDLE_HEIGHT;
    dragHandle.text = "≡";
    dragHandle.hint = "Arraste para mover";
    dragHandle.fontSize = 11;
    dragHandle.fontStyle = "bold";
    dragHandle.fontColor = "#AEB8C4";
    dragHandle.horzTextAlign = "center";
    dragHandle.vertTextAlign = "center";
    dragHandle.textTrimming = "character";
    dragHandle.cursor = "drag";
    -- Deixa o mouse chegar ao container movel do Firecast, como no fundo.
    -- Botões e edicao continuam capturando seus proprios cliques.
    dragHandle.hitTest = false;

    local closeButton = gui.newButton();
    closeButton.parent, closeButton.align = card, "none";
    closeButton.left, closeButton.top = ATTENTION_POPUP_WIDTH - FLOATING_PADDING - 18, FLOATING_PADDING;
    closeButton.width, closeButton.height = 18, ATTENTION_DRAG_HANDLE_HEIGHT;
    closeButton.text, closeButton.fontSize, closeButton.hitTest = "×", 11, true;
    closeButton.hint = "Fechar atenção neste cliente; reabrir pelos botões do chat";
    closeButton.onClick = function() M.closeAttention(popup._attentionRoot); end;

    local header = gui.newLayout();
    header.parent = card;
    header.align = "none";
    header.left = FLOATING_PADDING;
    header.top = FLOATING_PADDING + ATTENTION_DRAG_HANDLE_HEIGHT + FLOATING_GAP;
    header.width = ATTENTION_POPUP_WIDTH - 2 * FLOATING_PADDING;
    header.height = ATTENTION_HEADER_HEIGHT;
    header.hitTest = false;

    local requestButton = newAttentionIconButton(header,
        "M12 2 L22 21 L2 21 Z M12 8 L12 14 M12 17 L12 18",
        "#FFD86A", "Solicitar atenção", function()
            requestAttention(popup._attentionRoot);
        end);
    requestButton.left = 0;

    local nameEdit = gui.newEdit();
    nameEdit.parent = card;
    nameEdit.align = "none";
    nameEdit.left = FLOATING_PADDING;
    nameEdit.top = header.top + ATTENTION_HEADER_HEIGHT + FLOATING_GAP;
    nameEdit.width = ATTENTION_POPUP_WIDTH - 2 * FLOATING_PADDING;
    nameEdit.height = ATTENTION_NAME_HEIGHT;
    nameEdit.textPrompt = "Nick";
    nameEdit.hint = "Apelido para a atenção; o login do jogador aparece ao lado na lista";
    nameEdit.fontSize = 11;
    nameEdit.fontColor = "#D8E0E8";
    nameEdit.transparent = true;
    nameEdit.hitTest = true;
    nameEdit.horzTextAlign = "center";
    local saveButton = newAttentionIconButton(header,
        "M3 3 L17 3 L21 7 L21 21 L3 21 Z M7 3 L7 9 L16 9 L16 3 M7 21 L7 14 L17 14 L17 21",
        "#D8E0E8", "Salvar nome", function()
            local activeRoot = popup._attentionRoot;

            if activeRoot ~= nil then
                saveAttentionName(activeRoot, nameEdit.text);
            end
        end);
    saveButton.left = ATTENTION_BUTTON_WIDTH + ATTENTION_BUTTON_GAP;

    local clearButton = newAttentionIconButton(header,
        "M3 6 L21 6 M9 6 L9 3 L15 3 L15 6 M6 6 L7 21 L17 21 L18 6 M10 10 L10 17 M14 10 L14 17",
        "#D8E0E8", "Limpar", function()
            local activeRoot = popup._attentionRoot;

            if M.isMaster(activeRoot) then
                clearAllAttention(activeRoot);
            else
                clearOwnAttention(activeRoot);
            end
        end);
    clearButton.left = 2 * (ATTENTION_BUTTON_WIDTH + ATTENTION_BUTTON_GAP);
    sharedFloating.attentionClearButton = clearButton;

    -- Use the existing gap below the name; the card and list keep their size.
    local progressTrack = gui.newRectangle();
    progressTrack.parent, progressTrack.align = card, "none";
    progressTrack.left, progressTrack.top = FLOATING_PADDING, nameEdit.top + nameEdit.height;
    progressTrack.width, progressTrack.height = ATTENTION_POPUP_WIDTH - 2 * FLOATING_PADDING, FLOATING_GAP;
    progressTrack.color, progressTrack.strokeColor, progressTrack.strokeSize = "#3A424D", "transparent", 0;
    progressTrack.hitTest, progressTrack.visible = false, false;
    local progressFill = gui.newRectangle();
    progressFill.parent, progressFill.align = progressTrack, "none";
    progressFill.left, progressFill.top, progressFill.width, progressFill.height = 0, 0, 0, FLOATING_GAP;
    progressFill.color, progressFill.strokeColor, progressFill.strokeSize = "#FFD86A", "transparent", 0;
    progressFill.hitTest, progressFill.visible = false, false;
    popup._attentionProgressTrack, popup._attentionProgressFill = progressTrack, progressFill;

    local listPanel = gui.newScrollBox();
    listPanel.parent = card;
    listPanel.align = "none";
    listPanel.left = FLOATING_PADDING;
    listPanel.top = nameEdit.top + nameEdit.height + FLOATING_GAP;
    listPanel.width = ATTENTION_POPUP_WIDTH - 2 * FLOATING_PADDING;
    listPanel.height = ATTENTION_LIST_VIEWPORT_HEIGHT;
    listPanel.visible = false;
    sharedFloating.attentionListPanel = listPanel;
    sharedFloating.attentionNameEdit = nameEdit;

    popup.onHide = function()
        stopAttentionWatch(popup);
        windowPositions.stop(popup);
        if sharedFloating.attentionPopup == popup then
            sharedFloating.attentionPopup = nil;
            sharedFloating.attentionShowing = false;
            sharedFloating.attentionListPanel = nil;
            sharedFloating.attentionNameEdit = nil;
            sharedFloating.attentionClearButton = nil;
            clearAttentionRows();
            clearPopupControls(popup);

            if popup.handle ~= nil and popup.handle ~= 0 then
                popup:destroy();
            end
        end
    end;

    return popup;
end

renderAttentionPopup = function(root)
    if root == nil then
        return;
    end
    if sharedFloating.attentionRequestedRoot ~= nil and sharedFloating.attentionRequestedRoot ~= root then return; end

    local popup = sharedFloating.attentionPopup;
    if windowPositions.get(root, "attentionClosed") == true then
        if popup ~= nil and popup._attentionRoot == root then popup:close(); end
        return;
    end
    local now = getAttentionTimestamp(root);
    local entries, counts = getAttentionEntries(root, now);

    if popup == nil then
        popup = createAttentionPopup(root);
        sharedFloating.attentionPopup = popup;
    end

    local listPanel = sharedFloating.attentionListPanel;
    popup._attentionRoot = root;
    watchAttention(popup, root);
    local container = getAttentionContainer(root, false);
    popup._attentionProgressCycle = #entries > 0 and
        (tonumber(container ~= nil and container.cicloInicio)
            or tonumber(entries[1].cargaCicloInicio) or tonumber(entries[1].ultimaSolicitacao)) or nil;
    popup._attentionWatch.progressTick = updateAttentionProgress(popup, now);
    setAttentionWatchRate(popup, popup._attentionProgressCycle ~= nil);
    local localKey = getLocalAttentionKey(root);
    local isMaster = M.isMaster(root);
    local mesa = rrpg.getMesaDe(root);
    local players, displayNames = {}, {};
    for _, player in ipairs(mesa ~= nil and mesa.jogadores or {}) do
        players[getPlayerIdentity(player)] = player;
        local login = trimmed(player.login):lower();
        if login ~= "" then players[login] = player; end
    end
    local signature = {localKey, tostring(isMaster), tostring(root)};
    for _, entry in ipairs(entries) do
        displayNames[entry] = getAttentionDisplayName(entry, players);
        signature[#signature + 1] = tostring(entry) .. ":" .. tostring(counts[entry]) .. ":" .. displayNames[entry];
    end
    local ownEntry = findAttentionEntry(root, localKey);
    local ownName = getLocalAttentionName(root);
    if ownEntry ~= nil then local _, nick = getAttentionDisplayName(ownEntry, players); ownName = nick; end
    signature[#signature + 1] = ownName;
    signature = table.concat(signature, "\n");
    if popup._attentionSignature == signature and popup.isShowing == true then return; end
    popup._attentionSignature = signature;

    if listPanel ~= nil then
        listPanel:beginUpdate();
        listPanel.visible = #entries > 0;
    end
    clearAttentionRows();

    if listPanel ~= nil then
        for index, entry in ipairs(entries) do
            local row = gui.newLayout();
            row.parent = listPanel;
            row.align = "none";
            row.left = 0;
            row.top = (index - 1) * (ATTENTION_ROW_HEIGHT + ATTENTION_ROW_SPACING);
            row.width = ATTENTION_POPUP_WIDTH - 2 * FLOATING_PADDING
                - (#entries > ATTENTION_VISIBLE_ROWS and ATTENTION_SCROLLBAR_WIDTH or 0);
            row.height = ATTENTION_ROW_HEIGHT;
            row.hitTest = false;

            local rowBackground = gui.newRectangle();
            rowBackground.parent = row;
            rowBackground.align = "client";
            rowBackground.color = index == 1 and "#3A321C" or "#20262E";
            rowBackground.strokeColor = index == 1 and "#D7A84B" or "#303A46";
            rowBackground.strokeSize = 1;
            rowBackground.xradius = 4;
            rowBackground.yradius = 4;
            rowBackground.hitTest = false;

            local count = counts[entry];
            local fontSize = math.min(ATTENTION_MAX_FONT_SIZE,
                ATTENTION_MIN_FONT_SIZE + math.floor(math.log(count + 1) / math.log(2)));
            local canRemove = isMaster or trimmed(entry.participanteId or entry.jogadorId or entry.id) == localKey;

            if canRemove then
                local remove = gui.newButton();
                remove.parent = row;
                remove.align = "none";
                remove.left = row.width - FLOATING_PADDING - 18;
                remove.top = ATTENTION_ROW_LINE_HEIGHT;
                remove.width = 18;
                remove.height = ATTENTION_ROW_LINE_HEIGHT - FLOATING_PADDING;
                remove.hitTest = true;
                remove.text = "×";
                remove.fontSize = 11;
                remove.hint = isMaster and "Limpar solicitação" or "Retirar minha solicitação";
                remove.onClick = function()
                    if isMaster and trimmed(entry.participanteId or entry.jogadorId or entry.id) ~= localKey then
                        removeAttentionEntry(entry);
                    elseif ndb.testPermission(entry, "write") then
                        entry.contagem = 0;
                    end
                end;
            end

            local countLabel = gui.newLabel();
            countLabel.parent = row;
            countLabel.align = "none";
            countLabel.left = FLOATING_PADDING;
            countLabel.top = ATTENTION_ROW_LINE_HEIGHT;
            countLabel.width = row.width - 2 * FLOATING_PADDING
                - (canRemove and (18 + FLOATING_GAP) or 0);
            countLabel.height = ATTENTION_ROW_LINE_HEIGHT - FLOATING_PADDING;
            countLabel.text = tostring(count) .. "x";
            countLabel.hint = tostring(count) .. " solicitações";
            countLabel.hitTest = true;
            countLabel.fontSize = 10;
            countLabel.fontColor = "#FFD86A";
            countLabel.horzTextAlign = "center";
            countLabel.vertTextAlign = "center";

            local label = gui.newLabel();
            label.parent = row;
            label.align = "none";
            label.left = FLOATING_PADDING;
            label.top = FLOATING_PADDING;
            label.width = row.width - 2 * FLOATING_PADDING;
            label.height = ATTENTION_ROW_LINE_HEIGHT - FLOATING_PADDING;
            label.fontSize = fontSize;
            if index == 1 then
                label.fontStyle = "bold";
            end
            label.fontColor = index == 1 and "#FFD86A" or "#D8E0E8";
            label.text = displayNames[entry];
            label.hint = string.format("%s — %dx", label.text, count);
            label.hitTest = true;
            label.horzTextAlign = "leading";
            label.vertTextAlign = "center";
            label.wordWrap = false;
            label.textTrimming = "character";

            sharedFloating.attentionRows[#sharedFloating.attentionRows + 1] = row;
        end
    end

    if sharedFloating.attentionNameEdit ~= nil then
        local nameEdit = sharedFloating.attentionNameEdit;
        local savedName = ownName;

        if nameEdit._attentionRoot ~= root or nameEdit._attentionSavedName == nil
            or nameEdit.text == nameEdit._attentionSavedName then
            nameEdit.text = savedName;
        end

        nameEdit._attentionRoot = root;
        nameEdit._attentionSavedName = savedName;
    end

    if sharedFloating.attentionClearButton ~= nil then
        sharedFloating.attentionClearButton.hint = isMaster
            and "Limpar todas as solicitações" or "Retirar minha solicitação";
    end

    if listPanel ~= nil then
        listPanel:endUpdate();
        listPanel:needRepaint();
    end

    if popup.isShowing ~= true then
        local shown = showAttentionPopup(popup);

        if shown == false then
            sharedFloating.attentionPopup = nil;
            sharedFloating.attentionShowing = false;

            if popup.handle ~= nil and popup.handle ~= 0 then
                stopAttentionWatch(popup);
                clearAttentionRows();
                clearPopupControls(popup);
                popup:destroy();
            end

            return;
        end
    end

    sharedFloating.attentionShowing = popup.isShowing == true;
end

local function adoptPrimaryFloatingForm(form)
    if form == nil then
        return nil;
    end

    local previous = sharedFloating.primaryForm;

    if previous ~= form then
        if previous ~= nil and sharedFloating.turnPopup ~= nil then
            local fields = {
                "_activeTurnTimerPopup", "_turnTimerCard", "_turnTimerLabel",
                "_turnTimerNameLabel", "_turnTimerFullCaption", "_turnTimerRoot",
                "_turnTimerStateId", "_turnTimerStartedAt", "_turnTimerCompact",
                "_turnTimerIntervalId", "_activeTurnTimerContextPopup",
                "_turnTimerContextRoot", "_turnTimerContextStateId"
            };

            for _, field in ipairs(fields) do
                form[field] = previous[field];
            end
        end

        sharedFloating.primaryForm = form;
    end

    return form;
end

local function updateTurnAccessControls(form, root)
    local isMaster = M.isMaster(root);
    if form.btnIniciativas ~= nil then
        form.btnIniciativas.enabled = isMaster;
        form.btnIniciativas.hint = isMaster and "Iniciativas de todos os participantes"
            or "Somente o mestre pode alterar todas as iniciativas";
    end
    local button = form.btnProximoTurno;
    if button == nil then return; end
    if isMaster then
        form._turnAccessPending = nil;
        form._turnAccessContext = nil;
        button.enabled = true;
        button.hint = "Passar para o próximo turno";
        return;
    end
    local item = findCurrentTurnItem(root);
    local stateId = tostring(root.turnTimerId or "");
    local pending = form._turnAccessPending;
    if pending ~= nil and pending.root == root and pending.item == item
        and pending.stateId == stateId then return; end
    local context = form._turnAccessContext;
    if context == nil or context.root ~= root or context.item ~= item
        or context.stateId ~= stateId then
        button.enabled = false;
        button.hint = "Você pode passar o seu próprio turno";
    end
    form._turnAccessContext = {root = root, item = item, stateId = stateId};
    if item == nil then
        form._turnAccessPending = nil;
        button.enabled = false;
        return;
    end
    pending = {root = root, item = item, stateId = stateId};
    form._turnAccessPending = pending;
    turnAccess.check(root, item, getLocalPlayer(root), function(allowed)
        if form._turnAccessPending ~= pending then return; end
        form._turnAccessPending = nil;
        if sharedFloating.forms[form] ~= root or findCurrentTurnItem(root) ~= item
            or tostring(root.turnTimerId or "") ~= stateId then return; end
        button.enabled = allowed == true;
        button.hint = allowed == true and "Encerrar o meu turno"
            or "Você pode passar o seu próprio turno";
    end);
end

local function processTurnRequests(root)
    turnRequests.configure(root);
    turnRequests.process(root, turnAccess.check, function()
        M.nextTurn(root);
    end);
end

local function attachFloatingRoot(form, root)
    if form == nil or root == nil then
        return;
    end

    sharedFloating.forms[form] = root;
    adoptPrimaryFloatingForm(form);
    sharedFloating.activeRoot = root;

    local record = sharedFloating.roots[root];

    if record == nil then
        record = {forms = setmetatable({}, {__mode = "k"})};
        record.observer = ndb.newObserver(root);
        record.listenerIds = {};
        local function changed()
            if record.refreshScheduled == true then
                return;
            end

            record.refreshScheduled = true;
            setTimeout(function()
                record.refreshScheduled = false;

                if sharedFloating.activeRoot == root and refreshFloatingRoot ~= nil then
                    refreshFloatingRoot(root);
                end
            end, 1);
        end
        record.listenerIds[#record.listenerIds + 1] = record.observer:addEventListener("onDeepChanged", changed);
        record.listenerIds[#record.listenerIds + 1] = record.observer:addEventListener("onDeepChildAdded", changed);
        record.listenerIds[#record.listenerIds + 1] = record.observer:addEventListener("onDeepChildRemoved", changed);
        sharedFloating.roots[root] = record;
        record.turnRequestIntervalId = setInterval(function()
            if sharedFloating.roots[root] ~= record then return; end
            processTurnRequests(root);
            for currentForm in pairs(record.forms) do
                updateTurnAccessControls(currentForm, root);
            end
        end, 1000);
    end

    record.forms[form] = true;
    refreshFloatingRoot(root);
end

local function detachFloatingForm(form)
    local root = sharedFloating.forms[form];
    sharedFloating.forms[form] = nil;

    if root ~= nil then
        local record = sharedFloating.roots[root];

        if record ~= nil then
            record.forms[form] = nil;
            local hasForm = false;

            for _ in pairs(record.forms) do
                hasForm = true;
                break
            end

            if not hasForm then
                turnRequests.stop(root);
                if record.turnRequestIntervalId ~= nil then
                    clearInterval(record.turnRequestIntervalId);
                    record.turnRequestIntervalId = nil;
                end
                if record.observer ~= nil then
                    for _, listenerId in ipairs(record.listenerIds or {}) do
                        record.observer:removeEventListener(listenerId);
                    end
                end

                sharedFloating.roots[root] = nil;
            end
        end
    end

    if sharedFloating.primaryForm == form then
        sharedFloating.primaryForm = nil;

        for candidate, candidateRoot in pairs(sharedFloating.forms) do
            sharedFloating.primaryForm = candidate;
            sharedFloating.activeRoot = candidateRoot;
            break
        end
    end

    local hasAnyForm = false;

    for _ in pairs(sharedFloating.forms) do
        hasAnyForm = true;
        break
    end

    if not hasAnyForm then
        stopLocalTurnTimer(form);

        if sharedFloating.attentionPopup ~= nil
            and sharedFloating.attentionRequestedRoot ~= sharedFloating.attentionPopup._attentionRoot then
            windowPositions.stop(sharedFloating.attentionPopup, true);
            sharedFloating.attentionPopup:close();
        end

        sharedFloating.activeRoot = nil;
        sharedFloating.primaryForm = nil;
    elseif sharedFloating.activeRoot ~= nil then
        refreshFloatingRoot(sharedFloating.activeRoot);
    end
end

refreshFloatingRoot = function(root)
    if root == nil then
        return;
    end

    local positionStore = windowPositions.ensure(root, function()
        if sharedFloating.activeRoot == root then refreshFloatingRoot(root); end
    end);
    local form = adoptPrimaryFloatingForm(sharedFloating.primaryForm);

    if not positionStore.ready then
        -- Nao deixa botoes/lista da mesa anterior atuarem na nova mesa
        -- enquanto as preferencias individuais ainda estao carregando.
        local popup = sharedFloating.attentionPopup;
        if popup ~= nil and popup._attentionRoot ~= root then
            windowPositions.stop(popup, true);
            popup:close();
        end
        if form ~= nil and form._turnTimerRoot ~= root then
            stopLocalTurnTimer(form);
        end
        return;
    end

    configureAttentionPermissions(root);
    processTurnRequests(root);
    local record = sharedFloating.roots[root];
    if record ~= nil then
        for currentForm in pairs(record.forms) do
            updateTurnAccessControls(currentForm, root);
        end
    end

    if form ~= nil then
        syncLocalTurnTimer(form, root);
    end

    renderAttentionPopup(root);
end

function M.onNodeReady(form, sheet)
    M.onNodeUnready(form);
    turnRequests.configure(sheet);
    configureAttentionPermissions(sheet);
    if not M.isMaster(sheet) then
        attachFloatingRoot(form, sheet);
        return;
    end
    -- Somente o mestre inicializa/migra o estado compartilhado. Um jogador
    -- nao pode gerar um turnTimerId local diferente do que esta no servidor.
    M.ensureRootDefaults(sheet);
    local currentTurnItem = nil;

    for _, node in ipairs(M.getAllNodes(sheet)) do
        if M.isGroupNode(node) and node.grupoAtivo == nil then
            node.grupoAtivo = true;
        end

        if M.isGroupNode(node) and trimmed(node.grupoCor) == "" then
            node.grupoCor = getDefaultGroupColor(node.ordemGrupo);
        end

        if M.isItemNode(node) and tostring(node.itemId or "") == "" then
            sheet.proximoItemId = (tonumber(sheet.proximoItemId) or 0) + 1;
            node.itemId = tostring(sheet.proximoItemId);
        end

        if M.isItemNode(node) then
            M.normalizeTemporaries(node);

            if node.ocultacaoEstado == nil then
                node.ocultacaoEstado = 0;
            end

            if node.turnoAtual == true and currentTurnItem == nil then
                currentTurnItem = node;
            end
        end
    end

    local timerStateIsValid = tostring(sheet.turnTimerId or "") ~= ""
        and trimmed(sheet.turnTimerName) ~= ""
        and (tonumber(sheet.turnTimerStartedAt) or 0) > 0;
    local legacyStateIsValid = tostring(sheet.turnToastId or "") ~= ""
        and trimmed(sheet.turnToastName) ~= ""
        and (tonumber(sheet.turnToastStartedAt) or 0) > 0;
    local timerStateMatchesCurrent = false;

    if currentTurnItem ~= nil and timerStateIsValid then
        local currentItemId = tostring(currentTurnItem.itemId or "");
        local timerItemId = tostring(sheet.turnTimerItemId or "");
        local currentTurnName = trimmed(currentTurnItem.nome);

        if currentTurnName == "" then
            currentTurnName = "Sem nome";
        end

        timerStateMatchesCurrent = (timerItemId ~= "" and timerItemId == currentItemId)
            or (timerItemId == "" and trimmed(sheet.turnTimerName) == currentTurnName);
    end

    if timerStateMatchesCurrent and M.isMaster(sheet) and trimmed(sheet.turnChatCaption) == "" then
        sheet.turnChatCaption = "Turno de " .. M.getPublicItemName(currentTurnItem);
        sheet.turnChatAnnouncedId = tostring(sheet.turnTimerId);
    end

    if currentTurnItem ~= nil and (not timerStateMatchesCurrent or legacyStateIsValid) then
        local migratedStartedAt = 0;

        if legacyStateIsValid then
            migratedStartedAt = tonumber(sheet.turnToastStartedAt) or 0;
        end

        if migratedStartedAt <= 0 then
            migratedStartedAt = getCurrentTurnTimestamp(sheet);
        end

        publishTurnTimerState(sheet, currentTurnItem, {
            startedAt = migratedStartedAt,
            preserveChat = true
        });
    elseif currentTurnItem == nil and (timerStateIsValid or tostring(sheet.turnToastId or "") ~= "") then
        publishTurnTimerState(sheet, nil, {preserveChat = true});
    end

    attachFloatingRoot(form, sheet);
end

function M.onNodeUnready(form)
    if form ~= nil and form._activeToolbarPopup ~= nil then
        closePopup(form._activeToolbarPopup);
        form._activeToolbarPopup = nil;
    end

    if form ~= nil then
        form._turnAccessPending = nil;
        form._turnAccessContext = nil;
        detachFloatingForm(form);
    end
end

function M.onFormShow(form, sheet)
    if form ~= nil and sheet ~= nil then
        if sharedFloating.forms[form] == nil then
            attachFloatingRoot(form, sheet);
        else
            sharedFloating.activeRoot = sheet;
            adoptPrimaryFloatingForm(form);
            refreshFloatingRoot(sheet);
        end
    end
end

closePopup = function(popup)
    if popup ~= nil then
        popup:close(false, true);
    end
end

local function showToolbarPopup(form, control, width, entries, placement)
    if form == nil then
        return nil;
    end

    closeLocalTurnTimerContextMenu(form);

    if form._activeToolbarPopup ~= nil then
        closePopup(form._activeToolbarPopup);
        form._activeToolbarPopup = nil;
    end

    local popup = gui.newPopup();
    popup.parent = form;
    popup.width = math.max(CONTEXT_MENU_WIDTH, tonumber(width) or CONTEXT_MENU_WIDTH);
    popup.height = (#entries * (POPUP_ROW_HEIGHT + POPUP_ROW_SPACING)) + 4;
    popup.cancelable = true;
    popup.drawContainer = true;
    popup.backOpacity = 0;
    popup.onClose = function()
        if form._activeToolbarPopup == popup then
            form._activeToolbarPopup = nil;
        end
    end;

    for index, entry in ipairs(entries) do
        local button = gui.newButton();
        button.parent = popup;
        button.align = "top";
        button.height = POPUP_ROW_HEIGHT;
        button.text = tostring(entry.text or "");

        if index < #entries then
            button.margins = {bottom = POPUP_ROW_SPACING};
        end

        button.onClick = function()
            closePopup(popup);

            if type(entry.onClick) == "function" then
                entry.onClick();
            end
        end;
    end

    form._activeToolbarPopup = popup;

    if control ~= nil then
        popup:show(placement or "bottom", control);
    else
        popup:show(placement or "mouse");
    end

    return popup;
end

function M.openTurnTimerContextMenu(form)
    if form == nil or form._activeTurnTimerPopup == nil then
        return;
    end

    closeLocalTurnTimerContextMenu(form);

    if form._activeToolbarPopup ~= nil then
        closePopup(form._activeToolbarPopup);
        form._activeToolbarPopup = nil;
    end

    local contextRoot = form._turnTimerRoot;
    local contextStateId = tostring(form._turnTimerStateId or "");
    local sizeOptionText = form._turnTimerCompact == true
        and "Restaurar tamanho"
        or "Diminuir tamanho";

    local contextMenu = gui.newPopupForm();
    contextMenu._cardMargin = FLOATING_PADDING;
    local contextHeight = 2 * FLOATING_PADDING + 2 * POPUP_ROW_HEIGHT + FLOATING_GAP;
    applyFloatingPopupSize(contextMenu, CONTEXT_MENU_WIDTH, contextHeight);
    contextMenu.drawContainer = false;
    pcall(function()
        contextMenu.backOpacity = 0;
    end);
    contextMenu.cancelable = true;
    contextMenu.resizable = false;
    contextMenu.movable = false;
    contextMenu.hitTest = false;
    contextMenu.placement = "mouse";
    contextMenu._dynamicCtrls = {};

    local card = gui.newRectangle();
    card.parent = contextMenu;
    card.align = "none";
    card.left = FLOATING_PADDING;
    card.top = FLOATING_PADDING;
    card.width = CONTEXT_MENU_WIDTH;
    card.height = contextHeight;
    contextMenu._fixedSizeCard = card;
    card.color = "#181C21";
    card.strokeColor = "#63F28E";
    card.strokeSize = 1;
    card.xradius = 5;
    card.yradius = 5;
    card.hitTest = false;
    registerPopupControl(contextMenu, card);

    local btnDismiss = gui.newButton();
    btnDismiss.parent = card;
    btnDismiss.align = "none";
    btnDismiss.left = FLOATING_PADDING;
    btnDismiss.top = FLOATING_PADDING;
    btnDismiss.width = CONTEXT_MENU_WIDTH - 2 * FLOATING_PADDING;
    btnDismiss.height = POPUP_ROW_HEIGHT;
    btnDismiss.text = "Fechar até o próximo turno";
    btnDismiss.onClick = function()
        closeLocalTurnTimerContextMenu(form);

        if form._turnTimerRoot == contextRoot
            and tostring(form._turnTimerStateId or "") == contextStateId then
            dismissLocalTurnTimerUntilNextTurn(form);
        end
    end;

    local btnSize = gui.newButton();
    btnSize.parent = card;
    btnSize.align = "none";
    btnSize.left = FLOATING_PADDING;
    btnSize.top = FLOATING_PADDING + POPUP_ROW_HEIGHT + FLOATING_GAP;
    btnSize.width = CONTEXT_MENU_WIDTH - 2 * FLOATING_PADDING;
    btnSize.height = POPUP_ROW_HEIGHT;
    btnSize.text = sizeOptionText;
    btnSize.onClick = function()
        closeLocalTurnTimerContextMenu(form);
        toggleLocalTurnTimerSize(form);
    end;

    contextMenu.onHide = function()
        if form._activeTurnTimerContextPopup == contextMenu then
            form._activeTurnTimerContextPopup = nil;
            form._turnTimerContextRoot = nil;
            form._turnTimerContextStateId = nil;
        end

        destroyLocalTurnTimerContextPopup(contextMenu);
    end;

    form._activeTurnTimerContextPopup = contextMenu;
    form._turnTimerContextRoot = contextRoot;
    form._turnTimerContextStateId = contextStateId;

    local wasShown = gui.showPopup(contextMenu, {placement = "mouse"});

    if wasShown == false then
        if form._activeTurnTimerContextPopup == contextMenu then
            form._activeTurnTimerContextPopup = nil;
            form._turnTimerContextRoot = nil;
            form._turnTimerContextStateId = nil;
        end

        destroyLocalTurnTimerContextPopup(contextMenu);
        return nil;
    end

    return contextMenu;
end

local function showCustomPopup(form, control, width, placement, builder, options)
    if form == nil then
        return nil;
    end

    closeLocalTurnTimerContextMenu(form);

    if form._activeToolbarPopup ~= nil then
        closePopup(form._activeToolbarPopup);
        form._activeToolbarPopup = nil;
    end

    local popup = gui.newPopup();
    popup.parent = form;
    popup.width = width or 180;
    popup.height = POPUP_ROW_HEIGHT + 8;
    popup.cancelable = not (options ~= nil and options.cancelable == false);
    popup.drawContainer = not (options ~= nil and options.drawContainer == false);
    popup.backOpacity = tonumber(options ~= nil and options.backOpacity) or 0;
    popup.onClose = function()
        if popup._autoCloseTimeoutId ~= nil then
            clearTimeout(popup._autoCloseTimeoutId);
            popup._autoCloseTimeoutId = nil;
        end

        clearPopupControls(popup);

        if form._activeToolbarPopup == popup then
            form._activeToolbarPopup = nil;
        end
    end;

    popup._dynamicCtrls = {};

    if type(builder) == "function" then
        builder(popup);
    end

    if options ~= nil and tonumber(options.autoCloseMs) ~= nil and tonumber(options.autoCloseMs) > 0 then
        popup._autoCloseTimeoutId = setTimeout(
            function(currentPopup)
                if currentPopup ~= nil then
                    closePopup(currentPopup);
                end
            end,
            tonumber(options.autoCloseMs),
            popup);
    end

    form._activeToolbarPopup = popup;

    local finalPlacement = options ~= nil and tostring(options.placement or "") or "";

    if finalPlacement == "" then
        finalPlacement = placement or "bottom";
    end

    local targetControl = control;

    if options ~= nil and options.ignoreControl == true then
        targetControl = nil;
    end

    if targetControl ~= nil then
        popup:show(finalPlacement, targetControl);
    else
        popup:show(finalPlacement);
    end

    return popup;
end

local function buildHistoryPopup(form, popup, root)
    clearPopupControls(popup);

    if not M.isMaster(root) then
        local restricted = gui.newLabel();
        restricted.parent = popup;
        restricted.align = "top";
        restricted.height = POPUP_ROW_HEIGHT;
        restricted.text = "Histórico disponível para o mestre";
        restricted.horzTextAlign = "center";
        restricted.vertTextAlign = "center";
        registerPopupControl(popup, restricted);
        setPopupRowsHeight(popup, 1);
        return;
    end

    local entries = getItemHistoryEntries(root);

    if #entries == 0 then
        local label = gui.newLabel();
        label.parent = popup;
        label.align = "top";
        label.height = POPUP_ROW_HEIGHT;
        label.text = "Nenhum historico";
        label.horzTextAlign = "center";
        label.vertTextAlign = "center";
        registerPopupControl(popup, label);
        setPopupRowsHeight(popup, 1);
        return;
    end

    for index, entry in ipairs(entries) do
        local row = gui.newLayout();
        row.parent = popup;
        row.align = "top";
        row.height = POPUP_ROW_HEIGHT;

        if index < #entries then
            row.margins = {bottom = POPUP_ROW_SPACING};
        end

        registerPopupControl(popup, row);

        local btnDelete = gui.newButton();
        btnDelete.parent = row;
        btnDelete.align = "right";
        btnDelete.width = 26;
        btnDelete.text = "X";
        btnDelete.hint = "Excluir do historico";
        btnDelete.margins = {left = 4};
        btnDelete.onClick = function()
            M.deleteItemHistoryEntry(entry);
            buildHistoryPopup(form, popup, root);
        end;

        local button = gui.newButton();
        button.parent = row;
        button.align = "client";
        button.text = string.format("%s | Init %s | %s",
            tostring(entry.nome or "Sem nome"),
            tostring(entry.iniciativa or 0),
            trimmed(entry.teste) ~= "" and tostring(entry.teste) or "-");
        button.onClick = function()
            closePopup(popup);
            M.addItem(form, root, {
                nome = entry.nome,
                iniciativa = entry.iniciativa,
                teste = entry.teste,
                saveToHistory = false
            });
        end;
    end

    setPopupRowsHeight(popup, #entries);
end

local function buildColorPopup(popup, options)
    clearPopupControls(popup);

    local rows = {};
    local totalRows = math.ceil(#options / COLOR_SWATCH_COLUMNS);

    for index, option in ipairs(options) do
        local rowIndex = math.ceil(index / COLOR_SWATCH_COLUMNS);
        local row = rows[rowIndex];

        if row == nil then
            row = gui.newLayout();
            row.parent = popup;
            row.align = "top";
            row.height = COLOR_SWATCH_SIZE;

            if rowIndex < totalRows then
                row.margins = {bottom = COLOR_SWATCH_SPACING};
            end

            rows[rowIndex] = row;
            registerPopupControl(popup, row);
        end

        local slot = gui.newLayout();
        slot.parent = row;
        slot.align = "left";
        slot.width = COLOR_SWATCH_SIZE;

        if (index % COLOR_SWATCH_COLUMNS) ~= 0 and index < #options then
            slot.margins = {right = COLOR_SWATCH_SPACING};
        end

        local swatch = gui.newRectangle();
        swatch.parent = slot;
        swatch.align = "client";
        swatch.color = normalizeColor(option.color, DEFAULT_ITEM_COLOR);
        swatch.strokeSize = option.selected == true and 2 or 1;
        swatch.strokeColor = option.selected == true and "#FFFFFF" or "#111111";
        swatch.xradius = 0;
        swatch.yradius = 0;
        swatch.hitTest = true;
        swatch.cursor = "handPoint";
        swatch.hint = tostring(option.name or option.color or "");
        swatch.onClick = function()
            closePopup(popup);

            if type(option.onClick) == "function" then
                option.onClick();
            end
        end;
    end

    setColorPopupHeight(popup, #options);
end

getPlayerDisplayName = function(player)
    if player == nil then
        return "Sem nome";
    end

    local principalId = tonumber(player.personagemPrincipal);

    if principalId ~= nil and principalId > 0 then
        local personagem = nil;
        local mesa = player.mesa;

        if mesa ~= nil and mesa.findBibliotecaItem ~= nil then
            personagem = mesa:findBibliotecaItem(principalId);
        end

        local characterName = "";

        if personagem ~= nil then
            characterName = trimmed(personagem.nome or personagem.name);
        end

        if characterName ~= "" then
            return characterName;
        end
    end

    local nick = trimmed(player.nick);

    if nick ~= "" then
        return nick;
    end

    local login = trimmed(player.login);

    if login ~= "" then
        return login;
    end

    return "Sem nome";
end

function M.addAllPlayers(form, root)
    if root == nil then
        return;
    end

    local mesa = rrpg.getMesaDe(root);

    if mesa == nil then
        dialogs.alert("Nao foi possivel localizar a mesa.");
        return;
    end

    local players = mesa.jogadores or {};
    local existingNames = {};
    local added = 0;

    for _, node in ipairs(M.getAllNodes(root)) do
        if M.isItemNode(node) then
            existingNames[trimmed(node.nome):lower()] = true;
        end
    end

    table.sort(players,
        function(a, b)
            return getPlayerDisplayName(a):lower() < getPlayerDisplayName(b):lower();
        end);

    for _, player in ipairs(players) do
        local playerName = trimmed(getPlayerDisplayName(player));
        local key = playerName:lower();

        if playerName ~= "" and existingNames[key] ~= true then
            M.addItem(form, root, {nome = playerName, personagemId = player.personagemPrincipal,
                saveToHistory = false});
            existingNames[key] = true;
            added = added + 1;
        end
    end

    if added == 0 then
        dialogs.alert("Nenhum jogador novo para adicionar.");
    end
end

function M.openItemHistoryMenu(form, root, control)
    showCustomPopup(form, control, 340, "bottom",
        function(popup)
            buildHistoryPopup(form, popup, root);
        end);
end

function M.openToolbarGroupMenu(form, root, control)
    showToolbarPopup(form, control, 160, {
        {
            text = "Criar Grupo",
            onClick = function()
                M.createGroupFromForm(form, root);
            end
        }
    }, "bottom");
end

function M.openToolbarAddMenu(form, root, control)
    showToolbarPopup(form, control, 180, {
        {
            text = "Novo Item",
            onClick = function()
                M.addItem(form, root);
            end
        },
        {
            text = "Todos os Jogadores",
            onClick = function()
                M.addAllPlayers(form, root);
            end
        },
        {
            text = "Historico",
            onClick = function()
                M.openItemHistoryMenu(form, root, control);
            end
        },
        {
            text = "Apagar Tudo",
            onClick = function()
                M.clearAllItems(form, root);
            end
        }
    }, "bottom");
end

function M.openToolbarInitiativesMenu(form, root, control)
    if root == nil or not M.isMaster(root) then return; end
    showToolbarPopup(form, control, 180, {
        {
            text = "Rolar Tudo",
            onClick = function()
                M.rollAllInitiatives(form, root);
            end
        },
        {
            text = "Apagar Tudo",
            onClick = function()
                M.clearAllInitiatives(form, root);
            end
        }
    }, "bottom");
end

function M.openGroupColorMenu(form, groupNode)
    local currentColor = M.getGroupColor(groupNode);
    local options = {};

    for _, option in ipairs(GROUP_COLOR_OPTIONS) do
        options[#options + 1] = {
            name = option.name,
            color = option.color,
            selected = (normalizeColor(option.color, DEFAULT_ITEM_COLOR) == currentColor),
            onClick = function()
                M.setGroupColor(groupNode, option.color);
            end
        };
    end

    showCustomPopup(form, nil, getColorPopupWidth(#options), "mouse",
        function(popup)
            buildColorPopup(popup, options);
        end);
end

function M.openItemColorMenu(form, itemNode)
    local root = ndb.getRoot(itemNode);
    local customColor = trimmed(M.getItemCustomColor(itemNode));
    local options = {
        {
            name = "Cor do grupo",
            color = M.getItemColor(root, itemNode),
            selected = (customColor == ""),
            onClick = function()
                M.clearItemColor(itemNode);
            end
        }
    };

    for _, option in ipairs(GROUP_COLOR_OPTIONS) do
        options[#options + 1] = {
            name = option.name,
            color = option.color,
            selected = (customColor ~= "" and normalizeColor(option.color, DEFAULT_ITEM_COLOR) == customColor),
            onClick = function()
                M.setItemColor(itemNode, option.color);
            end
        };
    end

    showCustomPopup(form, nil, getColorPopupWidth(#options), "mouse",
        function(popup)
            buildColorPopup(popup, options);
        end);
end

function M.createGroup(root, customName)
    M.ensureRootDefaults(root);

    local listNode = ensureListNode(root);
    local groupName = trimmed(customName);
    local defaultGroupNumber = #M.getGroupHeaders(root) + 1;
    root.proximoGrupoId = (tonumber(root.proximoGrupoId) or 0) + 1;
    root.proximaOrdemGrupo = (tonumber(root.proximaOrdemGrupo) or 0) + 1;

    if groupName == "" then
        groupName = "Grupo " .. tostring(defaultGroupNumber);
    end

    local groupNode = ndb.createChildNode(listNode, "item");
    groupNode.tipo = "grupo";
    groupNode.grupoId = tostring(root.proximoGrupoId);
    groupNode.ordemGrupo = root.proximaOrdemGrupo;
    groupNode.grupoAtivo = true;
    groupNode.grupoCor = getDefaultGroupColor(groupNode.ordemGrupo);
    groupNode.nomeGrupo = groupName;

    return groupNode;
end

function M.createGroupFromForm(form, root)
    local group = M.createGroup(root);
    M.redrawList(form);
    return group;
end

function M.addItem(form, root, itemData)
    local listNode = ensureListNode(root);
    local itemNode = ndb.createChildNode(listNode, "item");
    local data = itemData or {};

    M.ensureRootDefaults(root);
    root.proximoItemId = (tonumber(root.proximoItemId) or 0) + 1;

    itemNode.tipo = "item";
    itemNode.itemId = tostring(root.proximoItemId);
    itemNode.teste = tostring(data.teste or itemNode.teste or "");
    itemNode.nome = tostring(data.nome or itemNode.nome or "");
    local characterId = tonumber(data.personagemId);
    if characterId ~= nil and characterId > 0 then
        itemNode.personagemId = characterId;
    end
    itemNode.iniciativa = tonumber(data.iniciativa);

    if itemNode.iniciativa == nil then
        itemNode.iniciativa = tonumber(itemNode.iniciativa) or 0;
    end

    itemNode.turnoAtual = false;

    if data.grupoId ~= nil and tostring(data.grupoId) ~= "" then
        itemNode.grupoId = tostring(data.grupoId);
    else
        itemNode.grupoId = nil;
    end

    if data.saveToHistory ~= false then
        M.saveItemHistoryData(root, itemNode.nome, itemNode.iniciativa, itemNode.teste);
    end

    M.redrawList(form);
    return itemNode;
end

function M.getGroupedTurnItems(root)
    local ordered = {};
    local usedGroupIds = {};

    for _, group in ipairs(M.getGroupHeaders(root)) do
        usedGroupIds[tostring(group.grupoId or "")] = true;
    end

    for _, node in ipairs(M.getOrderedListNodes(root)) do
        if M.isItemNode(node) then
            local groupId = tostring(node.grupoId or "");
            local group = M.getGroupById(root, groupId);

            if groupId == "" or not usedGroupIds[groupId] or M.isGroupActive(group) then
                ordered[#ordered + 1] = node;
            end
        end
    end

    return ordered;
end

function M.markTurn(itemNode)
    if itemNode == nil then return; end
    local root = ndb.getRoot(itemNode);

    if root == nil then
        return;
    end
    if not M.isMaster(root) then
        if itemNode.turnoAtual == true then M.nextTurn(root); end
        return;
    end

    for _, node in ipairs(M.getAllNodes(root)) do
        if M.isItemNode(node) then
            node.turnoAtual = (node == itemNode);
        else
            node.turnoAtual = false;
        end
    end

    publishTurnTimerState(root, itemNode);
    publishTurnChatMessage(root, itemNode);
end

function M.deleteItem(itemNode)
    if itemNode == nil then
        return;
    end

    local root = ndb.getRoot(itemNode);
    local wasCurrentTurn = itemNode.turnoAtual == true;

    if wasCurrentTurn and root ~= nil then
        publishTurnTimerState(root, nil);
    end

    ndb.deleteNode(itemNode);
end

function M.decrementTemporary(itemNode)
    if itemNode == nil then
        return;
    end

    local expired = {};
    local itemName = tostring(itemNode.nome or "Sem nome");

    for _, entry in ipairs(M.getTemporaryEntries(itemNode)) do
        local count = tonumber(entry.contagem);

        if count ~= nil and count > 0 then
            count = count - 1;
            entry.contagem = count;

            if count <= 0 then
                expired[#expired + 1] = trimmed(entry.nome);
            end
        end
    end

    for _, effectName in ipairs(expired) do
        local effectNode = nil;

        for _, entry in ipairs(M.getTemporaryEntries(itemNode)) do
            if trimmed(entry.nome) == effectName and (tonumber(entry.contagem) or 0) <= 0 then
                effectNode = entry;
                break
            end
        end

        if effectNode ~= nil then
            ndb.deleteNode(effectNode);
        end

        if effectName == "" then
            dialogs.alert("O efeito temporario de " .. itemName .. " acabou.");
        else
            dialogs.alert("O efeito " .. effectName .. " de " .. itemName .. " acabou.");
        end
    end
end

function M.clearTemporary(itemNode)
    if itemNode == nil then
        return;
    end

    itemNode.efeitoTemporarioNome = "";
    itemNode.efeitoTemporarioContagem = 0;

    for _, entry in ipairs(M.getTemporaryEntries(itemNode)) do
        ndb.deleteNode(entry);
    end
end

function M.nextTurn(root)
    if root == nil then return; end
    if not M.isMaster(root) then
        local current = findCurrentTurnItem(root);
        local stateId = tostring(root.turnTimerId or "");
        if current == nil then return; end
        turnAccess.check(root, current, getLocalPlayer(root), function(allowed)
            local trackerRecord = sharedFloating.roots[root];
            if trackerRecord == nil or next(trackerRecord.forms) == nil then return; end
            if findCurrentTurnItem(root) ~= current
                or tostring(root.turnTimerId or "") ~= stateId then return; end
            if allowed ~= true then
                dialogs.alert("Você só pode passar o seu próprio turno ou o de uma ficha compartilhada com você.");
                return;
            end
            local sent, reason = turnRequests.request(root, current, function(accepted, message)
                local record = sharedFloating.roots[root];
                if accepted ~= true and record ~= nil and next(record.forms) ~= nil then
                    dialogs.alert(message or "Não foi possível confirmar a passagem do turno.");
                end
            end);
            if sent ~= true then
                dialogs.alert(reason or "Não foi possível solicitar a passagem do turno.");
            end
        end);
        return;
    end
    local ordered = M.getGroupedTurnItems(root);

    if #ordered == 0 then
        publishTurnTimerState(root, nil);
        return;
    end

    local currentIndex = nil;

    for i, node in ipairs(ordered) do
        if node.turnoAtual == true then
            currentIndex = i;
            break
        end
    end

    local nextIndex = 1;

    if currentIndex ~= nil then
        M.decrementTemporary(ordered[currentIndex]);
        nextIndex = currentIndex + 1;

        if nextIndex > #ordered then
            nextIndex = 1;
            root.rodada = (tonumber(root.rodada) or 1) + 1;
        end
    end

    M.markTurn(ordered[nextIndex]);
end

function M.deleteGroup(groupNode)
    local root = ndb.getRoot(groupNode);

    if root == nil then
        return;
    end

    local groupId = tostring(groupNode.grupoId or "");

    for _, node in ipairs(M.getAllNodes(root)) do
        if M.isItemNode(node) and tostring(node.grupoId or "") == groupId then
            node.grupoId = nil;
        end
    end

    ndb.deleteNode(groupNode);
end

function M.onGroupActiveChange(groupNode)
    if groupNode == nil then
        return;
    end

    local root = ndb.getRoot(groupNode);

    if root == nil then
        return;
    end

    if not M.isGroupActive(groupNode) then
        local groupId = tostring(groupNode.grupoId or "");
        local removedCurrentTurn = false;

        for _, node in ipairs(M.getAllNodes(root)) do
            if M.isItemNode(node)
                and tostring(node.grupoId or "") == groupId
                and node.turnoAtual == true then
                node.turnoAtual = false;
                removedCurrentTurn = true;
            end
        end

        if removedCurrentTurn then
            publishTurnTimerState(root, nil);
        end
    end
end

function M.moveItemToGroup(itemNode, groupNode)
    if itemNode == nil then
        return;
    end

    if groupNode == nil then
        itemNode.grupoId = nil;
        return;
    end

    itemNode.grupoId = groupNode.grupoId;
end

function M.findItemById(root, itemId)
    local itemIdText = tostring(itemId or "");

    for _, node in ipairs(M.getAllNodes(root)) do
        if M.isItemNode(node) and tostring(node.itemId or "") == itemIdText then
            return node;
        end
    end

    return nil;
end

function M.moveItemIdToGroupId(root, itemId, targetGroupId)
    local itemNode = M.findItemById(root, itemId);

    if itemNode == nil then
        return false;
    end

    local targetGroup = nil;

    if targetGroupId ~= nil and tostring(targetGroupId) ~= "" then
        targetGroup = M.getGroupById(root, targetGroupId);
    end

    M.moveItemToGroup(itemNode, targetGroup);
    return true;
end

function M.rollAllInitiatives(form, root)
    if root == nil or not M.isMaster(root) then
        return;
    end

    local mesa = rrpg.getMesaDe(root);

    if mesa == nil or mesa.chat == nil then
        dialogs.alert("Nao foi possivel localizar o chat da mesa.");
        return;
    end

    for _, item in ipairs(M.getGroupedTurnItems(root)) do
        if canRollItemInitiative(root, item) then
            local formula = getInitiativeFormula(item);
            local nome = M.getPublicItemName(item);

            mesa.chat:rolarDados(formula, "Iniciativa de " .. nome,
                function(rolagem)
                    if rolagem ~= nil and M.isMaster(root) then
                        item.iniciativa = rolagem.resultado or 0;
                        M.redrawList(form);
                    end
                end);
        end
    end
end

function M.clearAllInitiatives(form, root)
    if root == nil or not M.isMaster(root) then
        return;
    end

    for _, node in ipairs(M.getAllNodes(root)) do
        if M.isItemNode(node) then
            node.iniciativa = 0;
        end
    end

    M.redrawList(form);
end

function M.clearAllItems(form, root)
    if root == nil then
        return;
    end

    publishTurnTimerState(root, nil);

    for _, node in ipairs(M.getAllNodes(root)) do
        ndb.deleteNode(node);
    end

    M.redrawList(form);
end

function M.getInitiativeFormula(itemNode)
    return getInitiativeFormula(itemNode);
end

return M;


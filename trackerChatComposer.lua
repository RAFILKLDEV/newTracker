-- Native controls for the chat input. Formatting is sent as TalemarkOptions;
-- RichEdit:getText() would discard rich formatting, so the source stays text.
local gui = require("gui.lua");
local dialogs = require("dialogs.lua");
local FireDrive = require("fireDrive.lua");
local Dice = require("trackerChatDice.lua");
local DiceIcons = require("trackerChatDiceIcons.lua");
local M = {};
local serial = 0;
local MUTED, TEXT, ACTIVE = "#919191", "#D1D1D1", "#C7D9EE";

local function trimmed(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "");
end

local function copy(value)
    if type(value) ~= "table" then return value; end
    local result = {};
    for key, item in pairs(value) do result[key] = copy(item); end
    return result;
end

local function property(object, key)
    local ok, value = pcall(function() return object ~= nil and object[key] or nil; end);
    return ok and value or nil;
end

local function set(control, key, value)
    if control[key] ~= value then control[key] = value; end
end

local function label(parent, text, size)
    local control = gui.newLabel();
    control.parent, control.align = parent, "none";
    control.text, control.fontSize, control.fontColor = text or "", size or 14, MUTED;
    control.vertTextAlign, control.horzTextAlign = "center", "leading";
    control.wordWrap, control.textTrimming = false, "none";
    return control;
end

local function closeStream(stream)
    local close = property(stream, "close");
    if type(close) == "function" then pcall(close, stream); end
end

local function keyCode(event)
    local code = tonumber(event.keyCode) or 0;
    if code == 0 then
        code = tonumber(event.key) or ((event.key == "\r" or event.key == "\n") and 13 or 0);
    end
    return code;
end

function M.mount(parent, callbacks, hosts)
    callbacks = callbacks or {};
    hosts = hosts or {};
    serial = serial + 1;
    local handle = {callbacks = callbacks, mode = "message", style = {}, uploads = {},
        generation = 0, closed = false};
    -- The caller owns the rounded background and its outer padding/height.
    -- Keep only a client layout here so no second gray border is introduced.
    local card = gui.newLayout();
    card.parent, card.align = parent, "client";
    card.hitTest = false;
    handle.card = card;

    local modes = gui.newLayout();
    modes.parent, modes.align, modes.height = card, "bottom", 24;
    local toolbar = gui.newLayout();
    toolbar.parent, toolbar.align, toolbar.height = card, "bottom", 26;
    toolbar.margins = {left = 0, top = 3, right = 0, bottom = 3};
    local navigation;
    if hosts.navigation ~= nil then
        navigation = gui.newLayout();
        navigation.parent, navigation.align = hosts.navigation, "client";
    end
    local inputHost = gui.newLayout();
    inputHost.parent, inputHost.align = card, "client";
    local input = gui.newTextEditor();
    input.parent, input.align = inputHost, "client";
    input.transparent, input.wordWrap = true, true;
    input.fontSize, input.fontColor = 14, TEXT;
    input.margins = {left = 2, right = 2, top = 2, bottom = 5};
    input.hint = "Enter envia; Shift+Enter quebra a linha. F3: anterior; F4: seguinte; ↑: histórico quando vazio.";
    handle.input = input;
    local prompt = label(inputHost, "Digite uma mensagem...", 14);
    prompt.align, prompt.vertTextAlign, prompt.hitTest = "client", "leading", false;
    prompt.canFocus = false;
    prompt.fontColor = "#8B8B8B";
    local promptRefreshId;
    local function refreshPrompt()
        if not handle.closed then
            set(prompt, "visible", tostring(input.text or "") == "");
        end
    end
    local function queuePromptRefresh()
        if handle.closed or promptRefreshId ~= nil then return; end
        promptRefreshId = setTimeout(function()
            promptRefreshId = nil;
            refreshPrompt();
        end, 1);
    end
    input.onEnter, input.onExit = refreshPrompt, refreshPrompt;
    input.onKeyUp = queuePromptRefresh;
    local prefix = label(modes, "Personificar:", 13);
    prefix.height, prefix.width, prefix.hitTest = 25, 91, false;
    local radios = {};
    for _, spec in ipairs({{"message", "Ninguém (F5)"}, {"narrative", "Narrador (F6)"}, {"npc", "NPC (F7)"}}) do
        local radio = gui.newRadioButton();
        radio.parent, radio.align, radio.height = modes, "none", 25;
        radio.fontSize, radio.fontColor = 13, MUTED;
        radio.text, radio.groupName = spec[2], "trackerChatComposer" .. tostring(serial);
        radios[spec[1]] = radio;
    end
    local npc = gui.newEdit();
    npc.parent, npc.align, npc.height = modes, "none", 23;
    npc.textPrompt, npc.fontSize, npc.fontColor = "Nome do NPC", 13, TEXT;
    npc.transparent, npc.width = true, 170;
    handle.npcInput = npc;
    local icons, dice = {}, {};
    local resizing, changingMode = false, false;

    local function invoke(name, ...)
        if handle.closed then return nil; end
        local callback = callbacks[name];
        if type(callback) ~= "function" then return nil; end
        local ok, result = pcall(callback, ...);
        if ok then return result; end
        local report = callbacks.onError;
        if name ~= "onError" and type(report) == "function" then pcall(report, tostring(result));
        elseif name ~= "onError" then dialogs.alert(tostring(result)); end
        return false;
    end

    local function fail(message)
        if handle.closed then return; end
        if type(callbacks.onError) == "function" then invoke("onError", tostring(message));
        else dialogs.alert(tostring(message)); end
    end

    local function icon(text, hint, action, style, host)
        local control = label(host or toolbar, text, 16);
        control.height, control.width = 24, 24;
        control.horzTextAlign, control.fontFamily = "center", "Segoe UI Symbol";
        control.hitTest, control.canFocus, control.hint = true, true, hint;
        if style ~= nil then control.fontStyle = style; end
        control.onClick = function() if not handle.closed then action(); end end;
        control.onKeyDown = function(event)
            if event ~= nil and keyCode(event) == 13 then
                action(); event.key, event.keyCode = "", 0;
            end
        end;
        control.onMouseEnter = function() if not handle.closed then control.fontColor = ACTIVE; end end;
        control.onMouseLeave = function() if not handle.closed then handle:refreshStyle(); end end;
        icons[#icons + 1] = {control = control, title = hint, run = action, host = host or toolbar};
        return control;
    end

    function handle:getText() return self.closed and "" or tostring(input.text or ""); end
    function handle:setText(text)
        if self.closed then return; end
        set(input, "text", tostring(text or ""));
        refreshPrompt();
    end
    function handle:focus()
        if self.closed then return; end
        refreshPrompt();
        input:setFocus();
    end
    function handle:getMode() return self.mode; end
    function handle:getNPCName() return self.closed and "" or trimmed(npc.text); end
    function handle:setNPCName(name) if not self.closed then set(npc, "text", tostring(name or "")); end end
    function handle:getTalemarkOptions()
        if next(self.style) == nil then return nil; end
        return {defaultTextStyle = copy(self.style)};
    end
    function handle:refreshStyle()
        if self.closed then return; end
        local styles = {};
        for _, name in ipairs({"bold", "italic", "underline"}) do
            if self.style[name] == true then styles[#styles + 1] = name; end
        end
        local fontKey = table.concat(styles, ":");
        if self.styleFontKey ~= fontKey then
            self.styleFontKey = fontKey; input.fontStyle = styles;
        end
        local color = self.style.color;
        set(input, "fontColor", type(color) == "string" and color ~= "" and color or TEXT);
        for key, control in pairs(self.formatButtons or {}) do
            local active = key == "color" and color ~= nil or self.style[key] == true;
            set(control, "fontColor", active and ACTIVE or MUTED);
        end
        for _, spec in ipairs(icons) do
            if not spec.format then set(spec.control, "fontColor", MUTED); end
        end
        if self.actionButton ~= nil then
            set(self.actionButton, "fontColor", self.mode == "action" and ACTIVE or MUTED);
        end
    end
    function handle:setMode(mode, silent)
        if self.closed then return; end
        if mode ~= "narrative" and mode ~= "npc" and mode ~= "action" then mode = "message"; end
        self.mode = mode;
        changingMode = true;
        for key, radio in pairs(radios) do set(radio, "checked", key == mode or key == "message" and mode == "action"); end
        changingMode = false;
        self:refreshStyle();
        if not silent then invoke("onModeChange", mode, self:getNPCName()); end
    end
    function handle:draftState()
        return {text = self:getText(), mode = self.mode, npcName = self:getNPCName(),
            style = copy(self.style), contextKey = self.contextKey};
    end
    function handle:restore(state)
        if self.closed then return; end
        state = type(state) == "table" and state or {};
        self.generation = self.generation + 1;
        self.contextKey = state.contextKey;
        self.style = type(state.style) == "table" and copy(state.style) or {};
        self.historyCursor, self.historyItems, self.historyRecallText = nil, nil, nil;
        self:setNPCName(state.npcName);
        self:setText(state.text or state.draft or "");
        self:setMode(state.mode or "message", true);
    end
    function handle:setContextKey(key) self.contextKey = key; end

    local function append(text)
        local old = handle:getText();
        handle:setText(old .. (old ~= "" and "\n" or "") .. text);
        handle:focus();
    end
    local function sameDraft(generation, contextKey)
        return not handle.closed and (handle.generation == generation
            or contextKey ~= nil and handle.contextKey == contextKey);
    end
    local function send()
        if handle.closed or trimmed(handle:getText()) == "" then return; end
        if handle.mode == "npc" and handle:getNPCName() == "" then
            fail("Preencha o nome do NPC para enviar a mensagem."); npc:setFocus(); return;
        end
        -- The controller clears only the confirmed draft after asyncSendStd.
        invoke("onSend", handle:getText(), handle.mode, handle:getTalemarkOptions(), handle:getNPCName());
    end
    local function openRoll(face, anchor)
        if anchor == nil or not anchor.visible then anchor = toolbar; end
        local options = {parent=card,anchor=anchor,face=face,caption=handle:getText()};
        -- Reuse the native popup for the composer's lifetime, resetting its
        -- fields on every opening. Native animations must finish on live UI.
        if handle.dicePopup ~= nil and handle.dicePopup:isAlive() then
            handle.dicePopup:open(options); return;
        end
        handle.dicePopup = Dice.open(options, {
            onRoll = function(expression, caption, settings, done)
                if handle.mode == "npc" and handle:getNPCName() == "" then
                    local reason = "Preencha o nome do NPC no chat para rolar.";
                    if type(done)=="function" then done(false,reason); else fail(reason); end
                    return false;
                end
                local function completed(ok, message)
                    if not handle.closed then
                        handle.historyCursor, handle.historyItems, handle.historyRecallText = nil, nil, nil;
                    end
                    if type(done) == "function" then done(ok, message); end
                end
                return invoke("onRoll", expression, caption, handle:getTalemarkOptions(),
                    handle.mode, handle:getNPCName(), settings, completed);
            end,
            onError = fail
        });
    end
    local function addLink()
        local generation, contextKey = handle.generation, handle.contextKey;
        dialogs.inputQuery("Inserir link", "URL do link:", "", function(url)
            if not sameDraft(generation, contextKey) or trimmed(url) == "" then return; end
            append(trimmed(url));
        end);
    end
    local function addImage()
        local generation, contextKey = handle.generation, handle.contextKey;
        dialogs.selectImageURL("", function(url)
            if handle.closed then return; end
            url = trimmed(url);
            if url ~= "" and not url:find("[%[%]%c]") then
                if sameDraft(generation, contextKey) then append("[§I " .. url .. "]");
                else dialogs.showMessage("Imagem selecionada. Link para inserir na conversa:\n" .. url); end
            elseif url ~= "" then fail("A URL da imagem contém caracteres inválidos."); end
        end);
    end

    local function upload(accept)
        local generation, contextKey = handle.generation, handle.contextKey;
        dialogs.openFile(accept == "audio/*" and "Escolha o áudio" or "Escolha o arquivo", accept or "*.*", false,
            function(files)
                for _, file in ipairs(files or {}) do
                    if handle.closed then closeStream(file.stream);
                    else
                        local ticket = {stream = file.stream, finished = false};
                        handle.uploads[ticket] = true;
                        local function finish()
                            if ticket.finished then return false; end
                            ticket.finished = true; handle.uploads[ticket] = nil;
                            closeStream(ticket.stream); ticket.stream = nil;
                            return true;
                        end
                        local ok, operation = pcall(FireDrive.quickUpload, file.name, nil, file.stream,
                            function(item)
                                if not finish() or handle.closed then return; end
                                local url = trimmed(property(item, "url"));
                                if url == "" then fail("O envio do arquivo não retornou um link."); return; end
                                local name = trimmed(property(item, "name") or file.name);
                                local mime = tostring(property(item, "mimeType") or "");
                                if sameDraft(generation, contextKey) then
                                    if mime:sub(1, 6) == "image/" and not url:find("[%[%]%c]") then
                                        append("[§I " .. url .. "]");
                                    else append((name ~= "" and name .. "\n" or "") .. url); end
                                    invoke("onStatus", "Arquivo anexado ao rascunho.");
                                elseif invoke("onUploadComplete", url, name, mime, contextKey) ~= true then
                                    dialogs.showMessage("Arquivo enviado. Link para inserir na conversa:\n" .. url);
                                end
                            end,
                            function(current, total)
                                if ticket.finished or handle.closed then return; end
                                local percent = tonumber(total) and total > 0 and math.floor((tonumber(current) or 0) * 100 / total) or 0;
                                if ticket.percent ~= percent then
                                    ticket.percent = percent; invoke("onStatus", "Enviando arquivo: " .. tostring(percent) .. "%");
                                end
                            end,
                            function(reason) if finish() then fail("Não foi possível enviar o arquivo: " .. tostring(reason)); end end);
                        if not ok then if finish() then fail(operation); end
                        elseif operation == nil then
                            if finish() then fail("Não foi possível iniciar o envio do arquivo."); end
                        else ticket.operation = operation; end
                    end
                end
            end);
    end
    local function attachments()
        dialogs.choose("Anexar", {"Imagem", "Arquivo", "Link", "Áudio (arquivo)"}, function(ok, index)
            if not ok or handle.closed then return; end
            if index == 1 then addImage(); elseif index == 2 then upload("*.*");
            elseif index == 3 then addLink(); elseif index == 4 then upload("audio/*"); end
        end);
    end
    local function rename()
        if type(callbacks.onRename) == "function" then invoke("onRename"); return; end
        dialogs.inputQuery("Apelido na mesa", "Novo apelido:", "", function(name)
            if not handle.closed and trimmed(name) ~= "" then
                invoke("onSend", "/nick " .. trimmed(name), "message", nil, "");
            end
        end);
    end
    local function formatMenu()
        dialogs.choose("Formatação", {"Inserir título", "Inserir separador", "Fala fora do personagem", "Limpar formatação"},
            function(ok, index)
                if not ok or handle.closed then return; end
                if index == 1 then append("# Título"); elseif index == 2 then append("---");
                elseif index == 3 then append("((Fala fora do personagem))");
                elseif index == 4 then handle.style = {}; handle:refreshStyle(); end
            end);
    end
    handle.formatButtons = {};
    for _, spec in ipairs({{"bold", "B", "Negrito na mensagem"}, {"italic", "I", "Itálico na mensagem"}, {"underline", "U", "Sublinhado na mensagem"}}) do
        local name = spec[1];
        local control = icon(spec[2], spec[3], function()
            handle.style[name] = handle.style[name] ~= true;
            handle:refreshStyle(); handle:focus();
        end, {name});
        icons[#icons].format = true;
        handle.formatButtons[name] = control;
    end
    handle.formatButtons.color = icon("A", "Cor do texto", function()
        local generation, contextKey = handle.generation, handle.contextKey;
        local ok, promise = pcall(dialogs.asyncSelectTalemarkColor, handle.style.color);
        if not ok or promise == nil then fail("Não foi possível abrir a seleção de cor."); return; end
        promise:thenDo(function(color)
            if not sameDraft(generation, contextKey) then return; end
            handle.style.color = color; handle:refreshStyle(); handle:focus();
        end, function() end);
    end, {"underline"});
    icons[#icons].format = true;
    local code = icon("</>", "Opções de formatação", formatMenu);
    code.fontSize = 11;
    icons[#icons].secondary = true;
    local attachButton = icon("", "Anexar imagem, arquivo ou link", attachments);
    attachButton.fontFamily = "Segoe MDL2 Assets";
    icons[#icons].gapBefore = 8;
    local renameButton = icon("", "Alterar apelido na mesa", rename);
    renameButton.fontFamily = "Segoe MDL2 Assets";
    icons[#icons].secondary = true;
    handle.actionButton = icon("", "Enviar como ação", function()
        handle:setMode(handle.mode == "action" and "message" or "action"); handle:focus();
    end);
    handle.actionButton.fontFamily = "Segoe MDL2 Assets";
    local audioButton = icon("", "Enviar áudio (arquivo)", function() upload("audio/*"); end);
    audioButton.fontFamily = "Segoe MDL2 Assets";
    icons[#icons].secondary = true;
    for _, faces in ipairs({4, 6, 8, 10, 12, 20, 100}) do
        local face = faces;
        local control;
        control = icon("", "Montar uma nova rolagem de d" .. tostring(face), function() openRoll(face,control); end);
        icons[#icons].dice = true;
        if #dice == 0 then icons[#icons].gapBefore = 10; end
        local drawing = DiceIcons.draw(control,face,4,4,16,MUTED);
        local enter, leave = control.onMouseEnter, control.onMouseLeave;
        control.onMouseEnter = function()
            if not handle.closed then enter(); drawing.strokeColor = ACTIVE; end
        end;
        control.onMouseLeave = function()
            if not handle.closed then leave(); drawing.strokeColor = MUTED; end
        end;
        dice[#dice + 1] = control;
        control.onMenu = function(_, _, event)
            if event ~= nil then event.handled = true; end
            openRoll(face,control);
        end;
    end
    local shortcuts = {};
    for _, spec in ipairs({{"", "Fixados", "onPins"}, {"", "Histórico", "onHistory"},
        {"", "Última", "onLatest"}, {"", "Permissões", "onSettings"},
        {"⚠", "Pedir atenção", "onAttention"}, {"☰", "Abrir atenção", "onOpenAttention"}}) do
        local callback = spec[3];
        local shortcut = icon(navigation and "" or spec[1], spec[2], function() invoke(callback); end, nil, navigation);
        icons[#icons].quick = true;
        local item = {control = shortcut};
        if navigation ~= nil then
            item.glyph = label(shortcut, spec[1], 14);
            item.glyph.fontFamily = #shortcuts < 4 and "Segoe MDL2 Assets" or "Segoe UI Symbol";
            item.glyph.width, item.glyph.height, item.glyph.horzTextAlign = 24, 24, "center";
            item.glyph.hitTest, item.glyph.canFocus = false, false;
            item.caption = label(shortcut, spec[2], 12);
            item.caption.left, item.caption.height = 26, 24;
            item.caption.hitTest, item.caption.canFocus = false, false;
            local enter, leave = shortcut.onMouseEnter, shortcut.onMouseLeave;
            shortcut.onMouseEnter = function()
                if handle.closed then return; end
                enter(); set(item.glyph, "fontColor", ACTIVE); set(item.caption, "fontColor", ACTIVE);
            end;
            shortcut.onMouseLeave = function()
                if handle.closed then return; end
                leave(); set(item.glyph, "fontColor", MUTED); set(item.caption, "fontColor", MUTED);
            end;
        else shortcut.fontFamily = "Segoe MDL2 Assets"; end
        shortcuts[#shortcuts + 1] = item;
    end
    local menu;
    menu = icon("⋯", "Mais opções do chat", function()
        local choices, actions = {}, {};
        for _, spec in ipairs({{"Fixados", "onPins"}, {"Histórico", "onHistory"}, {"Última mensagem", "onLatest"},
            {"Permissões", "onSettings"}, {"Pedir atenção", "onAttention"}, {"Abrir atenção", "onOpenAttention"}}) do
            if type(callbacks[spec[2]]) == "function" then
                choices[#choices + 1] = spec[1]; local name = spec[2]; actions[#actions + 1] = function() invoke(name); end;
            end
        end
        for _, spec in ipairs(icons) do
            if spec.control ~= menu and not spec.control.visible then
                if not spec.quick then choices[#choices + 1], actions[#actions + 1] = spec.title, spec.run; end
            end
        end
        choices[#choices + 1] = "Rolagem personalizada";
        actions[#actions + 1] = function() openRoll(nil,menu); end;
        dialogs.choose("Chat", choices, function(ok, index)
            if ok and not handle.closed and actions[index] ~= nil then actions[index](); end
        end);
    end);
    local sendButton = icon("➤", "Enviar mensagem (Enter)", send);
    sendButton.fontSize = 17;
    handle.sendButton = sendButton;

    function handle:resize()
        if self.closed or resizing then return; end
        resizing = true;
        local width = math.max(0, tonumber(toolbar.width) or 0);
        local step, rowHeight = 24, 26;
        local reserve = 60 + (navigation == nil and (#shortcuts * step + 8) or 0);
        local available = math.max(0, width - reserve - 8);
        local left, row = 0, 0;
        for _, spec in ipairs(icons) do
            local control = spec.control;
            if control ~= menu and control ~= sendButton and not spec.quick then
                local eligible = not spec.secondary or available >= 224;
                local gap = left > 0 and (spec.gapBefore or 0) or 0;
                -- Keep the dice together when the complete group fits a row.
                local groupWidth = spec.dice and spec.gapBefore and #dice * step or step;
                if eligible and left > 0 and left + gap + math.min(groupWidth, available) > available and row == 0 then
                    row, left, gap = 1, 0, 0;
                end
                local nextLeft = left + gap;
                local visible = eligible and nextLeft + step <= available;
                set(control, "visible", visible);
                if visible then
                    set(control, "left", nextLeft); set(control, "top", row * rowHeight);
                    set(control, "width", step); left = nextLeft + step;
                end
            end
        end
        set(toolbar, "height", (row + 1) * rowHeight);
        if hosts.background ~= nil then set(hosts.background, "height", 124 + row * rowHeight); end
        if navigation ~= nil then
            local navWidth = math.max(0, tonumber(navigation.width) or 0);
            local fullWidths = {88, 98, 80, 104, 116, 116};
            local showCaptions = navWidth >= 632;
            local showMainCaptions = navWidth >= 448;
            local total = showCaptions and 632 or showMainCaptions and 448 or #shortcuts * step + (#shortcuts - 1) * 6;
            local x = math.max(0, navWidth - total);
            for index, item in ipairs(shortcuts) do
                local showCaption = showCaptions or showMainCaptions and index <= 4;
                local buttonWidth = showCaption and fullWidths[index] or step;
                set(item.control, "visible", x + buttonWidth <= navWidth);
                set(item.control, "left", x); set(item.control, "width", buttonWidth);
                set(item.caption, "visible", showCaption);
                set(item.caption, "width", math.max(0, buttonWidth - 28));
                x = x + buttonWidth + 6;
            end
        else
            for index, item in ipairs(shortcuts) do
                set(item.control, "visible", width >= reserve);
                set(item.control, "left", math.max(0, width - reserve + (index - 1) * step));
                set(item.control, "top", row * rowHeight);
            end
        end
        set(menu, "left", math.max(0, width - 60)); set(menu, "top", row * rowHeight);
        set(menu, "visible", width >= 60);
        set(sendButton, "left", math.max(0, width - 28)); set(sendButton, "top", row * rowHeight);
        set(sendButton, "width", 28); set(sendButton, "visible", width >= 28);
        local compact = width < 580;
        set(prefix, "width", compact and 74 or 91); set(prefix, "fontSize", compact and 11 or 13);
        local x = compact and 74 or 91;
        for _, spec in ipairs({{"message", compact and "F5" or "Ninguém (F5)", compact and 47 or 119},
            {"narrative", compact and "F6" or "Narrador (F6)", compact and 47 or 122}, {"npc", compact and "F7" or "NPC (F7)", compact and 47 or 86}}) do
            local radio = radios[spec[1]];
            set(radio, "text", spec[2]); set(radio, "left", x); set(radio, "width", spec[3]);
            x = x + spec[3];
        end
        set(npc, "left", x); set(npc, "width", math.max(40, math.min(170, width - x - 4)));
        set(npc, "visible", width >= x + 44);
        resizing = false;
    end
    function handle:close()
        if self.closed then return; end
        if promptRefreshId ~= nil then clearTimeout(promptRefreshId); promptRefreshId = nil; end
        if self.dicePopup ~= nil then self.dicePopup:dispose(); self.dicePopup = nil; end
        self.closed = true;
        for ticket in pairs(self.uploads) do
            ticket.finished = true;
            if ticket.operation ~= nil then pcall(FireDrive.abortOperation, ticket.operation); end
            closeStream(ticket.stream); ticket.stream = nil;
        end
        self.uploads = {};
        if navigation ~= nil then navigation:destroy(); navigation = nil; end
        if card ~= nil then card:destroy(); card = nil; end
        self.card, self.input, self.npcInput = nil, nil, nil;
    end
    for key, radio in pairs(radios) do
        local mode = key;
        radio.onChange = function()
            if not changingMode and not handle.closed and radio.checked then
                handle:setMode(mode); handle:focus();
                if mode == "npc" and not npc.visible then
                    dialogs.inputQuery("Personificar NPC", "Nome do NPC:", handle:getNPCName(), function(name)
                        if not handle.closed then handle:setNPCName(name); invoke("onModeChange", mode, handle:getNPCName()); end
                    end);
                end
            end
        end;
    end
    npc.onUserChange = function()
        if handle.mode == "npc" and not handle.closed then invoke("onModeChange", "npc", handle:getNPCName()); end
    end;
    input.onChange = function()
        if not handle.closed then
            if handle:getText() ~= handle.historyRecallText then
                handle.historyCursor, handle.historyItems, handle.historyRecallText = nil, nil, nil;
            end
            refreshPrompt(); queuePromptRefresh(); invoke("onChange", handle:getText());
        end
    end;
    local function recallHistory(backward)
        if handle.historyItems == nil then
            local items = invoke("onInputHistory");
            if type(items) ~= "table" or #items == 0 then return false; end
            handle.historyItems, handle.historyCursor, handle.historyDraft = copy(items), 0, handle:getText();
        end
        local count = #handle.historyItems;
        if backward then handle.historyCursor = math.min(count, handle.historyCursor + 1);
        else handle.historyCursor = math.max(0, handle.historyCursor - 1); end
        handle.historyRecallText = handle.historyCursor == 0 and handle.historyDraft or handle.historyItems[handle.historyCursor];
        handle:setText(handle.historyRecallText); handle:focus();
        return true;
    end
    local function keyDown(event)
        if event == nil or handle.closed then return; end
        local key = keyCode(event);
        if key==13 and handle.dicePopup~=nil and handle.dicePopup:isOpen() then
            event.key,event.keyCode = "",0;
            handle.dicePopup:roll();
        elseif key == 114 or key == 38 and (handle:getText() == "" or handle:getText() == handle.historyRecallText) then
            if recallHistory(true) then event.key, event.keyCode = "", 0; end
        elseif key == 115 then
            if handle.historyCursor ~= nil then recallHistory(false); end
            event.key, event.keyCode = "", 0;
        elseif key == 40 and handle.historyCursor ~= nil then
            if recallHistory(false) then event.key, event.keyCode = "", 0; end
        elseif key == 116 or key == 117 or key == 118 then
            handle:setMode(key == 116 and "message" or key == 117 and "narrative" or "npc");
            if key == 118 then npc:setFocus(); else handle:focus(); end
            event.key, event.keyCode = "", 0;
        elseif key == 13 and event.shiftKey ~= true then
            send(); event.key, event.keyCode = "", 0;
        end
    end
    input.onKeyDown = function(event) keyDown(event); queuePromptRefresh(); end;
    npc.onKeyDown = keyDown;
    toolbar.onResize, modes.onResize, card.onResize = function() handle:resize(); end,
        function() handle:resize(); end, function() handle:resize(); end;
    if navigation ~= nil then navigation.onResize = function() handle:resize(); end; end
    handle:setText(""); handle:setMode("message", true); handle:resize();
    return handle;
end

return M;

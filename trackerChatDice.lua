-- Contextual roll menu; its parent and outside-click lifecycle belong only to
-- the chat. No Turno/Atenção window helper or position is used here.
local gui = require("gui.lua");
local rrpg = require("rrpg.lua");
local Icons = require("trackerChatDiceIcons.lua");
local M = {};
local WIDTH, HEIGHT = 520, 512;

local function trimmed(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "");
end

local function set(control, key, value)
    if control[key] ~= value then control[key] = value; end
end

-- Accept signed integer sequences, retaining every term. Never evaluate code
-- or silently turn an incomplete/invalid modifier into zero.
local function parseModifiers(source)
    source = trimmed(source):gsub("%s", "");
    local terms, total, consumed = {}, 0, "";
    for sign, digits in source:gmatch("([+-]?)(%d+)") do
        consumed = consumed .. sign .. digits;
        local value = tonumber(digits);
        if value == nil or value > 1000000000 then return nil; end
        total = total + (sign == "-" and -value or value);
        if math.abs(total) > 1000000000 then return nil; end
        terms[#terms + 1] = {negative = sign == "-", value = value};
    end
    if consumed ~= source then return nil; end
    return terms, total;
end

local function appendModifiers(expression, terms)
    for _, term in ipairs(terms or {}) do
        local sign = term.negative and " - " or " + ";
        if expression == "" then sign = term.negative and "-" or ""; end
        expression = expression .. sign .. string.format("%.0f", term.value);
    end
    return expression;
end

-- Recognize additive expressions for the quantity controls. Native special
-- expressions remain editable; their server result is never calculated here.
local function parsePool(expression)
    local source = trimmed(expression):gsub("%s", "");
    local pool, constants, consumed = {}, {}, "";
    for sign, term in source:gmatch("([+-]?)([^+-]+)") do
        consumed = consumed .. sign .. term;
        local quantity, face = term:match("^(%d*)[dD](%d+)$");
        if face == nil then quantity, face = term:match("^(%d*)[dD]([fF])$"); end
        if face ~= nil then
            if sign == "-" then return nil; end
            quantity = quantity == "" and 1 or tonumber(quantity);
            face = tonumber(face) or "F";
            if quantity < 1 or quantity > 1000 or type(face) == "number" and (face < 1 or face > 1000000) then return nil; end
            local found;
            for _, item in ipairs(pool) do if item.face == face then found = item; break; end end
            if found then
                found.quantity = found.quantity + quantity;
                if found.quantity > 1000 then return nil; end
            else pool[#pool + 1] = {face = face, quantity = quantity}; end
        elseif term:match("^%d+$") then
            local value = tonumber(term);
            if value == nil or value > 1000000000 then return nil; end
            constants[#constants + 1] = {negative = sign == "-", value = value};
        else return nil; end
    end
    if consumed ~= source then return nil; end
    return pool, constants;
end

function M.open(options, callbacks)
    options, callbacks = options or {}, callbacks or {};
    if options.parent == nil then return nil; end
    local popup = gui.newPopup();
    popup.parent, popup.width, popup.height = options.parent, WIDTH, HEIGHT;
    popup.drawContainer, popup.backOpacity, popup.cancelable = false, 0.12, true;
    local handle = {popup = popup, rows = {}, closed = false, opened = false, closing = false, busy = false,
        mode = "normal", order = "native"};
    local submit;
    local function keyRoll(event)
        if event == nil or handle.closed or not handle.opened then return false; end
        local key = tonumber(event.keyCode) or 0;
        if key==0 then key = tonumber(event.key) or ((event.key=="\r" or event.key=="\n") and 13 or 0); end
        if key~=13 then return false; end
        -- Consume before submitting: the closing popup must not pass this
        -- same Enter to the composer or activate a second control.
        event.key,event.keyCode = "",0;
        if submit~=nil then submit(); end
        return true;
    end
    popup.onKeyDown = keyRoll;
    local function control(factory, parent, x, y, w, h)
        local item = factory();
        item.parent, item.align = parent, "none";
        item.left, item.top, item.width, item.height = x, y, w, h;
        item.onKeyDown = keyRoll;
        return item;
    end
    local card = control(gui.newRectangle, popup, 0, 0, WIDTH, HEIGHT);
    card.color, card.strokeColor, card.strokeSize = "#292C30", "#59616B", 1;
    card.xradius, card.yradius, card.hitTest = 6, 6, true;
    local function text(parent, value, x, y, w, h, size)
        local item = control(gui.newLabel, parent, x, y, w, h);
        item.text, item.fontSize, item.fontColor = value, size or 12, "#BDBDBD";
        item.wordWrap, item.textTrimming, item.vertTextAlign, item.hitTest = false, "none", "center", false;
        return item;
    end
    -- Explicit pressed appearance, independent of the native button theme.
    local function button(parent, value, x, y, w, h, run)
        local item = control(gui.newRectangle, parent, x, y, w, h);
        item.color, item.strokeColor, item.strokeSize = "#373B40", "#59616B", 1;
        item.xradius, item.yradius, item.hitTest, item.canFocus = 4, 4, true, true;
        item._label = text(item, value, 0, 0, w, h, 12);
        item._label.horzTextAlign = "center";
        item.onClick = function() if not handle.closed and not handle.busy then run(); end end;
        item.onKeyDown = function(event)
            if keyRoll(event) then return; end
            if event ~= nil and event.keyCode == 32 then
                if not handle.closed and not handle.busy then run(); end
                event.key, event.keyCode = "", 0;
            end
        end;
        return item;
    end
    local function edit(value, x, y, w, h)
        local item = control(gui.newEdit, card, x, y, w, h);
        item.text, item.fontSize, item.fontColor = tostring(value or ""), 14, "#D1D1D1";
        return item;
    end
    local title = text(card, "Rolagem de dados", 12, 6, 496, 26, 15);
    title.fontStyle, title.fontColor = "bold", "#D5E0ED";
    text(card, "Clique nos ícones para adicionar dados", 12, 36, 352, 18);
    local list = control(gui.newScrollBox, card, 12, 114, 496, 100);
    text(card, "Modificadores", 12, 224, 370, 18);
    local modifier = edit("", 12, 244, 368, 30);
    modifier.textPrompt, modifier.hint = "+5-3+10", "Some bônus e penalidades: +5-3+10 aplica +12.";
    local modifierTotal = text(card, "Total: 0", 388, 244, 120, 30, 13);
    modifierTotal.fontStyle, modifierTotal.horzTextAlign = "bold", "trailing";
    text(card, "Modo", 12, 282, 248, 18);
    text(card, "Ordem dos dados", 272, 282, 236, 18);
    text(card, "Expressão dos dados (editável)", 12, 340, 496, 18);
    local expression = edit("", 12, 360, 496, 28);
    expression.textPrompt = "Ex.: 2d6 + 1d20";
    text(card, "Descrição", 12, 396, 72, 28);
    local caption = edit(options.caption or "", 88, 396, 420, 28);
    caption.textPrompt = "Opcional: ataque, dano, resistência…";
    local preview = control(gui.newTextEditor, card, 12, 432, 496, 36);
    preview.readOnly, preview.transparent, preview.wordWrap = true, true, true;
    preview.fontSize, preview.fontColor, preview.hitTest = 13, "#9DAEFF", false;
    local status = text(card, "", 100, 476, 274, 28, 12);
    status.wordWrap = true;
    local rollButton;
    local pool, constants = {}, {};
    local syncing = false;
    local rebuild, refreshPreview, refreshChoices;
    local modeButtons, orderButtons = {}, {};

    local function poolExpression()
        local pieces = {};
        for _, item in ipairs(pool or {}) do pieces[#pieces + 1] = tostring(item.quantity or 1) .. "d" .. tostring(item.face); end
        return appendModifiers(table.concat(pieces, " + "), constants);
    end
    local function syncExpression()
        handle.generatedExpression = poolExpression();
        syncing = true; set(expression, "text", handle.generatedExpression); syncing = false;
        refreshPreview();
    end
    refreshPreview = function()
        if handle.closed then return; end
        local terms, total = parseModifiers(modifier.text);
        local valid = terms ~= nil;
        for _, item in ipairs(pool or {}) do if item.quantity == nil then valid = false; end end
        local base = trimmed(expression.text);
        handle.expression = valid and appendModifiers(base, terms) or nil;
        set(modifierTotal, "text", terms and "Total: " .. (total > 0 and "+" or "") .. tostring(total) or "Total: ?");
        set(modifierTotal, "fontColor", terms and "#B8D9BC" or "#FF9999");
        local value = not valid and "Complete as quantidades e os modificadores. Use +5-3+10, por exemplo."
            or handle.expression ~= "" and "Vai rolar: " .. handle.expression or "Adicione um dado para começar.";
        set(preview, "text", value); set(preview, "hint", value);
        if rollButton ~= nil then
            set(rollButton, "enabled", not handle.busy and valid and handle.expression ~= "");
            set(rollButton._label, "fontColor", not handle.busy and valid and handle.expression ~= "" and "#E0EEF8" or "#7D8993");
        end
    end;
    rebuild = function()
        list:beginUpdate();
        for _, row in ipairs(handle.rows) do row:destroy(); end
        handle.rows = {};
        local function remember(item) handle.rows[#handle.rows + 1] = item; return item; end
        if pool == nil or #pool == 0 then
            local help = remember(text(list, pool == nil and "Expressão personalizada. Edite no campo abaixo."
                or "Nenhum dado adicionado.", 4, 4, 470, 30, 13));
            help.wordWrap = true;
        else
            for index, item in ipairs(pool) do
                local data, slot, y = item, index, (index - 1) * 32;
                remember(Icons.draw(list,data.face,4,y+3,22,"#B6C9DF"));
                remember(text(list,"d" .. tostring(data.face),34,y,52,28,13));
                remember(text(list,"Quantidade",90,y,86,28));
                local quantity = remember(control(gui.newEdit,list,180,y,72,28));
                quantity.text, quantity.fontSize = tostring(data.quantity or ""), 13;
                quantity.hint = "Quantidade: 1 a 1000";
                quantity.onChange = function()
                    if handle.closed or syncing or handle.busy then return; end
                    local count = tonumber(quantity.text);
                    data.quantity = count ~= nil and count % 1 == 0 and count >= 1 and count <= 1000 and count or nil;
                    syncExpression(); set(status,"text","");
                end;
                remember(button(list,"−",260,y,28,28,function()
                    local count = data.quantity or 1;
                    if count > 1 then data.quantity = count - 1; else table.remove(pool,slot); end
                    syncExpression(); rebuild();
                end));
                remember(button(list,"+",294,y,28,28,function()
                    data.quantity = math.min(1000,(data.quantity or 0)+1); syncExpression(); rebuild();
                end));
                local remove = remember(button(list,"×",334,y,28,28,function()
                    table.remove(pool,slot); syncExpression(); rebuild();
                end));
                remove.hint = "Remover este grupo de dados";
            end
        end
        list:endUpdate();
    end;
    function handle:addDie(face)
        if self.closed or self.busy then return; end
        face = tonumber(face) or (tostring(face):upper() == "F" and "F" or nil);
        if face == nil or type(face) == "number" and (face % 1 ~= 0 or face < 1 or face > 1000000) then
            set(status,"text","Informe um número de faces válido."); return;
        end
        if pool == nil then
            set(expression,"text",trimmed(expression.text) .. (trimmed(expression.text) ~= "" and " + " or "") .. "1d" .. tostring(face));
        else
            local found;
            for _, item in ipairs(pool) do if item.face == face then found = item; break; end end
            if found then found.quantity = math.min(1000,(found.quantity or 0)+1);
            else pool[#pool + 1] = {face=face,quantity=1}; end
            syncExpression(); rebuild();
        end
        set(status,"text","");
    end
    local function selected(control, active)
        set(control,"color",active and "#355673" or "#373B40");
        set(control,"strokeColor",active and "#83B7E0" or "#59616B");
        set(control._label,"fontColor",active and "#E0EEF8" or "#BDBDBD");
        set(control._label,"fontStyle",active and "bold" or "");
    end
    refreshChoices = function()
        for key, item in pairs(modeButtons) do selected(item,key==handle.mode); end
        for key, item in pairs(orderButtons) do selected(item,key==handle.order); end
        title.hint = handle.mode == "advantage" and "Vantagem: duas execuções da expressão; escolhe o maior total."
            or handle.mode == "disadvantage" and "Desvantagem: duas execuções da expressão; escolhe o menor total."
            or "Rolagem normal. A ordenação dos dados é apenas visual.";
    end;
    for _, spec in ipairs({{"normal","Normal",12,64},{"advantage","Vantagem",80,80},{"disadvantage","Desvantagem",164,96}}) do
        local key = spec[1];
        modeButtons[key] = button(card,spec[2],spec[3],304,spec[4],28,function()
            handle.mode = key; refreshChoices();
        end);
        modeButtons[key].hint = key == "normal" and "Rola a expressão uma vez."
            or key == "advantage" and "Rola duas vezes e escolhe o maior total." or "Rola duas vezes e escolhe o menor total.";
    end
    for _, spec in ipairs({{"native","Original",272,70},{"asc","Crescente",346,78},{"desc","Decrescente",428,80}}) do
        local key = spec[1];
        orderButtons[key] = button(card,spec[2],spec[3],304,spec[4],28,function()
            handle.order = key; refreshChoices();
        end);
        orderButtons[key].hint = "Ordem visual dos valores de cada grupo; preserva o total original.";
    end
    for index, face in ipairs(Icons.faces) do
        local faces = face;
        local tile = button(card,"d" .. tostring(faces),12+(index-1)*44,58,40,44,function() handle:addDie(faces); end);
        tile._label.top, tile._label.height, tile._label.fontSize = 27, 16, 11;
        Icons.draw(tile,faces,9,3,22,"#B6C9DF");
        tile.hint = "Adicionar um d" .. tostring(faces);
    end
    text(card,"Outro dado",376,36,132,18);
    local custom = edit("",376,65,90,28);
    custom.textPrompt, custom.hint = "Faces", "Número de faces do dado personalizado";
    local addCustom = button(card,"+",474,65,34,28,function() handle:addDie(custom.text); end);
    addCustom.hint = "Adicionar o dado personalizado";
    modifier.onChange = function()
        if handle.closed or syncing or handle.busy then return; end
        refreshPreview(); set(status,"text","");
    end;
    expression.onChange = function()
        if handle.closed or syncing or handle.busy or expression.text == handle.generatedExpression then return; end
        handle.generatedExpression = nil;
        pool, constants = parsePool(expression.text);
        rebuild(); refreshPreview(); set(status,"text","");
    end;
    submit = function()
        if handle.closed or not handle.opened or handle.busy then return; end
        refreshPreview();
        local expr = handle.expression;
        if expr == nil or expr == "" then set(status,"text","Complete os dados e modificadores."); return; end
        local valid, parsed = pcall(rrpg.interpretarRolagem,expr);
        if not valid or parsed == nil or trimmed(parsed.asString) == "" then
            set(status,"text","Expressão inválida."); status.hint = tostring(valid and expr or parsed); return;
        end
        if type(callbacks.onRoll) ~= "function" then return; end
        local description = tostring(caption.text or "");
        local settings = {mode=handle.mode,order=handle.order};
        handle.busy = true;
        -- Dispatch only from the native onClose event. The popup and its
        -- controls stay owned by the composer while the fade-out finishes.
        handle.pendingRoll = {expression=expr,description=description,settings=settings};
        handle:close();
    end;
    rollButton = button(card,"Rolar",382,476,126,28,submit);
    rollButton.color, rollButton.strokeColor = "#355673", "#83B7E0";
    rollButton.hint = "Rolar (Enter): enviar a expressão da prévia ao chat da mesa";
    button(card,"Zerar",12,476,78,28,function()
        pool,constants,handle.mode,handle.order = {},{},"normal","native";
        syncing = true; modifier.text,expression.text,custom.text,caption.text = "","","",""; syncing = false;
        handle.generatedExpression = "";
        rebuild(); refreshPreview(); refreshChoices(); set(status,"text","");
    end);
    function handle:isAlive() return not self.closed and self.popup ~= nil; end
    function handle:isOpen() return self:isAlive() and self.opened; end
    function handle:roll() submit(); end
    local function hidden()
        if handle.closed then return; end
        handle.opened,handle.closing,handle.busy = false,false,false;
        local pending = handle.pendingRoll; handle.pendingRoll = nil;
        local nextOptions = handle.pendingOpen; handle.pendingOpen = nil;
        if type(callbacks.onClose) == "function" then callbacks.onClose(); end
        -- One native popup lives as long as its composer. Do not destroy it
        -- during/after onClose: native fade animations still retain UI locks.
        if pending==nil and nextOptions==nil then return; end
        setTimeout(function()
            if handle.closed then return; end
            if pending~=nil then
                local ok,reason = pcall(callbacks.onRoll,pending.expression,pending.description,pending.settings);
                if not ok and type(callbacks.onError)=="function" then callbacks.onError(tostring(reason)); end
            end
            if nextOptions~=nil and not handle.closed then handle:open(nextOptions); end
        end,1);
    end
    function handle:close()
        if not self:isOpen() or self.closing then return; end
        self.closing,self.opened = true,false;
        self.popup:close(false,false);
    end
    function handle:open(nextOptions)
        if not self:isAlive() then return; end
        if self.closing then self.pendingOpen = nextOptions; return; end
        nextOptions = nextOptions or options;
        options.anchor = nextOptions.anchor or options.parent;
        pool,constants,self.mode,self.order,self.busy = {},{},"normal","native",false;
        syncing = true;
        modifier.text,expression.text,custom.text = "","","";
        caption.text = tostring(nextOptions.caption or "");
        syncing = false;
        self.generatedExpression = "";
        rebuild(); refreshPreview(); refreshChoices(); set(status,"text","");
        if nextOptions.face~=nil then self:addDie(nextOptions.face); end
        if not self.opened then
            self.opened = true;
            local ok,shown = pcall(function() return popup:showPopup("top",options.anchor); end);
            if not ok or shown==false then
                self.opened = false;
                if type(callbacks.onError)=="function" then callbacks.onError(tostring(ok and "Não foi possível abrir a rolagem." or shown)); end
                return;
            end
        end
        modifier:setFocus();
    end
    function handle:dispose()
        if self.closed then return; end
        local wasOpen = self.opened;
        self.closed,self.opened,self.pendingOpen,self.pendingRoll = true,false,nil,nil;
        if wasOpen then self.popup:close(true,false); end
        -- The composer destroys its parent card and all owned controls. This
        -- menu never calls destroy on the animated native popup separately.
    end
    popup.onClose = hidden;
    handle:open(options);
    return handle;
end

return M;

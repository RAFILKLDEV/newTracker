local gui = require("gui.lua");
local view = require("trackerChatView.lua");

local M = {};
local PADDING = 2;
local WIDTH = 360;
local HEIGHT = 420;
local COMPACT_HEIGHT = 32;

local function assign(control, field, value)
    if control[field] ~= value then control[field] = value; end
end

local function invoke(callbacks, name, ...)
    local callback = callbacks ~= nil and callbacks[name] or nil;
    if type(callback) == "function" then return callback(...); end
end

-- Isolated copy of the documented popup recipe. Do not call or refactor the
-- Turno/Atenção helpers: this panel owns only its own card and controls.
local function applySize(popup, card, height)
    popup.width = WIDTH + 2 * PADDING;
    popup.height = height + 2 * PADDING;
    if card ~= nil then
        card.left, card.top = PADDING, PADDING;
        card.width, card.height = WIDTH, height;
    end
end

function M.open(session, callbacks)
    local popup = gui.newPopupForm();
    popup._cardMargin = PADDING;
    applySize(popup, nil, HEIGHT);
    popup.drawContainer = false;
    pcall(function() popup.backOpacity = 0; end);
    popup.cancelable = false;
    popup.resizable = false;
    popup.movable = true;
    popup.hitTest = false;
    popup.placement = "topRight";
    popup._dynamicCtrls = {};
    pcall(function() popup.alwaysOnTop = true; end);
    pcall(function() popup.topMost = true; end);
    local card = gui.newRectangle();
    card.parent = popup;
    card.align = "none";
    card.left, card.top = PADDING, PADDING;
    card.width, card.height = WIDTH, HEIGHT;
    card.color = "#181C21";
    card.strokeColor = "#D7A84B";
    card.strokeSize = 1;
    card.xradius, card.yradius = 5, 5;
    card.hitTest = false;
    popup._fixedSizeCard = card;
    local function register(control)
        popup._dynamicCtrls[#popup._dynamicCtrls + 1]=control;
        return control;
    end
    register(card);
    local handle = {
        popup = popup, card = card, session = session, callbacks = callbacks or {},
        rows = {}, closed = false, compact = false
    };
    local header = gui.newLabel();
    header.parent = card;
    header.align = "none";
    header.left, header.top = PADDING, PADDING;
    header.width, header.height = WIDTH - 64, 28;
    header.text = "≡  Mensagens fixadas";
    header.fontColor = "#D8E0E8";
    header.fontStyle = "bold";
    header.fontSize = 12;
    header.vertTextAlign = "center";
    header.hitTest = false;
    header.hint = "Arraste pelo título para mover";
    local sizeButton = gui.newButton();
    sizeButton.parent = card;
    sizeButton.align = "none";
    sizeButton.left, sizeButton.top = WIDTH - 60, PADDING;
    sizeButton.width, sizeButton.height = 28, 28;
    sizeButton.text = "−";
    sizeButton.hint = "Minimizar";
    sizeButton.hitTest = true;
    local closeButton = gui.newButton();
    closeButton.parent = card;
    closeButton.align = "none";
    closeButton.left, closeButton.top = WIDTH - 30, PADDING;
    closeButton.width, closeButton.height = 28, 28;
    closeButton.text = "×";
    closeButton.hint = "Fechar fixados";
    closeButton.hitTest = true;
    local list = gui.newScrollBox();
    list.parent = card;
    list.align = "none";
    list.left, list.top = PADDING, COMPACT_HEIGHT + PADDING;
    list.width, list.height = WIDTH - 2 * PADDING, HEIGHT - COMPACT_HEIGHT - 2 * PADDING;
    local empty = gui.newLabel();
    empty.parent = list;
    empty.align = "none";
    empty.left, empty.top = PADDING, PADDING;
    empty.width, empty.height = WIDTH - 24, 48;
    empty.text = "Clique com o botão direito em uma mensagem para fixá-la.";
    empty.fontColor = "#B8C3CE";
    empty.fontSize = 12;
    empty.wordWrap = true;
    empty.hitTest = false;
    for _, control in ipairs({header,sizeButton,closeButton,list,empty}) do register(control); end

    function handle:isOpen()
        return not self.closed and self.popup ~= nil and self.popup.handle ~= nil and self.popup.handle ~= 0;
    end

    local function finish()
        if handle.closed then return; end
        handle.closed = true;
        for _, row in pairs(handle.rows) do row.message:destroy(); row.remove:destroy(); end
        handle.rows = {};
        local window = handle.popup;
        handle.popup = nil;
        if window ~= nil and window.handle ~= nil and window.handle ~= 0 then window:destroy(); end
        invoke(handle.callbacks, "onClose");
    end

    function handle:close()
        if not self:isOpen() then return; end
        self.popup:close();
        finish();
    end

    function handle:show()
        if self:isOpen() and self.popup.isShowing ~= true then
            -- Explicit /fixados or toolbar action reuses the same native form.
            -- Do not recreate controls or reapply card geometry on visibility.
            gui.showPopup(self.popup,{placement="topRight",onClose=finish});
        end
    end

    function handle:queueLayout()
        if not self:isOpen() or self.layoutPending then return; end
        self.layoutPending = true;
        setTimeout(function()
            self.layoutPending = false;
            if self:isOpen() then self:render(self.pins); end
        end, 16);
    end

    function handle:render(pins)
        if not self:isOpen() then return; end
        pins = pins or {};
        self.pins = pins;
        local top, retained = 0, {};
        list:beginUpdate();
        assign(empty, "visible", #pins == 0);
        for index, pin in ipairs(pins) do
            local entry = pin.entry;
            if entry ~= nil then
                local key = tostring(pin.scope or "private") .. ":" .. tostring(entry.key or index);
                local row = self.rows[key];
                if row == nil then
                    row = {message = view.createMessage(list, self.callbacks, {
                        maxBodyHeight = 160,
                        room = self.session.room,
                        onResize = function()
                            handle:queueLayout();
                        end
                    })};
                    row.remove = gui.newButton();
                    row.remove.parent = list;
                    row.remove.align = "none";
                    row.remove.width, row.remove.height = 78, 24;
                    row.remove.text = "Desafixar";
                    row.remove.fontSize = 10;
                    row.remove.hitTest = true;
                    row.remove.onClick = function() invoke(handle.callbacks, "onUnpin", row.pin); end;
                    self.rows[key] = row;
                end
                row.pin = pin;
                assign(row.remove, "enabled", pin.canUnpin ~= false);
                local badge = pin.scope == "shared" and "Compartilhada" or "Particular";
                local height = row.message:update(entry, pin.state or {}, WIDTH - 22, badge);
                assign(row.message.control, "top", top);
                assign(row.remove, "left", WIDTH - 102);
                assign(row.remove, "top", top + height);
                assign(row.remove, "hint", "Desafixar " .. tostring(entry.name or "mensagem"));
                top = top + height + 28;
                retained[key] = true;
            end
        end
        for key, row in pairs(self.rows) do
            if not retained[key] then
                row.message:destroy();
                row.remove:destroy();
                self.rows[key] = nil;
            end
        end
        list:endUpdate();
        list:needRepaint();
        -- Message updates never change native width, height or coordinates.
    end

    sizeButton.onClick = function()
        if not handle:isOpen() then return; end
        handle.compact = not handle.compact;
        popup:beginUpdate();
        -- Only an explicit user action changes size, as with Turno compact.
        applySize(popup, card, handle.compact and COMPACT_HEIGHT or HEIGHT);
        list.visible = not handle.compact;
        sizeButton.text = handle.compact and "+" or "−";
        sizeButton.hint = handle.compact and "Expandir" or "Minimizar";
        popup:endUpdate();
        popup:needRepaint();
    end;
    closeButton.onClick = function() handle:close(); end;
    -- Hiding the room/tab does not destroy the pins or invalidate chat cache.
    -- Only the native close event and explicit close button dispose this panel.
    local shown = gui.showPopup(popup, {placement = "topRight",onClose=finish});
    if shown == false then finish(); return nil; end
    return handle;
end

return M;

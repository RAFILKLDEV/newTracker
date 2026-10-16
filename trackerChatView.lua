local gui = require("gui.lua");
local System = require("system.lua");
local model = require("trackerChatModel.lua");
local ndb = require("ndb.lua");
local Firecast = require("rrpg.lua");
local Composer = require("trackerChatComposer.lua");
local Inline = require("trackerChatInline.lua");
local dialogs = require("dialogs.lua");

local M = {};
local MESSAGE_GAP = 2;
local BACKGROUND = "#242424";
local BODY_FONT = 14;
local nameColors = {};
local nameColorCount = 0;
local messageBindings = setmetatable({}, {__mode = "k"});
local bindingsByHandle = {};
local mountedMessages = setmetatable({}, {__mode = "k"});
local uiSignature;

local function assign(control, field, value)
    if control[field] ~= value then control[field] = value; end
end

local function visualState(state)
    state = state or {};
    return {result = state.result, delta = state.delta, corrected = state.corrected,
        ownPin = state.ownPin ~= nil and state.ownPin ~= false,
        sharedPin = state.sharedPin ~= nil and state.sharedPin ~= false,
        notes = state.notes, rollOrder = state.rollOrder};
end

local function invoke(callbacks, name, ...)
    local callback = callbacks ~= nil and callbacks[name] or nil;
    if type(callback) == "function" then return callback(...); end
end

local function trimmed(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "");
end

-- State consists of plain values supplied by the chat controller, never combat
-- NDBs. A stable signature keeps unchanged messages intact during log polling.
local function fingerprint(value, depth, seen)
    local kind = type(value);
    if kind ~= "table" then
        if kind == "function" or kind == "userdata" then return kind; end
        return kind .. ":" .. tostring(value);
    end
    depth, seen = depth or 0, seen or {};
    if depth > 8 or seen[value] then return "table"; end
    seen[value] = true;
    local keys, parts = {}, {};
    for key in pairs(value) do
        if type(key) == "string" or type(key) == "number" then keys[#keys + 1] = key; end
    end
    table.sort(keys, function(a, b) return tostring(a) < tostring(b); end);
    for _, key in ipairs(keys) do
        parts[#parts + 1] = tostring(key) .. "=" .. fingerprint(value[key], depth + 1, seen);
    end
    seen[value] = nil;
    return "{" .. table.concat(parts, "\n") .. "}";
end

M.fingerprint = fingerprint;

local function messageLayout(entry, previous, index)
    local system = tostring(entry.kind):sub(1, 4) == "sys_";
    local previousSystem = previous ~= nil and tostring(previous.kind):sub(1, 4) == "sys_";
    local continued = not system and previous ~= nil and not previousSystem
        and entry.authorLogin == previous.authorLogin and entry.name == previous.name
        and fingerprint(entry.impersonation) == fingerprint(previous.impersonation)
        and math.abs((tonumber(entry.epoch) or 0) - (tonumber(previous.epoch) or 0)) <= 300;
    return {header = not system and not continued,
        separator = index > 1 and (system and not previousSystem or not system and not continued)};
end

local function label(parent, height)
    local control = gui.newLabel();
    control.parent = parent;
    control.align = "none";
    control.height = height;
    control.fontSize = 12;
    control.fontFamily = "Roboto";
    control.fontColor = "#E1E1E1";
    control.vertTextAlign = "leading";
    control.textTrimming = "none";
    control.wordWrap = true;
    control.autoSize = true;
    control.hitTest = true;
    return control;
end

local function richAvailable()
    local ok, supported = pcall(System.checkAPIVersion, 87, 4);
    return ok and supported == true and type(gui.newRichEdit) == "function";
end

local function newBody(parent, rich)
    local control;
    if rich then
        local ok, created = pcall(gui.newRichEdit);
        if ok then control = created; end
    end
    if control == nil then
        control = label(parent, 20);
        control.fontSize = BODY_FONT;
        rich = false;
    else
        control.readOnly = true;
        control.showToolbar = false;
        control.backgroundColor = BACKGROUND;
        control.defaultFontColor = "#E1E1E1";
        control.defaultFontSize = BODY_FONT;
        control.hideSelection = false;
    end
    control.parent = parent;
    control.align = "none";
    control.hitTest = true;
    return control, rich;
end

local function characters(text)
    text = tostring(text or "");
    if type(utf8) == "table" and type(utf8.codes) == "function" then
        local ok, width = pcall(function()
            local units = 0;
            for _, point in utf8.codes(text) do
                if (point >= 0x300 and point <= 0x36F) or (point >= 0xFE00 and point <= 0xFE0F)
                    or point == 0x200D then
                    -- Combining marks and emoji joiners do not occupy a column.
                elseif (point >= 0x1100 and point <= 0x115F)
                    or (point >= 0x2E80 and point <= 0xA4CF)
                    or (point >= 0xAC00 and point <= 0xD7AF)
                    or (point >= 0xF900 and point <= 0xFAFF)
                    or (point >= 0xFF01 and point <= 0xFF60)
                    or point >= 0x1F000 then
                    units = units + 2;
                else
                    units = units + 1;
                end
            end
            return units;
        end);
        if ok then return width; end
    end
    if type(utf8) == "table" and type(utf8.len) == "function" then
        local ok, length = pcall(utf8.len, text);
        if ok and length ~= nil then return length; end
    end
    local _, length = text:gsub("[^\128-\191]", "");
    return length;
end

-- Only formatted bodies need an editor viewport. Ordinary text uses the native
-- Label's actual wrapped height, including font metrics and the client's scale.
local function talemarkSpace(text, options, baseFont)
    local extra, font = 0, baseFont or BODY_FONT;
    if type(Firecast.parseTalemark) ~= "function" then return extra, font; end
    local ok, root = pcall(Firecast.parseTalemark, tostring(text or ""), options);
    if not ok or type(root) ~= "table" then return extra, font; end
    local function visit(tag, depth)
        if type(tag) ~= "table" or depth > 32 then return; end
        if tag.type == "heading" then
            local level = tonumber(tag.level) or 1;
            font = math.max(font, level <= 1 and 30 or level == 2 and 25 or 21);
            extra = extra + 12;
        elseif tag.type == "initialCaps" then
            extra = extra + 20;
        elseif tag.type == "image" then
            extra = extra + math.max(32, tonumber(tag.height) or 96)
                + math.max(0, tonumber(tag.descent) or 0);
        elseif tag.type == "smiley" then
            extra = extra + 12;
        elseif tag.type == "paragraph" or tag.type == "horzLine" then
            extra = extra + 5;
        end
        for _, child in ipairs(tag.children or {}) do visit(child, depth + 1); end
    end
    visit(root, 0);
    return extra, font;
end

local function estimateHeight(text, width, maximum, fontSize, extra, inset)
    fontSize, extra, inset = fontSize or BODY_FONT, extra or 0, inset or 8;
    local columns = math.max(1, math.floor(math.max(1, width - inset) / (fontSize * 0.64)));
    local lines = 0;
    for line in (tostring(text or "") .. "\n"):gmatch("(.-)\n") do
        local length = characters(line:gsub("\t", "    "));
        local count = math.max(1, math.ceil(length / columns));
        lines = lines + count;
    end
    local lineHeight = math.max(16, math.ceil(fontSize * 1.4));
    local height = lines * lineHeight + inset + extra;
    if maximum ~= nil then height = math.min(maximum, height); end
    return math.max(lineHeight + inset, height);
end

local function safeBody(entry, state, original)
    local ok, text = pcall(model.bodyText, entry, state, original);
    if ok and type(text) == "string" then return text; end
    return tostring(entry.content or "");
end

local function safeRoll(entry, state)
    local ok, text = pcall(model.rollText, entry, state);
    if ok and type(text) == "string" then return text; end
    return tostring(entry.roll ~= nil and entry.roll.detail or "");
end

local function bodyText(entry, state)
    if entry.roll ~= nil and entry.deleted ~= true then return model.stripCodes(entry.content or ""); end
    return safeBody(entry, state, false);
end

local function rollLineParts(entry, state)
    local parts = {};
    local caption = tostring(entry.content or "");
    if trimmed(caption) ~= "" then
        local style = type(entry.talemarkOptions) == "table" and entry.talemarkOptions.defaultTextStyle or nil;
        style = type(style) == "table" and style or {};
        parts[#parts + 1] = {text=model.stripCodes(caption) .. " — ",color=style.color or "#BDBDBD",
            bold=style.bold==true,italic=style.italic==true,underline=style.underline==true,strikeout=style.strikeout==true};
    end
    for _, part in ipairs(model.rollSegments(entry,state)) do parts[#parts + 1] = part; end
    return parts;
end

local function parseText(text, options)
    if not richAvailable() or type(Firecast.parseTalemark) ~= "function" then return nil; end
    local ok, tree = pcall(Firecast.parseTalemark, tostring(text or ""):gsub("%[Â§", "[§"), options);
    if ok and type(tree) == "table" then return tree; end
end

local function needsRichText(entry)
    if entry.deleted or tostring(entry.kind):sub(1, 4) == "sys_" then return false; end
    -- Files retain native clickable links. All Talemark spans/images continue
    -- through the native renderer; plain paragraphs have no editor chrome.
    if entry.kind == "file" then return richAvailable(); end
    local tree = parseText(entry.content, entry.talemarkOptions);
    if tree == nil then return false; end
    local function formatted(tag, depth)
        if type(tag) ~= "table" or depth > 32 then return false; end
        if tag.type ~= "root" and tag.type ~= "paragraph"
            and tag.type ~= "text" and tag.type ~= "breakline" then return true; end
        for _, child in ipairs(tag.children or {}) do
            if formatted(child, depth + 1) then return true; end
        end
        return false;
    end
    return formatted(tree, 0);
end

local function measureLabel(control, width)
    -- With wordWrap + autoSize, the native Label keeps its assigned width and
    -- computes its own height. onResize below also handles deferred layout.
    assign(control, "width", width);
    local fontSize = control.fontSize;
    if control._chatMetricSize ~= fontSize then
        local ok, height = pcall(function() return control:getFontHeight(); end);
        control._chatMetricHeight = ok and tonumber(height) or 0;
        control._chatMetricSize = fontSize;
    end
    return math.ceil(math.max(tonumber(control.height) or 0,
        control._chatMetricHeight or 0, 16));
end

local function nameColor(parent, entry, fallback)
    local name = tostring(entry.name or "");
    if not name:find("§", 1, true) or not richAvailable() then return fallback; end
    local key = fingerprint({name, entry.talemarkOptions});
    if nameColors[key] ~= nil then return nameColors[key]; end
    -- Resolve the native chat palette without keeping a tiny editor in every
    -- header. The temporary, hidden probe is destroyed and the color is cached.
    local probe, began, color;
    local ok = pcall(function()
        probe = gui.newRichEdit();
        probe.parent = parent;
        probe.visible, probe.showToolbar = false, false;
        probe.defaultFontColor = fallback;
        probe:beginEdit(); began = true;
        probe:insertTalemark(name:gsub("%[Â§", "[§"), entry.talemarkOptions);
        probe:gotoStart(); probe:gotoNext(true);
        color = probe:getSelectionFontColor();
    end);
    if began then pcall(function() probe:endEdit(); end); end
    if probe ~= nil then pcall(function() probe:destroy(); end); end
    if not ok or type(color) ~= "string" or color == "" then color = fallback; end
    if nameColorCount >= 128 then nameColors, nameColorCount = {}, 0; end
    nameColors[key], nameColorCount = color, nameColorCount + 1;
    return color;
end

local function setBody(row, entry, state)
    local plain = bodyText(entry, state);
    if row.richBody ~= nil then row.richBody.visible = false; end
    row.body = row.plainBody;
    row.rich = false;
    row.plainBody.visible = true;
    if needsRichText(entry) then
        if row.richBody == nil then
            local control, rich = newBody(row.control, true);
            if rich then
                row.richBody = control;
                control.onMenu, control.onMouseDown = row.menu, row.navigate;
            else
                control:destroy();
            end
        end
        if row.richBody ~= nil then
            row.body, row.rich = row.richBody, true;
            row.plainBody.visible, row.richBody.visible = false, true;
        end
    end
    local rich = row.rich;
    if not rich then row.body.text = plain; return plain; end
    local began = false;
    local ok = pcall(function()
        row.body.readOnly = false;
        row.body:beginEdit();
        began = true;
        row.body:selectAll();
        row.body:deleteSelection();
        if entry.deleted == true then
            row.body:insertText(plain);
        elseif entry.roll ~= nil then
            if tostring(entry.content or "") ~= "" then
                row.body:insertTalemark(entry.content, entry.talemarkOptions);
                row.body:gotoEnd(); row.body:unselect();
                row.body:insertText(" — ");
            end
            for _, part in ipairs(model.rollSegments(entry,state)) do
                local firstGlyph = row.body:getLengthInGlyphs();
                row.body:insertText(part.text);
                local lastGlyph = row.body:getLengthInGlyphs();
                row.body:gotoPositionInGlyphs(firstGlyph);
                row.body:gotoPositionInGlyphs(lastGlyph,true);
                row.body:setSelectionFontColor(part.color);
                row.body:setSelectionFontStyle(part.bold and {"bold"} or {});
                row.body:gotoEnd(); row.body:unselect();
            end
        elseif entry.kind == "file" then
            local caption, filename, url = tostring(entry.content or ""),
                tostring(entry.fileName or ""), tostring(entry.fileURL or "");
            local haveText = false;
            if caption ~= "" then
                row.body:insertTalemark(caption, entry.talemarkOptions);
                haveText = true;
            end
            if filename ~= "" then
                if haveText then row.body:breakLine(); end
                row.body:insertText(filename);
                haveText = true;
            end
            if url ~= "" then
                if haveText then row.body:breakLine(); end
                local firstGlyph = row.body:getLengthInGlyphs();
                row.body:insertText(url);
                row.body:gotoPositionInGlyphs(firstGlyph, true);
                row.body:setSelectionURL(url);
                row.body:gotoEnd(); row.body:unselect();
            end
        elseif entry.kind == "laugh" or tostring(entry.kind):sub(1,4) == "sys_" then
            row.body:insertText(safeBody(entry, nil, true));
        else
            row.body:insertTalemark(tostring(entry.content or ""), entry.talemarkOptions);
        end
        for _, note in ipairs(entry.roll == nil and state.notes or {}) do
            row.body:breakLine();
            row.body:insertText("Observação de " .. tostring(note.author or note.authorLogin or "") .. ": "
                .. tostring(note.text or note.content or ""));
        end
        row.body:gotoStart();
        row.body:unselect();
    end);
    if began then pcall(function() row.body:endEdit(); end); end
    pcall(function() row.body.readOnly = true; end);
    if not ok then
        row.body:destroy();
        row.richBody = nil;
        row.body, row.rich = row.plainBody, false;
        row.plainBody.visible = true;
        row.body.text = plain;
    else
        local read, renderedText = pcall(function() return row.body:getText(); end);
        -- The editor includes a terminal paragraph separator in getText().
        -- It is not an additional empty message line.
        if read and type(renderedText) == "string" then plain = renderedText:gsub("[\r\n]+$", ""); end
    end
    return plain;
end

local function setName(row, entry)
    local mode = entry.impersonation and entry.impersonation.mode;
    local fallback = mode == "character" and "#DFBB7D"
        or mode == "narrator" and "#B8C8DC" or "#E1E1E1";
    row.name.text = model.stripCodes(tostring(entry.name or "Mensagem"));
    row.name.fontColor = fallback;
end

-- Exported to let the independent pins window use exactly the same renderer.
-- It does not touch or reuse any Turno/Atenção popup or their layout helpers.
function M.createMessage(parent, callbacks, options)
    options = options or {};
    local control = gui.newRectangle();
    control.parent = parent;
    control.align = "none";
    control.left = 0;
    control.color = BACKGROUND;
    control.strokeColor = "transparent";
    control.strokeSize = 0;
    control.hitTest = true;
    local row = {control = control, callbacks = callbacks, options = options};
    row.separator = gui.newHorzLine();
    row.separator.parent, row.separator.align = control, "none";
    row.separator.height, row.separator.strokeSize, row.separator.strokeColor = 1, 1, "#46494C";
    row.separator.hitTest = false;
    row.name = label(control, 20);
    row.name.fontSize, row.name.fontStyle = BODY_FONT, "bold";
    row.nameSizer = label(control, 20);
    row.nameSizer.visible, row.nameSizer.wordWrap = false, false;
    row.nameSizer.fontSize, row.nameSizer.fontStyle = BODY_FONT, "bold";
    row.time = label(control, 23);
    row.time.fontSize = 12;
    row.time.fontColor = "#666B70";
    row.time.fontStyle = "";
    row.time.autoSize, row.time.wordWrap = false, false;
    row.time.height, row.time.vertTextAlign = 20, "center";
    row.time.horzTextAlign = "trailing";
    row.avatar = gui.newImage();
    row.avatar.parent = control;
    row.avatar.align = "none";
    row.avatar.width = 40;
    row.avatar.height = 40;
    row.avatar.style = "autoFit";
    row.avatar.showProgress = false;
    row.avatar.hitTest = true;
    row.avatarPlaceholder = label(control, 40);
    row.avatarPlaceholder.autoSize, row.avatarPlaceholder.wordWrap = false, false;
    row.avatarPlaceholder.width, row.avatarPlaceholder.height = 40, 40;
    row.avatarPlaceholder.fontFamily, row.avatarPlaceholder.fontSize = "Segoe MDL2 Assets", 28;
    row.avatarPlaceholder.text, row.avatarPlaceholder.horzTextAlign = "", "center";
    row.avatarPlaceholder.vertTextAlign = "center";
    row.avatarMask = gui.newPath();
    row.avatarMask.parent, row.avatarMask.align = control, "none";
    row.avatarMask.width, row.avatarMask.height = 44, 44;
    row.avatarMask.mode, row.avatarMask.color = "stretch", BACKGROUND;
    row.avatarMask.strokeSize, row.avatarMask.hitTest = 0, false;
    -- Bleed beyond the image and crop one pixel inside it, covering its frame.
    row.avatarMask.data = "M0 0 L44 0 L44 44 L0 44 Z M22 3 C11.506 3 3 11.506 3 22 C3 32.494 11.506 41 22 41 C32.494 41 41 32.494 41 22 C41 11.506 32.494 3 22 3 Z";
    row.result = label(control, 24);
    row.result.fontStyle = "bold";
    row.result.fontSize = 14;
    row.result.fontColor = "#63E893";
    row.badge = label(control, 20);
    row.badge.fontSize = 11;
    row.badge.fontColor = "#AEBECD";
    row.plainBody = label(control, 20);
    row.plainBody.fontSize = BODY_FONT;
    row.rollNotes = label(control, 20);
    row.rollNotes.fontSize, row.rollNotes.fontColor = BODY_FONT, "#BDBDBD";
    row.rollNotes.visible = false;
    row.body, row.rich = row.plainBody, false;
    row.details = gui.newButton();
    row.details.parent = control;
    row.details.align = "none";
    row.details.height = 22;
    row.details.text = "Detalhes";
    row.details.fontSize = 10;
    local function currentEntry()
        if type(row.options.getEntry) == "function" then return row.options.getEntry(); end
        return row.entry;
    end
    row.menu = function()
        local entry = currentEntry();
        if entry ~= nil then invoke(row.callbacks, "onContext", entry, row.body); end
    end;
    row.navigate = function()
        if type(row.options.onNavigate) == "function" then row.options.onNavigate(); end
    end;
    for _, child in ipairs({control, row.name, row.time, row.avatar, row.avatarPlaceholder, row.result, row.badge, row.body, row.rollNotes, row.details}) do
        child.onMenu = row.menu;
        child.onMouseDown = row.navigate;
    end
    local function layoutChanged()
        if row.control ~= nil and row.signature ~= nil and type(row.options.onResize) == "function" then
            -- The owning list/pins panel coalesces these native measurements.
            row.options.onResize();
        end
    end
    for _, child in ipairs({row.name, row.nameSizer, row.time, row.result, row.badge, row.plainBody, row.rollNotes}) do
        child.onResize = layoutChanged;
    end
    row.details.onClick = function()
        local entry = currentEntry();
        if entry ~= nil then invoke(row.callbacks, "onDetails", entry); end
    end;

    function row:update(entry, state, width, extraBadge, signature, resolvedAvatar, layout)
        state = state or {};
        width = math.max(48, tonumber(width) or 600);
        local avatar = resolvedAvatar or model.avatarForEntry(entry, self.options.room);
        layout = layout or {header = true, separator = false};
        signature = signature or uiSignature(entry, state, avatar, layout) .. tostring(extraBadge or "");
        local changed = self.signature ~= signature;
        self.entry, self.state = entry, state;
        assign(self.control, "width", width);
        local system = tostring(entry.kind):sub(1, 4) == "sys_";
        local showHeader = not system and layout.header ~= false;
        local portrait = showHeader and width >= 160;
        local hasAvatar = portrait and trimmed(avatar) ~= "";
        local contentLeft = system and 46 or width >= 160 and 56 or 4;
        local inner = math.max(24, width - contentLeft - 6);
        local hasRoll = entry.roll ~= nil and entry.deleted ~= true;
        local showTime = system or width >= 110;
        local timeWidth = system and 44 or width >= 440 and 146 or 44;
        local bodyWidth = math.max(24, inner - (not system and showTime and timeWidth + 8 or 0));
        local text = self.plain or "";
        if changed then
            self.signature = signature;
            setName(self, entry);
            self.nameSizer.text = self.name.text;
            self.name.hint = tostring(entry.name or "Mensagem");
            assign(self.avatar, "url", tostring(avatar or ""));
            self.result.visible = false;
            self.rollNotes.text = hasRoll and safeBody({kind="standard",content=""},state,false):gsub("^\n", "") or "";
            self.rollNotes.visible = hasRoll and self.rollNotes.text ~= "";
            local badges = {};
            if state.corrected == true then badges[#badges + 1] = "Corrigida"; end
            if state.ownPin ~= nil and state.ownPin ~= false then badges[#badges + 1] = "Fixada para mim"; end
            if state.sharedPin ~= nil and state.sharedPin ~= false then badges[#badges + 1] = "Fixada na mesa"; end
            if trimmed(extraBadge) ~= "" then badges[#badges + 1] = extraBadge; end
            if entry.kind == "action" or entry.kind == "acao" then badges[#badges + 1] = "Ação"; end
            if entry.deleted == true then badges[#badges + 1] = "Removida no chat original"; end
            local notes = type(state.notes) == "table" and #state.notes or 0;
            if notes > 0 then badges[#badges + 1] = tostring(notes) .. " observações"; end
            self.badge.text = table.concat(badges, " · ");
            self.badge.hint = self.badge.text;
            self.badge.visible = #badges > 0;
            self.details.visible = false;
            text = setBody(self, entry, state);
            self.plain = text;
            self.rollParts = hasRoll and not self.rich and rollLineParts(entry,state) or nil;
            self.richExtra, self.richFont = talemarkSpace(entry.content, entry.talemarkOptions);
            assign(self.plainBody, "fontSize", BODY_FONT);
            local color = system and "#7FFF6B" or "#BDBDBD";
            local style = type(entry.talemarkOptions) == "table" and entry.talemarkOptions.defaultTextStyle or nil;
            local flags = {};
            if type(style) == "table" then
                for _, key in ipairs({"bold", "italic", "underline"}) do
                    if style[key] == true then flags[#flags + 1] = key; end
                end
                if type(style.color) == "string" then color = style.color;
                elseif type(style.color) == "number" then
                    color = nameColor(self.control, {name = "[§K" .. tostring(style.color) .. "]x"}, color);
                end
            elseif entry.kind == "action" then flags[1] = "italic"; end
            local flagKey = table.concat(flags, ",");
            if self.plainFontStyle ~= flagKey then
                self.plainBody.fontStyle = flags;
                self.plainFontStyle = flagKey;
            end
            assign(self.plainBody, "fontColor", color);
        end
        local start = layout.separator and 26 or 2;
        assign(self.separator, "visible", layout.separator == true);
        assign(self.separator, "left", 0); assign(self.separator, "top", 12);
        assign(self.separator, "width", width - 4);
        assign(self.avatar, "visible", hasAvatar);
        assign(self.avatarPlaceholder, "visible", portrait and not hasAvatar);
        assign(self.avatarMask, "visible", hasAvatar);
        for _, item in ipairs({self.avatar, self.avatarPlaceholder}) do
            assign(item, "left", 0); assign(item, "top", start);
        end
        assign(self.avatarMask, "left", -2); assign(self.avatarMask, "top", start - 2);
        assign(self.name, "visible", false);
        assign(self.time, "visible", showTime);
        assign(self.name, "left", contentLeft); assign(self.name, "top", start);
        local nameHeight = 16;
        if showHeader then
            if self.nameInline == nil then
                self.nameInline = Inline.new(self.control, {fontSize = BODY_FONT,
                    fontFamily = "Roboto", bold = true, color = self.name.fontColor,
                    onResize = layoutChanged, onMenu = self.menu, onNavigate = self.navigate});
            end
            assign(self.nameInline.control, "visible", true);
            assign(self.nameInline.control, "left", contentLeft);
            assign(self.nameInline.control, "top", start);
            self.nameInline:setParts({{text = tostring(entry.name or "Mensagem"),
                nickname = true, bold = true, color = self.name.fontColor}}, bodyWidth);
            nameHeight = self.nameInline:getHeight();
        elseif self.nameInline ~= nil then assign(self.nameInline.control, "visible", false); end
        local fullTime = tostring(entry.timeText or "");
        local hour, minute = fullTime:match("(%d%d):(%d%d):%d%d");
        local date = fullTime:match("(%d%d/%d%d/%d%d%d%d)");
        local shortTime = hour and hour .. ":" .. minute or fullTime;
        assign(self.time, "text", system and "[" .. shortTime .. "]"
            or timeWidth > 44 and date ~= nil and date .. " - " .. shortTime or shortTime);
        assign(self.time, "hint", fullTime);
        assign(self.time, "horzTextAlign", system and "leading" or "trailing");
        assign(self.time, "width", timeWidth);
        local timeHeight = 20;
        assign(self.time, "left", system and 0 or width - timeWidth - 6);
        assign(self.time, "top", start);
        local top = start;
        if showHeader then top = start + math.max(nameHeight, timeHeight) + 4; end
        assign(self.body, "left", contentLeft); assign(self.body, "top", top);
        local bodyHeight;
        local systemParts = system and entry.deleted ~= true and #(state.notes or {}) == 0
            and model.systemSegments(entry) or nil;
        if self.systemInline ~= nil then assign(self.systemInline.control, "visible", systemParts ~= nil); end
        if systemParts ~= nil then
            if self.systemInline == nil then
                self.systemInline = Inline.new(self.control, {fontSize = BODY_FONT, fontFamily = "Roboto",
                    color = "#7FFF6B", onResize = layoutChanged, onMenu = self.menu, onNavigate = self.navigate});
            end
            assign(self.body, "visible", false);
            assign(self.systemInline.control, "left", contentLeft);
            assign(self.systemInline.control, "top", top);
            self.systemInline:setParts(systemParts, bodyWidth);
            bodyHeight = self.systemInline:getHeight();
        elseif hasRoll and not self.rich then
            assign(self.body, "visible", false); bodyHeight = 0;
        elseif self.rich then
            assign(self.body, "visible", true);
            assign(self.body, "width", bodyWidth);
            assign(self.body, "height", estimateHeight(text, bodyWidth, self.options.maxBodyHeight,
                self.richFont or BODY_FONT, self.richExtra or 0, 14));
            bodyHeight = self.body.height;
        else
            assign(self.body, "visible", true);
            bodyHeight = measureLabel(self.body, bodyWidth);
        end
        if system then bodyHeight = math.max(bodyHeight, timeHeight); end
        top = top + bodyHeight + (bodyHeight > 0 and 2 or 0);
        local inlineRoll = hasRoll and not self.rich;
        if self.rollInline ~= nil then assign(self.rollInline.control, "visible", inlineRoll); end
        if inlineRoll then
            if self.rollInline == nil then
                self.rollInline = Inline.new(self.control, {fontSize=BODY_FONT,fontFamily="Roboto",
                    color="#BDBDBD",onResize=layoutChanged,onMenu=self.menu,onNavigate=self.navigate});
            end
            assign(self.rollInline.control, "left", contentLeft); assign(self.rollInline.control, "top", top);
            self.rollInline:setParts(self.rollParts or rollLineParts(entry,state),bodyWidth);
            top = top + self.rollInline:getHeight() + 2;
        end
        if self.rollNotes.visible then
            assign(self.rollNotes, "left", contentLeft); assign(self.rollNotes, "top", top);
            top = top + measureLabel(self.rollNotes,bodyWidth) + 2;
        end
        assign(self.badge, "left", contentLeft); assign(self.badge, "top", top);
        local badgeHeight = measureLabel(self.badge, bodyWidth);
        if self.badge.visible then top = top + badgeHeight + 2; end
        assign(self.details, "left", contentLeft); assign(self.details, "top", top);
        assign(self.details, "width", math.min(100, inner));
        if self.details.visible then top = top + 23; end
        assign(self.control, "height", math.ceil(math.max(top + 2, portrait and start + 44 or 0,
            showTime and start + timeHeight + 2 or 0)));
        return self.control.height;
    end

    function row:destroy()
        if self.nameInline ~= nil then self.nameInline:destroy(); self.nameInline = nil; end
        if self.systemInline ~= nil then self.systemInline:destroy(); self.systemInline = nil; end
        if self.rollInline ~= nil then self.rollInline:destroy(); self.rollInline = nil; end
        if self.control ~= nil then self.control:destroy(); self.control = nil; end
    end
    return row;
end

function M.details(text, title)
    local form=gui.newForm();
    form.width=720; form.height=500; form.theme="dark"; form.title=title or "Detalhes da mensagem";
    local bar=gui.newLayout(); bar.parent=form; bar.align="top"; bar.height=32;
    local close=gui.newButton(); close.parent=bar; close.align="right"; close.width=80; close.text="Fechar";
    local copy=gui.newButton(); copy.parent=bar; copy.align="right"; copy.width=80; copy.text="Copiar";
    local body=gui.newTextEditor(); body.parent=form; body.align="client"; body.readOnly=true;
    body.wordWrap=true; body.fontSize=14; body.fontColor="#E1E1E1";
    local handle={form=form,closed=false};
    function handle:isOpen() return not self.closed and self.form ~= nil; end
    function handle:update(value) if self:isOpen() then body.text=tostring(value or ""); end end
    local function finish()
        if handle.closed then return; end
        handle.closed=true; handle.form=nil;
        pcall(function() form:destroy(); end);
    end
    function handle:close() if self:isOpen() then gui.closePopup(form); finish(); end end
    close.onClick=function() handle:close(); end;
    copy.onClick=function() System.setClipboardText(body.text); end;
    form.onHide=finish;
    handle:update(text);
    if gui.showPopup(form,{placement="center",onClose=finish}) == false then finish(); return nil; end
    return handle;
end

local function nodeBinding(node)
    if node == nil then return nil; end
    local binding = messageBindings[node];
    if binding ~= nil then return binding; end
    local ok, nativeHandle = pcall(ndb.getNodeHandle, node);
    if ok and nativeHandle ~= nil then return bindingsByHandle[nativeHandle]; end
end

function M.resizeMessage(form)
    local record = mountedMessages[form];
    if record == nil or record.resizing or form.handle == nil or form.handle == 0 then return; end
    local binding = nodeBinding(record.node);
    if binding == nil or binding.owner.closed then return; end
    if binding.owner.active == false then
        record.geometryDirty = true;
        return;
    end
    record.resizing = true;
    record.binding = binding;
    record.row.callbacks = binding.owner.callbacks;
    record.row.entry, record.row.state = binding.entry, binding.state;
    record.row.options.room = binding.owner.session.room;
    -- Item forms are resized as child controls of the native RecordList.
    -- Form.width describes the form window and can differ from that control.
    local ok, controlWidth = pcall(gui.Control.getWidth, form);
    local fallback = (tonumber(binding.owner.form.messageHost.width) or 320) - 20;
    local usableWidth = ok and tonumber(controlWidth) or nil;
    local width = math.max(48, usableWidth ~= nil and usableWidth >= 48 and usableWidth or fallback);
    if not record.geometryDirty and record.width == width and record.revision == binding.revision then
        record.resizing = false;
        return;
    end
    record.geometryDirty = false;
    record.width, record.revision = width, binding.revision;
    local height = record.row:update(binding.entry, binding.state, width, nil,
        binding.signature, binding.avatar, binding.layout);
    assign(record.row.control, "left", 0); assign(record.row.control, "top", 0);
    assign(form, "height", height + MESSAGE_GAP);
    record.resizing = false;
    if record.height ~= height then
        record.height = height;
        if type(binding.owner.messageResized) == "function" then
            binding.owner:messageResized(binding.group);
        end
    end
end

function M.unmountMessage(form)
    local record = mountedMessages[form];
    if record == nil then return; end
    mountedMessages[form] = nil;
    if record.observer ~= nil then pcall(function() record.observer:destroy(); end); end
    if record.row ~= nil then pcall(function() record.row:destroy(); end); end
    record.node, record.binding, record.row = nil, nil, nil;
end

function M.mountMessage(form, node)
    if form == nil or node == nil then return; end
    local record = mountedMessages[form];
    if record ~= nil and record.node ~= node then M.unmountMessage(form); record = nil; end
    if record == nil then
        record = {node = node};
        record.row = M.createMessage(form, {}, {getEntry = function()
            local binding = nodeBinding(record.node);
            return binding ~= nil and binding.entry or nil;
        end, onResize = function()
            record.geometryDirty = true;
            local binding = nodeBinding(record.node);
            if binding ~= nil and not binding.owner.closed then
                binding.owner:queueLayout(binding.group, form);
            end
        end, onNavigate = function()
            local binding = nodeBinding(record.node);
            if binding ~= nil and binding.group ~= nil then
                binding.group.follow, binding.group.latestPending = false, false;
                binding.group.scrollToken = (binding.group.scrollToken or 0) + 1;
            end
        end});
        mountedMessages[form] = record;
        local ok, observer = pcall(ndb.newObserver, node);
        if ok and observer ~= nil then
            record.observer = observer;
            observer:addEventListener("onChanged", function() M.resizeMessage(form); end);
        end
    end
    M.resizeMessage(form);
end

uiSignature = function(entry, state, avatar, layout)
    return fingerprint({key = entry.key, name = entry.name, avatar = avatar or entry.avatar,
        timeText = entry.timeText, kind = entry.kind, content = entry.content,
        deleted = entry.deleted, roll = entry.roll, talemarkOptions = entry.talemarkOptions,
        fileName = entry.fileName, fileURL = entry.fileURL, leaveType = entry.leaveType,
        state = visualState(state), layout = layout,
        systemParts = model.systemSegments(entry),
        authorLogin = entry.authorLogin});
end

local function forgetBinding(node)
    messageBindings[node] = nil;
    local ok, nativeHandle = pcall(ndb.getNodeHandle, node);
    if ok and nativeHandle ~= nil then bindingsByHandle[nativeHandle] = nil; end
end

local mountedViews = setmetatable({}, {__mode = "k"});

-- Firecast owns this tablesDock form. Switching room tabs only hides it; the
-- conversation's nodes, rows and scroll position remain in local memory.
function M.mount(form, session, callbacks)
    if form == nil then return nil; end
    local existing = mountedViews[form];
    if existing ~= nil and existing:isOpen() then
        existing.session = session;
        existing.callbacks = callbacks or {};
        return existing;
    end
    local handle = {form = form, session = session, callbacks = callbacks or {},
        groups = {}, closed = false, active = true};
    mountedViews[form] = handle;
    handle.composer = Composer.mount(form.composer, {
        onSend = function(text, mode, options, npcName)
            local result = invoke(handle.callbacks, "onSend", text, mode, options, npcName);
            if result == true then handle.composer:setText(""); end
            return result;
        end,
        onRoll = function(expression, caption, options, mode, npcName, settings, done)
            return invoke(handle.callbacks, "onRoll", expression, caption, options, mode, npcName, settings, done);
        end,
        onInputHistory = function() return invoke(handle.callbacks, "onInputHistory"); end,
        onPins = function() invoke(handle.callbacks, "onPins"); end,
        onSettings = function() invoke(handle.callbacks, "onSettings"); end,
        onAttention = function() invoke(handle.callbacks, "onAttention"); end,
        onOpenAttention = function() invoke(handle.callbacks, "onOpenAttention"); end,
        onHistory = function()
            if handle.activeGroup ~= nil then
                handle.activeGroup.follow, handle.activeGroup.latestPending = false, false;
            end
            invoke(handle.callbacks, "onHistory");
        end,
        onLatest = function()
            if type(handle.callbacks.onLatest) == "function" then invoke(handle.callbacks, "onLatest");
            else handle:latest(); end
        end,
        onError = function(message) handle:status(message); dialogs.alert(message); end,
        onStatus = function(message) handle:status(message); end
    }, {navigation = form.chatTools, background = form.composerCard});

    function handle:isOpen()
        return not self.closed and self.form ~= nil and self.form.handle ~= nil and self.form.handle ~= 0;
    end

    function handle:focus()
        if self:isOpen() then self.composer:focus(); end
    end

    function handle:setActive(active)
        self.active = active ~= false;
        if self.active and self:isOpen() then
            self:status(self.session.statusText or "");
            if self.activeGroup ~= nil then self:queueLayout(self.activeGroup); end
        end
    end

    function handle:status(text)
        if not self:isOpen() then return; end
        if not self.active then return; end
        text = tostring(text or "");
        assign(self.form.statusLabel, "text", text);
        assign(self.form.statusLabel, "hint", text);
        local width = math.max(48, tonumber(self.form.statusLabel.width) or 300);
        local show = trimmed(text) ~= "" and text ~= "Chat conectado ao Firecast." and text ~= "Mensagem enviada."
            and text ~= "Rolagem enviada." and text ~= "Alteração salva.";
        assign(self.form.statusLabel, "visible", show);
        assign(self.form.statusLabel, "height", show and estimateHeight(text, width, nil, 11, 0, 4) or 0);
    end

    function handle:clearInput(sentText, conversationKey)
        if not self:isOpen() then return; end
        local group = conversationKey ~= nil and self.groups[tostring(conversationKey)] or self.activeGroup;
        if group ~= nil and group ~= self.activeGroup then
            if group.draftState ~= nil and group.draftState.text == sentText then group.draftState.text = ""; end
        elseif (conversationKey == nil or (group ~= nil and group == self.activeGroup))
            and self.composer:getText() == sentText then
            self.composer:setText("");
            if group ~= nil and group.draftState ~= nil then group.draftState.text = ""; end
        end
    end

    local function scheduleLatest(group)
        if not handle:isOpen() or not handle.active or group == nil or group.scrollScheduled then return; end
        group.scrollScheduled = true;
        setTimeout(function()
            group.scrollScheduled = false;
            if not handle:isOpen() or not handle.active or handle.activeGroup ~= group
                or not group.follow or not group.latestPending then return; end
            -- A successful SDK call before native rows exist can do nothing.
            -- Keep the request pending until onEndEnumeration retries it.
            if group.awaitingEnumeration then return; end
            if group.lastNode ~= nil then
                local ok = pcall(function() group.list:scrollToNode(group.lastNode); end);
                if ok then group.latestPending = false; end
            end
        end, 16);
    end

    function handle:queueLayout(group, itemForm)
        if not self:isOpen() or group == nil then return; end
        group.dirtyForms = group.dirtyForms or {};
        if itemForm ~= nil then group.dirtyForms[itemForm] = true; end
        if group.layoutScheduled or not self.active or self.activeGroup ~= group then return; end
        group.layoutScheduled = true;
        setTimeout(function()
            group.layoutScheduled = false;
            if not handle:isOpen() or not handle.active or handle.activeGroup ~= group then return; end
            local dirty = group.dirtyForms or {};
            group.dirtyForms = {};
            for item in pairs(dirty) do M.resizeMessage(item); end
            if group.latestPending then scheduleLatest(group); end
        end, 16);
    end

    function handle:latest()
        if not self:isOpen() or self.activeGroup == nil then return; end
        self.activeGroup.follow, self.activeGroup.latestPending = true, true;
        scheduleLatest(self.activeGroup);
    end

    function handle:messageResized(group)
        if group ~= self.activeGroup or not group.follow then return; end
        group.latestPending = true;
        scheduleLatest(group);
    end

    local function createGroup(key)
        local root = ndb.newMemNodeDatabase();
        local children = ndb.createChildNode(root, "messages");
        local scope = gui.newDataScopeBox();
        scope.parent, scope.align = form.messageHost, "client";
        scope:setNodeObject(root);
        local list = gui.newRecordList();
        list.parent, list.align = scope, "client";
        list.field, list.templateForm = "messages", "frmTrackerChatMessage";
        list.layout, list.autoHeight, list.selectable = "vertical", false, false;
        local group = {key = key, root = root, children = children, scope = scope,
            list = list, nodes = {}, serial = 0, follow = true, latestPending = true,
            awaitingEnumeration = false,
            draftState = {text = "", mode = "message", contextKey = key}};
        list.onCompare = function(a, b) return (tonumber(a.order) or 0) - (tonumber(b.order) or 0); end;
        list.onItemAdded = function(node, itemForm) M.mountMessage(itemForm, node); end;
        list.onItemRemoved = function(_, itemForm) M.unmountMessage(itemForm); end;
        list.onBeginEnumeration = function() group.awaitingEnumeration = true; end;
        list.onEndEnumeration = function()
            group.awaitingEnumeration = false;
            if group.latestPending then scheduleLatest(group); end
        end;
        list.onResize = function()
            if not handle:isOpen() or group.resizing then return; end
            local width = list.width;
            if group.layoutWidth ~= width then
                group.layoutWidth = width;
                for _, itemForm in ipairs(list:getChildren()) do handle:queueLayout(group, itemForm); end
            end
            if group.latestPending then scheduleLatest(group); end
        end;
        -- Explicit history/navigation leaves the reader in place. "Última"
        -- resumes following without requesting another server history page.
        local function pauseFollowing()
            group.follow, group.latestPending = false, false;
            group.scrollToken = (group.scrollToken or 0) + 1;
        end
        list.onMouseDown, list.onKeyDown = pauseFollowing, pauseFollowing;
        handle.groups[key] = group;
        return group;
    end

    local function activate(group)
        local old = handle.activeGroup;
        if old == group then return; end
        if old ~= nil then
            old.draftState = handle.composer:draftState();
            old.scope.visible = false;
        end
        handle.activeGroup = group;
        group.scope.visible = true;
        handle:queueLayout(group);
        handle.composer:restore(group.draftState);
        handle.composer:setContextKey(group.key);
    end

    function handle:render(entries, stateGetter, conversationKey, options)
        if not self:isOpen() or not self.active then return; end
        options = options or {};
        local key = tostring(conversationKey or "mesa");
        local group = self.groups[key] or createGroup(key);
        activate(group);
        local previousLastKey = group.lastKey;
        local retained, changed, newestAdded = {}, false, false;
        -- Presence/property transport updates remain in the authoritative cache
        -- for IDs and pagination. They do not create chat bubbles or affect the
        -- last *displayed* message that the dock follows.
        local displayed = {};
        for _, entry in ipairs(entries or {}) do
            if model.isDisplayable(entry) then displayed[#displayed + 1] = entry; end
        end
        entries = displayed;
        local latestEntry = entries[#entries];
        local nextLastKey = latestEntry ~= nil and tostring(latestEntry.key or #entries) or nil;
        group.list:beginUpdate();
        ndb.beginUpdate(group.root);
        for index, entry in ipairs(entries) do
            local entryKey = tostring(entry.key or index);
            local node = group.nodes[entryKey];
            local binding;
            if node == nil then
                group.awaitingEnumeration = true;
                group.serial = group.serial + 1;
                node = ndb.createChildNode(group.children, "message_" .. tostring(group.serial));
                group.nodes[entryKey] = node;
                binding = {node = node, owner = self, group = group, entry = entry, state = {}, revision = 0};
                messageBindings[node] = binding;
                local nativeHandle = ndb.getNodeHandle(node);
                if nativeHandle ~= nil then bindingsByHandle[nativeHandle] = binding; end
                changed = true;
                if entryKey == nextLastKey then newestAdded = true; end
            else
                binding = nodeBinding(node);
            end
            if binding ~= nil then
                local state = type(stateGetter) == "function" and stateGetter(entry) or {};
                local avatar = model.avatarForEntry(entry, self.session.room);
                local layout = messageLayout(entry, entries[index - 1], index);
                local signature = uiSignature(entry, state, avatar, layout);
                binding.entry, binding.state, binding.owner, binding.group = entry, state, self, group;
                binding.avatar = avatar;
                binding.layout = layout;
                if binding.signature ~= signature then
                    binding.signature = signature;
                    binding.revision = binding.revision + 1;
                    node.uiRevision = binding.revision;
                end
                if tonumber(node.order) ~= index then node.order = index; changed = true; end
                retained[entryKey] = true;
            end
        end
        for entryKey, node in pairs(group.nodes) do
            if not retained[entryKey] then
                group.awaitingEnumeration = true;
                forgetBinding(node);
                ndb.deleteNode(node);
                group.nodes[entryKey] = nil;
                changed = true;
            end
        end
        ndb.endUpdate(group.root);
        if changed then group.list:sort(); end
        group.list:endUpdate();
        group.lastKey = nextLastKey;
        group.lastNode = nextLastKey ~= nil and group.nodes[nextLastKey] or nil;
        if options.follow ~= nil then group.follow = options.follow == true; end
        if options.latest == true then
            group.follow, group.latestPending = true, true;
        elseif newestAdded and previousLastKey ~= nil and previousLastKey ~= nextLastKey and group.follow then
            group.latestPending = true;
        end
        if group.latestPending then scheduleLatest(group); end
    end

    function handle:dispose()
        if self.closed then return; end
        self.closed = true;
        mountedViews[self.form] = nil;
        if self.composer ~= nil then self.composer:close(); self.composer = nil; end
        for _, group in pairs(self.groups) do
            group.scrollToken = (group.scrollToken or 0) + 1;
            local ok, children = pcall(function() return group.list:getChildren(); end);
            if ok then
                for _, itemForm in ipairs(children) do M.unmountMessage(itemForm); end
            end
            for _, node in pairs(group.nodes) do forgetBinding(node); end
            pcall(function() group.scope:setNodeObject(nil); group.scope:destroy(); end);
            group.nodes, group.root, group.children, group.dirtyForms = {}, nil, nil, nil;
        end
        self.groups, self.activeGroup, self.form = {}, nil, nil;
        -- The dock belongs to Firecast. Only transient children belong to us.
    end

    form.onResize = function()
        if not handle:isOpen() or not handle.active then return; end
        handle.composer:resize();
        handle:status(form.statusLabel.text);
    end;
    return handle;
end

return M;

-- Small colored inline text assembled with native labels. FlowLayout supplies
-- wrapping and line height; no font or glyph dimensions are guessed here.
local gui = require("gui.lua");
local Firecast = require("firecast.lua");
local System = require("system.lua");
local M = {};
local paletteCache, paletteCount = {}, 0;
local NBSP = " ";

local function textValue(value)
    if type(value) == "string" then return value; end
    if type(value) == "number" then return tostring(value); end
    return "";
end

local function appendKey(parts, value)
    local text = textValue(value);
    parts[#parts + 1] = type(value) .. ":" .. tostring(#text) .. ":" .. text;
end

local function signature(parts)
    local result = {};
    for _, part in ipairs(parts or {}) do
        if type(part) == "table" then
            appendKey(result, part.text); appendKey(result, part.color);
            result[#result + 1] = part.bold == true and "b1" or part.bold == false and "b0" or "bn";
            for _, name in ipairs({"italic","underline","strikeout"}) do
                result[#result + 1] = part[name] == true and name or "";
            end
            result[#result + 1] = part.nickname == true and "n1" or "n0";
            appendKey(result, type(part.nickname) == "string" and part.nickname or "");
        end
    end
    return table.concat(result, "|");
end

local function paletteColor(parent, index, fallback)
    if type(index) ~= "number" or index ~= math.floor(index) or index < 0 or index > 255 then return fallback; end
    local key = tostring(index) .. ":" .. fallback;
    if paletteCache[key] ~= nil then return paletteCache[key]; end
    local probe, began, color;
    local ok = pcall(function()
        if not System.checkAPIVersion(87, 4) then return; end
        probe = gui.newRichEdit();
        probe.parent, probe.visible, probe.showToolbar = parent, false, false;
        probe.defaultFontColor, probe.readOnly = fallback, false;
        probe:beginEdit(); began = true;
        probe:insertTalemark("[§K" .. tostring(index) .. "]x");
        probe:gotoStart(); probe:gotoNext(true);
        color = probe:getSelectionFontColor();
    end);
    if began then pcall(function() probe:endEdit(); end); end
    if probe ~= nil then pcall(function() probe:destroy(); end); end
    if not ok or type(color) ~= "string" or color == "" then color = fallback; end
    if paletteCount >= 128 then paletteCache, paletteCount = {}, 0; end
    paletteCache[key], paletteCount = color, paletteCount + 1;
    return color;
end

local function colorValue(parent, value, fallback)
    if type(value) == "number" then return paletteColor(parent, value, fallback); end
    return type(value) == "string" and value ~= "" and value or fallback;
end

local function expandedParts(parent, parts, options)
    local segments = {};
    local emitted = 0;
    local fallback = options.color or "#D1D1D1";
    local function push(text, state)
        text = textValue(text);
        if text == "" then return; end
        emitted = emitted + 1;
        local previous = segments[#segments];
        if previous ~= nil and previous.color == state.color and previous.bold == state.bold
            and previous.italic == state.italic and previous.underline == state.underline
            and previous.strikeout == state.strikeout then
            previous.text = previous.text .. text;
        else
            segments[#segments + 1] = {text = text, color = state.color, bold = state.bold,
                italic = state.italic, underline = state.underline, strikeout = state.strikeout};
        end
    end
    local function walk(node, inherited)
        if type(node) ~= "table" then return; end
        local state = {};
        for key, value in pairs(inherited) do state[key] = value; end
        if node.type == "fontColor" then
            if node.mode == "palette" or node.mode == "pallete" then
                state.color = paletteColor(parent, node.color, fallback);
            elseif node.mode == "rgb" then state.color = colorValue(parent, node.color, fallback);
            elseif node.mode == "default" then state.color = fallback; end
        elseif node.type == "fontStyle" then
            local style = textValue(node.style):lower();
            if style == "bold" or style == "italic" or style == "underline" or style == "strikeout" then state[style] = true; end
        elseif node.type == "strong" then state.bold = true;
        elseif node.type == "emphasis" then state.italic = true; end
        if node.type == "text" or node.type == "url" then push(node.text, state);
        elseif node.type == "breakline" then push("\n", state);
        elseif node.type == "smiley" then push(node.altText or node.shortcut, state); end
        for _, child in ipairs(node.children or {}) do walk(child, state); end
    end
    for _, part in ipairs(parts or {}) do
        if type(part) == "table" then
            local state = {color = colorValue(parent, part.color, fallback),
                bold = part.bold == nil and options.bold == true or part.bold == true,
                italic = part.italic==true,underline = part.underline==true,strikeout = part.strikeout==true};
            local nickname = type(part.nickname) == "string" and part.nickname or part.nickname == true and textValue(part.text) or nil;
            if nickname ~= nil and type(Firecast.parseTalemark) == "function" then
                nickname = nickname:gsub("%[Â§", "[§");
                local ok, tree = pcall(Firecast.parseTalemark, nickname);
                local before = emitted;
                if ok and type(tree) == "table" then walk(tree, state); end
                if emitted == before then push(nickname:gsub("%[§[^%]]*%]", ""), state); end
            else push(part.text, state); end
        end
    end
    return segments;
end

function M.new(parent, options)
    options = options or {};
    local flow = gui.newFlowLayout();
    flow.parent, flow.align, flow.height = parent, "none", 0;
    flow.autoHeight, flow.orientation, flow.horzAlign = true, "horizontal", "leading";
    flow.lineSpacing, flow.maxControlsPerLine = 0, 0;
    flow.hitTest = true;
    flow.onMenu, flow.onMouseDown = options.onMenu, options.onNavigate;
    local handle = {control = flow, cells = {}, width = 24, closed = false, updating = false};
    local measuring, needsRealign, lastHeight;

    local function nativeHeight()
        if handle.closed then return 0; end
        local height = tonumber(flow.contentHeight) or 0;
        if height > 0 then return height; end
        -- Auto-layout can finish after setParts returns. The initial value uses
        -- the native label's height until onAfterLayoutCalc reports the lines.
        for _, cell in ipairs(handle.cells) do
            if cell.label ~= nil then height = math.max(height, tonumber(cell.label.height) or 0); end
        end
        return height;
    end
    local function queueGeometry(realign)
        if handle.closed then return; end
        if realign then needsRealign = true; end
        if handle.updating or measuring then return; end
        measuring = true;
        if needsRealign then needsRealign = false; flow:needRealign(); end
        local height = nativeHeight();
        if lastHeight ~= height then
            lastHeight = height;
            if type(options.onResize) == "function" then options.onResize(handle); end
        end
        measuring = false;
    end
    local function assign(control, key, value)
        if control[key] == value then return false; end
        control[key] = value;
        return true;
    end
    local function fit(cell)
        if cell.label == nil then return false; end
        local label = cell.label;
        local measured = tonumber(label.width) or 0;
        if not cell.wrapped and measured > 0 then cell.naturalWidth = measured; end
        local natural = cell.naturalWidth or measured;
        local wrap = natural > handle.width;
        local changed = false;
        if wrap ~= cell.wrapped then
            cell.wrapped = wrap;
            changed = assign(label, "wordWrap", wrap) or changed;
        end
        if wrap then changed = assign(label, "width", handle.width) or changed;
        elseif natural > 0 then changed = assign(label, "width", natural) or changed; end
        return changed;
    end
    local function addLabel(text, segment)
        local label = gui.newLabel();
        local cell = {label = label, wrapped = false};
        handle.cells[#handle.cells + 1] = cell;
        label.autoSize, label.wordWrap = true, false;
        label.fontSize, label.fontColor = options.fontSize or 14, segment.color;
        if type(options.fontFamily) == "string" then label.fontFamily = options.fontFamily; end
        local styles = {};
        for _, name in ipairs({"bold", "italic", "underline", "strikeout"}) do
            if segment[name] then styles[#styles + 1] = name; end
        end
        label.fontStyle = styles;
        label.horzTextAlign, label.vertTextAlign, label.textTrimming = "leading", "leading", "none";
        label.hitTest = true;
        label.onMenu, label.onMouseDown = options.onMenu, options.onNavigate;
        -- NBSP has the same visible spacing and preserves the native measured
        -- advance of trailing spaces in independently colored label segments.
        label.text = text:gsub(" ", NBSP):gsub("\t", NBSP .. NBSP .. NBSP .. NBSP);
        label.parent = flow;
        cell.width, cell.height = label.width, label.height;
        label.onResize = function()
            if handle.closed then return; end
            local changed = fit(cell);
            local width, height = label.width, label.height;
            if changed or width ~= cell.width or height ~= cell.height then
                cell.width, cell.height = width, height;
                queueGeometry(true);
            end
        end;
        fit(cell);
    end
    local function addBreak()
        local control = gui.newFlowLineBreak();
        control.lineSpacing, control.height = 0, 0;
        control.parent = flow;
        handle.cells[#handle.cells + 1] = {control = control};
    end
    local function addSegment(segment)
        local text = segment.text:gsub("\r\n", "\n"):gsub("\r", "\n");
        local cursor = 1;
        while cursor <= #text do
            local newline = text:find("\n", cursor, true);
            local line = newline ~= nil and text:sub(cursor, newline - 1) or text:sub(cursor);
            local lead = line:match("^%s+");
            if lead ~= nil then addLabel(lead, segment); line = line:sub(#lead + 1); end
            for token in line:gmatch("%S+%s*") do addLabel(token, segment); end
            if newline == nil then break; end
            if line == "" and lead == nil then addLabel(NBSP, segment); end
            addBreak(); cursor = newline + 1;
        end
    end

    function handle:setParts(parts, width)
        if self.closed then return; end
        parts = type(parts) == "table" and parts or {};
        width = math.max(24, tonumber(width) or 24);
        local current = signature(parts);
        local rebuilt = self.signature ~= current;
        local changed = self.width ~= width;
        if not rebuilt and not changed then return; end
        self.updating = true;
        flow:beginUpdate();
        self.width = width;
        if assign(flow, "width", width) then changed = true; end
        if rebuilt then
            self.signature = current;
            for _, cell in ipairs(self.cells) do (cell.label or cell.control):destroy(); end
            self.cells = {};
            for _, segment in ipairs(expandedParts(parent, parts, options)) do addSegment(segment); end
            changed = true;
        else
            for _, cell in ipairs(self.cells) do if fit(cell) then changed = true; end end
        end
        flow:endUpdate();
        self.updating = false;
        queueGeometry(changed);
    end
    function handle:getHeight() return nativeHeight(); end
    function handle:destroy()
        if self.closed then return; end
        self.closed = true;
        flow:destroy(); self.cells = {}; self.control = nil;
    end
    flow.onResize = function() queueGeometry(false); end;
    flow.onAfterLayoutCalc = function() queueGeometry(false); end;
    return handle;
end

return M;

local ndb = require("ndb.lua");
local rrpg = require("rrpg.lua");
local vhd = require("vhd.lua");

local M = {};
local STORE_NAME = "newTracker.windowPositions.v1";
local SAMPLE_INTERVAL_MS = 100;
local stores = setmetatable({}, {__mode = "k"});
local kinds = {"attention", "turn"};
local fields = {
    "attentionLeft", "attentionTop", "attentionUpdatedAt",
    "turnLeft", "turnTop", "turnUpdatedAt",
    "turnCompact", "turnCompactUpdatedAt"
};
local allowedFields = {revision = true};
for _, field in ipairs(fields) do allowedFields[field] = true; end

local function finite(value)
    local number = tonumber(value);
    if number ~= nil and number == number and math.abs(number) < 10000000000000000 then
        return number;
    end
    return nil;
end

local function nextRevision(previous)
    return math.max((tonumber(previous) or 0) + 1, os.time() * 1000);
end

local function point(node, kind)
    local left = finite(node[kind .. "Left"]);
    local top = finite(node[kind .. "Top"]);
    if left ~= nil and top ~= nil then return {left = left, top = top}; end
    return nil;
end

local function readSnapshot(fileName)
    local stream = vhd.openFile(fileName, "r");
    if stream == nil then return nil; end
    local ok, text = pcall(function() return stream:readBinary("utf8"); end);
    stream:close();
    if not ok or type(text) ~= "string" or text:sub(1, 24) ~= "newTracker.positions.v2\n"
        or text:sub(-4) ~= "end\n" then
        return nil;
    end
    local values = {};
    for key, value in text:gmatch("([%w]+)=([^\r\n]+)") do
        if allowedFields[key] then
            if key == "turnCompact" then
                if value == "true" then values[key] = true;
                elseif value == "false" then values[key] = false; end
            else
                values[key] = finite(value);
            end
        end
    end
    if values.revision == nil then return nil; end
    return values;
end

local function cacheForRoom(mesa)
    local player = mesa ~= nil and mesa.meuJogador or nil;
    local user = tostring(player ~= nil and (player.login or player.codigoInterno) or "local")
        :gsub("[^%w_-]", "_");
    local room = tostring(mesa ~= nil and mesa.codigoInterno or "local")
        :gsub("[^%w_-]", "_");
    local base = "/window-positions-" .. user .. "-" .. room;
    local cache, slot = {}, nil;
    local legacyFile = base .. ".xml";
    if vhd.fileExists(legacyFile) then
        local legacy = ndb.load(legacyFile);
        for _, field in ipairs(fields) do cache[field] = legacy[field]; end
    end
    for index = 1, 2 do
        local candidate = readSnapshot(base .. "." .. index .. ".positions");
        if candidate ~= nil and (tonumber(candidate.revision) or 0) > (tonumber(cache.revision) or 0) then
            cache, slot = candidate, index;
        end
    end
    return cache, base, slot;
end

local function persist(record)
    -- Fecha o arquivo imediatamente. Dois snapshots completos preservam a
    -- ultima gravacao mesmo se a substituicao do plugin interromper a proxima.
    record.cache.revision = nextRevision(record.cache.revision);
    local lines = {"newTracker.positions.v2", "revision=" .. tostring(record.cache.revision)};
    for _, field in ipairs(fields) do
        if record.cache[field] ~= nil then
            lines[#lines + 1] = field .. "=" .. tostring(record.cache[field]);
        end
    end
    lines[#lines + 1] = "end";
    local text = table.concat(lines, "\n") .. "\n";
    local slot = record.slot == 1 and 2 or 1;
    local stream = vhd.openFile(record.base .. "." .. slot .. ".positions", "w+");
    if stream ~= nil then
        local ok, written = pcall(function() return stream:writeBinary("utf8", text); end);
        stream:close();
        if ok and written == #text then record.slot = slot; end
    end
    if record.remote ~= nil then
        ndb.beginUpdate(record.remote);
        for _, field in ipairs(fields) do
            if record.cache[field] ~= nil and record.remote[field] ~= record.cache[field] then
                record.remote[field] = record.cache[field];
            end
        end
        ndb.endUpdate(record.remote);
    end
end

function M.ensure(root, onReady)
    local record = stores[root];
    if record ~= nil then
        if onReady ~= nil then record.onReady = onReady; end
        return record;
    end
    local mesa = rrpg.getMesaDe(root);
    local cache, base, slot = cacheForRoom(mesa);
    record = {ready = false, cache = cache, base = base, slot = slot, onReady = onReady};
    stores[root] = record;

    local function loaded(node)
        if record.ready then return; end
        record.remote = node;
        if node ~= nil then
            for _, kind in ipairs(kinds) do
                local localPoint, remotePoint = point(cache, kind), point(node, kind);
                local stampField = kind .. "UpdatedAt";
                local localStamp = tonumber(cache[stampField]) or 0;
                local remoteStamp = tonumber(node[stampField]) or 0;
                if remotePoint ~= nil and (localPoint == nil or remoteStamp > localStamp) then
                    cache[kind .. "Left"], cache[kind .. "Top"] = remotePoint.left, remotePoint.top;
                    cache[stampField] = remoteStamp;
                elseif localPoint ~= nil and remotePoint ~= nil and localStamp == 0 and remoteStamp == 0
                    and (localPoint.left ~= remotePoint.left or localPoint.top ~= remotePoint.top) then
                    -- Os arquivos da versao anterior nao tinham revisao.
                    -- Nesse caso preserva a ultima posicao local, nao o canto
                    -- que uma carga antiga do servidor poderia trazer.
                    cache[stampField] = nextRevision(0);
                end
            end
            if node.turnCompact ~= nil and (cache.turnCompact == nil
                or (tonumber(node.turnCompactUpdatedAt) or 0) > (tonumber(cache.turnCompactUpdatedAt) or 0)) then
                cache.turnCompact = node.turnCompact;
                cache.turnCompactUpdatedAt = tonumber(node.turnCompactUpdatedAt) or 0;
            end
        end
        persist(record);
        record.ready = true;
        setTimeout(function()
            if record.onReady ~= nil then record.onReady(); end
        end, 1);
    end

    if mesa ~= nil and mesa.asyncOpenUserRoomNDB ~= nil then
        local ok, promise = pcall(function()
            return mesa:asyncOpenUserRoomNDB(STORE_NAME, {create = true});
        end);
        if ok and promise ~= nil then
            promise:thenDo(loaded, function() loaded(nil); end);
        else
            loaded(nil);
        end
    else
        loaded(nil);
    end
    return record;
end

function M.get(root, field)
    return M.ensure(root).cache[field];
end

function M.set(root, field, value)
    local record = M.ensure(root);
    if record.cache[field] == value then return; end
    record.cache[field] = value;
    if field == "turnCompact" then
        record.cache.turnCompactUpdatedAt = nextRevision(record.cache.turnCompactUpdatedAt);
    end
    persist(record);
end

local function currentPoint(popup)
    if popup.handle == nil or popup.handle == 0 or popup.isShowing ~= true then return nil; end
    local left, top = finite(popup.left), finite(popup.top);
    if left == nil or top == nil then return nil; end
    return {left = math.floor(left + 0.5), top = math.floor(top + 0.5)};
end

local function samePoint(a, b)
    return a ~= nil and b ~= nil and math.abs(a.left - b.left) <= 1 and math.abs(a.top - b.top) <= 1;
end

function M.capture(popup)
    if popup == nil or popup._positionReady ~= true then return; end
    local current = currentPoint(popup);
    if current == nil then return; end
    local record = M.ensure(popup._positionRoot);
    local kind = popup._positionKind;
    popup._positionTarget = current;
    local saved = point(record.cache, kind);
    if saved ~= nil and saved.left == current.left and saved.top == current.top then return; end
    record.cache[kind .. "Left"], record.cache[kind .. "Top"] = current.left, current.top;
    record.cache[kind .. "UpdatedAt"] = nextRevision(record.cache[kind .. "UpdatedAt"]);
    persist(record);
end

function M.stop(popup, captureBeforeClose)
    if popup == nil then return; end
    -- onHide ocorre durante a desmontagem do host. Nunca grava coordenadas
    -- desse evento; a captura final so acontece ANTES de chamar close().
    if captureBeforeClose == true then M.capture(popup); end
    if popup._positionIntervalId ~= nil then
        clearInterval(popup._positionIntervalId);
        popup._positionIntervalId = nil;
    end
    popup._positionGeneration = (popup._positionGeneration or 0) + 1;
    popup._positionReady = false;
    popup._positionRestorePending = false;
    popup._positionRoot = nil;
    popup._positionKind = nil;
    popup._positionTarget = nil;
    popup._positionLastSample = nil;
    popup._positionStableSamples = 0;
    popup._positionLayoutPending = false;
    popup._positionLayoutRoot = nil;
end

function M.beginLayout(popup)
    if popup._positionRoot == nil or currentPoint(popup) == nil then return nil; end
    M.capture(popup);
    local target = popup._positionTarget;
    if target == nil then return nil; end
    local token = {left = target.left, top = target.top,
        root = popup._positionRoot, kind = popup._positionKind};
    popup._positionReady = false;
    popup._positionRestorePending = true;
    popup._positionStableSamples = 0;
    popup._positionRestoreAttempts = 0;
    return token;
end

function M.endLayout(popup, token)
    if token == nil or popup._positionRoot ~= token.root or popup._positionKind ~= token.kind
        or currentPoint(popup) == nil then return; end
    popup._positionTarget = {left = token.left, top = token.top};
    popup.left, popup.top = token.left, token.top;
end

function M.bind(popup, root, kind)
    if popup._positionLayoutPending == true then
        popup._positionLayoutRoot = root;
        return;
    end
    if popup._positionRoot == root and popup._positionKind == kind
        and (popup._positionReady or popup._positionRestorePending) then return; end
    M.stop(popup, true);
    local record = M.ensure(root);
    if not record.ready then return; end
    popup._positionRoot = root;
    popup._positionKind = kind;
    popup._positionTarget = point(record.cache, kind);
    popup._positionRestorePending = true;
    popup._positionStableSamples = 0;
    popup._positionRestoreAttempts = 0;
    local generation = popup._positionGeneration;

    local target = popup._positionTarget;
    if target ~= nil then popup.left, popup.top = target.left, target.top; end

    popup._positionIntervalId = setInterval(function()
        if popup._positionGeneration ~= generation then return; end
        local current = currentPoint(popup);
        if current == nil then return; end
        if popup._positionReady then
            M.capture(popup);
            return;
        end
        local expected = popup._positionTarget;
        if expected ~= nil and not samePoint(current, expected) then
            popup._positionRestoreAttempts = (popup._positionRestoreAttempts or 0) + 1;
            -- O host pode ajustar/limitar a posicao; apos poucas tentativas
            -- aceita a posicao atual para nao brigar com o arraste do usuario.
            if popup._positionRestoreAttempts <= 5 then
                popup._positionStableSamples = 0;
                popup.left, popup.top = expected.left, expected.top;
                return;
            end
            popup._positionTarget = current;
            expected = current;
        end
        if expected ~= nil or samePoint(current, popup._positionLastSample) then
            popup._positionStableSamples = popup._positionStableSamples + 1;
        else
            popup._positionStableSamples = 0;
        end
        popup._positionLastSample = current;
        if popup._positionStableSamples >= 2 then
            -- Primeiro confirma a restauracao. A posicao inicial da janela
            -- nunca e gravada por cima de uma posicao salva ainda em restauracao.
            popup._positionRestorePending = false;
            popup._positionReady = true;
        end
    end, SAMPLE_INTERVAL_MS);
end

return M;

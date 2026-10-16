local ndb = require("ndb.lua");
local rrpg = require("rrpg.lua");
local utils = require("utils.lua");

local M = {};
local REQUEST_MESSAGE = "newTracker.nextTurn.v2";
local REPLY_MESSAGE = "newTracker.nextTurn.reply.v2";
local RETRY_MS = 1000;
local MAX_ATTEMPTS = 3;
local RESULT_TIMEOUT_SECONDS = 15;
local MAX_RESULTS = 128;
local requestCounter = 0;
local states = setmetatable({}, {__mode = "k"});
local reasons = {
    denied = "Você só pode passar o seu próprio turno ou o de uma ficha compartilhada com você.",
    stale = "O turno mudou antes de concluir o pedido. Confira o turno atual.",
    failed = "Não foi possível concluir a passagem do turno. Tente novamente.",
    noMaster = "O mestre não confirmou o pedido. Ele precisa estar com o tracker aberto.",
    timeout = "O mestre recebeu o pedido, mas a passagem do turno não foi concluída. Tente novamente.",
    closed = "O pedido foi cancelado porque o tracker foi fechado.",
    connection = "Não foi possível enviar o pedido de passagem do turno. Confira a conexão.",
    loading = "O estado do turno ainda está sincronizando. Aguarde um instante e tente novamente."
};

local function trimmed(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "");
end

local function property(object, name)
    if object == nil then return nil; end
    local ok, value = pcall(function() return object[name]; end);
    return ok and value or nil;
end

local function sameLogin(first, second)
    local login = trimmed(first):lower();
    return login ~= "" and login == trimmed(second):lower();
end

local function enabled(value)
    local text = trimmed(value):lower();
    return value == true or text == "true" or text == "1" or text == "yes" or text == "sim";
end

local function getRoom(root)
    local ok, room = pcall(function() return rrpg.getMesaDe(root); end);
    return ok and room or nil;
end

local function localPlayer(room)
    local player = property(room, "meuJogador");
    if player ~= nil then return player; end
    if room == nil or property(room, "getMeuJogador") == nil then return nil; end
    local ok, result = pcall(function() return room:getMeuJogador(); end);
    return ok and result or nil;
end

local function isMaster(root)
    local room = getRoom(root);
    local player = localPlayer(room);
    if player ~= nil then return enabled(property(player, "isMestre")); end
    return enabled(property(room, "isMestre"));
end

local function nodeIsOpen(root)
    local ok, state = pcall(ndb.getState, root);
    return ok and state == "open";
end

-- A published nil is meaningful: it must not become a player-local combat ID.
local function published(node, field)
    if ndb.getPersistedAttributeValue ~= nil then
        local ok, value = pcall(ndb.getPersistedAttributeValue, node, field);
        if ok then return value; end
    end
    return property(node, field);
end

local function turnId(root)
    return tostring(published(root, "turnTimerId") or "");
end

local function currentItem(root)
    local container = property(root, "itens");
    if container == nil then return nil; end
    local timerItemId = tostring(published(root, "turnTimerItemId") or "");
    local selected = nil;
    for _, item in ipairs(ndb.getChildNodes(container)) do
        if property(item, "turnoAtual") == true and published(item, "turnoAtual") == true then
            local itemId = tostring(published(item, "itemId") or "");
            if itemId ~= "" and (timerItemId == "" or timerItemId == itemId) then
                if selected ~= nil then return nil; end
                selected = item;
            end
        end
    end
    return selected;
end

local function nativePlayer(room, sender)
    if room == nil or trimmed(sender) == "" then return nil; end
    local ok, player = pcall(function() return room:findJogador(sender); end);
    if not ok or player == nil or not sameLogin(property(player, "login"), sender) then return nil; end
    for _, candidate in ipairs(property(room, "jogadores") or {}) do
        if sameLogin(property(candidate, "login"), sender) then return player; end
    end
    return nil;
end

local function validId(value)
    return type(value) == "string" and value ~= "" and #value <= 256
        and value:find("[%c]") == nil;
end

local function broadcast(root, messageId, payload)
    if not nodeIsOpen(root) then return false; end
    local ok, result = pcall(ndb.broadcastMessage, root, messageId, payload, false);
    return ok and result ~= false;
end

local function withUpdate(root, callback)
    local began = pcall(ndb.beginUpdate, root);
    if not began then return false; end
    local ok, result = pcall(callback);
    local ended = pcall(ndb.endUpdate, root);
    return ok and ended and result ~= false;
end

local function newRequestId()
    if utils.generateUniqueString ~= nil then
        local ok, result = pcall(utils.generateUniqueString);
        if ok and validId(result) then return result; end
    end
    requestCounter = requestCounter + 1;
    return string.format("%d-%d", os.time(), requestCounter);
end

local function stateOf(root)
    local state = states[root];
    if state == nil then
        state = {entries = {}, order = {}, queue = {}};
        states[root] = state;
    end
    return state;
end

local function clearPendingTimer(state)
    if state.pendingTimer ~= nil then
        clearInterval(state.pendingTimer);
        state.pendingTimer = nil;
    end
end

local function finishPending(state, success, reason)
    local pending = state.pending;
    if pending == nil then return; end
    state.pending = nil;
    clearPendingTimer(state);
    -- Cleanup is complete before entering the caller's UI callback.
    if type(pending.onResult) == "function" then pending.onResult(success == true, reason); end
end

local function sendReply(root, entry)
    return broadcast(root, REPLY_MESSAGE, {
        targetLogin = entry.sender,
        requestId = entry.requestId,
        turnId = entry.turnId,
        itemId = entry.itemId,
        status = entry.status,
        reason = entry.reason
    });
end

local function cacheResult(state, entry)
    state.order[#state.order + 1] = entry.key;
    while #state.order > MAX_RESULTS do
        local key = table.remove(state.order, 1);
        local previous = state.entries[key];
        if previous ~= nil and previous.status ~= "pending" then state.entries[key] = nil; end
    end
end

local function complete(root, state, entry, status, reason)
    if states[root] ~= state or state.stopped or entry.status ~= "pending" then return; end
    entry.status = status;
    entry.reason = reason;
    cacheResult(state, entry);
    if isMaster(root) then sendReply(root, entry); end
end

local function matchesTurn(root, entry, item)
    return nodeIsOpen(root) and turnId(root) == entry.turnId
        and tostring(property(root, "turnTimerId") or "") == entry.turnId
        and currentItem(root) == item and property(item, "turnoAtual") == true
        and tostring(published(item, "itemId") or "") == entry.itemId
        and tostring(property(item, "itemId") or "") == entry.itemId;
end

local function processEntry(root, state, entry)
    if entry.status ~= "pending" or entry.checking or not isMaster(root) then return; end
    if os.time() - entry.startedAt >= RESULT_TIMEOUT_SECONDS then
        complete(root, state, entry, "failed", reasons.timeout);
        return;
    end
    if type(state.authorize) ~= "function" or type(state.advance) ~= "function" then return; end
    local item = currentItem(root);
    local player = nativePlayer(getRoom(root), entry.sender);
    if item == nil or not matchesTurn(root, entry, item) then
        complete(root, state, entry, "stale", reasons.stale);
        return;
    end
    if player == nil then
        complete(root, state, entry, "denied", reasons.denied);
        return;
    end
    entry.checking = true;
    local answered = false;
    local checked = pcall(state.authorize, root, item, player, function(allowed)
        if answered or states[root] ~= state or state.stopped or entry.status ~= "pending" then return; end
        answered = true;
        if not isMaster(root) then return; end
        if os.time() - entry.startedAt >= RESULT_TIMEOUT_SECONDS then
            complete(root, state, entry, "failed", reasons.timeout);
            return;
        end
        if allowed ~= true then
            complete(root, state, entry, "denied", reasons.denied);
            return;
        end
        if nativePlayer(getRoom(root), entry.sender) == nil or not matchesTurn(root, entry, item) then
            complete(root, state, entry, "stale", reasons.stale);
            return;
        end
        if state.advancing or not ndb.testPermission(root, "write")
            or not ndb.testPermission(item, "write") then
            complete(root, state, entry, "failed", reasons.failed);
            return;
        end
        local oldTurnId = tostring(property(root, "turnTimerId") or "");
        state.advancing = true;
        local advanced = withUpdate(root, function() return state.advance(root); end);
        state.advancing = false;
        if advanced and tostring(property(root, "turnTimerId") or "") ~= oldTurnId then
            complete(root, state, entry, "success", nil);
        else
            complete(root, state, entry, "failed", reasons.failed);
        end
    end);
    if not checked and entry.status == "pending" then
        complete(root, state, entry, "failed", reasons.failed);
    end
end

local function receiveRequest(root, state, sender, payload)
    if states[root] ~= state or state.stopped or not isMaster(root)
        or type(payload) ~= "table" or not validId(payload.requestId)
        or not validId(payload.turnId) or not validId(payload.itemId) then return; end
    -- Only the SDK-supplied sender authenticates a request.
    local player = nativePlayer(getRoom(root), sender);
    if player == nil then return; end
    local key = trimmed(sender):lower() .. "\n" .. payload.requestId;
    local entry = state.entries[key];
    if entry ~= nil then
        if entry.turnId == payload.turnId and entry.itemId == payload.itemId then sendReply(root, entry); end
        return;
    end
    entry = {
        key = key, sender = property(player, "login"), requestId = payload.requestId,
        turnId = payload.turnId, itemId = payload.itemId, status = "pending", startedAt = os.time()
    };
    state.entries[key] = entry;
    sendReply(root, entry);
    if type(state.authorize) == "function" and type(state.advance) == "function" then
        processEntry(root, state, entry);
    else
        state.queue[#state.queue + 1] = entry;
    end
end

local function receiveReply(root, state, sender, payload)
    local pending = state.pending;
    if states[root] ~= state or state.stopped or pending == nil or type(payload) ~= "table" then return; end
    local room = getRoom(root);
    local player = nativePlayer(room, sender);
    local me = localPlayer(room);
    if player == nil or not enabled(property(player, "isMestre"))
        or not sameLogin(payload.targetLogin, property(me, "login"))
        or payload.requestId ~= pending.payload.requestId or payload.turnId ~= pending.payload.turnId
        or payload.itemId ~= pending.payload.itemId then return; end
    if payload.status == "pending" then
        if not pending.acknowledged then
            pending.acknowledged = true;
            pending.deadline = os.time() + RESULT_TIMEOUT_SECONDS;
        end
    elseif payload.status == "success" then
        finishPending(state, true, nil);
    elseif payload.status == "denied" or payload.status == "stale" or payload.status == "failed" then
        local reason = payload.status == "failed" and payload.reason == reasons.timeout
            and reasons.timeout or reasons[payload.status];
        finishPending(state, false, reason);
    end
end

local function tickPending(root, state)
    local pending = state.pending;
    if states[root] ~= state or state.stopped or pending == nil then return; end
    if not nodeIsOpen(root) then finishPending(state, false, reasons.connection); return; end
    local publishedTurn = turnId(root);
    if pending.acknowledged and publishedTurn ~= "" and publishedTurn ~= pending.payload.turnId then
        finishPending(state, true, nil);
        return;
    end
    if pending.acknowledged then
        if os.time() >= pending.deadline then finishPending(state, false, reasons.timeout); end
    elseif pending.attempts >= MAX_ATTEMPTS then
        finishPending(state, false, reasons.noMaster);
    else
        pending.attempts = pending.attempts + 1;
        if not broadcast(root, REQUEST_MESSAGE, pending.payload) then
            finishPending(state, false, reasons.connection);
        end
    end
end

-- No ACL or combat data writes: both players and masters need the listeners.
function M.configure(root)
    if root == nil or not nodeIsOpen(root) then return false, reasons.connection; end
    local state = stateOf(root);
    if state.requestListener ~= nil and state.replyListener ~= nil then return true; end
    local ok, requestListener = pcall(ndb.newBroadcastListener, root, REQUEST_MESSAGE,
        function(sender, _, payload) receiveRequest(root, state, sender, payload); end);
    if not ok or requestListener == nil then return false, reasons.connection; end
    local replyOk, replyListener = pcall(ndb.newBroadcastListener, root, REPLY_MESSAGE,
        function(sender, _, payload) receiveReply(root, state, sender, payload); end);
    if not replyOk or replyListener == nil then
        pcall(function() requestListener:destroy(); end);
        return false, reasons.connection;
    end
    state.requestListener = requestListener;
    state.replyListener = replyListener;
    return true;
end

function M.request(root, itemNode, onResult)
    if root == nil or itemNode == nil or isMaster(root) then return false, reasons.denied; end
    local configured, reason = M.configure(root);
    if not configured then return false, reason; end
    local canonicalTurn = turnId(root);
    local canonicalItem = tostring(published(itemNode, "itemId") or "");
    if canonicalTurn == "" or canonicalItem == "" or currentItem(root) ~= itemNode
        or tostring(property(root, "turnTimerId") or "") ~= canonicalTurn then
        return false, reasons.loading;
    end
    local state = stateOf(root);
    if state.pending ~= nil then
        if state.pending.payload.turnId == canonicalTurn and state.pending.payload.itemId == canonicalItem then
            if type(onResult) == "function" then state.pending.onResult = onResult; end
            return true;
        end
        return false, "Aguarde a confirmação do pedido anterior antes de passar outro turno.";
    end
    local pending = {
        payload = {requestId = newRequestId(), turnId = canonicalTurn, itemId = canonicalItem},
        onResult = onResult, attempts = 1, acknowledged = false
    };
    state.pending = pending;
    if not broadcast(root, REQUEST_MESSAGE, pending.payload) then
        if state.pending == pending then state.pending = nil; end
        return false, reasons.connection;
    end
    -- A synchronously delivered reply may have completed the request already.
    if state.pending == pending then
        state.pendingTimer = setInterval(function() tickPending(root, state); end, RETRY_MS);
    end
    return true;
end

function M.process(root, canPlayerAdvance, advance)
    local configured, reason = M.configure(root);
    if not configured then return false, reason; end
    local state = stateOf(root);
    state.authorize = canPlayerAdvance;
    state.advance = advance;
    if not isMaster(root) then return true; end
    if state.processing or state.advancing then return true; end
    state.processing = true;
    local ok = pcall(function()
        local queued = state.queue;
        state.queue = {};
        for _, entry in ipairs(queued) do processEntry(root, state, entry); end
        for _, entry in pairs(state.entries) do
            if entry.status == "pending" then
                if os.time() - entry.startedAt >= RESULT_TIMEOUT_SECONDS then
                    complete(root, state, entry, "failed", reasons.timeout);
                elseif not entry.checking then
                    processEntry(root, state, entry);
                end
            end
        end
    end);
    state.processing = false;
    return ok, not ok and reasons.failed or nil;
end

function M.stop(root)
    local state = root ~= nil and states[root] or nil;
    if state == nil then return; end
    state.stopped = true;
    states[root] = nil;
    clearPendingTimer(state);
    for _, listener in ipairs({state.requestListener, state.replyListener}) do
        if listener ~= nil then pcall(function() listener:destroy(); end); end
    end
    state.requestListener = nil;
    state.replyListener = nil;
    state.entries = {};
    state.queue = {};
    finishPending(state, false, reasons.closed);
end

return M;

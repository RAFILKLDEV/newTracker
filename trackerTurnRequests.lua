local ndb = require("ndb.lua");
local rrpg = require("rrpg.lua");

local M = {};
local requestCounter = 0;
local states = setmetatable({}, {__mode = "k"});
local dataPermissions = {write = true, createChild = true, delete = true};

local function trimmed(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "");
end

local function enabled(value)
    local text = trimmed(value):lower();
    return value == true or text == "true" or text == "1" or text == "sim";
end

local function getRoom(root)
    return root ~= nil and rrpg.getMesaDe(root) or nil;
end

local function getLocalPlayer(room)
    if room == nil then
        return nil;
    end

    if room.meuJogador ~= nil then
        return room.meuJogador;
    end

    if room.getMeuJogador ~= nil then
        return room:getMeuJogador();
    end

    return nil;
end

local function isMaster(root)
    local room = getRoom(root);
    local player = getLocalPlayer(room);

    if player ~= nil then
        return enabled(player.isMestre);
    end

    return room ~= nil and enabled(room.isMestre);
end

local function stateOf(root)
    local state = states[root];

    if state == nil then
        state = {processed = {}, completed = {}};
        states[root] = state;
    end

    return state;
end

-- The slot name establishes the sender. No identity from the payload is trusted.
local function slotName(login)
    local normalized = trimmed(login):lower();

    if normalized == "" then
        return nil;
    end

    return "user_" .. normalized:gsub(".", function(byte)
        return string.format("%02x", string.byte(byte));
    end);
end

local function withUpdate(node, callback)
    local began, beginError = pcall(ndb.beginUpdate, node);

    if not began then
        return false, beginError;
    end

    local ok, result = pcall(callback);
    local ended, endError = pcall(ndb.endUpdate, node);

    if not ok then
        return false, result;
    end

    if not ended then
        return false, endError;
    end

    return true, result;
end

local function setPermission(node, kind, selector, permission, allowance)
    if ndb.getPermission(node, kind, selector, permission) ~= allowance then
        ndb.setPermission(node, kind, selector, permission, allowance);
    end
end

local function configureNode(node, ownerLogin)
    if not ndb.testPermission(node, "writePermissions") then
        return false;
    end

    -- Remove old data grants which could make another user's slot writable.
    -- Read and all meta-permissions are preserved and remain inherited in slots.
    for _, entry in ipairs(ndb.enumPermissions(node)) do
        if dataPermissions[entry.permission] then
            local knownGroup = entry.selKind == "group"
                and (entry.selId == "todos" or entry.selId == "jogadores" or entry.selId == "mestres");
            local ownerWrite = ownerLogin ~= nil and entry.permission == "write"
                and entry.selKind == "user" and trimmed(entry.selId):lower() == ownerLogin:lower();
            local canonical = ownerLogin == nil and knownGroup
                or ownerLogin ~= nil and entry.permission == "write" and (knownGroup or ownerWrite);

            if not canonical then
                ndb.setPermission(node, entry.selKind, entry.selId, entry.permission, nil);
            end
        end
    end

    local permissions = ownerLogin ~= nil and {"write"} or {"write", "createChild", "delete"};

    for _, permission in ipairs(permissions) do
        setPermission(node, "group", "todos", permission, "deny");
        setPermission(node, "group", "jogadores", permission, "deny");
        setPermission(node, "group", "mestres", permission, "strongAllow");
    end

    if ownerLogin ~= nil then
        setPermission(node, "user", ownerLogin, "write", "strongAllow");
    else
        setPermission(node, "group", "todos", "read", "strongAllow");
    end

    return true;
end

local function currentItem(root)
    local itemId = tostring(root.turnTimerItemId or "");

    if itemId == "" or root.itens == nil then
        return nil;
    end

    for _, item in ipairs(ndb.getChildNodes(root.itens)) do
        if item.turnoAtual == true and tostring(item.itemId or "") == itemId then
            return item;
        end
    end

    return nil;
end

local function acknowledge(root, slot, requestId)
    if not isMaster(root) or not ndb.testPermission(slot, "write") then
        return false;
    end

    if tostring(slot.requestId or "") ~= requestId then
        return true;
    end

    if tostring(slot.processedRequestId or "") == requestId then
        return true;
    end

    return withUpdate(slot, function()
        if tostring(slot.requestId or "") == requestId
            and tostring(slot.processedRequestId or "") ~= requestId then
            slot.processedRequestId = requestId;
        end
    end);
end

local function complete(root, state, name, slot, requestId)
    if not isMaster(root) then
        if state.processed[name] == requestId then
            state.processed[name] = nil;
        end
        return false;
    end

    state.completed[name] = requestId;
    return acknowledge(root, slot, requestId);
end

-- Safe to call repeatedly as participants join: unchanged ACLs are not written.
function M.configure(root)
    if root == nil or not isMaster(root) then
        return false;
    end

    local state = stateOf(root);

    if state.configuring then
        return false;
    end

    local room = getRoom(root);
    local container = root.turnRequests;

    if room == nil or (container == nil and not ndb.testPermission(root, "createChild")) then
        return false;
    end

    state.configuring = true;
    local ok, configured = withUpdate(root, function()
        container = container or ndb.createChildNode(root, "turnRequests");

        if container == nil or not configureNode(container, nil) then
            return false;
        end

        for _, player in ipairs(room.jogadores or {}) do
            local login = trimmed(player.login);
            local name = slotName(login);

            if name ~= nil then
                local slot = container[name];

                if slot == nil and ndb.testPermission(container, "createChild") then
                    slot = ndb.createChildNode(container, name);
                end

                if slot == nil or not configureNode(slot, login) then
                    return false;
                end
            end
        end

        return true;
    end);
    state.configuring = false;
    return ok and configured == true;
end

function M.request(root, itemNode)
    if root == nil or itemNode == nil or isMaster(root) then
        return false;
    end

    local player = getLocalPlayer(getRoom(root));
    local name = player ~= nil and slotName(player.login) or nil;
    local container = root.turnRequests;
    local slot = container ~= nil and name ~= nil and container[name] or nil;
    local turnId = tostring(root.turnTimerId or "");
    local itemId = tostring(itemNode.itemId or "");

    if slot == nil or turnId == "" or itemId == "" or currentItem(root) ~= itemNode
        or not ndb.testPermission(slot, "write") then
        return false;
    end

    local state = stateOf(root);

    if not state.requestFailed and tostring(slot.turnId or "") == turnId
        and tostring(slot.itemId or "") == itemId and trimmed(slot.requestId) ~= ""
        and tostring(slot.requestId) ~= tostring(slot.processedRequestId or "") then
        return true;
    end

    local requestId;

    repeat
        requestCounter = requestCounter + 1;
        requestId = string.format("%d-%d", os.time(), requestCounter);
    until requestId ~= tostring(slot.requestId or "")
        and requestId ~= tostring(slot.processedRequestId or "");

    local ok = withUpdate(slot, function()
        slot.turnId = turnId;
        slot.itemId = itemId;
        slot.requestId = requestId;
    end);
    state.requestFailed = not ok;
    return ok;
end

-- canPlayerAdvance(root, item, player, onResult) may complete asynchronously.
function M.process(root, canPlayerAdvance, advance)
    if root == nil or not isMaster(root) or type(canPlayerAdvance) ~= "function"
        or type(advance) ~= "function" then
        return;
    end

    local state = stateOf(root);

    if state.processing or state.advancing then
        return;
    end

    local room = getRoom(root);
    local container = root.turnRequests;

    if room == nil or container == nil then
        return;
    end

    state.processing = true;
    state.lastError = nil;
    local ok, processError = pcall(function()
        for _, player in ipairs(room.jogadores or {}) do
            local name = slotName(player.login);
            local slot = name ~= nil and container[name] or nil;
            local requestId = slot ~= nil and trimmed(slot.requestId) or "";

            if requestId ~= "" and state.completed[name] == requestId
                and tostring(slot.processedRequestId or "") ~= requestId then
                acknowledge(root, slot, requestId);
            elseif requestId ~= "" and state.processed[name] ~= requestId then
                local requestedTurn = tostring(slot.turnId or "");
                local requestedItem = tostring(slot.itemId or "");
                local item = currentItem(root);
                state.processed[name] = requestId;

                if tostring(slot.processedRequestId or "") == requestId then
                    -- This completed request also stays consumed after reloading.
                elseif item ~= nil and requestedTurn ~= "" and requestedItem ~= ""
                    and requestedTurn == tostring(root.turnTimerId or "")
                    and requestedItem == tostring(item.itemId or "") then
                    local answered = false;
                    local requester = player;

                    local checked, checkError = pcall(canPlayerAdvance, root, item, requester, function(allowed)
                        if answered then
                            return;
                        end

                        answered = true;

                        if not isMaster(root) then
                            if state.processed[name] == requestId then
                                state.processed[name] = nil;
                            end
                            return;
                        end

                        if allowed ~= true or state.advancing
                            or requestedTurn ~= tostring(root.turnTimerId or "")
                            or currentItem(root) ~= item or item.turnoAtual ~= true
                            or requestedItem ~= tostring(item.itemId or "")
                            or not ndb.testPermission(root, "write")
                            or not ndb.testPermission(root.itens, "write")
                            or not ndb.testPermission(item, "write") then
                            complete(root, state, name, slot, requestId);
                            return;
                        end

                        -- A player leaving the room cannot finish a pending request.
                        local stillPresent = false;

                        for _, candidate in ipairs(room.jogadores or {}) do
                            if slotName(candidate.login) == name then
                                stillPresent = true;
                                break;
                            end
                        end

                        if not stillPresent then
                            complete(root, state, name, slot, requestId);
                            return;
                        end

                        state.advancing = true;
                        local advanced, advanceError = withUpdate(root, function()
                            return advance(root);
                        end);
                        state.advancing = false;
                        complete(root, state, name, slot, requestId);

                        if not advanced then
                            state.lastError = advanceError;
                        end
                    end);

                    if not checked then
                        state.lastError = checkError;
                        complete(root, state, name, slot, requestId);
                    end
                else
                    complete(root, state, name, slot, requestId);
                end
            end
        end
    end);
    state.processing = false;

    return ok, not ok and processError or state.lastError;
end

return M;

local ndb = require("ndb.lua");
local rrpg = require("rrpg.lua");
local utils = require("utils.lua");

local M = {};
-- Guarda somente nodos vivos. A permissao e consultada novamente em cada pedido.
local roomNodes = setmetatable({}, {__mode = "k"});

local function property(object, name)
    if object == nil then return nil; end
    local ok, value = pcall(function() return object[name]; end);
    if ok then return value; end
    return nil;
end

local function safeBoolean(value)
    if type(value) == "boolean" then return value; end
    local text = tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", ""):lower();
    return text == "true" or text == "1" or text == "yes" or text == "sim";
end

local function normalize(value)
    local text = tostring(value or "");
    local ok, plain = pcall(function() return utils.removerFmtChat(text, false); end);
    if ok and type(plain) == "string" then text = plain; end
    text = text:gsub("^%s+", ""):gsub("%s+$", ""):gsub("%s+", " ");
    local converted, unaccented = pcall(function() return utils.removerAcentos(text); end);
    if converted and type(unaccented) == "string" then text = unaccented; end
    return text:lower();
end

local function sameLogin(first, second)
    local name = normalize(first);
    return name ~= "" and name == normalize(second);
end

local function getRoom(root, player)
    local ok, mesa = pcall(function() return rrpg.getMesaDe(root); end);
    if ok and mesa ~= nil then return mesa; end
    return property(player, "mesa");
end

local function findCharacter(mesa, id)
    local code = tonumber(id);
    if mesa == nil or code == nil or code < 0 then return nil; end
    local ok, character = pcall(function() return mesa:findBibliotecaItem(code); end);
    if ok and property(character, "tipo") == "personagem" then return character; end
    return nil;
end

local function isSameName(item, player, mesa)
    local name = normalize(property(item, "nome"));
    if name == "" then return false; end
    if name == normalize(property(player, "nick")) or name == normalize(property(player, "login")) then
        return true;
    end
    local principal = findCharacter(mesa, property(player, "personagemPrincipal"));
    return principal ~= nil and name == normalize(property(principal, "nome"));
end

function M.isSameName(item, player)
    if item == nil or player == nil or property(item, "tipo") == "grupo" then return false; end
    return isSameName(item, player, getRoom(item, player));
end

local function findCharacters(mesa, item)
    local associated = findCharacter(mesa, property(item, "personagemId"));
    if associated ~= nil then return {associated}; end
    local name = normalize(property(item, "nome"));
    local result, visited = {}, {};
    if name == "" then return result; end

    local function visit(entry)
        if entry == nil or visited[entry] then return; end
        visited[entry] = true;
        local kind = property(entry, "tipo");
        if kind == "personagem" then
            if normalize(property(entry, "nome")) == name then result[#result + 1] = entry; end
        elseif kind == "biblioteca" or kind == "diretorio" then
            for _, child in ipairs(property(entry, "filhos") or {}) do visit(child); end
        end
    end
    visit(property(mesa, "biblioteca"));
    return result;
end

local function getOwnerLogin(character)
    local login = property(character, "loginDono");
    if normalize(login) ~= "" then return login; end
    return property(property(character, "dono"), "login");
end

local function applicableSelectors(character, player)
    local login = property(player, "login");
    local owner = sameLogin(login, getOwnerLogin(character));
    local creator = sameLogin(login, property(character, "loginCriador"));
    local selectors = {{kind = "group", id = "todos"}};
    if normalize(login) ~= "" then selectors[#selectors + 1] = {kind = "user", id = login}; end
    if safeBoolean(property(player, "isJogador")) then
        selectors[#selectors + 1] = {kind = "group", id = "jogadores"};
    end
    if safeBoolean(property(player, "isEspectador")) then
        selectors[#selectors + 1] = {kind = "group", id = "espectadores"};
    end
    if owner then selectors[#selectors + 1] = {kind = "group", id = "dono"}; end
    if creator then selectors[#selectors + 1] = {kind = "group", id = "criador"}; end
    for field, group in pairs({isCego = "cegos", isMudo = "mudos", haveVoice = "voices"}) do
        if safeBoolean(property(player, field)) then selectors[#selectors + 1] = {kind = "group", id = group}; end
    end
    return selectors, owner;
end

local function inheritedWrite(node, selector)
    local visited = {};
    while node ~= nil and not visited[node] do
        visited[node] = true;
        local value = ndb.getPermission(node, selector.kind, selector.id, "write");
        if value ~= nil then return value; end
        node = ndb.getParent(node);
    end
    return nil;
end

local function remoteCanWrite(node, character, player)
    local selectors, owner = applicableSelectors(character, player);
    local allowed, denied, defined = false, false, false;
    for _, selector in ipairs(selectors) do
        local value = inheritedWrite(node, selector);
        if value == "strongAllow" then return true; end
        if value == "deny" then denied, defined = true, true;
        elseif value == "allow" then allowed, defined = true, true; end
    end
    if denied then return false; end
    if allowed then return true; end
    -- As permissoes basicas da ficha autorizam seu dono e os mestres.
    -- O criador so recebe acesso se houver uma definicao aplicavel.
    return not defined and owner;
end

local function isLocalPlayer(mesa, player)
    local localPlayer = property(mesa, "meuJogador");
    return localPlayer ~= nil and (localPlayer == player
        or sameLogin(property(localPlayer, "login"), property(player, "login")));
end

local function nodeIsOpen(node)
    local ok, state = pcall(function() return ndb.getState(node); end);
    return ok and state == "open";
end

local function openCharacterNode(mesa, character, onNode)
    local cache = roomNodes[mesa];
    if cache == nil then
        cache = setmetatable({}, {__mode = "k"});
        roomNodes[mesa] = cache;
    end
    local cached = cache[character];
    if cached ~= nil and nodeIsOpen(cached) then onNode(cached); return; end
    cache[character] = nil;
    local completed = false;
    local function loaded(node)
        if completed then return; end
        completed = true;
        if node ~= nil and nodeIsOpen(node) then cache[character] = node;
        else node = nil; end
        onNode(node);
    end
    local ok, promise = pcall(function() return character:asyncOpenNDB(); end);
    if not ok or promise == nil then loaded(nil); return; end
    local subscribed = pcall(function()
        promise:thenDo(function(node) loaded(node); end, function() loaded(nil); end);
    end);
    if not subscribed then loaded(nil); end
end

function M.check(root, item, player, onResult)
    if type(onResult) ~= "function" then return; end
    local finished = false;
    local function finish(allowed)
        if finished then return; end
        finished = true;
        onResult(allowed == true);
    end
    local ok = pcall(function()
        if root == nil or item == nil or player == nil or property(item, "tipo") == "grupo" then
            finish(false);
            return;
        end
        if safeBoolean(property(player, "isMestre")) then finish(true); return; end
        local mesa = getRoom(root, player);
        if isSameName(item, player, mesa) then finish(true); return; end
        if mesa == nil then finish(false); return; end
        local characters = findCharacters(mesa, item);
        local index = 0;
        local function checkNext()
            if finished then return; end
            index = index + 1;
            local character = characters[index];
            if character == nil then finish(false); return; end
            openCharacterNode(mesa, character, function(node)
                if finished then return; end
                local permissionOk, allowed = pcall(function()
                    if node == nil then return false; end
                    if isLocalPlayer(mesa, player) then return ndb.testPermission(node, "write"); end
                    return remoteCanWrite(node, character, player);
                end);
                if permissionOk and allowed == true then finish(true);
                else
                    local continued = pcall(checkNext);
                    if not continued then finish(false); end
                end
            end);
        end
        checkNext();
    end);
    if not ok then finish(false); end
end

return M;

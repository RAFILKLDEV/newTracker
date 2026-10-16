-- Metadata for the native Firecast chat. Original records and dice are never written.
local ndb = require("ndb.lua");
local rrpg = require("rrpg.lua");
local vhd = require("vhd.lua");
local utils = require("utils.lua");
local serializer = require("utils.serializer.dlua");
local model = require("trackerChatModel.lua");

local M = {};
local Store = {};
Store.__index = Store;
local REQUEST = "newTracker.chat.metadata.request.v1";
local REPLY = "newTracker.chat.metadata.reply.v1";
local PRESENCE = "newTracker.chat.metadata.master.v1";
local DATABASE = "newTracker.chatAdvanced.v1";
local MAX_SERIALIZED = 2097152;
local MAX_AUDIT = 1024;
local MAX_CORRECTIONS = 256;
local MAX_MESSAGES = 2000;
local REQUEST_TIMEOUT = 18;
local counter = 0;

local function property(object, name)
    if object == nil then return nil; end
    local ok, value = pcall(function() return object[name]; end);
    return ok and value or nil;
end

local function trim(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "");
end

local function login(value)
    return trim(value):lower();
end

local function sameLogin(a, b)
    return login(a) ~= "" and login(a) == login(b);
end

local function finite(value)
    return type(value) == "number" and value == value and value ~= math.huge and value ~= -math.huge;
end

local function validId(value)
    return type(value) == "string" and #value > 0 and #value <= 1024 and not value:find("[%c]");
end

local function validText(value, maximum)
    if type(value) ~= "string" or #value > maximum * 4 or value:find("%z") then return false; end
    local _,count=value:gsub("[^\128-\191]", "");
    return count <= maximum;
end

local function copy(value, depth)
    if type(value) ~= "table" then return value; end
    depth = (depth or 0) + 1;
    if depth > 20 then return nil; end
    local result = {};
    for key, child in pairs(value) do
        if type(key) == "string" or type(key) == "number" then
            local kind = type(child);
            if kind == "table" then result[key] = copy(child, depth);
            elseif kind == "string" or kind == "number" or kind == "boolean" then result[key] = child; end
        end
    end
    return result;
end

local function newData()
    return {version = 1, revision = 0, messages = {}, ops = {}, opOrder = {},
        settings = {allowThirdParty = false, pinCreate = "players", pinRemove = "creator"}};
end

local function normalizeSettings(settings)
    settings = type(settings) == "table" and settings or {};
    return {
        allowThirdParty = settings.allowThirdParty == true,
        pinCreate = settings.pinCreate == "masters" and "masters" or "players",
        pinRemove = (settings.pinRemove == "masters" or settings.pinRemove == "players")
            and settings.pinRemove or "creator"
    };
end

local function decode(value)
    if type(value) ~= "string" or #value > MAX_SERIALIZED then return newData(), false; end
    local ok, result = pcall(serializer.deserialize, value);
    if not ok or type(result) ~= "table" or result.version ~= 1 or type(result.messages) ~= "table" then
        return newData(), false;
    end
    result.settings = normalizeSettings(result.settings);
    result.ops = type(result.ops) == "table" and result.ops or {};
    result.opOrder = type(result.opOrder) == "table" and result.opOrder or {};
    result.revision = tonumber(result.revision) or 0;
    if not finite(result.revision) or result.revision < 0 then return newData(), false; end
    return result, true;
end

local function encode(value)
    local ok, result = pcall(serializer.serialize, value);
    if not ok or type(result) ~= "string" or #result > MAX_SERIALIZED then return nil; end
    return result;
end

local function nodeOpen(node)
    local ok, state = pcall(ndb.getState, node);
    return ok and state == "open";
end

local function canWrite(node)
    local ok, allowed = pcall(ndb.testPermission, node, "write");
    return ok and allowed == true;
end

local function writeAttribute(node, text)
    if node == nil or not nodeOpen(node) or not canWrite(node) then return false; end
    if property(node, "data") == text then return true; end
    local ok = pcall(function() node.data = text; end);
    return ok and property(node, "data") == text;
end

local function uniqueId()
    if utils.generateUniqueString ~= nil then
        local ok, value = pcall(utils.generateUniqueString);
        if ok and validId(value) then return value; end
    end
    counter = counter + 1;
    return tostring(os.time()) .. "-chat-" .. tostring(counter);
end

local function hex(value)
    return tostring(value or ""):gsub(".", function(character)
        return string.format("%02x", string.byte(character));
    end);
end

local function callback(fn, ...)
    if type(fn) == "function" then pcall(fn, ...); end
end

local function myPlayer(room)
    local player = property(room, "meuJogador");
    if player ~= nil then return player; end
    local ok, result = pcall(function() return room:getMeuJogador(); end);
    return ok and result or nil;
end

local function playerFor(room, sender)
    if room == nil or not validId(sender) then return nil; end
    local ok, player = pcall(function() return room:findJogador(sender); end);
    if not ok or player == nil or not sameLogin(property(player, "login"), sender) then return nil; end
    -- The native roster is the authority; a user-supplied nickname is never an identity.
    for _, candidate in ipairs(property(room, "jogadores") or {}) do
        if sameLogin(property(candidate, "login"), sender) then return player; end
    end
    return nil;
end

local function isMaster(player)
    return property(player, "isMestre") == true;
end

function Store:_leader()
    local masters = {};
    local now=os.time();
    if isMaster(myPlayer(self.room)) then masters[#masters + 1]=login(self.userLogin); end
    for sender,expires in pairs(self.masterPeers) do
        if expires > now and not sameLogin(sender,self.userLogin) then
            local player=playerFor(self.room,sender);
            if isMaster(player) then masters[#masters + 1]=sender; end
        end
    end
    table.sort(masters);
    return masters[1];
end

function Store:_isLeader()
    return isMaster(myPlayer(self.room)) and os.time() - self.startedAt >= 2
        and self:_leader() == login(self.userLogin);
end

function Store:_changed()
    if not self.destroyed then callback(self.onChange, self); end
end

function Store:_status(reason)
    if not self.destroyed then callback(self.onStatus, reason); end
end

local function destroyObserver(observer)
    if observer ~= nil then pcall(function() observer:destroy(); end); end
end

-- Native broadcasts cover an entire NodeDatabase, not the individual node.
-- Deduplicate the initiative root and its metadata child by their native root.
local function databaseIdentity(node)
    if node == nil or not nodeOpen(node) then return nil; end
    local rootOk, root = pcall(ndb.getRoot, node);
    if not rootOk or root == nil or not nodeOpen(root) then return nil; end
    local handleOk, handle = pcall(ndb.getNodeHandle, root);
    if not handleOk or handle == nil or handle == 0 then return nil; end
    return tostring(handle), root;
end

local function destroyTransport(binding)
    if binding == nil then return; end
    binding.active = false;
    for _, receiver in pairs(binding.receivers or {}) do
        pcall(function() receiver:destroy(); end);
    end
    binding.receivers = {};
end

function Store:_loadShared()
    local node = self.sharedNode;
    if node == nil then return; end
    local value = property(node, "data");
    if self.sharedEncoded == value then return; end
    self.sharedEncoded = value;
    self.shared = decode(value);
    self:_changed();
end

function Store:_secure(node)
    if node == nil or not isMaster(myPlayer(self.room)) then return; end
    local ok, allowed = pcall(ndb.testPermission, node, "writePermissions");
    if not ok or not allowed then return; end
    -- These permissions belong only to the new metadata branch. The tracker root,
    -- initiative items, character sheets and turn nodes retain their existing ACL.
    local function set(kind,id,permission,value)
        local readOk,current=pcall(ndb.getPermission,node,kind,id,permission);
        if not readOk or current ~= value then pcall(ndb.setPermission,node,kind,id,permission,value); end
    end
    set("group","todos","read","strongAllow");
    local permissions={"write","createChild","delete","writePermissions","writeMetaPermissions"};
    -- Grant the master selectors first; denying everyone must not remove the
    -- caller's ability to finish configuring this new branch.
    for _, permission in ipairs(permissions) do
        for _, group in ipairs({"mestres", "mestresAux"}) do
            set("group",group,permission,"strongAllow");
        end
    end
    local selectors={};
    for _, group in ipairs({"todos","jogadores","espectadores","criadorDaMesa","criador","dono","cegos","mudos","voices"}) do
        selectors["group:" .. group]={kind="group",id=group};
    end
    local ancestor=node;
    local visited={};
    while ancestor ~= nil and not visited[ancestor] do
        visited[ancestor]=true;
        local readOk,rules=pcall(ndb.enumPermissions,ancestor);
        if readOk then
            for _, rule in ipairs(rules or {}) do
                if (rule.selKind == "group" or rule.selKind == "user") and validId(rule.selId)
                    and rule.selId ~= "mestres" and rule.selId ~= "mestresAux" then
                    selectors[rule.selKind .. ":" .. rule.selId]={kind=rule.selKind,id=rule.selId};
                end
            end
        end
        local parentOk,parent=pcall(ndb.getParent,ancestor);
        ancestor=parentOk and parent or nil;
    end
    for _, selector in pairs(selectors) do
        for _, permission in ipairs(permissions) do set(selector.kind,selector.id,permission,"deny"); end
    end
end

function Store:_bindShared(node)
    if self.destroyed or node == nil or self.sharedNode == node then return; end
    destroyObserver(self.sharedObserver);
    self.sharedObserver = nil;
    self.sharedNode = node;
    self.sharedEncoded = nil;
    self:_secure(node);
    local ok, observer = pcall(ndb.newObserver, node);
    if ok and observer ~= nil then
        self.sharedObserver = observer;
        for _, event in ipairs({"onChanged", "onPersistedChanged", "onStateChanged"}) do
            observer:addEventListener(event, function()
                if not self.destroyed and self.sharedNode == node and self.sharedObserver == observer then
                    self:_loadShared();
                end
            end);
        end
    end
    self:_loadShared();
end

function Store:_ensureBranch()
    if self.destroyed or self.ensuringBranch then return; end
    self.ensuringBranch = true;
    local rootAvailable = self.root ~= nil and nodeOpen(self.root);
    local replicaAvailable = self.roomNode ~= nil and nodeOpen(self.roomNode);
    local branch = rootAvailable and property(self.root, "chatAdvanced") or nil;
    if rootAvailable and branch == nil and self:_isLeader() then
        local ok, allowed = pcall(ndb.testPermission, self.root, "createChild");
        if ok and allowed then
            local created, node = pcall(ndb.createChildNode, self.root, "chatAdvanced");
            if created then branch = node; end
        end
    end
    if branch ~= nil and nodeOpen(branch) then
        self.branch = branch;
        -- A shared tracker branch is the common source across subscription levels.
        -- A newer Room NDB replica may contain work made with the dock alone.
        -- Restore it before selecting the branch, instead of overwriting it with
        -- older metadata when an initiative tracker is opened later.
        if replicaAvailable and isMaster(myPlayer(self.room)) and os.time() - self.startedAt >= 2 then
            local branchText, replicaText = property(branch, "data"), property(self.roomNode, "data");
            if self.handoffBranch ~= branch or self.handoffRoom ~= self.roomNode
                or self.handoffBranchText ~= branchText or self.handoffReplicaText ~= replicaText then
                local branchData, branchValid = decode(branchText);
                local replicaData, replicaValid = decode(replicaText);
                local synchronized = true;
                if replicaValid and (not branchValid or replicaData.revision > branchData.revision) then
                    if self.sharedNode ~= branch then self:_secure(branch); end
                    synchronized = writeAttribute(branch, replicaText);
                    if synchronized then
                        self.handoffWarning = nil;
                    elseif not self.handoffWarning then
                        self.handoffWarning = true;
                        self:_status("Não foi possível restaurar os metadados mais recentes no tracker. Confira a permissão do mestre.");
                    end
                elseif branchValid and branchText ~= replicaText then
                    -- The existing branch wins equal revisions and is mirrored only
                    -- after checking that the replica is not newer. Any master with
                    -- both sources can bridge an elected Room-only master; only the
                    -- elected master still processes actual mutation requests.
                    synchronized = writeAttribute(self.roomNode, branchText);
                end
                if synchronized then
                    self.handoffBranch, self.handoffRoom = branch, self.roomNode;
                    self.handoffBranchText = property(branch, "data");
                    self.handoffReplicaText = property(self.roomNode, "data");
                end
            end
        end
        self:_bindShared(branch);
        self:_loadShared();
    elseif replicaAvailable then
        self.branch = nil;
        self:_bindShared(self.roomNode);
    elseif self.sharedNode ~= nil and not nodeOpen(self.sharedNode) then
        destroyObserver(self.sharedObserver);
        self.sharedObserver, self.sharedNode, self.sharedEncoded = nil, nil, nil;
    end
    self.ensuringBranch = false;
end

function Store:_savePrivate(data)
    local text = encode(data);
    if text == nil then return false, "O limite de armazenamento particular foi atingido."; end
    if self.privateNode == nil then
        return false, "Não foi possível abrir o armazenamento particular deste usuário.";
    end
    local previous = property(self.privateNode, "data");
    local written = pcall(function() self.privateNode.data = text; end);
    if not written then return false, "Não foi possível salvar os dados particulares."; end
    -- ndb.load supplies the persisted XML database; explicitly flush its XML so a
    -- restart immediately after a click does not depend on the provider's save delay.
    local xmlOk, xml = pcall(ndb.exportXML, self.privateNode);
    local openOk, stream = pcall(vhd.openFile, self.privateFile, "w+");
    local saved = false;
    if xmlOk and type(xml) == "string" and openOk and stream ~= nil then
        local ok, count = pcall(function() return stream:writeBinary("utf8", xml); end);
        local closed = pcall(function() stream:close(); end);
        saved = ok and closed and count ~= false;
    elseif openOk and stream ~= nil then
        pcall(function() stream:close(); end);
    end
    if not saved then
        pcall(function() self.privateNode.data = previous; end);
        return false, "Não foi possível gravar o arquivo particular. Confira o armazenamento local.";
    end
    self.private = data;
    self.privateEncoded = text;
    if self.userRoomNode ~= nil then
        -- This API is scoped by the authenticated current user, unlike room metadata.
        pcall(function() self.userRoomNode.data = text; end);
    end
    self:_changed();
    return true;
end

function Store:_saveShared(data)
    self:_ensureBranch();
    if not self:_isLeader() or self.sharedNode == nil then
        return false, "O mestre precisa manter o tracker ou o Chat Avançado aberto.";
    end
    local text = encode(data);
    if text == nil then return false, "O limite de armazenamento compartilhado foi atingido."; end
    local currentRevision = tonumber(self.shared.revision) or 0;
    if self.roomNode ~= nil and nodeOpen(self.roomNode) then
        local replica, valid = decode(property(self.roomNode, "data"));
        if valid then currentRevision = math.max(currentRevision, replica.revision); end
    end
    if (tonumber(data.revision) or 0) <= currentRevision then
        return false, "Os metadados foram atualizados durante a operação. Tente novamente.";
    end
    if not writeAttribute(self.sharedNode, text) then
        return false, "O mestre não tem permissão para salvar os metadados compartilhados.";
    end
    self.shared = data;
    self.sharedEncoded = text;
    if self.roomNode ~= nil and self.roomNode ~= self.sharedNode then
        writeAttribute(self.roomNode, text);
    end
    self:_changed();
    return true;
end

local function mergePrivate(localData, cloudData)
    local merged = copy(localData);
    for key, message in pairs(cloudData.messages) do
        local existing = merged.messages[key];
        if type(message) == "table" and (existing == nil
            or (tonumber(message.updatedAt) or 0) > (tonumber(existing.updatedAt) or 0)) then
            merged.messages[key] = copy(message);
        end
    end
    merged.revision = math.max(localData.revision or 0, cloudData.revision or 0);
    return merged;
end

function Store:_openCloud()
    if self.room == nil then return; end
    if property(self.room, "asyncOpenRoomNDB") ~= nil then
        local ok, promise = pcall(function()
            return self.room:asyncOpenRoomNDB(DATABASE, {create = isMaster(myPlayer(self.room))});
        end);
        if ok and promise ~= nil and property(promise, "thenDo") ~= nil then
            promise:thenDo(function(node)
                if self.destroyed or node == nil then return; end
                self.roomNode = node;
                self:_secure(node);
                self:_ensureBranch();
                self:_bindTransport();
            end, function()
                if self.destroyed then return; end
                self:_ensureBranch();
                if self.sharedNode == nil then
                    self:_status("O armazenamento compartilhado está indisponível. As funções particulares continuam disponíveis.");
                end
            end);
        end
    end
    if property(self.room, "asyncOpenUserRoomNDB") ~= nil then
        local ok, promise = pcall(function()
            return self.room:asyncOpenUserRoomNDB(DATABASE, {create = true});
        end);
        if ok and promise ~= nil and property(promise, "thenDo") ~= nil then
            promise:thenDo(function(node)
                if self.destroyed or node == nil then return; end
                self.userRoomNode = node;
                local cloud = decode(property(node, "data"));
                local merged = mergePrivate(self.private, cloud);
                self:_savePrivate(merged);
            end, function() end);
        end
    end
end

local function findCorrection(record, correctionId)
    if type(record) ~= "table" then return nil; end
    for _, correction in ipairs(record.corrections or {}) do
        if correction.id == correctionId then return correction; end
    end
    return nil;
end

function Store:_permission(entry, action, scope, correctionId, actor, data)
    if entry == nil or not validId(entry.key) or entry.deleted == true then
        return false, "Esta mensagem não está mais disponível.";
    end
    if scope ~= "private" and scope ~= "shared" then return false, "Escolha a visibilidade da alteração."; end
    local actorLogin = property(actor, "login");
    if not validId(actorLogin) then return false, "Não foi possível identificar o usuário pelo login."; end
    local master = isMaster(actor);
    if scope == "shared" then
        if entry.public ~= true or entry.stable ~= true then
            return false, "Esta mensagem aceita somente dados particulares para preservar sua visibilidade.";
        end
        if self.sharedNode == nil or not nodeOpen(self.sharedNode) then
            return false, "Os dados compartilhados ainda estão carregando. O mestre precisa abrir o tracker.";
        end
    end
    local settings = normalizeSettings((scope == "shared" and (data or self.shared) or self.shared).settings);
    local record = (data or (scope == "shared" and self.shared or self.private)).messages[entry.key];
    if action == "correct" then
        if type(entry.roll) ~= "table" or entry.roll.compatible ~= true or not finite(entry.roll.result) then
            return false, "Esta rolagem não aceita uma correção aditiva segura.";
        end
        if not master and not sameLogin(entry.authorLogin, actorLogin) and not settings.allowThirdParty then
            return false, "Você só pode corrigir suas próprias rolagens.";
        end
    elseif action == "edit" or action == "undo" then
        local correction = findCorrection(record, correctionId);
        if correction == nil or correction.undone == true then return false, "Esta correção não está ativa."; end
        if not master and not sameLogin(correction.authorLogin, actorLogin) then
            return false, "Você só pode editar ou desfazer as correções que criou.";
        end
        if action == "edit" and (type(entry.roll) ~= "table" or entry.roll.compatible ~= true) then
            return false, "O formato original desta rolagem não aceita uma correção aditiva segura.";
        end
    elseif action == "pin" then
        if scope == "shared" and not master and settings.pinCreate == "masters" then
            return false, "O mestre reservou a criação de fixações compartilhadas aos mestres.";
        end
    elseif action == "unpin" then
        if record == nil or record.pin == nil then return false, "Esta mensagem não está fixada nesta lista."; end
        if scope == "shared" and not master then
            if settings.pinRemove == "masters" or (settings.pinRemove ~= "players"
                and not sameLogin(record.pin.creator, actorLogin)) then
                return false, "Você não tem permissão para remover esta fixação compartilhada.";
            end
        end
    elseif action ~= "note" then
        return false, "Ação de metadados inválida.";
    end
    return true;
end

function Store:can(entry, action, scope, correctionId)
    self:_ensureBranch();
    return self:_permission(entry, action, scope or "private", correctionId, myPlayer(self.room));
end

function Store:getSettings()
    return normalizeSettings(self.shared.settings);
end

function Store:get(entry)
    local result = {delta = 0, corrected = false, corrections = {}, audit = {}, notes = {}};
    if entry == nil or entry.deleted then return result; end
    local compatible = type(entry.roll) == "table" and entry.roll.compatible == true;
    result.result = type(entry.roll) == "table" and entry.roll.result or nil;
    for _, scope in ipairs({"shared", "private"}) do
        local database = scope == "shared" and self.shared or self.private;
        -- Restricted/native-hidden records never consult a room-wide metadata map.
        local record = (scope == "private" or entry.public == true) and database.messages[entry.key] or nil;
        if type(record) == "table" then
            for _, value in ipairs(record.corrections or {}) do
                local correction = copy(value);
                correction.scope = scope;
                correction.author = correction.authorName or correction.authorLogin;
                correction.time = correction.updatedAt or correction.createdAt;
                correction.active = correction.undone ~= true;
                result.corrections[#result.corrections + 1] = correction;
                if compatible and correction.active and finite(correction.delta) then result.delta = result.delta + correction.delta; end
            end
            for _, value in ipairs(record.audit or {}) do
                local audit = copy(value);
                audit.scope = scope;
                audit.author = audit.actorName or audit.actorLogin;
                audit.authorLogin = audit.actorLogin;
                audit.time = audit.at;
                result.audit[#result.audit + 1] = audit;
            end
            for _, value in pairs(record.notes or {}) do
                local note = copy(value);
                note.scope = scope;
                note.author = note.authorName or note.authorLogin;
                note.time = note.at;
                result.notes[#result.notes + 1] = note;
            end
            if scope == "private" then result.ownPin = copy(record.pin);
            else result.sharedPin = copy(record.pin); end
        end
    end
    table.sort(result.audit, function(a, b)
        if a.time == b.time then return tostring(a.opId or "") < tostring(b.opId or ""); end
        return (tonumber(a.time) or 0) < (tonumber(b.time) or 0);
    end);
    table.sort(result.notes, function(a, b) return (tonumber(a.at) or 0) < (tonumber(b.at) or 0); end);
    local active = false;
    for _, correction in ipairs(result.corrections) do if correction.active then active = true; break; end end
    result.corrected = active and compatible;
    if finite(result.result) then result.result = result.result + result.delta; end
    return result;
end

function Store:listPins()
    local pins = {};
    for _, scope in ipairs({"private", "shared"}) do
        local database = scope == "shared" and self.shared or self.private;
        for _, record in pairs(database.messages) do
            if type(record) == "table" and record.pin ~= nil and type(record.entry) == "table"
                and record.entry.deleted ~= true and (scope == "private" or record.entry.public == true) then
                local entry = copy(record.entry);
                pins[#pins + 1] = {entry = entry, state = self:get(entry), scope = scope,
                    creator = record.pin.creator, pinnedAt = record.pin.at,
                    canUnpin=self:can(entry,"unpin",scope)};
            end
        end
    end
    table.sort(pins, function(a, b)
        if a.pinnedAt == b.pinnedAt then return tostring(a.entry.key) < tostring(b.entry.key); end
        return (tonumber(a.pinnedAt) or 0) < (tonumber(b.pinnedAt) or 0);
    end);
    return pins;
end

local function storeOp(data, opKey)
    data.ops[opKey] = true;
    data.opOrder[#data.opOrder + 1] = opKey;
    while #data.opOrder > 256 do data.ops[table.remove(data.opOrder, 1)] = nil; end
end

function Store:_apply(entry, action, input, actor, opId)
    local scope = input.scope;
    if scope == "shared" then self:_ensureBranch(); end
    self:_loadShared();
    local current = scope == "shared" and self.shared or self.private;
    local opKey = login(property(actor, "login")) .. ":" .. opId;
    if current.ops[opKey] then return true; end
    local allowed, reason = self:_permission(entry, action, scope, input.correctionId, actor, current);
    if not allowed then return false, reason; end
    local data = copy(current);
    local record = data.messages[entry.key];
    if record == nil then
        local count = 0;
        for _ in pairs(data.messages) do count = count + 1; end
        if count >= MAX_MESSAGES then return false, "O limite de mensagens com metadados foi atingido."; end
        record = {corrections = {}, audit = {}, notes = {}};
        data.messages[entry.key] = record;
    end
    record.corrections = record.corrections or {};
    record.audit = record.audit or {};
    record.notes = record.notes or {};
    if #record.audit >= MAX_AUDIT then return false, "O limite do histórico desta mensagem foi atingido."; end
    local now = os.time();
    local actorLogin = property(actor, "login");
    local actorName = property(actor, "nick") or actorLogin;
    local audit = {action = action, opId = opId, actorLogin = actorLogin, actorName = actorName, at = now};
    if action == "correct" or action == "edit" then
        local delta = tonumber(input.delta);
        local description = trim(input.reason);
        if not finite(delta) or math.abs(delta) > 1000000 then
            return false, "Informe um modificador numérico entre -1000000 e 1000000.";
        end
        if not validText(description, 400) then
            return false, "O motivo da correção pode ter até 400 caracteres.";
        end
        if action == "correct" then
            if #record.corrections >= MAX_CORRECTIONS then return false, "O limite de correções desta mensagem foi atingido."; end
            record.corrections[#record.corrections + 1] = {id = opId, delta = delta, reason = description,
                authorLogin = actorLogin, authorName = actorName, createdAt = now, updatedAt = now, undone = false};
            audit.correctionId = opId;
        else
            local correction = findCorrection(record, input.correctionId);
            audit.previousDelta = correction.delta;
            audit.previousReason = correction.reason;
            audit.correctionId = correction.id;
            correction.delta = delta;
            correction.reason = description;
            correction.updatedAt = now;
        end
        audit.delta = delta;
        audit.reason = description;
    elseif action == "undo" then
        local correction = findCorrection(record, input.correctionId);
        audit.correctionId = correction.id;
        audit.delta = correction.delta;
        audit.reason = correction.reason;
        correction.undone = true;
        correction.undoneBy = actorLogin;
        correction.undoneAt = now;
    elseif action == "pin" then
        if record.pin == nil then record.pin = {creator = actorLogin, creatorName = actorName, at = now}; end
    elseif action == "unpin" then
        record.pin = nil;
    elseif action == "note" then
        if not validText(input.text, 4000) then return false, "A observação pode ter até 4000 caracteres."; end
        if trim(input.text) == "" then return false, "Informe o texto da observação."; end
        audit.text = input.text;
        record.notes[#record.notes + 1] = {id=opId, text=input.text, authorLogin=actorLogin, authorName=actorName, at=now};
    end
    local snapshotOk, snapshot = pcall(model.snapshot, entry);
    if not snapshotOk or type(snapshot) ~= "table" then return false, "Não foi possível preservar a mensagem original."; end
    record.entry = snapshot;
    record.updatedAt = now;
    record.audit[#record.audit + 1] = audit;
    data.revision = (data.revision or 0) + 1;
    storeOp(data, opKey);
    if scope == "shared" then return self:_saveShared(data); end
    return self:_savePrivate(data);
end

function Store:_broadcast(messageId, payload)
    if self.destroyed then return false; end
    self:_bindTransport();
    local sent = false;
    for _, binding in pairs(self.transportBindings) do
        if binding.active and nodeOpen(binding.node) then
            local ok, result = pcall(ndb.broadcastMessage, binding.node, messageId, payload, false);
            if ok and result ~= false then sent = true; end
        end
    end
    return sent;
end

function Store:_reply(sender, opId, success, reason, pending)
    self:_broadcast(REPLY, {targetLogin = sender, opId = opId, success = success == true,
        reason = reason, pending = pending == true});
end

function Store:_receiveRequest(sender, payload)
    if self.destroyed or not self:_isLeader() or type(payload) ~= "table" or not validId(payload.opId) then return; end
    local actor = playerFor(self.room, sender);
    if actor == nil then return; end
    self:_ensureBranch();
    self:_loadShared();
    local requestKey = login(sender) .. ":" .. payload.opId;
    local previous = self.handled[requestKey];
    if previous ~= nil then
        self:_reply(sender, payload.opId, previous.success, previous.reason, previous.pending);
        return;
    end
    if self.shared.ops[requestKey] then self:_reply(sender, payload.opId, true); return; end
    local request = {pending = true, startedAt = os.time()};
    self.handled[requestKey] = request;
    self:_reply(sender, payload.opId, false, nil, true);
    local function finish(success, reason)
        if self.destroyed or not request.pending then return; end
        request.pending = false;
        request.success = success == true;
        request.reason = reason;
        self.handledOrder[#self.handledOrder + 1] = requestKey;
        while #self.handledOrder > 256 do self.handled[table.remove(self.handledOrder, 1)] = nil; end
        self:_reply(sender, payload.opId, success, reason);
    end
    if payload.action == "settings" then
        if not isMaster(actor) then finish(false, "Somente o mestre pode mudar estas permissões."); return; end
        if type(payload.settings) ~= "table" then finish(false, "As configurações são inválidas."); return; end
        self:_loadShared();
        local data = copy(self.shared);
        data.settings = normalizeSettings(payload.settings);
        data.revision = data.revision + 1;
        storeOp(data, requestKey);
        local success, reason = self:_saveShared(data);
        finish(success, reason);
        return;
    end
    local reference = payload.reference;
    if type(reference) ~= "table" or not validId(reference.key) or not validId(reference.id)
        or not validId(reference.tid) or type(reference.medium) ~= "table" or reference.medium.kind ~= "room"
        or type(payload.data) ~= "table" or payload.data.scope ~= "shared" or type(self.resolve) ~= "function" then
        finish(false, "A referência da mensagem original é inválida.");
        return;
    end
    local called = false;
    local resolved = pcall(self.resolve, copy(reference), function(original, reason)
        if called or self.destroyed or not request.pending then return; end
        called = true;
        if os.time() - request.startedAt >= REQUEST_TIMEOUT then
            finish(false,"A consulta da mensagem original excedeu o tempo limite."); return;
        end
        if not self:_isLeader() then finish(false, "O mestre responsável pelo chat mudou. Tente novamente."); return; end
        local currentActor = playerFor(self.room, sender);
        if currentActor == nil then finish(false, "O usuário não está mais na mesa."); return; end
        if original == nil or original.key ~= reference.key or original.id ~= reference.id or original.tid ~= reference.tid
            or original.public ~= true or original.stable ~= true or original.deleted == true then
            finish(false, reason or "O mestre não conseguiu confirmar a mensagem original pública.");
            return;
        end
        local success, failure = self:_apply(original, payload.action, payload.data, currentActor, payload.opId);
        finish(success, failure);
    end);
    if not resolved then finish(false, "Não foi possível consultar a mensagem original no chat nativo."); end
end

function Store:_receiveReply(sender, payload)
    if self.destroyed or type(payload) ~= "table" or not sameLogin(payload.targetLogin, self.userLogin) then return; end
    local actor = playerFor(self.room, sender);
    if actor == nil or not isMaster(actor) or login(sender) ~= self:_leader() then return; end
    local pending = self.pending[payload.opId];
    if pending == nil then return; end
    if payload.pending == true then pending.acknowledged = true; return; end
    self.pending[payload.opId] = nil;
    self:_ensureBranch();
    self:_loadShared();
    callback(pending.callback, payload.success == true, payload.reason);
end

function Store:_bindTransport()
    if self.destroyed then return; end
    self.transportBindings = self.transportBindings or {};
    local desired = {};
    local function include(node)
        local key, root = databaseIdentity(node);
        if key ~= nil then desired[key] = root; end
    end
    include(self.root);
    include(self.roomNode);
    include(self.sharedNode);
    for key, binding in pairs(self.transportBindings) do
        if desired[key] == nil or not nodeOpen(binding.node) then
            destroyTransport(binding);
            self.transportBindings[key] = nil;
        end
    end
    for key, node in pairs(desired) do
        if self.transportBindings[key] == nil then
            local binding = {node = node, active = true, receivers = {}};
            local function live()
                return not self.destroyed and binding.active
                    and self.transportBindings[key] == binding and nodeOpen(binding.node);
            end
            local function listen(messageId, handler)
                local ok, receiver = pcall(ndb.newBroadcastListener, node, messageId,
                    function(sender, _, payload) if live() then handler(sender, payload); end end);
                if not ok or receiver == nil then return false; end
                binding.receivers[#binding.receivers + 1] = receiver;
                return true;
            end
            local ready = listen(REQUEST, function(sender, payload) self:_receiveRequest(sender, payload); end)
                and listen(REPLY, function(sender, payload) self:_receiveReply(sender, payload); end)
                and listen(PRESENCE, function(sender, payload)
                    if type(payload) ~= "table" or not isMaster(playerFor(self.room, sender)) then return; end
                    self.masterPeers[login(sender)] = payload.alive == true and os.time() + 6 or nil;
                end);
            if ready then
                self.transportBindings[key] = binding;
                self.nextPresence = 0;
            else destroyTransport(binding); end
        end
    end
end

function Store:_sendRequest(payload, onResult)
    self:_ensureBranch();
    self:_bindTransport();
    if self:_leader() == nil or (isMaster(myPlayer(self.room)) and os.time() - self.startedAt < 2) then
        callback(onResult,false,"Aguardando o mestre conectar o Chat Avançado. Tente novamente em alguns instantes.");
        return false;
    end
    if next(self.transportBindings) == nil then
        callback(onResult, false, "Não foi possível alcançar o mestre. Abra o tracker e confira a conexão.");
        return false;
    end
    self.pending[payload.opId] = {payload = payload, callback = onResult, attempts = 1, startedAt = os.time(), lastSent = os.time()};
    if self:_isLeader() then
        -- Master-local broadcasts use loopBack=false, so dispatch with native local identity.
        self:_receiveRequest(self.userLogin, payload);
        local request = self.handled[login(self.userLogin) .. ":" .. payload.opId];
        if request ~= nil and not request.pending and self.pending[payload.opId] ~= nil then
            self.pending[payload.opId] = nil;
            callback(onResult, request.success, request.reason);
        end
        return true;
    end
    if not self:_broadcast(REQUEST, payload) then
        self.pending[payload.opId] = nil;
        callback(onResult, false, "Não foi possível enviar o pedido ao mestre. Confira a conexão.");
        return false;
    end
    return true;
end

function Store:mutate(entry, action, data, onResult)
    if self.destroyed then callback(onResult, false, "O Chat Avançado foi fechado."); return false; end
    data = type(data) == "table" and copy(data) or {};
    data.scope = data.scope or "private";
    local allowed, reason = self:can(entry, action, data.scope, data.correctionId);
    if not allowed then callback(onResult, false, reason); return false; end
    local opId = uniqueId();
    if data.scope == "private" then
        local success, failure = self:_apply(entry, action, data, myPlayer(self.room), opId);
        callback(onResult, success, failure);
        return success;
    end
    -- Only identifiers and proposed metadata cross the public transport. Neither the
    -- supplied author, original text, dice values nor a client snapshot is trusted.
    return self:_sendRequest({opId = opId, action = action, data = data,
        reference = {key = entry.key, id = entry.id, tid = entry.tid,
            medium = copy(entry.medium), timestamp = copy(entry.timestamp)}}, onResult);
end

function Store:updateSettings(settings, onResult)
    if self.destroyed or not isMaster(myPlayer(self.room)) then
        callback(onResult, false, "Somente o mestre pode mudar estas permissões.");
        return false;
    end
    return self:_sendRequest({opId = uniqueId(), action = "settings", settings = normalizeSettings(settings)}, onResult);
end

function Store:observe(entry)
    if self.destroyed or entry == nil or not validId(entry.key) then return; end
    self:_ensureBranch();
    local changedPrivate = false;
    -- Ordinary chat records have no annotations or pins. Do not clone the
    -- entire metadata database just to discover there is nothing to update.
    if self.private.messages[entry.key] ~= nil then
        local private = copy(self.private);
        local record = private.messages[entry.key];
        if entry.deleted == true then private.messages[entry.key] = nil; changedPrivate = true;
        else
            local ok, snapshot = pcall(model.snapshot, entry);
            if ok and type(snapshot) == "table" then
                local old = encode(record.entry);
                if old ~= encode(snapshot) then record.entry = snapshot; changedPrivate = true; end
            end
        end
        if changedPrivate then private.revision = private.revision + 1; self:_savePrivate(private); end
    end
    if self:_isLeader() then
        self:_loadShared();
        if self.shared.messages[entry.key] ~= nil then
            local shared = copy(self.shared);
            local sharedRecord = shared.messages[entry.key];
            if entry.deleted == true or entry.public ~= true then
                -- Remove the complete snapshot and its annotations after deletion or
                -- a visibility change; previously public content must not linger in pins.
                shared.messages[entry.key] = nil;
                shared.revision = shared.revision + 1;
                self:_saveShared(shared);
            else
                local ok, snapshot = pcall(model.snapshot, entry);
                if ok and type(snapshot) == "table" and encode(sharedRecord.entry) ~= encode(snapshot) then
                    sharedRecord.entry = snapshot;
                    shared.revision = shared.revision + 1;
                    self:_saveShared(shared);
                end
            end
        end
    end
end

function Store:_tick()
    if self.destroyed then return; end
    self:_ensureBranch();
    self:_bindTransport();
    local now = os.time();
    if isMaster(myPlayer(self.room)) and now >= (self.nextPresence or 0) then
        self:_broadcast(PRESENCE,{alive=true});
        self.nextPresence=now + 2;
    end
    if self:_isLeader() and self.sharedNode ~= nil and now >= (self.nextPermissionRefresh or 0) then
        self:_secure(self.sharedNode);
        self.nextPermissionRefresh=now + 10;
    end
    for opId, pending in pairs(self.pending) do
        if now - pending.startedAt >= REQUEST_TIMEOUT then
            self.pending[opId] = nil;
            callback(pending.callback, false, "O mestre não confirmou o pedido. Ele precisa manter o tracker ou o Chat Avançado aberto.");
        elseif self:_isLeader() then
            local result = self.handled[login(self.userLogin) .. ":" .. opId];
            if result ~= nil and not result.pending then
                self.pending[opId] = nil;
                callback(pending.callback, result.success, result.reason);
            end
        elseif not pending.acknowledged and pending.attempts < 3 and now - pending.lastSent >= 2 then
            pending.attempts = pending.attempts + 1;
            pending.lastSent = now;
            self:_broadcast(REQUEST, pending.payload);
        end
    end
    if self:_isLeader() then
        for key, request in pairs(self.handled) do
            if request.pending and now - request.startedAt >= REQUEST_TIMEOUT then
                request.pending = false;
                request.success = false;
                request.reason = "A consulta da mensagem original excedeu o tempo limite.";
                self.handledOrder[#self.handledOrder + 1] = key;
            end
        end
    end
end

function Store:destroy()
    if self.destroyed then return; end
    if isMaster(myPlayer(self.room)) then self:_broadcast(PRESENCE,{alive=false}); end
    self.destroyed = true;
    if self.timer ~= nil then clearInterval(self.timer); self.timer = nil; end
    destroyObserver(self.sharedObserver);
    destroyObserver(self.rootObserver);
    for _, binding in pairs(self.transportBindings or {}) do destroyTransport(binding); end
    for _, pending in pairs(self.pending) do callback(pending.callback, false, "O Chat Avançado foi fechado."); end
    self.pending = {};
    self.handled = {};
    self.sharedObserver = nil;
    self.rootObserver = nil;
    self.transportBindings = {};
end

function M.create(options)
    options = options or {};
    local self = setmetatable({room = options.room, root = options.root, resolve = options.resolve,
        onChange = options.onChange, onStatus = options.onStatus, private = newData(), shared = newData(),
        pending = {}, handled = {}, handledOrder = {}, masterPeers={}, transportBindings={}, startedAt=os.time()}, Store);
    local player = myPlayer(self.room);
    local currentUser;
    local userOk, user = pcall(rrpg.getCurrentUser);
    if userOk then currentUser = user; end
    self.userLogin = property(player, "login") or property(currentUser, "login") or "";
    local roomId = property(self.room, "codigoInterno") or property(self.room, "id") or "";
    if trim(self.userLogin) ~= "" and tostring(roomId) ~= "" then
        self.privateFile = "/newTracker-chat-" .. hex(login(self.userLogin)) .. "-" .. hex(roomId) .. ".xml";
        local loaded, node = pcall(ndb.load, self.privateFile);
        if loaded then self.privateNode = node; self.private = decode(property(node, "data")); end
    end
    self:_ensureBranch();
    if self.root ~= nil then
        local ok, observer = pcall(ndb.newObserver, self.root);
        if ok and observer ~= nil then
            self.rootObserver = observer;
            observer:addEventListener("onChildAdded", function() self:_ensureBranch(); self:_bindTransport(); end);
            observer:addEventListener("onStateChanged", function() self:_ensureBranch(); self:_bindTransport(); end);
        end
    end
    self:_bindTransport();
    self:_openCloud();
    self.timer = setInterval(function() self:_tick(); end, 1000);
    return self;
end

return M;

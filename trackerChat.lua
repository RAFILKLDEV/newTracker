-- Additional client for Firecast's native chat. Original records are never edited.
local rrpg = require("rrpg.lua");
local ndb = require("ndb.lua");
local gui = require("gui.lua");
local dialogs = require("dialogs.lua");
local System = require("system.lua");
local Model = require("trackerChatModel.lua");
local Store = require("trackerChatStore.lua");
local View = require("trackerChatView.lua");
local Floating = require("trackerChatFloating.lua");
local Commands = require("trackerChatCommands.lua");
local Async = require("async.lua");

local M = {};
local sessions = {};
local attached = setmetatable({}, {__mode = "k"});
local dockAttached = setmetatable({}, {__mode = "k"});
local historyCaches, historyCacheOrder = {}, {};
local listeners = {};
local toolButton;
local globalsStarted=false;
local render, requestRender, release, openSession, context, ensure;

local function property(object, field)
    if object == nil then return nil; end
    local ok, value = pcall(function() return object[field]; end);
    return ok and value or nil;
end

local function roomKey(room)
    return tostring(property(room, "codigoInterno") or "");
end

local function userLogin(room)
    local value=property(property(room,"meuJogador"),"login");
    if value == nil then
        local ok,user=pcall(rrpg.getCurrentUser);
        if ok then value=property(user,"login"); end
    end
    return tostring(value or ""):lower();
end

local function chatKey(chat)
    local medium = property(chat, "medium");
    local key = medium ~= nil and Model.mediumKey(medium) or nil;
    if key ~= nil then return key; end
    return "local-chat:" .. tostring(property(chat, "handle") or chat);
end

local function status(session, message)
    session.statusText = tostring(message or "");
    for _, view in pairs(session.views or {}) do view:status(session.statusText); end
end

local function failure(session, reason)
    local text = tostring(reason or "Não foi possível concluir a operação.");
    status(session, text);
    dialogs.alert(text);
end

local function thenDo(promise, success, failed)
    if promise == nil or property(promise, "thenDo") == nil then
        failed("Esta versão do Firecast não oferece a operação solicitada.");
        return;
    end
    local ok, reason = pcall(function() promise:thenDo(success, failed); end);
    if not ok then failed(reason); end
end

-- readLogRecs returns the complete locally loaded log. Keep plain source
-- snapshots so an unchanged poll does not normalize, copy and serialize every
-- historical message again. Compare values, not raw table identity: Firecast
-- can mutate a LogRec (including visibility/deletion) in place.
local recordFields={"id","tid","medium","timestamp","entity","visibility",
    "_visible","_storable","isDeleted"};
local messageFields={"msgType","content","talemarkOptions","impersonation",
    "fileName","fileURL","fileMimeType","fileSize","responsible","propertyId",
    "oldValue","newValue","joinType","leaveType"};
local rollFields={"tipo","asString","resultado","isRolado","ops"};

local function plainValue(value)
    local kind=type(value);
    if kind == "string" or kind == "boolean" then return value; end
    if kind == "number" and value == value and value ~= math.huge and value ~= -math.huge then
        return value;
    end
    return nil;
end

local function plainKey(key)
    return type(key) == "string" or (type(key) == "number" and plainValue(key) ~= nil);
end

local function copySource(value, seen, depth)
    if type(value) ~= "table" then return plainValue(value); end
    depth=depth or 0;
    seen=seen or {};
    if depth >= 24 or seen[value] then return nil; end
    seen[value]=true;
    local result={};
    for key, item in pairs(value) do
        if plainKey(key) then result[key]=copySource(item,seen,depth+1); end
    end
    seen[value]=nil;
    return result;
end

local function sameSource(value, snapshot, seen, depth)
    if type(value) ~= "table" then return plainValue(value) == snapshot; end
    depth=depth or 0;
    if depth >= 24 or seen[value] then return snapshot == nil; end
    if type(snapshot) ~= "table" then return false; end
    seen[value]=true;
    for key, item in pairs(value) do
        if plainKey(key) and not sameSource(item,snapshot[key],seen,depth+1) then
            seen[value]=nil; return false;
        end
    end
    for key in pairs(snapshot) do
        if value[key] == nil then seen[value]=nil; return false; end
    end
    seen[value]=nil;
    return true;
end

local function sourceSnapshot(record)
    local result={record={},message={},roll={}};
    for _, field in ipairs(recordFields) do result.record[field]=copySource(record[field]); end
    local msg=type(record.msg) == "table" and record.msg or nil;
    result.hasMessage=msg ~= nil;
    if msg ~= nil then
        for _, field in ipairs(messageFields) do result.message[field]=copySource(msg[field]); end
        result.hasRoll=msg.roll ~= nil;
        if result.hasRoll then
            for _, field in ipairs(rollFields) do result.roll[field]=copySource(property(msg.roll,field)); end
        end
    end
    return result;
end

local function sourceUnchanged(record, snapshot, seen)
    if type(record) ~= "table" then return false; end
    for _, field in ipairs(recordFields) do
        if not sameSource(record[field],snapshot.record[field],seen) then return false; end
    end
    local msg=type(record.msg) == "table" and record.msg or nil;
    if (msg ~= nil) ~= snapshot.hasMessage then return false; end
    if msg ~= nil then
        for _, field in ipairs(messageFields) do
            if not sameSource(msg[field],snapshot.message[field],seen) then return false; end
        end
        if (msg.roll ~= nil) ~= snapshot.hasRoll then return false; end
        if snapshot.hasRoll then
            for _, field in ipairs(rollFields) do
                if not sameSource(property(msg.roll,field),snapshot.roll[field],seen) then return false; end
            end
        end
    end
    return true;
end

local function ordered(holder)
    if holder.orderedEntries ~= nil then return holder.orderedEntries; end
    local result = {};
    for _, entry in pairs(holder.entries) do result[#result + 1] = entry; end
    table.sort(result, function(a, b)
        if a.epoch ~= b.epoch then return (a.epoch or 0) < (b.epoch or 0); end
        if a.tid ~= b.tid then return tostring(a.tid or "") < tostring(b.tid or ""); end
        return a.key < b.key;
    end);
    holder.orderedEntries=result;
    return result;
end

local function displayable(holder)
    if holder.displayEntries ~= nil then return holder.displayEntries; end
    local entries, indices={}, {};
    for _, entry in ipairs(ordered(holder)) do
        if Model.isDisplayable(entry) then
            entries[#entries+1]=entry; indices[entry.key]=#entries;
        end
    end
    holder.displayEntries=entries; holder.displayIndices=indices;
    return entries;
end

local function visibleWindow(holder)
    if holder.windowEntries ~= nil then return holder.windowEntries; end
    local entries=displayable(holder);
    local first=holder.windowFirstKey and holder.displayIndices[holder.windowFirstKey];
    if first == nil then first=math.max(1,#entries-math.max(100,holder.shownCount or 100)+1); end
    local result={};
    for i=first,#entries do result[#result+1]=entries[i]; end
    holder.windowFirstKey=entries[first] and entries[first].key or nil;
    holder.windowStart=first; holder.shownCount=#result;
    holder.windowEntries=result;
    return result;
end

local function merge(session, holder, records)
    local changed, visibleChanged = false, false;
    local occurrences = {};
    holder.sources=holder.sources or {};
    holder.fingerprints=holder.fingerprints or {};
    holder.comparisonSeen=holder.comparisonSeen or {};
    for _, record in ipairs(records or {}) do
        local keyOk, key=pcall(Model.key,record);
        if not keyOk then key=nil; end
        local unchanged=false;
        if keyOk and key ~= nil and holder.sources[key] ~= nil then
            local compared, same=pcall(sourceUnchanged,record,holder.sources[key],holder.comparisonSeen);
            unchanged=compared and same;
            if not compared then holder.comparisonSeen={}; end
        end
        if not unchanged then
          local ok, entry = pcall(Model.normalize, record, session.room);
          if ok then
            if entry ~= nil then
                local fingerprint=Model.fingerprint(entry);
                if entry.key == nil then
                    -- Local/system records have no server identity. These keys
                    -- are used only in this client's view and particular data.
                    local first, second = 0, 17;
                    for i=1,#fingerprint do
                        local byte=string.byte(fingerprint, i);
                        first=(first * 131 + byte) % 2147483647;
                        second=(second * 137 + byte) % 2147483629;
                    end
                    local localId=tostring(first) .. ":" .. tostring(second);
                    occurrences[localId]=(occurrences[localId] or 0) + 1;
                    entry.key="local:" .. holder.key .. ":" .. localId .. ":" .. occurrences[localId];
                end
                -- IDs come from LogRec. Local records have local-only keys.
                local previous=holder.entries[entry.key];
                local previousFingerprint=holder.fingerprints[entry.key];
                if previous ~= nil and previousFingerprint == nil then previousFingerprint=Model.fingerprint(previous); end
                if previous == nil or previousFingerprint ~= fingerprint then
                    holder.entries[entry.key] = entry;
                    holder.fingerprints[entry.key]=fingerprint;
                    if session.stateCache ~= nil then session.stateCache[entry.key]=nil; end
                    changed = true;
                    if Model.isDisplayable(entry) or (previous ~= nil and Model.isDisplayable(previous)) then
                        visibleChanged=true;
                    end
                    if session.store ~= nil then session.store:observe(entry); end
                elseif previous ~= nil then
                    -- Keep the most recent native object for original-record access.
                    previous.raw=record;
                    holder.fingerprints[entry.key]=previousFingerprint;
                end
            elseif key ~= nil then
                local previous=holder.entries[key];
                if previous ~= nil then
                    visibleChanged=visibleChanged or Model.isDisplayable(previous);
                    holder.entries[key]=nil; holder.fingerprints[key]=nil; changed=true;
                    if session.stateCache ~= nil then session.stateCache[key]=nil; end
                end
                if session.detailsMeta ~= nil and session.detailsMeta.entry.key == key then
                    if session.detailsView ~= nil then session.detailsView:close(); end
                    session.detailsMeta=nil; session.refreshDetails=nil;
                end
                if session.store ~= nil then
                    session.store:observe({key=key, id=record.id, tid=record.tid,
                        medium=record.medium, deleted=true, public=false});
                end
            end
            if key ~= nil then
                local snapshotOk, snapshot=pcall(sourceSnapshot,record);
                if snapshotOk then holder.sources[key]=snapshot; end
            end
          end
        end
    end
    if changed then
        holder.orderedEntries=nil;
        if visibleChanged then
            holder.displayEntries=nil; holder.displayIndices=nil; holder.windowEntries=nil;
        end
        -- Internal transport/property updates still participate in pagination and
        -- metadata cleanup, but do not repaint an unrelated visible conversation.
        local detailsChanged=session.detailsMeta ~= nil
            and session.detailsMeta.entry.mediumKey == holder.key;
        if (holder == session.current and visibleChanged) or detailsChanged then requestRender(session); end
    end
    return changed;
end

local function readLocal(session, holder)
    local ok, records = pcall(function() return holder.chat:readLogRecs(); end);
    if ok and type(records) == "table" then
        merge(session, holder, records);
    elseif not holder.warned then
        holder.warned = true;
        status(session, "Não foi possível ler o histórico local. Confira a versão e a conexão do Firecast.");
    end
end

local function chatName(chat, index)
    local medium = property(chat, "medium") or {};
    if medium.kind == "room" then return "Mesa"; end
    local names = {};
    for _, player in ipairs(property(chat, "participants") or {}) do
        names[#names + 1] = tostring(property(player, "nick") or property(player, "login") or "");
    end
    if #names > 0 then return "Privado: " .. table.concat(names, ", "); end
    if medium.kind == "roomChannel" then return "Canal: " .. tostring(medium.channelId or index); end
    return "Conversa " .. tostring(index);
end

local function addChat(session, chat)
    if chat == nil then return nil; end
    local medium = property(chat, "medium");
    if type(medium) == "table" and medium.kind ~= "room" then return nil; end
    if chat ~= property(session.room, "chat") and (type(medium) ~= "table" or medium.kind ~= "room") then return nil; end
    local key = chatKey(chat);
    local holder = session.byChat[key];
    if holder ~= nil then holder.chat = chat; return holder; end
    for _, candidate in ipairs(session.chats) do
        if candidate.chat == chat or (property(chat,"handle") ~= nil
            and property(candidate.chat,"handle") == property(chat,"handle")) then
            session.byChat[candidate.key]=nil;
            candidate.key=key; candidate.chat=chat; candidate.name=chatName(chat,1);
            session.byChat[key]=candidate; session.chatsChanged=true;
            return candidate;
        end
    end
    holder = {key=key, chat=chat, entries={}, name=chatName(chat, #session.chats + 1)};
    session.chats[#session.chats + 1] = holder;
    session.byChat[key] = holder;
    if session.current == nil then session.current = holder; end
    session.chatsChanged = true;
    return holder;
end

local function discover(session)
    local holder = addChat(session, property(session.room, "chat"));
    if holder ~= nil then session.current = holder; end
    session.chatsChanged = false;
end

local function query(session, holder, older)
    if holder == nil or holder.loading or (older and holder.bof) then return; end
    local params = {limit=50};
    if older then
        for _, entry in ipairs(ordered(holder)) do
            if entry.stable then params.tid = entry.tid; break; end
        end
    end
    local fetchingLatest=params.tid == nil;
    holder.loading = true;
    status(session, "Carregando histórico…");
    local ok, promise = pcall(function() return holder.chat:asyncQueryLogRecs(params); end);
    local function failed(reason)
        holder.loading = false;
        if fetchingLatest then holder.queried=false; end
        if session.closed then return; end
        status(session, "Histórico do servidor indisponível: " .. tostring(reason)
            .. ". As mensagens carregadas pelo Firecast continuam disponíveis.");
    end
    if not ok then failed(promise); return; end
    thenDo(promise, function(response)
        holder.loading = false;
        if session.closed then return; end
        if type(response) ~= "table" then failed("Resposta inválida"); return; end
        if fetchingLatest then holder.queried=true; end
        holder.bof = response.bof == true;
        merge(session, holder, response.logRecs);
        if older then
            -- The earlier cached range was exhausted before this query. Reveal
            -- its new page immediately without mounting the entire native log.
            local shown=#visibleWindow(holder);
            holder.windowFirstKey=nil;
            holder.shownCount=shown+50;
            holder.windowEntries=nil;
            requestRender(session);
        end
        status(session, holder.bof and "Início do histórico carregado." or "Chat conectado ao Firecast.");
    end, failed);
end

local function history(session)
    local holder=session.current;
    if holder == nil or holder.loading then return; end
    visibleWindow(holder);
    if (holder.windowStart or 1) > 1 then
        local first=math.max(1,holder.windowStart-50);
        holder.windowFirstKey=displayable(holder)[first].key;
        holder.windowEntries=nil;
        render(session);
        status(session,"Mensagens anteriores carregadas do histórico local.");
        return;
    end
    query(session,holder,true);
end

-- Master resolves the real record, never a player's supplied content or author.
local function resolve(session, reference, done)
    discover(session);
    local holder = session.byChat[Model.mediumKey(reference.medium or {})];
    if holder == nil then done(nil, "Conversa original não está disponível para o mestre."); return; end
    readLocal(session, holder);
    local entry = holder.entries[reference.key];
    if entry ~= nil then done(entry); return; end
    if type(reference.timestamp) ~= "table" then
        done(nil, "A mensagem original precisa ser carregada pelo mestre."); return;
    end
    local ok, promise = pcall(function()
        return holder.chat:asyncQueryLogRecs({limit=50, timestamp=reference.timestamp});
    end);
    if not ok then done(nil, "Não foi possível verificar a mensagem original."); return; end
    thenDo(promise, function(response)
        if session.closed then done(nil, "Sessão encerrada."); return; end
        merge(session, holder, type(response) == "table" and response.logRecs or {});
        local original = holder.entries[reference.key];
        if original == nil or original.id ~= reference.id or original.tid ~= reference.tid then
            done(nil, "O mestre não encontrou a mensagem original. Carregue esse trecho do histórico.");
        else done(original); end
    end, function(reason) done(nil, "Falha ao verificar o original: " .. tostring(reason)); end);
end

local function makeStore(session, root)
    if session.store ~= nil then session.store:destroy(); end
    session.root = root;
    session.metadataRevision=(session.metadataRevision or 0)+1;
    session.stateCache={};
    session.store = Store.create({room=session.room, root=root,
        resolve=function(reference, done) resolve(session, reference, done); end,
        onChange=function()
            if session.closed then return; end
            session.metadataRevision=(session.metadataRevision or 0)+1;
            session.stateCache={};
            session.metadataPending=true;
            requestRender(session);
        end,
        onStatus=function(message) if not session.closed then status(session, message); end end});
end

local function state(session, entry)
    if session.store ~= nil then
        session.stateCache=session.stateCache or {};
        local cached=session.stateCache[entry.key];
        if cached ~= nil and cached.entry == entry then
            cached.value.rollOrder = session.rollOrders and session.rollOrders[entry.key];
            return cached.value;
        end
        local value=session.store:get(entry);
        value.rollOrder = session.rollOrders and session.rollOrders[entry.key];
        session.stateCache[entry.key]={entry=entry,value=value};
        return value;
    end
    return {result=entry.roll and entry.roll.result, delta=0, corrected=false, corrections={}, audit={}, notes={},
        rollOrder=session.rollOrders and session.rollOrders[entry.key]};
end

local function reconcileMetadata(session)
    if not session.metadataPending or session.store == nil then return; end
    session.metadataPending=false;
    local store=session.store;
    local keys={};
    for _, data in ipairs({store.private,store.shared}) do
        if type(data) == "table" then
            for key in pairs(data.messages or {}) do keys[key]=true; end
        end
    end
    for key in pairs(keys) do
        for _, holder in ipairs(session.chats) do
            local entry=holder.entries[key];
            local source=holder.sources and holder.sources[key];
            if entry ~= nil or source ~= nil then
                local private=store.private and store.private.messages[key];
                local shared=store.shared and store.shared.messages[key];
                local needsRefresh=entry == nil or entry.deleted == true or (shared ~= nil and entry.public ~= true);
                if not needsRefresh then
                    local expected=holder.fingerprints and holder.fingerprints[key] or Model.fingerprint(entry);
                    for _, record in pairs({private=private,shared=shared}) do
                        local ok, actual=pcall(Model.fingerprint,record.entry);
                        if not ok or actual ~= expected then needsRefresh=true; break; end
                    end
                end
                if needsRefresh and (private ~= nil or shared ~= nil) then
                    if entry ~= nil then store:observe(entry);
                    else
                        -- Metadata may arrive asynchronously after a hidden
                        -- record was captured. Purge only a known tombstone;
                        -- absence from the locally loaded log is not deletion.
                        store:observe({key=key,id=source.record.id,tid=source.record.tid,
                            medium=source.record.medium,deleted=true,public=false});
                    end
                end
                break;
            end
        end
    end
end

requestRender = function(session)
    if session.closed or session.renderPending ~= nil then return; end
    local token={};
    session.renderPending=token;
    setTimeout(function()
        if session.closed or session.renderPending ~= token then return; end
        session.renderPending=nil;
        render(session);
    end,1);
end;

render = function(session)
    if session.closed then return; end
    -- An explicit user action can satisfy a render already queued by the native
    -- event and metadata observers. The old callback then becomes a no-op.
    session.renderPending=nil;
    reconcileMetadata(session);
    session.canConfigure=property(property(session.room,"meuJogador"),"isMestre") == true;
    if session.current ~= nil then
        local holder=session.current;
        local entries=visibleWindow(holder);
        for _, view in pairs(session.views or {}) do
            view:render(entries,function(entry) return state(session,entry); end,holder.key,
                {latest=holder.latestPending == true});
        end
        holder.latestPending=false;
    end
    if session.pins ~= nil and session.store ~= nil and (session.pinsRendered ~= session.pins
        or session.pinsRevision ~= session.metadataRevision or session.pinsAvatarRevision ~= session.avatarRevision
        or session.pinsOrderRevision ~= session.rollOrderRevision) then
        local pins = session.store:listPins();
        for _, pin in ipairs(pins) do
            if pin.state ~= nil and pin.entry ~= nil then
                pin.state.rollOrder = session.rollOrders and session.rollOrders[pin.entry.key];
            end
        end
        session.pins:render(pins);
        session.pinsRendered=session.pins; session.pinsRevision=session.metadataRevision;
        session.pinsAvatarRevision=session.avatarRevision;
        session.pinsOrderRevision=session.rollOrderRevision;
    end
    if session.refreshDetails ~= nil and session.detailsMeta ~= nil then
        local reference=session.detailsMeta;
        local holder=session.byChat[reference.entry.mediumKey];
        local current=holder and holder.entries[reference.entry.key] or reference.entry;
        if current ~= reference.entry or reference.revision ~= session.metadataRevision then session.refreshDetails(); end
    end
end;

local function mutate(session, entry, action, data)
    if session.closed or session.store == nil then return; end
    session.store:mutate(entry, action, data, function(ok, reason)
        if session.closed then return; end
        if ok then status(session, "Alteração salva."); render(session); else failure(session, reason); end
    end);
end

local function chooseScope(session, entry, action, callback)
    local scopes, labels = {}, {};
    for _, scope in ipairs({"shared", "private"}) do
        local allowed = session.store:can(entry, action, scope);
        if allowed then
            scopes[#scopes + 1] = scope;
            labels[#labels + 1] = scope == "shared" and "Compartilhada com a mesa" or "Particular (somente você)";
        end
    end
    if #scopes == 0 then
        local _, reason = session.store:can(entry, action, "private");
        failure(session, reason); return;
    end
    dialogs.choose("Visibilidade", labels, function(ok, index)
        if ok and not session.closed then callback(scopes[index]); end
    end, 1, true);
end

local function correction(session, entry, old)
    local function prompt(scope)
        dialogs.inputQuery(old and "Editar correção" or "Corrigir rolagem", "Modificador (+2, -3):",
            old and tostring(old.delta) or "", function(value)
                if session.closed then return; end
                local delta = tonumber(tostring(value):gsub(",", "."));
                if delta == nil or delta ~= delta or math.abs(delta) > 1000000 then
                    failure(session, "Informe um modificador numérico entre -1000000 e 1000000."); return;
                end
                dialogs.inputQuery("Motivo", "Por que o resultado deve ser corrigido?", old and old.reason or "",
                    function(reason)
                        mutate(session, entry, old and "edit" or "correct",
                            {scope=scope, delta=delta, reason=reason, correctionId=old and old.id});
                    end, nil, true);
            end);
    end
    if old ~= nil then prompt(old.scope); else chooseScope(session, entry, "correct", prompt); end
end

local function selectCorrection(session, entry, action)
    local options, labels = {}, {};
    for _, item in ipairs(state(session, entry).corrections or {}) do
        if session.store:can(entry, action, item.scope, item.id) then
            options[#options + 1] = item;
            labels[#labels + 1] = (item.delta >= 0 and "+" or "") .. tostring(item.delta)
                .. " — " .. tostring(item.reason or "") .. " (" .. tostring(item.author or item.authorLogin or "") .. ")";
        end
    end
    if #options == 0 then failure(session, "Nenhuma correção ativa que você possa alterar."); return; end
    dialogs.choose(action == "edit" and "Editar correção" or "Desfazer correção", labels,
        function(ok, index)
            if not ok or session.closed then return; end
            local item = options[index];
            if action == "edit" then correction(session, entry, item);
            else mutate(session, entry, "undo", {scope=item.scope, correctionId=item.id}); end
        end, 1, true);
end

local function details(session, entry, original)
    local info = state(session, entry);
    local lines = {Model.plainText(entry, info, original == true)};
    if entry.authorLogin ~= nil then lines[#lines + 1] = "\nAutor real: " .. entry.authorLogin; end
    if original ~= true then
        if entry.roll ~= nil then
            lines[#lines + 1]="\nResultado original: " .. tostring(entry.roll.result or "?");
            lines[#lines + 1]="Modificador total: " .. tostring(info.delta or 0);
            lines[#lines + 1]="Resultado exibido: " .. tostring(info.result or "?");
        end
        for _, item in ipairs(info.audit or {}) do
            local time = tonumber(item.time);
            lines[#lines + 1] = "\n" .. tostring(item.action or "correção") .. " — "
                .. tostring(item.author or item.authorLogin or "")
                .. (time and " — " .. os.date("%d/%m/%Y %H:%M:%S", time) or "")
                .. (item.delta and " — " .. tostring(item.delta) or "")
                .. (item.reason and " — " .. item.reason or "")
                .. (item.previousDelta and "\nAnterior: " .. tostring(item.previousDelta) .. " — " .. tostring(item.previousReason or "") or "")
                .. (item.text and "\n" .. item.text or "");
        end
        for _, note in ipairs(info.notes or {}) do
            lines[#lines + 1] = "\nObservação (" .. tostring(note.scope or "") .. ") — "
                .. tostring(note.author or note.authorLogin or "") .. ": " .. tostring(note.text or "")
                .. (note.time and " — " .. os.date("%d/%m/%Y %H:%M:%S", note.time) or "");
        end
    end
    local text=table.concat(lines,"\n");
    if session.detailsView ~= nil and session.detailsView:isOpen() then session.detailsView:update(text);
    else session.detailsView=View.details(text,original == true and "Mensagem original" or "Detalhes e histórico"); end
    session.detailsMeta={entry=entry,original=original,revision=session.metadataRevision};
    session.refreshDetails=function()
        if session.detailsView == nil or not session.detailsView:isOpen() then
            session.refreshDetails=nil; session.detailsMeta=nil; return;
        end
        local reference=session.detailsMeta;
        local holder=session.byChat[reference.entry.mediumKey];
        local current=holder and holder.entries[reference.entry.key] or reference.entry;
        details(session,current,reference.original);
    end;
end

local function popupMenu(session, choices)
    if session.menu ~= nil then pcall(gui.closePopup, session.menu); end
    if session.detailsView ~= nil then session.detailsView:close(); end
    local popup = gui.newPopupForm();
    popup._cardMargin = 2;
    popup.width = 284; popup.height = #choices * 32 + 6;
    popup.drawContainer = false;
    pcall(function() popup.backOpacity = 0; end);
    popup.cancelable = true; popup.resizable = false; popup.movable = false; popup.hitTest = false;
    popup.placement = "mouse";
    popup._dynamicCtrls = {};
    local card = gui.newRectangle();
    card.parent=popup; card.align="none"; card.left=2; card.top=2;
    card.width=280; card.height=#choices * 32 + 2;
    card.color="#20252B"; card.hitTest=false;
    popup._fixedSizeCard=card;
    popup._dynamicCtrls[#popup._dynamicCtrls + 1] = card;
    for i, choice in ipairs(choices) do
        local button = gui.newButton();
        button.parent=card; button.align="none"; button.left=2; button.top=2+(i-1)*32;
        button.width=276; button.height=30; button.text=choice.text; button.hitTest=true;
        button.enabled = choice.enabled ~= false;
        button.onClick=function() gui.closePopup(popup); choice.run(); end;
        popup._dynamicCtrls[#popup._dynamicCtrls + 1] = button;
    end
    session.menu = popup;
    gui.showPopup(popup, {placement="mouse", onClose=function()
        if session.menu == popup then session.menu=nil; end
        pcall(function() popup:destroy(); end);
    end});
end

context = function(session, entry)
    if session.store == nil or entry.deleted then return; end
    local info = state(session, entry);
    local choices = {{text="📌 Fixar mensagem", run=function()
        chooseScope(session, entry, "pin", function(scope) mutate(session, entry, "pin", {scope=scope}); end);
    end}};
    for _, scope in ipairs({"private", "shared"}) do
        local pinned = scope == "private" and info.ownPin or scope == "shared" and info.sharedPin;
        if pinned then
            choices[#choices + 1] = {text="Desafixar " .. (scope == "private" and "particular" or "compartilhada"),
                enabled=session.store:can(entry, "unpin", scope),
                run=function() mutate(session, entry, "unpin", {scope=scope}); end};
        end
    end
    if entry.roll ~= nil and entry.roll.compatible then
        local ownAllowed=session.store:can(entry, "correct", "private");
        local sharedAllowed=session.store:can(entry, "correct", "shared");
        choices[#choices + 1] = {text="✏ Corrigir rolagem", enabled=ownAllowed or sharedAllowed,
            run=function() correction(session, entry); end};
    end
    choices[#choices + 1] = {text="📝 Adicionar observação", run=function()
        chooseScope(session, entry, "note", function(scope)
            dialogs.inputQuery("Observação", "Texto da observação:", "", function(text)
                mutate(session, entry, "note", {scope=scope, text=text});
            end);
        end);
    end};
    choices[#choices + 1] = {text="Copiar mensagem", run=function()
        System.setClipboardText(Model.plainText(entry, info, false));
    end};
    choices[#choices + 1] = {text="Visualizar original", run=function() details(session, entry, true); end};
    choices[#choices + 1] = {text="Detalhes e histórico", run=function() details(session, entry, false); end};
    if #(info.corrections or {}) > 0 then
        choices[#choices + 1] = {text="Editar correção", run=function() selectCorrection(session, entry, "edit"); end};
        choices[#choices + 1] = {text="Desfazer correção", run=function() selectCorrection(session, entry, "undo"); end};
    end
    popupMenu(session, choices);
end;

local function openPins(session)
    if session.pins ~= nil and session.pins:isOpen() then session.pins:show(); render(session); return; end
    session.pins = Floating.open(session, {
        onClose=function() session.pins=nil; release(session); end,
        onUnpin=function(pin) mutate(session, pin.entry, "unpin", {scope=pin.scope}); end,
        onContext=function(entry) context(session, entry); end,
        onDetails=function(entry) details(session, entry, false); end});
    render(session);
end

local function settings(session)
    if property(property(session.room, "meuJogador"), "isMestre") ~= true then
        failure(session, "Somente o mestre pode mudar as permissões do Chat Avançado.");
        return;
    end
    local current = session.store:getSettings();
    dialogs.choose("Permissões do Chat Avançado", {
        "Correções de terceiros: " .. (current.allowThirdParty and "permitidas" or "bloqueadas"),
        "Criar fixações compartilhadas: " .. (current.pinCreate == "masters" and "mestres" or "jogadores e mestres"),
        "Remover fixações compartilhadas: " .. tostring(current.pinRemove)}, function(ok, index)
            if not ok or session.closed then return; end
            local function save()
                session.store:updateSettings(current, function(saved, reason)
                    if not saved then failure(session, reason); else status(session, "Permissões salvas."); end
                end);
            end
            if index == 1 then current.allowThirdParty=not current.allowThirdParty; save();
            elseif index == 2 then current.pinCreate=current.pinCreate == "masters" and "players" or "masters"; save();
            else
                dialogs.choose("Quem pode remover fixações compartilhadas?", {"Criador e mestres", "Somente mestres", "Todos os jogadores"},
                    function(confirmed, selected)
                        if confirmed and not session.closed then current.pinRemove=({"creator", "masters", "players"})[selected]; save(); end
                    end, 1);
            end
        end, 1);
end

local function rememberInput(session, text)
    if type(text) ~= "string" or text:match("^%s*$") then return nil; end
    session.inputSubmissions = session.inputSubmissions or {};
    session.inputSequence = (session.inputSequence or 0) + 1;
    local item = {text = text, epoch = os.time(), sequence = session.inputSequence};
    session.inputSubmissions[#session.inputSubmissions + 1] = item;
    if #session.inputSubmissions > 200 then table.remove(session.inputSubmissions, 1); end
    session.inputHistoryRevision = (session.inputHistoryRevision or 0) + 1;
    return item;
end

local function inputHistory(session)
    local holder = session.current;
    if holder == nil then return {}; end
    local entries = ordered(holder);
    if session.inputHistorySource == entries and session.inputHistoryCachedRevision == session.inputHistoryRevision then
        return session.inputHistoryCache or {};
    end
    local candidates, keys = {}, {};
    for index = #entries, 1, -1 do
        local entry = entries[index];
        local own = session.userLogin ~= "" and tostring(entry.authorLogin or ""):lower() == session.userLogin;
        local plain = Model.stripCodes(entry.content or "");
        local generated = session.generatedMessageKeys and session.generatedMessageKeys[entry.key];
        local turnNotice = plain:match("^[%s>%-]*Turno de%s") ~= nil;
        if own and not generated and not turnNotice and not entry.deleted
            and (entry.kind == "standard" or entry.kind == "action")
            and tostring(entry.content or ""):find("%S") ~= nil then
            keys[entry.key] = true;
            candidates[#candidates + 1] = {text = entry.content, epoch = entry.epoch or 0, sequence = index};
            if #candidates >= 200 then break; end
        end
    end
    for index, item in ipairs(session.inputSubmissions or {}) do
        if item.key == nil or (not keys[item.key] and holder.entries[item.key] ~= nil and not holder.entries[item.key].deleted) then
            candidates[#candidates + 1] = {text = item.text, epoch = item.epoch, sequence = #entries + index};
        end
    end
    table.sort(candidates, function(a, b)
        if a.epoch ~= b.epoch then return a.epoch > b.epoch; end
        return a.sequence > b.sequence;
    end);
    local result = {};
    for _, item in ipairs(candidates) do
        if result[#result] ~= item.text then result[#result + 1] = item.text; end
        if #result >= 200 then break; end
    end
    session.inputHistorySource, session.inputHistoryCachedRevision = entries, session.inputHistoryRevision;
    session.inputHistoryCache = result;
    return result;
end

local function messageParams(chat, mode, options, npcName)
    local native = property(chat, "talemarkOptions");
    local merged = {};
    for key, value in pairs(type(native) == "table" and native or {}) do merged[key] = value; end
    for key, value in pairs(type(options) == "table" and options or {}) do
        if key ~= "defaultTextStyle" then merged[key] = value; end
    end
    if type(options) == "table" and type(options.defaultTextStyle) == "table" then
        local style = {};
        for key, value in pairs(type(merged.defaultTextStyle) == "table" and merged.defaultTextStyle or {}) do style[key] = value; end
        for key, value in pairs(options.defaultTextStyle) do style[key] = value; end
        merged.defaultTextStyle = style;
    end
    local impersonation = {mode = "none"};
    if mode == "narrative" then impersonation = {mode = "narrator"};
    elseif mode == "npc" then
        local current = property(chat, "impersonation");
        impersonation = {mode = "character", name = tostring(npcName or "")};
        if property(current, "mode") == "character" and property(current, "name") == impersonation.name then
            impersonation.avatar = property(current, "avatar");
        end
    end
    return {impersonation = impersonation, talemarkOptions = merged};
end

local function send(session, text, mode, options, npcName)
    if Commands.dispatch(text,session) then rememberInput(session, text); return true; end
    local holder = session.current;
    if holder == nil or tostring(text or ""):match("^%s*$") then return false; end
    if holder.sending then status(session,"Aguardando a confirmação da mensagem anterior…"); return false; end
    if tostring(text):match("^%s*/") then
        local ok, reason = pcall(function() holder.chat:enviarMensagem(text); end);
        if not ok then failure(session, reason); return false; end
        rememberInput(session, text);
        status(session, "Comando enviado ao Firecast."); return true;
    end
    local params = messageParams(holder.chat, mode, options, npcName);
    if mode == "npc" and tostring(npcName or ""):match("^%s*$") then
        dialogs.inputQuery("Mensagem de personagem", "Nome do NPC/personagem:", session.npcName or "",
            function(name)
                if session.closed then return; end
                session.npcName=name;
                session.pendingNPC={mode="character", name=name};
                send(session, text, "npcConfirmed", options, name);
            end);
        return false;
    elseif mode == "npcConfirmed" then params.impersonation=session.pendingNPC; end
    holder.sending=true;
    local submission = rememberInput(session, text);
    local ok, promise=pcall(function()
        if mode == "action" then return holder.chat:asyncSendAction(text, params); end
        return holder.chat:asyncSendStd(text, params);
    end);
    if not ok then holder.sending=false; failure(session, promise); return false; end
    thenDo(promise, function(record)
        holder.sending=false;
        if not session.closed then
            if submission ~= nil then
                submission.key = Model.key(record);
                submission.epoch = Model.timestampToEpoch(property(record, "timestamp")) or submission.epoch;
                session.inputHistoryRevision = (session.inputHistoryRevision or 0) + 1;
            end
            merge(session, holder, {record}); status(session, "Mensagem enviada.");
            for _, view in pairs(session.views) do view:clearInput(text,holder.key); end
        end
    end, function(reason) holder.sending=false; if not session.closed then failure(session, reason); end end);
    return false; -- Keep the draft until the native server confirms delivery.
end

local function roll(session, expression, caption, options, mode, npcName, settings, done)
    local holder=session.current;
    settings = type(settings) == "table" and settings or {};
    if session.rollBusy then
        local message = "Aguarde a conclusão da rolagem anterior.";
        status(session,message);
        if type(done) == "function" then done(false,message); end
        return false;
    end
    local completed = false;
    local function finish(ok, message)
        if completed then return; end
        completed = true;
        session.rollBusy = false;
        if type(done) == "function" then done(ok, message); end
    end
    local function failed(reason)
        if completed then return; end
        local ok,callbackError = pcall(finish,false,tostring(reason));
        if not ok then reason = tostring(reason) .. "\n" .. tostring(callbackError); end
        if not session.closed then failure(session, reason); end
    end
    if holder == nil or tostring(expression or ""):match("^%s*$") then
        failed("O chat da mesa não está disponível."); return false;
    end
    local params = messageParams(holder.chat, mode, options, npcName);
    local comparison = settings.mode == "advantage" or settings.mode == "disadvantage";
    local title = settings.mode == "advantage" and "Vantagem" or "Desvantagem";
    local results = {};
    local historySaved = false;
    local function rememberRoll(record)
        if not historySaved then
            rememberInput(session, "/r " .. expression);
            historySaved = true;
        end
        local key = Model.key(record);
        if key ~= nil and (settings.order == "asc" or settings.order == "desc") then
            session.rollOrders = session.rollOrders or {};
            session.rollOrders[key] = settings.order;
            session.rollOrderRevision = (session.rollOrderRevision or 0) + 1;
            if session.stateCache ~= nil then session.stateCache[key] = nil; end
            -- The native receive event may have merged this same record before
            -- its Promise resolves. An unchanged merge still needs this repaint.
            requestRender(session);
        end
        merge(session, holder, {record});
    end
    -- Keep both dice requests and the summary in one awaited execution. A
    -- callback's processing error belongs to its returned Promise, not to the
    -- original request's failure callback. Observe that whole execution too.
    session.rollBusy = true;
    local publishedCount = 0;
    local ok, execution = pcall(Async.execute,function()
        for index=1,(comparison and 2 or 1) do
            if session.closed then finish(false, "O chat foi fechado."); return; end
            local description = tostring(caption or "");
            if comparison then
                description = (description ~= "" and description .. " — " or "") .. title .. " " .. tostring(index) .. "/2";
            end
            local promise = holder.chat:asyncRoll(expression,description,params);
            if promise == nil then error("O Firecast não retornou a confirmação da rolagem."); end
            local succeeded,result,rolled,record = Async.pawait(promise);
            if not succeeded then error(tostring(result)); end
            publishedCount = index;
            if session.closed then finish(false,"O chat foi fechado."); return; end
            if type(record) ~= "table" and type(result) == "table" and result.msg ~= nil then record = result; end
            if type(result) ~= "number" then
                result = property(rolled,"resultado") or property(property(property(record,"msg"),"roll"),"resultado");
            end
            if type(result) ~= "number" or result ~= result or math.abs(result) == math.huge then
                error("O Firecast não retornou um total numérico válido.");
            end
            rememberRoll(record);
            results[index] = result;
        end
        if not comparison then
            status(session,"Rolagem enviada."); finish(true,"Resultado: " .. tostring(results[1])); return;
        end
        local selected;
        if settings.mode == "advantage" then selected = math.max(results[1],results[2]);
        else selected = math.min(results[1],results[2]); end
        local text = title .. ": " .. tostring(results[1]) .. " / " .. tostring(results[2])
            .. " → escolhido " .. tostring(selected);
        if tostring(caption or "") ~= "" then text = tostring(caption) .. " — " .. text; end
        local promise = holder.chat:asyncSendStd(text,params);
        if promise == nil then error("O Firecast não retornou a confirmação do resumo."); end
        local succeeded,record = Async.pawait(promise);
        if not succeeded then error(tostring(record)); end
        if session.closed then finish(false,"O chat foi fechado."); return; end
        session.generatedMessageKeys = session.generatedMessageKeys or {};
        local key = Model.key(record);
        if key ~= nil then session.generatedMessageKeys[key] = true; end
        session.inputHistoryRevision = (session.inputHistoryRevision or 0)+1;
        merge(session,holder,{record}); status(session,"Rolagem enviada."); finish(true,text);
    end);
    local function executionFailed(reason)
        local prefix = comparison and publishedCount==2 and "As duas rolagens já foram enviadas; o resumo não foi concluído: "
            or comparison and publishedCount==1 and "A primeira rolagem já foi enviada; a operação não foi concluída: "
            or "Não foi possível concluir a rolagem: ";
        failed(prefix .. tostring(reason));
    end
    if not ok then executionFailed(execution); return false; end
    thenDo(execution,function() end,executionFailed);
    return true;
end

local function viewCallbacks(session)
    local function attention(open)
        if session.root == nil then
            failure(session, "Abra o Tracker da iniciativa nesta mesa para usar a Atenção."); return;
        end
        local main = require("trackerMain.lua");
        if open then main.openAttention(session.root); else main.requestAttention(session.root); end
    end
    return {
        onInputHistory=function() return inputHistory(session); end,
        onHistory=function() history(session); end,
        onLatest=function()
            if session.current ~= nil then session.current.latestPending=true; render(session); end
        end,
        onSend=function(text,mode,options,npcName) return send(session,text,mode,options,npcName); end,
        onRoll=function(expression,caption,options,mode,npcName,settings,done)
            return roll(session,expression,caption,options,mode,npcName,settings,done);
        end,
        onContext=function(entry) context(session,entry); end,
        onPins=function() openPins(session); end,
        onSettings=function() settings(session); end,
        onAttention=function() attention(false); end,
        onOpenAttention=function() attention(true); end,
        onDetails=function(entry) details(session,entry,false); end
    };
end

local function loadCurrent(session)
    if session.current == nil then return; end
    readLocal(session,session.current);
    if not session.current.queried then
        session.current.queried=true;
        query(session,session.current,false);
    end
end

openSession = function(session, chat)
    if chat ~= nil then session.current=addChat(session, chat); end
    discover(session);
    if session.view ~= nil and session.view:isOpen() then
        if session.current ~= nil then session.current.latestPending=true; end
        session.view:focus(); render(session); loadCurrent(session);
    else
        dialogs.showMessage("O Chat Avançado agora é uma janela acoplável da mesa. "
            .. "Abra \"Chat Avançado\" no menu de janelas acopláveis do Firecast.");
    end
end;

local function stopGlobals()
    if next(sessions) ~= nil then return; end
    for _, id in ipairs(listeners) do pcall(rrpg.Messaging.unlisten, id); end
    listeners={};
    globalsStarted=false;
    Commands.stop();
    if toolButton ~= nil then pcall(rrpg.unregisterChatToolButton, toolButton); toolButton=nil; end
end

release = function(session)
    if next(session.views) ~= nil or session.pins ~= nil or next(session.forms) ~= nil then return; end
    session.closed=true;
    if session.interval ~= nil then clearInterval(session.interval); end
    if session.menu ~= nil then pcall(gui.closePopup, session.menu); end
    if session.detailsView ~= nil then session.detailsView:close(); end
    if session.store ~= nil then session.store:destroy(); end
    -- Keep history data, not live windows/listeners. Reopening a dock in this
    -- room reuses successfully queried pages instead of downloading them again.
    historyCaches[session.key]={chats=session.chats,currentKey=session.current and session.current.key,
        userLogin=session.userLogin, inputSubmissions=session.inputSubmissions,
        inputSequence=session.inputSequence, generatedMessageKeys=session.generatedMessageKeys,
        rollOrders=session.rollOrders};
    for i=#historyCacheOrder,1,-1 do
        if historyCacheOrder[i] == session.key then table.remove(historyCacheOrder,i); end
    end
    historyCacheOrder[#historyCacheOrder + 1]=session.key;
    while #historyCacheOrder > 4 do historyCaches[table.remove(historyCacheOrder,1)]=nil; end
    sessions[session.key]=nil;
    stopGlobals();
end;

local function startGlobals()
    if globalsStarted then return; end
    globalsStarted=true;
    Commands.configure({
        resolve=function(message)
            local room=message.room or message.mesa or property(message.chat,"room");
            if room == nil then return nil; end
            return sessions[roomKey(room)] or ensure(nil,nil,room);
        end,
        nextTurn=function(session)
            -- The chat dock's own node is never an initiative root. Use the
            -- existing Tracker lifecycle so player authorization stays intact.
            if session.root == nil or next(session.forms) == nil then
                return false,"Abra o Tracker da iniciativa nesta mesa para usar />>.";
            end
            return require("trackerMain.lua").nextTurn(session.root);
        end,
        openPins=function(session) openPins(session); return true; end,
        onError=function(reason,session)
            if session ~= nil then failure(session,reason); else dialogs.alert(reason); end
        end
    });
    Commands.start();
    local function receive(event)
        if type(event) ~= "table" then return; end
        local chat=event.chat;
        local room=property(chat, "room");
        local medium=event.logRec and event.logRec.medium or property(chat, "medium");
        local key=room and roomKey(room) or tostring(medium and medium.roomId or "");
        local session=sessions[key];
        if session == nil or chat == nil then return; end
        local holder=addChat(session, chat);
        if holder == nil then return; end
        if event.logRec ~= nil then merge(session, holder, {event.logRec});
        else readLocal(session, holder); end
    end
    for _, name in ipairs({"ChatMessageEx", "ChatMessage"}) do
        local ok, id=pcall(rrpg.Messaging.listen, name, receive);
        if ok and id ~= nil then listeners[#listeners + 1]=id; end
    end
    local ok, handle=pcall(rrpg.registerChatToolButton, {
        icon="/newTracker-chat.png", hint="Chat Avançado do New Tracker", group="newTracker", priority=20,
        callback=function(chat)
            local session=sessions[roomKey(property(chat, "room"))];
            if session ~= nil then openSession(session, chat); end
        end});
    if ok then toolButton=handle; end
end

ensure = function(form, sheet, knownRoom)
    local ok, room=true,knownRoom;
    if room == nil then ok,room=pcall(rrpg.getMesaDe,sheet); end
    if not ok or room == nil or roomKey(room) == "" then return nil; end
    local key=roomKey(room);
    local session=sessions[key];
    -- Only callers with the initiative tracker sheet may establish this root.
    local root=sheet ~= nil and ndb.getRoot(sheet) or nil;
    if session == nil then
        session={key=key,room=room,userLogin=userLogin(room),name=property(room,"nome"),forms=setmetatable({}, {__mode="k"}),
            views=setmetatable({}, {__mode="k"}),chats={},byChat={}};
        local cache=historyCaches[key];
        if cache ~= nil and session.userLogin ~= "" and cache.userLogin == session.userLogin then
            session.inputSubmissions, session.inputSequence = cache.inputSubmissions, cache.inputSequence;
            session.generatedMessageKeys, session.rollOrders = cache.generatedMessageKeys, cache.rollOrders;
            for _, previous in ipairs(cache.chats) do
                if property(property(previous.chat, "medium"), "kind") == "room" then
                    local holder={key=previous.key,chat=previous.chat,name=previous.name,entries=previous.entries,
                        queried=previous.queried and not previous.loading,bof=previous.bof,
                        sources=previous.sources,fingerprints=previous.fingerprints,orderedEntries=previous.orderedEntries,
                        displayEntries=previous.displayEntries,displayIndices=previous.displayIndices,
                        windowEntries=previous.windowEntries,windowStart=previous.windowStart,
                        windowFirstKey=previous.windowFirstKey,shownCount=previous.shownCount};
                    session.chats[#session.chats + 1]=holder; session.byChat[holder.key]=holder;
                    if holder.key == cache.currentKey then session.current=holder; end
                end
            end
            session.current=session.current or session.chats[1];
        end
        sessions[key]=session;
        startGlobals(); -- Listen before the initial read/query.
        discover(session);
        makeStore(session, root);
        session.interval=setInterval(function()
            if session.closed then return; end
            discover(session);
            for _, holder in ipairs(session.chats) do readLocal(session, holder); end
            if Model.avatarRevision ~= nil then
                local revision=Model.avatarRevision(session.room);
                if session.avatarRevision ~= nil and session.avatarRevision ~= revision then requestRender(session); end
                session.avatarRevision=revision;
            end
            release(session);
        end, 1500);
    elseif session.root == nil and root ~= nil then makeStore(session, root); end
    if form ~= nil then session.forms[form]=true; attached[form]=session; end
    return session;
end;

function M.mount(form,sheet)
    if form == nil or sheet == nil then return; end
    local ok,room=pcall(rrpg.getMesaDe,sheet);
    if not ok or room == nil then return; end
    local existing=dockAttached[form];
    if existing ~= nil and (existing.key ~= roomKey(room) or existing.userLogin ~= userLogin(room)) then
        M.unmount(form); existing=nil;
    end
    if existing ~= nil and not existing.closed then
        existing.view=existing.views[form] or existing.view;
        local view=existing.views[form];
        if view ~= nil and view.setActive ~= nil then view:setActive(true); end
        -- onShow after an ordinary tab change keeps the same view, nodes,
        -- cached pages and scroll position. It does not query history.
        render(existing);
        return;
    end
    local session=ensure(nil,nil,room);
    if session == nil then return; end
    local view=View.mount(form,session,viewCallbacks(session));
    session.views[form]=view; session.view=view; dockAttached[form]=session;
    session.chatsChanged=true; discover(session);
    if session.current ~= nil then session.current.latestPending=true; end
    render(session); loadCurrent(session);
    status(session,session.statusText or "Chat conectado ao Firecast.");
end

function M.unmount(form)
    local session=dockAttached[form]; dockAttached[form]=nil;
    if session == nil then return; end
    local view=session.views[form]; session.views[form]=nil;
    if view ~= nil then view:dispose(); end
    if session.view == view then
        session.view=nil;
        for _, remaining in pairs(session.views) do session.view=remaining; break; end
    end
    release(session);
end

function M.hide(form)
    -- Firecast hides dock forms while switching tabs; that is not disposal.
    local session=dockAttached[form];
    local view=session and session.views[form];
    if view ~= nil and view.setActive ~= nil then view:setActive(false); end
end

function M.attach(form, sheet)
    if form == nil or sheet == nil then return; end
    local existing=attached[form];
    if existing ~= nil and not existing.closed and existing.root == ndb.getRoot(sheet) then return; end
    M.detach(form);
    ensure(form, sheet);
end

function M.detach(form)
    local session=attached[form];
    attached[form]=nil;
    if session ~= nil then session.forms[form]=nil; release(session); end
end

function M.open(form, sheet)
    local session=ensure(form, sheet);
    if session == nil then dialogs.alert("Não foi possível localizar o chat da mesa."); return; end
    openSession(session);
end

return M;

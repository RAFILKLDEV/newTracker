-- Plain chat records derived from the public Firecast SDK contracts.
-- This module never executes a roll or changes a received LogRec.
local M = {};

local function property(object, name)
    if object == nil then return nil; end
    local ok, value = pcall(function() return object[name]; end);
    return ok and value or nil;
end

local function finite(value)
    return type(value) == "number" and value == value
        and value ~= math.huge and value ~= -math.huge;
end

local function integer(value)
    return finite(value) and value == math.floor(value);
end

local function stringValue(value)
    return type(value) == "string" and value or "";
end

local function validId(value)
    return type(value) == "string" and value ~= "" and #value <= 2048
        and value:find("[%c]") == nil;
end

local function plainCopy(value, seen, depth)
    local kind = type(value);
    if kind == "string" or kind == "boolean" then return value; end
    if kind == "number" then return finite(value) and value or nil; end
    if kind ~= "table" then return nil; end
    depth = depth or 0;
    seen = seen or {};
    if depth >= 24 or seen[value] then return nil; end
    seen[value] = true;
    local copy = {};
    for key, item in pairs(value) do
        if type(key) == "string" or (type(key) == "number" and finite(key)) then
            local copied = plainCopy(item, seen, depth + 1);
            if copied ~= nil then copy[key] = copied; end
        end
    end
    seen[value] = nil;
    return copy;
end

local function part(value)
    local text = tostring(value or "");
    return tostring(#text) .. ":" .. text;
end

local function userId(value)
    return integer(value) and value > 0;
end

function M.mediumKey(medium)
    if type(medium) ~= "table" then return nil; end
    local kind = stringValue(medium.kind);
    if kind == "room" then
        if not userId(medium.roomId) then return nil; end
        return kind .. "|" .. part(medium.roomId);
    elseif kind == "direct" or kind == "pvtOnRoom" then
        if not userId(medium.user1) or not userId(medium.user2) then return nil; end
        if kind == "pvtOnRoom" and not userId(medium.roomId) then return nil; end
        return kind .. "|" .. part(medium.roomId) .. "|" .. part(medium.user1)
            .. "|" .. part(medium.user2);
    elseif kind == "groupPvtOnRoom" or kind == "roomChannel" then
        local identifier = kind == "groupPvtOnRoom" and medium.groupId or medium.channelId;
        if not userId(medium.roomId) or not validId(identifier) then return nil; end
        return kind .. "|" .. part(medium.roomId) .. "|" .. part(identifier);
    end
    return nil;
end

function M.key(logRec)
    if type(logRec) ~= "table" or not validId(logRec.id) or not validId(logRec.tid) then
        return nil;
    end
    local medium = M.mediumKey(logRec.medium);
    if medium == nil then return nil; end
    return medium .. "|" .. part(logRec.id) .. "|" .. part(logRec.tid);
end

local function daysInMonth(year, month)
    if month == 2 then
        local leap = year % 4 == 0 and (year % 100 ~= 0 or year % 400 == 0);
        return leap and 29 or 28;
    end
    return ({31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31})[month];
end

-- Convert UTC calendar components directly to Unix seconds. os.time(table)
-- is intentionally avoided because it interprets calendar values in local time.
function M.timestampToEpoch(timestamp)
    if type(timestamp) ~= "table" then return nil; end
    local year, month, day = timestamp.year, timestamp.month, timestamp.day;
    local hour, minute, second = timestamp.hour or 0, timestamp.min or 0, timestamp.sec or 0;
    local millisecond = timestamp.msec or 0;
    if not integer(year) or year < 1 or year > 9999
        or not integer(month) or month < 1 or month > 12
        or not integer(day) or day < 1 or day > daysInMonth(year, month)
        or not integer(hour) or hour < 0 or hour > 23
        or not integer(minute) or minute < 0 or minute > 59
        or not integer(second) or second < 0 or second > 59
        or not integer(millisecond) or millisecond < 0 or millisecond > 999 then
        return nil;
    end
    local adjustment = math.floor((14 - month) / 12);
    local calendarYear = year + 4800 - adjustment;
    local calendarMonth = month + 12 * adjustment - 3;
    local julianDay = day + math.floor((153 * calendarMonth + 2) / 5)
        + 365 * calendarYear + math.floor(calendarYear / 4)
        - math.floor(calendarYear / 100) + math.floor(calendarYear / 400) - 32045;
    return (julianDay - 2440588) * 86400 + hour * 3600 + minute * 60
        + second + millisecond / 1000;
end

local function timeText(timestamp, epoch)
    if epoch ~= nil then
        local ok, value = pcall(os.date, "%d/%m/%Y %H:%M:%S", math.floor(epoch));
        if ok and type(value) == "string" and value ~= "" then return value; end
        return string.format("%02d/%02d/%04d %02d:%02d:%02d UTC", timestamp.day,
            timestamp.month, timestamp.year, timestamp.hour or 0, timestamp.min or 0,
            timestamp.sec or 0);
    end
    return "Horário indisponível";
end

local function numberText(value)
    if not finite(value) then return "?"; end
    if integer(value) then return string.format("%.0f", value); end
    return string.format("%.12g", value);
end

local function rollSnapshot(source)
    if source == nil then return nil; end
    local result = property(source, "resultado");
    local roll = {
        type = stringValue(property(source, "tipo")),
        asString = stringValue(property(source, "asString")),
        result = finite(result) and result or nil,
        ops = {},
        compatible = false
    };
    local ops = property(source, "ops");
    local details, supported, haveTerm, expectTerm, leadingSign = {}, true, false, true, false;
    if type(ops) ~= "table" then supported = false; ops = {}; end
    for _, op in ipairs(ops) do
        local kind = stringValue(property(op, "tipo"));
        local copied = plainCopy(op) or {};
        copied.tipo = kind;
        if kind == "dado" then
            local quantity, face = property(op, "quantidade"), property(op, "face");
            copied.quantidade = finite(quantity) and quantity or nil;
            copied.face = (finite(face) or type(face) == "string") and face or nil;
            copied.resultados = {};
            local results = property(op, "resultados");
            local individual = {};
            if type(results) ~= "table" then supported = false; results = {}; end
            for _, value in ipairs(results) do
                if finite(value) then
                    copied.resultados[#copied.resultados + 1] = value;
                    individual[#individual + 1] = numberText(value);
                else
                    supported = false;
                    individual[#individual + 1] = "?";
                end
            end
            if not expectTerm or not integer(quantity) or quantity < 1
                or #copied.resultados ~= quantity or copied.face == nil then
                supported = false;
            end
            details[#details + 1] = numberText(quantity) .. "d" .. tostring(face or "?")
                .. " [" .. table.concat(individual, ", ") .. "]";
            haveTerm, expectTerm = true, false;
        elseif kind == "imediato" then
            local value = property(op, "valor");
            copied.valor = finite(value) and value or nil;
            if not expectTerm or copied.valor == nil then supported = false; end
            details[#details + 1] = numberText(value);
            haveTerm, expectTerm = true, false;
        elseif kind == "soma" or kind == "subtracao" then
            -- A leading sign is valid; consecutive operators are not.
            if expectTerm and (haveTerm or leadingSign) then supported = false; end
            if not haveTerm then leadingSign = true; end
            details[#details + 1] = kind == "soma" and " + " or " - ";
            expectTerm = true;
        else
            supported = false;
            local comparator = property(op, "comparacao");
            if type(comparator) == "string" then copied.comparacao = comparator; end
            details[#details + 1] = " {" .. (copied.comparacao or kind or "operação") .. "} ";
        end
        roll.ops[#roll.ops + 1] = copied;
    end
    roll.detail = table.concat(details);
    if roll.detail == "" then roll.detail = roll.asString; end
    roll.compatible = roll.type == "direta" and property(source, "isRolado") == true
        and roll.result ~= nil and supported and haveTerm and not expectTerm;
    return roll;
end

-- Resolve the current main character and profile from the room roster once
-- per interval, rather than invoking findJogador for every record,
-- and retain observed URLs so leaving the room does not erase historical faces.
-- These caches contain no chat text and never leave the current Lua process.
local avatarCaches = setmetatable({}, {__mode = "k"});
local AVATAR_REFRESH_SECONDS = 5;
local absentAvatarURLs = { ["0"] = true, ["nil"] = true, ["null"] = true,
    ["false"] = true, ["undefined"] = true };

local function avatarURL(value)
    local url = stringValue(value):gsub("^%s+", ""):gsub("%s+$", "");
    return absentAvatarURLs[url:lower()] and "" or url;
end

local function loginKey(login)
    return stringValue(login):lower();
end

local function playerAvatar(room, player)
    local code = tonumber(property(player, "personagemPrincipal"));
    local find = property(room, "findBibliotecaItem");
    if code ~= nil and code >= 0 and type(find) == "function" then
        local ok, character = pcall(find, room, code);
        if ok and property(character, "tipo") == "personagem" then
            local avatar = avatarURL(property(character, "avatar"));
            if avatar ~= "" then return avatar; end
        end
    end
    return avatarURL(property(player, "avatar"));
end

local function sameValues(first, second)
    for key, value in pairs(first) do if second[key] ~= value then return false; end end
    for key, value in pairs(second) do if first[key] ~= value then return false; end end
    return true;
end

local function avatarCache(room)
    if room == nil then return nil; end
    local cache = avatarCaches[room];
    if cache == nil then
        cache = {logins = {}, ids = {}, knownLogins = {}, knownIds = {}, misses = {}, revision = 0};
        avatarCaches[room] = cache;
    end
    local now = os.time();
    if cache.refreshedAt ~= nil and now >= cache.refreshedAt
        and now - cache.refreshedAt < AVATAR_REFRESH_SECONDS then return cache; end
    cache.refreshedAt = now;
    cache.misses = {};
    local players = property(room, "jogadores");
    if type(players) ~= "table" then return cache; end
    local logins, ids = {}, {};
    for _, player in ipairs(players) do
        local login = loginKey(property(player, "login"));
        local id = property(player, "id");
        local avatar = playerAvatar(room, player);
        if login ~= "" then
            logins[login] = avatar;
            -- An empty current avatar clears a previously observed profile
            -- image, while removing the player from the roster preserves it.
            cache.knownLogins[login] = avatar;
        end
        if userId(id) then ids[id] = avatar; cache.knownIds[id] = avatar; end
    end
    if not sameValues(cache.logins, logins) or not sameValues(cache.ids, ids) then
        cache.revision = cache.revision + 1;
    end
    cache.logins, cache.ids, cache.haveRoster = logins, ids, true;
    return cache;
end

local function avatarFor(room, login, id, receivedAvatar)
    local cache = avatarCache(room);
    local key = loginKey(login);
    local avatar;
    if cache ~= nil then
        if userId(id) then avatar = cache.ids[id]; end
        if avatar == nil and key ~= "" then avatar = cache.logins[key]; end
        if avatar ~= nil then return avatar, true; end
        if not cache.haveRoster and key ~= "" and not cache.misses[key] then
            cache.misses[key] = true;
            local findPlayer = property(room, "findJogador");
            if type(findPlayer) == "function" then
                local ok, player = pcall(findPlayer, room, login);
                if ok and player ~= nil then
                    avatar = playerAvatar(room, player);
                    cache.logins[key], cache.knownLogins[key] = avatar, avatar;
                    if userId(id) then cache.ids[id], cache.knownIds[id] = avatar, avatar; end
                    cache.revision = cache.revision + 1;
                    return avatar, true;
                end
            end
        end
        if userId(id) then avatar = cache.knownIds[id]; end
        if avatar == nil and key ~= "" then avatar = cache.knownLogins[key]; end
        if avatar ~= nil then return avatar, true; end
    end
    -- Entity does not require an avatar in the public schema. If a native
    -- record carries one, retain that supplied URL without inventing endpoints
    -- or replacing its real author identity with the displayed character name.
    avatar = avatarURL(receivedAvatar);
    if avatar ~= "" then
        if cache ~= nil then
            if key ~= "" then cache.knownLogins[key] = avatar; end
            if userId(id) then cache.knownIds[id] = avatar; end
            cache.revision = cache.revision + 1;
        end
        return avatar, true;
    end
    return "", false;
end

function M.avatarRevision(room)
    local cache = avatarCache(room);
    return cache ~= nil and cache.revision or 0;
end

function M.clearAvatarCache(room)
    if room ~= nil then avatarCaches[room] = nil;
    else avatarCaches = setmetatable({}, {__mode = "k"}); end
end

function M.avatarForEntry(entry, room)
    if type(entry) ~= "table" then return ""; end
    local impersonation = entry.impersonation;
    local mode = stringValue(property(impersonation, "mode"));
    if mode == "narrator" or mode == "character" then
        local avatar = avatarURL(property(impersonation, "avatar"));
        if avatar ~= "" then return avatar; end
    end
    local entity = property(entry.raw, "entity");
    local receivedAvatar = avatarURL(property(entity, "avatar"));
    if receivedAvatar == "" then receivedAvatar = avatarURL(entry.avatar); end
    local avatar, found = avatarFor(room, entry.authorLogin, entry.authorId,
        receivedAvatar);
    if found then return avatar; end
    -- Snapshots already shown or pinned may carry a known URL even after the
    -- roster wrapper has been released. Do not overwrite it with an empty one.
    return avatarURL(entry.avatar);
end

local function nonemptyArray(value)
    return type(value) == "table" and next(value) ~= nil;
end

function M.isPublic(entry)
    if type(entry) ~= "table" or entry.visible ~= true or entry.storable ~= true
        or entry.deleted == true or entry.stable ~= true or M.key(entry) == nil
        or type(entry.medium) ~= "table" or entry.medium.kind ~= "room" then
        return false;
    end
    local visibility = entry.visibility;
    if visibility ~= nil and type(visibility) ~= "table" then return false; end
    visibility = visibility or {};
    -- In standard mode the server's recipients array records who was present.
    -- It is not a private-recipient restriction; blacklist still restricts it.
    local mode = visibility.mode;
    return (mode == nil or mode == "standard")
        and not nonemptyArray(visibility.blacklist)
        and (visibility.blacklist == nil or type(visibility.blacklist) == "table")
        and (visibility.recipients == nil or type(visibility.recipients) == "table");
end

local hiddenKinds = {startTypingStatus = true, stopTypingStatus = true, signal = true};

function M.normalize(logRec, room)
    if type(logRec) ~= "table" or logRec._visible ~= true or type(logRec.msg) ~= "table" then
        return nil;
    end
    local msg, entity = logRec.msg, logRec.entity;
    local kind = stringValue(msg.msgType);
    if kind == "" or hiddenKinds[kind] then return nil; end
    entity = type(entity) == "table" and entity or {};
    local login = stringValue(entity.login);
    local impersonation = type(msg.impersonation) == "table" and msg.impersonation or {};
    local name = stringValue(entity.nick);
    if name == "" then name = login; end
    local narrator = name;
    local mode = stringValue(impersonation.mode);
    if mode == "narrator" then
        name = "Narrador" .. (narrator ~= "" and " — narrado por " .. narrator or "");
    elseif mode == "character" and stringValue(impersonation.name) ~= "" then
        name = impersonation.name .. (narrator ~= "" and " — narrado por " .. narrator or "");
    end
    local avatar = (mode == "narrator" or mode == "character")
        and avatarURL(impersonation.avatar) or "";
    if avatar == "" then avatar = avatarFor(room, login, entity.id, entity.avatar); end
    local epoch = M.timestampToEpoch(logRec.timestamp);
    local deleted = logRec.isDeleted == true;
    local entry = {
        key = M.key(logRec), id = stringValue(logRec.id), tid = stringValue(logRec.tid),
        medium = plainCopy(logRec.medium), mediumKey = M.mediumKey(logRec.medium),
        visible = true, storable = logRec._storable == true,
        visibility = plainCopy(logRec.visibility),
        deleted = deleted, authorLogin = login,
        authorId = userId(entity.id) and entity.id or nil,
        name = name ~= "" and name or "Firecast", avatar = avatar,
        epoch = epoch or 0, timestamp = plainCopy(logRec.timestamp),
        timeText = timeText(logRec.timestamp, epoch), kind = kind,
        content = deleted and "" or stringValue(msg.content),
        talemarkOptions = plainCopy(msg.talemarkOptions),
        impersonation = plainCopy(msg.impersonation),
        -- Keep the original only in memory. snapshot() excludes this reference.
        raw = logRec
    };
    entry.stable = entry.key ~= nil;
    entry.public = M.isPublic(entry);
    if not deleted then
        if kind == "dice" then entry.roll = rollSnapshot(msg.roll); end
        if kind == "file" then
            entry.fileName = stringValue(msg.fileName);
            entry.fileURL = stringValue(msg.fileURL);
            entry.fileMimeType = stringValue(msg.fileMimeType);
            entry.fileSize = finite(msg.fileSize) and msg.fileSize or nil;
        end
        entry.responsible = plainCopy(msg.responsible);
        entry.propertyId = plainCopy(msg.propertyId);
        entry.oldValue = plainCopy(msg.oldValue);
        entry.newValue = plainCopy(msg.newValue);
        entry.joinType = stringValue(msg.joinType);
        entry.leaveType = stringValue(msg.leaveType);
    end
    return entry;
end

local snapshotFields = {
    "key", "id", "tid", "mediumKey", "medium", "stable", "public", "visible", "storable",
    "visibility", "deleted", "authorLogin", "authorId", "name", "avatar", "epoch",
    "timestamp", "timeText", "kind", "content", "talemarkOptions", "impersonation", "roll",
    "fileName", "fileURL", "fileMimeType", "fileSize", "responsible", "propertyId",
    "oldValue", "newValue", "joinType", "leaveType"
};

function M.snapshot(entry)
    if type(entry) ~= "table" then return nil; end
    local copy = {};
    for _, field in ipairs(snapshotFields) do copy[field] = plainCopy(entry[field]); end
    if copy.deleted then
        copy.content, copy.roll = "", nil;
        copy.fileName, copy.fileURL, copy.fileMimeType, copy.fileSize = nil, nil, nil, nil;
        copy.oldValue, copy.newValue = nil, nil;
    end
    copy.public = M.isPublic(copy);
    return copy;
end

local function encode(value)
    local kind = type(value);
    if kind == "nil" then return "n"; end
    if kind == "boolean" then return value and "b1" or "b0"; end
    if kind == "number" then return "d" .. part(string.format("%.17g", value)); end
    if kind == "string" then return "s" .. part(value); end
    if kind ~= "table" then return "n"; end
    local fields = {};
    for key, item in pairs(value) do fields[#fields + 1] = {key = encode(key), value = encode(item)}; end
    table.sort(fields, function(first, second) return first.key < second.key; end);
    local parts = {"t", tostring(#fields), ":"};
    for _, field in ipairs(fields) do
        parts[#parts + 1] = part(field.key);
        parts[#parts + 1] = part(field.value);
    end
    return table.concat(parts);
end

function M.fingerprint(entry)
    -- Ignore a controller-assigned local key and all nonserializable handles.
    local snapshot = M.snapshot(entry);
    if snapshot == nil then return ""; end
    snapshot.key = nil;
    return encode(snapshot);
end

local function withoutChatCodes(value)
    local text = stringValue(value);
    return (text:gsub("%[Â§[^%]]*%]", ""):gsub("%[§[^%]]*%]", ""));
end

M.stripCodes = withoutChatCodes;

local SYSTEM_GREEN = "#78FF69";
local SYSTEM_BLUE = "#8585FF";
local systemPresentations = setmetatable({}, {__mode = "k"});
local modeDefinitions = {
    {key = "gm", label = "Mestre", aliases = {"gm", "master", "mestre"}},
    {key = "mute", label = "Mudo", aliases = {"mute", "mudo"}},
    {key = "voice", label = "Voz", aliases = {"voice", "voz"}},
    {key = "blind", label = "Cego", aliases = {"blind", "cego"}},
    {key = "player", label = "Jogador", aliases = {"player", "jogador"}},
    {key = "juggernaut", label = "Juggernaut", aliases = {"juggernaut"}}
};
local modeAliases = {};
for _, definition in ipairs(modeDefinitions) do
    for _, alias in ipairs(definition.aliases) do modeAliases[alias] = definition.key; end
end

local function modeSet(value)
    local result = {};
    local function include(name, enabled)
        local key = modeAliases[stringValue(name):lower()];
        if key ~= nil and enabled then result[key] = true; end
    end
    if type(value) == "table" then
        for key, item in pairs(value) do
            if type(key) == "number" and type(item) == "string" then
                include(item, true);
            elseif type(key) == "string" then
                include(key, item == true or item == 1 or item == "true");
            end
        end
    elseif type(value) == "string" then
        for sign, name in value:gmatch("([+-]?)([%a_]+)") do include(name, sign ~= "-"); end
    end
    return result;
end

local function segment(parts, text, color, bold, nickname)
    text = stringValue(text);
    if text == "" then return; end
    parts[#parts + 1] = {text = withoutChatCodes(text), color = color or SYSTEM_GREEN,
        bold = bold == true, nickname = nickname};
end

local function actorSegments(parts, entity, fallbackName, fallbackLogin)
    local login = stringValue(property(entity, "login"));
    if login == "" then login = stringValue(fallbackLogin); end
    local name = stringValue(property(entity, "nick"));
    if name == "" then name = stringValue(fallbackName); end
    if name == "" then name = login; end
    if name == "" then name = "Usuário"; end
    -- nickname retains native palette tags for the view's color resolver; text
    -- itself stays plain so no renderer shows the markup literally.
    segment(parts, name, SYSTEM_GREEN, false, name);
    if login ~= "" then segment(parts, " (" .. login .. ")"); end
end

local function targetSegments(parts, entry, includeLogin)
    local entity = property(entry.raw, "entity");
    local login = includeLogin and entry.authorLogin or "";
    if not includeLogin then entity = {nick = property(entity, "nick")}; end
    actorSegments(parts, entity, entry.name, login);
end

local function barChange(entry)
    local index, field = stringValue(entry.propertyId):match("^mainCharBar([0-3])(%a+)$");
    if index == nil or (field ~= "Val" and field ~= "Max")
        or not finite(entry.oldValue) or not finite(entry.newValue)
        or entry.oldValue == entry.newValue then return nil; end
    local delta = entry.newValue - entry.oldValue;
    if not finite(delta) then return nil; end
    local parts = {};
    segment(parts, "≡ ", "#AAAAAA");
    -- The public player API exposes values, not the room's configured bar
    -- captions. Never assume that a particular index means HP, mana or XP.
    -- Character bar0..bar3 are zero based; user-facing labels start at one.
    local caption = "Barra " .. tostring(tonumber(index) + 1);
    if field == "Max" then caption = "Máximo de " .. caption; end
    segment(parts, caption, SYSTEM_BLUE);
    segment(parts, " de ");
    targetSegments(parts, entry, false);
    segment(parts, ": " .. numberText(entry.oldValue)
        .. (delta < 0 and " - " or " + ") .. numberText(math.abs(delta))
        .. " = " .. numberText(entry.newValue));
    return parts;
end

local function modesChange(entry)
    local old, current = modeSet(entry.oldValue), modeSet(entry.newValue);
    local changes = {};
    for _, definition in ipairs(modeDefinitions) do
        if (old[definition.key] == true) ~= (current[definition.key] == true) then
            changes[#changes + 1] = {added = current[definition.key] == true,
                text = (current[definition.key] == true and "+" or "−") .. definition.label};
        end
    end
    if #changes == 0 then return nil; end
    local parts = {};
    local responsible = entry.responsible;
    if stringValue(property(responsible, "login")) ~= ""
        or stringValue(property(responsible, "nick")) ~= "" then
        actorSegments(parts, responsible);
        segment(parts, #changes > 1 and " alterou os modos "
            or changes[1].added and " colocou o modo " or " retirou o modo ");
    else
        segment(parts, #changes > 1 and "Modos " or "Modo ");
    end
    for index, change in ipairs(changes) do
        if index > 1 then segment(parts, ", "); end
        segment(parts, change.text, SYSTEM_GREEN, true);
    end
    segment(parts, " em ");
    targetSegments(parts, entry, true);
    return parts;
end

local function makeSystemSegments(entry)
    local kind = stringValue(entry.kind);
    if kind == "sys_userPresencePropertyChange" then
        if entry.propertyId == "modes" then return modesChange(entry); end
        return barChange(entry);
    elseif kind == "sys_mediumPropertyChange" then
        -- Room property records can contain passwords, tables and private
        -- configuration. No generic tostring() or property dump belongs here.
        return nil;
    end
    local parts, content = {}, stringValue(entry.content);
    if content:find("%S") ~= nil then
        segment(parts, content);
    elseif kind == "sys_userJoin" or kind == "sys_userLeave" then
        segment(parts, "🚪 ", "#D4B781");
        targetSegments(parts, entry, true);
        if kind == "sys_userJoin" then segment(parts, " entrou");
        elseif entry.leaveType == "kicked" then
            segment(parts, " foi removido do chat");
            local responsible = entry.responsible;
            if stringValue(property(responsible, "login")) ~= ""
                or stringValue(property(responsible, "nick")) ~= "" then
                segment(parts, " por "); actorSegments(parts, responsible);
            end
        else segment(parts, " saiu"); end
    elseif kind == "sys_mediumCreation" then segment(parts, "Conversa criada.");
    elseif kind == "sys_mediumDestruction" then segment(parts, "Conversa encerrada.");
    elseif kind:sub(1, 4) == "sys_" then segment(parts, "Notificação do Firecast.");
    else return nil; end
    return parts;
end

-- Segments are immutable presentation values, cached by the immutable entry.
-- They contain no native handles and never modify its snapshot or author IDs.
function M.systemSegments(entry)
    if type(entry) ~= "table" then return nil; end
    local cached = systemPresentations[entry];
    if cached ~= nil then return cached ~= false and cached or nil; end
    local segments = makeSystemSegments(entry);
    systemPresentations[entry] = segments or false;
    return segments;
end

-- Keep every native property record in the controller cache for IDs and
-- pagination. Only known, meaningful presence changes enter the visual list.
function M.isDisplayable(entry)
    if type(entry) ~= "table" then return false; end
    local kind = stringValue(entry.kind);
    if kind == "sys_mediumPropertyChange" or kind == "sys_userPresencePropertyChange" then
        return M.systemSegments(entry) ~= nil;
    end
    return true;
end

local rollPresentations = setmetatable({}, {__mode="k"});

function M.rollSegments(entry, state)
    local roll = type(entry) == "table" and entry.roll or nil;
    if type(roll) ~= "table" then return {}; end
    state = type(state) == "table" and state or {};
    local cacheKey = tostring(state.result) .. ":" .. tostring(state.delta) .. ":"
        .. tostring(state.corrected) .. ":" .. tostring(state.rollOrder);
    local cached = rollPresentations[entry];
    if cached ~= nil and cached.key == cacheKey then return cached.parts; end
    local parts, details = {}, {};
    local text = stringValue(roll.asString);
    if text == "" then text = stringValue(roll.detail); end
    local result = roll.result;
    local corrected = type(state) == "table" and state.corrected == true and roll.compatible == true;
    local delta = corrected and finite(state.delta) and state.delta or 0;
    if corrected then
        if delta ~= 0 then text = text .. (delta > 0 and " + " or " - ") .. numberText(math.abs(delta)); end
        if finite(state.result) then result = state.result; end
    end
    -- Like the native chat: expression = total {[dice], ... + modifier}.
    -- The server's total is authoritative, including Storyteller/comparisons.
    segment(parts, text, "#8585FF");
    segment(parts, " = ", "#BDBDBD");
    segment(parts, numberText(result), "#78FF69", true);
    for _, op in ipairs(roll.ops or {}) do
        if op.tipo == "dado" then
            local values = {};
            for i, value in ipairs(op.resultados or {}) do values[i] = value; end
            if type(state) == "table" and (state.rollOrder == "asc" or state.rollOrder == "desc") then
                table.sort(values, function(a,b) return state.rollOrder == "asc" and a < b or state.rollOrder == "desc" and a > b; end);
            end
            segment(details, "[", "#BDBDBD");
            for i, value in ipairs(values) do
                if i > 1 then segment(details, ", ", "#BDBDBD"); end
                local face = tonumber(op.face);
                local critical = face ~= nil and face > 1 and value == face;
                local minimum = face ~= nil and face > 1 and value == 1;
                segment(details, numberText(value), critical and "#78FF69" or minimum and "#FF7373" or "#BDBDBD", critical or minimum);
            end
            segment(details, "]", "#BDBDBD");
        elseif op.tipo == "imediato" then segment(details, numberText(op.valor), "#BDBDBD");
        elseif op.tipo == "soma" then segment(details, " + ", "#BDBDBD");
        elseif op.tipo == "subtracao" then segment(details, " - ", "#BDBDBD");
        elseif op.tipo == "comparacao" then segment(details, " " .. stringValue(op.comparacao) .. " ", "#BDBDBD");
        elseif op.tipo ~= "ordenacao" then segment(details, " {?}", "#BDBDBD"); end
    end
    if delta ~= 0 then segment(details, (delta > 0 and " + " or " - ") .. numberText(math.abs(delta)), "#BDBDBD"); end
    if #details > 0 then
        segment(parts, " {", "#BDBDBD");
        for _, item in ipairs(details) do parts[#parts + 1] = item; end
        segment(parts, "}", "#BDBDBD");
    end
    if corrected then segment(parts, " (Corrigida)", "#AEBECD"); end
    rollPresentations[entry] = {key=cacheKey,parts=parts};
    return parts;
end

function M.rollText(entry, state)
    local parts = {};
    for _, item in ipairs(M.rollSegments(entry, state)) do parts[#parts + 1] = item.text; end
    return table.concat(parts);
end

local function systemText(entry)
    local parts = {};
    for _, value in ipairs(M.systemSegments(entry) or {}) do parts[#parts + 1] = value.text; end
    if #parts > 0 then return table.concat(parts); end
    return "Configuração atualizada.";
end

function M.bodyText(entry, state, original)
    if type(entry) ~= "table" then return ""; end
    if entry.deleted == true then return "Mensagem excluída."; end
    local body = stringValue(entry.content);
    if entry.kind == "dice" then
        local displayedState = state;
        if original then displayedState = nil; end
        local dice = M.rollText(entry, displayedState);
        body = body ~= "" and body .. ": " .. dice or dice;
    elseif entry.kind == "laugh" then
        body = body ~= "" and body or "Hohohohoho";
    elseif entry.kind == "file" then
        local filename = stringValue(entry.fileName);
        if filename ~= "" then body = body ~= "" and body .. "\n" .. filename or filename; end
        local url = stringValue(entry.fileURL);
        if url ~= "" then body = body ~= "" and body .. "\n" .. url or url; end
    elseif stringValue(entry.kind):sub(1, 4) == "sys_" then
        body = systemText(entry);
    end
    local text = withoutChatCodes(body);
    if not original and type(state) == "table" and type(state.notes) == "table" then
        for _, note in ipairs(state.notes) do
            if type(note) == "table" and stringValue(note.text or note.content) ~= "" then
                local author = stringValue(note.authorLogin);
                text = text .. "\nObservação" .. (author ~= "" and " de " .. author or "")
                    .. ": " .. withoutChatCodes(note.text or note.content);
            end
        end
    end
    return text;
end

function M.plainText(entry, state, original)
    if type(entry) ~= "table" then return ""; end
    local body = M.bodyText(entry, state, original);
    if entry.deleted == true then return body; end
    local kind = stringValue(entry.kind);
    local prefix = "";
    if kind:sub(1, 4) ~= "sys_" then
        local name = withoutChatCodes(entry.name);
        prefix = kind == "action" and name .. " " or name .. ": ";
    end
    return "[" .. stringValue(entry.timeText) .. "] " .. prefix .. body;
end

return M;

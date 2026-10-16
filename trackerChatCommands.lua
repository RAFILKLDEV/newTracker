-- Local commands for the advanced composer and Firecast's command dispatcher.
-- HandleChatCommand is a local input event, not a received chat message.
-- SDK contract: https://firecast.app/sdk3/MensagensdeChat.html
local rrpg = require("rrpg.lua");
local dialogs = require("dialogs.lua");

local M = {};
local callbacks = {};
local listeners = {};
local started = false;

local function trim(value)
    return tostring(value or ""):match("^%s*(.-)%s*$");
end

local function recognized(command)
    return command == ">>" or command == "fixados";
end

local function report(reason, context)
    local text = tostring(reason or "Não foi possível executar o comando.");
    if type(callbacks.onError) == "function" then
        local ok = pcall(callbacks.onError, text, context);
        if ok then return; end
    end
    pcall(dialogs.alert, text);
end

local function execute(command, parameter, context)
    if not recognized(command) then return false; end
    if trim(parameter) ~= "" then
        report("Use /" .. command .. " sem parâmetros.", context);
        return true;
    end
    if context == nil then
        report("Abra o New Tracker ou o Chat Avançado desta mesa para usar /" .. command .. ".");
        return true;
    end
    local callback = command == ">>" and callbacks.nextTurn or callbacks.openPins;
    if type(callback) ~= "function" then
        report("O comando /" .. command .. " ainda não está disponível nesta mesa.", context);
        return true;
    end
    -- nextTurn must delegate to trackerMain.nextTurn with the initiative root.
    -- That module owns authorization and the authenticated master request.
    local ok, accepted, reason = pcall(callback, context);
    if not ok then
        report(accepted, context);
    elseif accepted == false then
        report(reason, context);
    end
    return true;
end

local function resolve(message)
    if type(callbacks.resolve) ~= "function" then return nil; end
    local ok, context = pcall(callbacks.resolve, message);
    if not ok then report(context); return nil; end
    return context;
end

local function handleCommand(message)
    if type(message) ~= "table" then return; end
    if type(message.response) == "table" and message.response.handled == true then return; end
    local command = string.lower(trim(message.command)):gsub("^/", "");
    if not recognized(command) then return; end
    -- A handled response suppresses native command errors and chat echo.
    -- Set it before the action, including when permission/context is missing.
    message.response = {handled = true};
    execute(command, message.parameter, resolve(message));
end

local function listCommands(message)
    if type(message) ~= "table" or resolve(message) == nil then return; end
    message.response = {
        {command = "/>>", description = "Passa o turno atual, respeitando as permissões da iniciativa."},
        {command = "/fixados", description = "Abre o painel independente de mensagens fixadas desta mesa."}
    };
end

function M.configure(options)
    if type(options) ~= "table"
        or type(options.resolve) ~= "function"
        or type(options.nextTurn) ~= "function"
        or type(options.openPins) ~= "function" then
        return false, "Comandos do chat precisam de resolve, nextTurn e openPins.";
    end
    callbacks = options;
    return true;
end

function M.start()
    if started then return true; end
    local ok, reason = pcall(function()
        local commandListener = rrpg.Messaging.listen("HandleChatCommand", handleCommand);
        if commandListener == nil then error("Não foi possível registrar os comandos do chat."); end
        listeners[#listeners + 1] = commandListener;
        local helpListener = rrpg.Messaging.listen("ListChatCommands", listCommands);
        if helpListener == nil then error("Não foi possível registrar a ajuda dos comandos do chat."); end
        listeners[#listeners + 1] = helpListener;
    end);
    if not ok then
        M.stop();
        return false, tostring(reason);
    end
    started = true;
    return true;
end

function M.stop()
    for _, listener in ipairs(listeners) do
        pcall(rrpg.Messaging.unlisten, listener);
    end
    listeners = {};
    started = false;
end

function M.dispatch(text, context)
    local command, parameter = trim(text):match("^/(%S+)%s*(.-)%s*$");
    if command == nil then return false; end
    return execute(string.lower(command), parameter, context);
end

return M;

local dialogs = require("dialogs.lua");
local gui = require("gui.lua");
local ndb = require("ndb.lua");
local trackerMain = require("trackerMain.lua");

local M = {};

local MAX_HISTORY = 8;

local function trimmed(value)
    return tostring(value or ""):gsub("^%s+", ""):gsub("%s+$", "");
end

local function getRoot(sheet)
    return ndb.getRoot(sheet);
end

local function getHistoryContainer(root)
    if root == nil then
        return nil;
    end

    local container = root.historicoTemporarios;

    if container == nil then
        container = ndb.createChildNode(root, "historicoTemporarios");
    end

    return container;
end

local function getHistoryEntries(root)
    local container = getHistoryContainer(root);

    if container == nil then
        return {};
    end

    local entries = ndb.getChildNodes(container);

    table.sort(entries,
        function(a, b)
            return (tonumber(a.ordemHistorico) or 0) > (tonumber(b.ordemHistorico) or 0);
        end);

    return entries;
end

local function trimHistory(root)
    local entries = getHistoryEntries(root);

    for i = MAX_HISTORY + 1, #entries, 1 do
        ndb.deleteNode(entries[i]);
    end
end

local function saveHistory(sheet, nome, quantidade)
    local root = getRoot(sheet);

    if root == nil then
        return;
    end

    trackerMain.ensureRootDefaults(root);

    local existing = nil;

    for _, entry in ipairs(getHistoryEntries(root)) do
        if trimmed(entry.nome or "") == nome and (tonumber(entry.quantidade) or 0) == quantidade then
            existing = entry;
            break;
        end
    end

    root.proximoHistoricoId = (tonumber(root.proximoHistoricoId) or 0) + 1;

    if existing == nil then
        local container = getHistoryContainer(root);
        existing = ndb.createChildNode(container, "item");
    end

    existing.nome = nome;
    existing.quantidade = quantidade;
    existing.ordemHistorico = root.proximoHistoricoId;

    trimHistory(root);
end

local function clearHistoryButtons(form)
    if form._historyCtrls == nil then
        form._historyCtrls = {};
        return;
    end

    for _, ctrl in ipairs(form._historyCtrls) do
        if ctrl ~= nil then
            ctrl:destroy();
        end
    end

    form._historyCtrls = {};
end

local function deleteHistoryEntry(form, sheet, entryNode)
    if entryNode == nil then
        return;
    end

    ndb.deleteNode(entryNode);
    M.populateHistory(form, sheet);
end

local function applyTemporary(form, sheet, nome, quantidade)
    local qtd = math.floor(tonumber(quantidade) or 0);
    local nomeLimpo = trimmed(nome);

    if nomeLimpo == "" then
        dialogs.alert("Preencha o nome do temporario.");
        return false;
    end

    if qtd <= 0 then
        dialogs.alert("Informe uma quantidade maior que zero.");
        return false;
    end

    trackerMain.addTemporary(sheet, nomeLimpo, qtd);
    saveHistory(sheet, nomeLimpo, qtd);
    return true;
end

function M.populateHistory(form, sheet)
    clearHistoryButtons(form);

    local root = getRoot(sheet);
    local entries = getHistoryEntries(root);

    form.lblHistorico.visible = (#entries > 0);
    form.sbxHistorico.visible = (#entries > 0);
    form.lblSemHistorico.visible = (#entries == 0);

    for _, entry in ipairs(entries) do
        local row = gui.newLayout();
        row.parent = form.sbxHistorico;
        row.align = "top";
        row.height = 28;
        row.margins = {bottom = 4};

        local btnDelete = gui.newButton();
        btnDelete.parent = row;
        btnDelete.align = "right";
        btnDelete.width = 26;
        btnDelete.text = "X";
        btnDelete.hint = "Excluir do historico";
        btnDelete.margins = {left = 4};
        btnDelete.onClick = function()
            deleteHistoryEntry(form, sheet, entry);
        end;

        local button = gui.newButton();
        button.parent = row;
        button.align = "client";
        button.text = string.format("%s (%s)", tostring(entry.nome or ""), tostring(entry.quantidade or 0));
        button.onClick = function()
            if applyTemporary(form, sheet, entry.nome, entry.quantidade) then
                form:close();
            end
        end;

        form._historyCtrls[#form._historyCtrls + 1] = row;
    end
end

function M.onNodeReady(form, sheet)
    form._historyCtrls = {};
    form.edtNome.text = "";
    form.edtQuantidade.text = "";

    M.populateHistory(form, sheet);
end

function M.onNodeUnready(form)
    clearHistoryButtons(form);
end

function M.apply(form, sheet, quantidade)
    if applyTemporary(form, sheet, form.edtNome.text, quantidade) then
        form:close();
    end
end

function M.applyCustom(form, sheet)
    M.apply(form, sheet, form.edtQuantidade.text);
end

return M;

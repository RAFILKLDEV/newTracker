local rrpg = require("rrpg.lua");
local dialogs = require("dialogs.lua");
local gui = require("gui.lua");
local ndb = require("ndb.lua");
local trackerMain = require("trackerMain.lua");

local M = {};

function M.configureItemMenu(popup, sheet)
    local root = ndb.getRoot(sheet);
    local canChangeVisibility = root ~= nil and trackerMain.isMaster(root)
        and not trackerMain.isGroupNode(sheet);
    local state = trackerMain.getVisibilityState(sheet);
    local visibilityButton = popup.btnVisibilidade;

    if visibilityButton ~= nil then
        visibilityButton.visible = canChangeVisibility;
        visibilityButton.fontSize = 12;
        visibilityButton.text = state == 0 and "Ocultar identidade"
            or (state == 1 and "Ocultar totalmente" or "Mostrar no tracker");
        visibilityButton.hint = state == 0 and "Visível"
            or (state == 1 and "Identidade oculta" or "Totalmente oculto");
    end

    local height = canChangeVisibility and 170 or 136;
    popup.width = 200;
    popup.height = height;
    gui.Control.setWidth(popup, 200);
    gui.Control.setHeight(popup, height);
end

function M.changeVisibility(popup, sheet)
    local root = ndb.getRoot(sheet);

    if root == nil or not trackerMain.isMaster(root) or trackerMain.isGroupNode(sheet) then
        return;
    end

    trackerMain.toggleItemVisibility(sheet);

    if popup.itemForm ~= nil then
        require("trackerItem.lua").updateVisual(popup.itemForm, sheet);
        trackerMain.redrawList(popup.itemForm);
    end

    popup:close();
end

function M.rollInitiative(popup, sheet)
    local formula = trackerMain.getInitiativeFormula(sheet);

    local mesa = rrpg.getMesaDe(sheet);

    if mesa == nil or mesa.chat == nil then
        dialogs.alert("Nao foi possivel localizar o chat da mesa.");
        return;
    end

    local nome = trackerMain.getPublicItemName(sheet);

    mesa.chat:rolarDados(formula, "Iniciativa de " .. nome,
        function(rolagem)
            if rolagem ~= nil then
                sheet.iniciativa = rolagem.resultado or 0;

                if popup ~= nil and popup.itemForm ~= nil then
                    trackerMain.redrawList(popup.itemForm);
                end
            end
        end);

    popup:close();
end

function M.openGroupMenu(popup, sheet)
    local root = ndb.getRoot(sheet);

    if root == nil then
        return;
    end

    local currentGroupId = tostring(sheet.grupoId or "");
    local availableGroups = {};

    for _, group in ipairs(trackerMain.getGroupHeaders(root)) do
        if tostring(group.grupoId or "") ~= currentGroupId then
            availableGroups[#availableGroups + 1] = group;
        end
    end

    local menu = gui.newPopupForm();
    menu.width = 190;
    menu.height = 72 + (#availableGroups * 34);
    menu.theme = "dark";
    menu.drawContainer = false;
    menu.cancelable = true;
    menu.resizable = false;
    menu.movable = false;
    menu.placement = "mouse";

    local layout = gui.newLayout();
    layout.parent = menu;
    layout.align = "client";

    local btnCreate = gui.newButton();
    btnCreate.parent = layout;
    btnCreate.align = "top";
    btnCreate.height = 30;
    btnCreate.text = "Criar grupo";
    btnCreate.margins = {bottom = 4};
    btnCreate.onClick = function()
        menu:close();
        popup:close();

        local group = trackerMain.createGroup(root);
        trackerMain.moveItemToGroup(sheet, group);

        if popup.itemForm ~= nil then
            trackerMain.redrawList(popup.itemForm);
        end
    end;

    local btnNoGroup = gui.newButton();
    btnNoGroup.parent = layout;
    btnNoGroup.align = "top";
    btnNoGroup.height = 30;
    btnNoGroup.text = "Sem grupo";
    btnNoGroup.margins = {bottom = 4};
    btnNoGroup.onClick = function()
        trackerMain.moveItemToGroup(sheet, nil);

        if popup.itemForm ~= nil then
            trackerMain.redrawList(popup.itemForm);
        end

        menu:close();
        popup:close();
    end;

    for _, group in ipairs(availableGroups) do
        local btnGroup = gui.newButton();
        btnGroup.parent = layout;
        btnGroup.align = "top";
        btnGroup.height = 30;
        btnGroup.text = tostring(group.nomeGrupo or "Grupo");
        btnGroup.margins = {bottom = 4};
        btnGroup.onClick = function()
            trackerMain.moveItemToGroup(sheet, group);

            if popup.itemForm ~= nil then
                trackerMain.redrawList(popup.itemForm);
            end

            menu:close();
            popup:close();
        end;
    end

    popup:close();
    gui.showPopup(menu, {placement = "mouse"});
end

function M.openTemporaryMenu(popup, sheet)
    local menu = gui.newPopupForm("frmTrackerTemporaryMenu");
    menu.scopeNode = sheet;
    popup:close();
    gui.showPopup(menu, {placement = "mouse"});
end

function M.openItemColorMenu(popup, sheet)
    popup:close();
    trackerMain.openItemColorMenu(popup.itemForm, sheet);
end

return M;


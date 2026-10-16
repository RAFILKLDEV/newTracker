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

    local pinButton = popup.btnFixar;
    pinButton.visible = canChangeVisibility;
    pinButton.text = trackerMain.isItemPinned(sheet) and "Desafixar posição" or "Fixar posição";
    popup.hitTest = false;
    local y = 2;
    for _, name in ipairs({"btnRolar", "btnGrupo", "btnCor", "btnVisibilidade", "btnFixar", "btnTemporario"}) do
        local button = popup[name];
        if button.visible then
            button.top, button.width, button.height = y, 276, 30;
            y = y + 32;
        end
    end
    popup.menuCard.height = y;
    popup.width, popup.height = 284, y + 4;
end

function M.togglePin(popup, sheet)
    local root = ndb.getRoot(sheet);
    if root == nil or not trackerMain.isMaster(root) or trackerMain.isGroupNode(sheet) then return; end
    trackerMain.toggleItemPin(sheet);
    if popup.itemForm ~= nil then
        require("trackerItem.lua").updateVisual(popup.itemForm, sheet);
        trackerMain.redrawList(popup.itemForm);
    end
    popup:close();
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
    local cardHeight = 4 + (2 + #availableGroups) * 30 + (1 + #availableGroups) * 2;
    menu.width, menu.height = 284, cardHeight + 4;
    menu.drawContainer = false;
    menu.cancelable = true;
    menu.resizable = false;
    menu.movable = false;
    menu.hitTest = false;
    menu.placement = "mouse";

    local layout = gui.newRectangle();
    layout.parent = menu;
    layout.align = "none";
    layout.left, layout.top, layout.width, layout.height = 2, 2, 280, cardHeight;
    layout.color, layout.strokeColor, layout.strokeSize = "#181C21", "#3B4654", 1;
    layout.xradius, layout.yradius, layout.hitTest = 5, 5, false;

    local btnCreate = gui.newButton();
    btnCreate.parent = layout;
    btnCreate.align = "none";
    btnCreate.left, btnCreate.top, btnCreate.width, btnCreate.fontSize = 2, 2, 276, 13;
    btnCreate.height = 30;
    btnCreate.text = "Criar grupo";
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
    btnNoGroup.align = "none";
    btnNoGroup.left, btnNoGroup.top, btnNoGroup.width, btnNoGroup.fontSize = 2, 34, 276, 13;
    btnNoGroup.height = 30;
    btnNoGroup.text = "Sem grupo";
    btnNoGroup.onClick = function()
        trackerMain.moveItemToGroup(sheet, nil);

        if popup.itemForm ~= nil then
            trackerMain.redrawList(popup.itemForm);
        end

        menu:close();
        popup:close();
    end;

    for index, group in ipairs(availableGroups) do
        local btnGroup = gui.newButton();
        btnGroup.parent = layout;
        btnGroup.align = "none";
        btnGroup.left, btnGroup.top, btnGroup.width, btnGroup.fontSize = 2, 66 + (index - 1) * 32, 276, 13;
        btnGroup.height = 30;
        btnGroup.text = tostring(group.nomeGrupo or "Grupo");
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


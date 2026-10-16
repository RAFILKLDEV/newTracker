local ndb = require("ndb.lua");
local gui = require("gui.lua");
local trackerMain = require("trackerMain.lua");

local M = {};
local BASE_FORM_HEIGHT = 34;
local TEMP_SECTION_TOP_MARGIN = 4;
local TEMP_ROW_HEIGHT = 22;
local TEMP_ROW_SPACING = 2;
local ITEM_GROUP_LEFT_MARGIN = 12;
local TEMP_ACTIONS_WIDTH = 118;
local TURN_IDLE_COLOR = "#1B2F21";
local TURN_IDLE_STROKE = "#3CA95B";
local TURN_IDLE_TEXT = "#63F28E";
local TURN_ACTIVE_COLOR = "#1F8F3A";
local TURN_ACTIVE_STROKE = "#63F28E";
local TURN_ACTIVE_TEXT = "#FFFFFF";
local TURN_BLINK_OFF_COLOR = "#14311D";
local TURN_BLINK_OFF_STROKE = "#2E7D46";
local TURN_BLINK_OFF_TEXT = "#63F28E";
local TURN_BLINK_INTERVAL_MS = 1000;

local function clearTemporaryControls(form)
    if form == nil then
        return;
    end

    if form._tempCtrls == nil then
        form._tempCtrls = {};
        return;
    end

    for _, ctrl in ipairs(form._tempCtrls) do
        if ctrl ~= nil then
            ctrl:destroy();
        end
    end

    form._tempCtrls = {};
end

local function registerTemporaryControl(form, ctrl)
    if form._tempCtrls == nil then
        form._tempCtrls = {};
    end

    form._tempCtrls[#form._tempCtrls + 1] = ctrl;
end

local function setTurnIndicatorColors(form, active)
    if form == nil or form.rectTurn == nil or form.lblTurnIndicator == nil then
        return;
    end

    if active then
        form.rectTurn.color = TURN_ACTIVE_COLOR;
        form.rectTurn.strokeColor = TURN_ACTIVE_STROKE;
        form.lblTurnIndicator.fontColor = TURN_ACTIVE_TEXT;
    else
        form.rectTurn.color = TURN_BLINK_OFF_COLOR;
        form.rectTurn.strokeColor = TURN_BLINK_OFF_STROKE;
        form.lblTurnIndicator.fontColor = TURN_BLINK_OFF_TEXT;
    end
end

local function stopTurnBlink(form)
    if form == nil then
        return;
    end

    if form._turnBlinkIntervalId ~= nil then
        clearInterval(form._turnBlinkIntervalId);
        form._turnBlinkIntervalId = nil;
    end

    form._turnBlinkOn = false;
end

local function resetTurnIndicator(form)
    stopTurnBlink(form);

    if form == nil or form.rectTurn == nil or form.lblTurnIndicator == nil then
        return;
    end

    form.rectTurn.color = TURN_IDLE_COLOR;
    form.rectTurn.strokeColor = TURN_IDLE_STROKE;
    form.lblTurnIndicator.fontColor = TURN_IDLE_TEXT;
end

local function startTurnBlink(form, sheet)
    if form == nil or sheet == nil then
        return;
    end

    if form._turnBlinkIntervalId ~= nil then
        return;
    end

    form._turnBlinkOn = true;
    setTurnIndicatorColors(form, true);

    form._turnBlinkIntervalId = setInterval(
        function()
            if sheet.turnoAtual ~= true then
                resetTurnIndicator(form);
                return;
            end

            form._turnBlinkOn = not form._turnBlinkOn;
            setTurnIndicatorColors(form, form._turnBlinkOn);
        end,
        TURN_BLINK_INTERVAL_MS);
end

local function rebuildTemporaryRows(form, sheet)
    clearTemporaryControls(form);

    if form == nil or sheet == nil or form.layTemp == nil then
        return 0;
    end

    local temporaries = trackerMain.getTemporaryEntries(sheet);

    for index, temporaryNode in ipairs(temporaries) do
        local row = gui.newLayout();
        row.parent = form.layTemp;
        row.align = "top";
        row.height = TEMP_ROW_HEIGHT;

        if index < #temporaries then
            row.margins = {bottom = TEMP_ROW_SPACING};
        end

        registerTemporaryControl(form, row);

        local rightArea = gui.newLayout();
        rightArea.parent = row;
        rightArea.align = "right";
        rightArea.width = TEMP_ACTIONS_WIDTH;

        local btnDelete = gui.newButton();
        btnDelete.parent = rightArea;
        btnDelete.align = "right";
        btnDelete.width = 26;
        btnDelete.text = "X";
        btnDelete.margins = {left = 6};
        btnDelete.onClick = function()
            trackerMain.removeTemporary(temporaryNode);
        end;

        local lblTurns = gui.newLabel();
        lblTurns.parent = rightArea;
        lblTurns.align = "right";
        lblTurns.width = 44;
        lblTurns.text = "turnos";

        local edtCount = gui.newEdit();
        edtCount.parent = rightArea;
        edtCount.align = "right";
        edtCount.width = 36;
        edtCount.type = "number";
        edtCount.horzTextAlign = "center";
        edtCount.text = tostring(math.max(0, math.floor(tonumber(temporaryNode.contagem) or 0)));
        edtCount.onUserChange = function()
            local count = tonumber(edtCount.text);

            if count == nil then
                return;
            end

            count = math.floor(count);

            if count <= 0 then
                trackerMain.removeTemporary(temporaryNode);
                return;
            end

            temporaryNode.contagem = count;
        end;

        local lblName = gui.newLabel();
        lblName.parent = row;
        lblName.align = "client";
        lblName.text = tostring(temporaryNode.nome or "");
    end

    return #temporaries;
end

function M.openContextMenu(form, sheet)
    local root = ndb.getRoot(sheet);

    if root ~= nil and not trackerMain.isMaster(root)
        and trackerMain.getVisibilityState(sheet) > 0 then
        return;
    end

    if trackerMain.isGroupNode(sheet) then
        trackerMain.openGroupColorMenu(form, sheet);
        return;
    end

    local popup = gui.newPopupForm("frmTrackerItemMenu");
    popup.scopeNode = sheet;
    popup.itemForm = form;
    require("trackerMenu.lua").configureItemMenu(popup, sheet);
    gui.showPopup(popup, {placement = "mouse"});
end

function M.updateVisual(form, sheet)
    if form == nil or sheet == nil then
        return;
    end

    local isGroup = trackerMain.isGroupNode(sheet);
    local root = ndb.getRoot(sheet);
    local viewerVisibility = isGroup and 0
        or trackerMain.getViewerVisibilityState(root, sheet);
    local isMaster = trackerMain.isMaster(root);

    if viewerVisibility == 2 then
        stopTurnBlink(form);
        form.height = 0;
        form.visible = false;
        return;
    end

    form.visible = true;
    if not isGroup then
        if form.edtTeste ~= nil then
            form.edtTeste.readOnly = not isMaster or viewerVisibility == 1;
        end
        if form.edtNome ~= nil then
            form.edtNome.readOnly = not isMaster or viewerVisibility == 1;
        end
        if form.edtIniciativa ~= nil then
            form.edtIniciativa.readOnly = not isMaster or viewerVisibility == 1;
        end
    end

    form.layGrupo.visible = isGroup;
    form.layItem.visible = not isGroup;

    if isGroup then
        local groupColor = trackerMain.getGroupColor(sheet);

        resetTurnIndicator(form);
        clearTemporaryControls(form);
        form.layTemp.visible = false;
        form.layTemp.height = 0;
        form.height = BASE_FORM_HEIGHT;
        form.rectBg.margins = nil;
        form.rectBg.strokeSize = 1;
        form.rectBg.strokeColor = "#111111";

        if trackerMain.isGroupActive(sheet) then
            form.rectBg.color = groupColor;
        else
            form.rectBg.color = trackerMain.getItemColor(ndb.getRoot(sheet), {grupoId = sheet.grupoId});
        end
    else
        local hasGroup = trackerMain.getGroupById(root, sheet.grupoId) ~= nil;
        local temporaryCount = rebuildTemporaryRows(form, sheet);

        if viewerVisibility == 1 then
            clearTemporaryControls(form);
            temporaryCount = 0;
            form.layTemp.visible = false;
            form.layTemp.height = 0;
            if form.edtTeste ~= nil then form.edtTeste.text = "???"; end
            if form.edtNome ~= nil then form.edtNome.text = "???"; end
            if form.edtIniciativa ~= nil then form.edtIniciativa.text = "—"; end
        end

        if temporaryCount > 0 then
            form.layTemp.visible = true;
            form.layTemp.height = (temporaryCount * TEMP_ROW_HEIGHT) + ((temporaryCount - 1) * TEMP_ROW_SPACING);
            form.height = BASE_FORM_HEIGHT + TEMP_SECTION_TOP_MARGIN + form.layTemp.height;
        else
            form.layTemp.visible = false;
            form.layTemp.height = 0;
            form.height = BASE_FORM_HEIGHT;
        end

        if hasGroup then
            form.rectBg.margins = {left = ITEM_GROUP_LEFT_MARGIN};
        else
            form.rectBg.margins = nil;
        end

        form.rectBg.color = viewerVisibility == 1
            and "#2A2A2A"
            or trackerMain.getItemColor(root, sheet);
        form.rectBg.strokeSize = sheet.turnoAtual == true and 2 or 1;

        if isMaster and trackerMain.getVisibilityState(sheet) == 1 then
            form.rectBg.strokeColor = "#D7A84B";
        elseif isMaster and trackerMain.getVisibilityState(sheet) == 2 then
            form.rectBg.strokeColor = "#B85C68";
        else
            form.rectBg.strokeColor = sheet.turnoAtual == true and "#63F28E" or "#111111";
        end

        if sheet.turnoAtual == true then
            startTurnBlink(form, sheet);
        else
            resetTurnIndicator(form);
        end
    end
end

function M.onNodeReady(form, sheet)
    form._tempCtrls = {};
    M.updateVisual(form, sheet);

    form._obs = ndb.newObserver(sheet);
    form._obsIds = {};
    form._obsIds[#form._obsIds + 1] = form._obs:addEventListener("onChanged",
        function(node, attribute, oldValue)
            if attribute == "turnoAtual"
                or attribute == "tipo"
                or attribute == "nomeGrupo"
                or attribute == "grupoId"
                or attribute == "itemCor"
                or attribute == "ocultacaoEstado"
                or attribute == "posicaoFixada"
                or attribute == "efeitoTemporarioNome"
                or attribute == "efeitoTemporarioContagem" then
                M.updateVisual(form, sheet);
            end
        end);

    form._obsIds[#form._obsIds + 1] = form._obs:addEventListener("onDeepChanged",
        function(node, attribute, oldValue)
            M.updateVisual(form, sheet);
        end);

    form._obsIds[#form._obsIds + 1] = form._obs:addEventListener("onDeepChildAdded",
        function(node)
            M.updateVisual(form, sheet);
        end);

    form._obsIds[#form._obsIds + 1] = form._obs:addEventListener("onDeepChildRemoved",
        function(node)
            M.updateVisual(form, sheet);
        end);

    local root = ndb.getRoot(sheet);

    if root ~= nil then
        form._rootObs = ndb.newObserver(root);
        form._rootObsIds = {};
        form._rootObsIds[#form._rootObsIds + 1] = form._rootObs:addEventListener("onDeepChanged",
            function(node, attribute, oldValue)
                if trackerMain.isGroupNode(node)
                    and (attribute == "grupoCor"
                        or attribute == "grupoAtivo"
                        or attribute == "nomeGrupo"
                        or attribute == "grupoId") then
                    M.updateVisual(form, sheet);
                end
            end);

        form._rootObsIds[#form._rootObsIds + 1] = form._rootObs:addEventListener("onDeepChildAdded",
            function(node)
                if trackerMain.isGroupNode(node) then
                    M.updateVisual(form, sheet);
                end
            end);

        form._rootObsIds[#form._rootObsIds + 1] = form._rootObs:addEventListener("onDeepChildRemoved",
            function(node)
                if trackerMain.isGroupNode(node) then
                    M.updateVisual(form, sheet);
                end
            end);
    end
end

function M.onNodeUnready(form)
    clearTemporaryControls(form);
    stopTurnBlink(form);

    if form ~= nil and form._activeToolbarPopup ~= nil then
        form._activeToolbarPopup:close(false, true);
        form._activeToolbarPopup = nil;
    end

    if form ~= nil and form._obs ~= nil and form._obsIds ~= nil then
        for _, obsId in ipairs(form._obsIds) do
            form._obs:removeEventListener(obsId);
        end
    end

    if form ~= nil and form._rootObs ~= nil and form._rootObsIds ~= nil then
        for _, obsId in ipairs(form._rootObsIds) do
            form._rootObs:removeEventListener(obsId);
        end
    end

    if form ~= nil then
        form._obs = nil;
        form._obsIds = nil;
        form._rootObs = nil;
        form._rootObsIds = nil;
        form._tempCtrls = nil;
        form._turnBlinkIntervalId = nil;
        form._turnBlinkOn = nil;
    end
end

function M.onTurnClick(form, sheet)
    trackerMain.markTurn(sheet);
    M.updateVisual(form, sheet);
end

function M.onInitChange(form)
    trackerMain.redrawList(form);
end

function M.onFieldUserChange(sheet)
    trackerMain.saveItemHistory(sheet);
end

function M.onDeleteItemClick(sheet)
    trackerMain.deleteItem(sheet);
end

function M.onPinClick(form, sheet)
    trackerMain.toggleItemPin(sheet);
    M.updateVisual(form, sheet);
    trackerMain.redrawList(form);
end

function M.onDeleteGroupClick(form, sheet)
    trackerMain.deleteGroup(sheet);
    trackerMain.redrawList(form);
end

function M.onClearTemporaryClick(form, sheet)
    trackerMain.clearTemporary(sheet);
    M.updateVisual(form, sheet);
end

function M.onGroupActiveChange(form, sheet)
    trackerMain.onGroupActiveChange(sheet);
    M.updateVisual(form, sheet);
end

function M.onStartDrag(form, sheet, drag)
    if drag == nil or sheet == nil or trackerMain.isGroupNode(sheet) then
        return;
    end

    drag:addData("newTracker.itemId", tostring(sheet.itemId or ""));
end

function M.onStartDrop(form, sheet, drop)
    if drop == nil or sheet == nil then
        return;
    end

    local root = ndb.getRoot(sheet);
    local targetGroupId = sheet.grupoId;

    if trackerMain.isGroupNode(sheet) then
        targetGroupId = sheet.grupoId;
    end

    drop:addAction("newTracker.itemId",
        function(itemId)
            local moved = trackerMain.moveItemIdToGroupId(root, itemId, targetGroupId);

            if moved then
                trackerMain.redrawList(form);
            end
        end);
end

return M;


require("firecast.lua");
local __o_rrpgObjs = require("rrpgObjs.lua");
require("rrpgGUI.lua");
require("rrpgDialogs.lua");
require("rrpgLFM.lua");
require("ndb.lua");
require("locale.lua");
local __o_Utils = require("utils.lua");

local function constructNew_frmTrackerItemMenu()
    local obj = GUI.fromHandle(_obj_newObject("popupForm"));
    local self = obj;
    local sheet = nil;

    rawset(obj, "_oldSetNodeObjectFunction", obj.setNodeObject);

    function obj:setNodeObject(nodeObject)
        sheet = nodeObject;
        self.sheet = nodeObject;
        self:_oldSetNodeObjectFunction(nodeObject);
    end;

    function obj:setNodeDatabase(nodeObject)
        self:setNodeObject(nodeObject);
    end;

    _gui_assignInitialParentForForm(obj.handle);
    obj:beginUpdate();
    obj:setName("frmTrackerItemMenu");
    obj:setWidth(284);
    obj:setHeight(198);
    obj:setDrawContainer(false);
    obj:setCancelable(true);
    obj:setResizable(false);
    obj.movable = false;
    obj:setPlacement("mouse");


        local trackerMenu = require("trackerMenu.lua");
    


    obj.menuCard = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.menuCard:setParent(obj);
    obj.menuCard:setName("menuCard");
    obj.menuCard:setAlign("none");
    obj.menuCard:setLeft(2);
    obj.menuCard:setTop(2);
    obj.menuCard:setWidth(280);
    obj.menuCard:setHeight(194);
    obj.menuCard:setColor("#181C21");
    obj.menuCard:setStrokeColor("#3B4654");
    obj.menuCard:setStrokeSize(1);
    obj.menuCard:setXradius(5);
    obj.menuCard:setYradius(5);
    obj.menuCard:setHitTest(false);

    obj.btnRolar = GUI.fromHandle(_obj_newObject("button"));
    obj.btnRolar:setParent(obj.menuCard);
    obj.btnRolar:setName("btnRolar");
    obj.btnRolar:setAlign("none");
    obj.btnRolar:setLeft(2);
    obj.btnRolar:setWidth(276);
    obj.btnRolar:setHeight(30);
    obj.btnRolar:setFontSize(13);
    obj.btnRolar:setText("Rolar iniciativa");

    obj.btnGrupo = GUI.fromHandle(_obj_newObject("button"));
    obj.btnGrupo:setParent(obj.menuCard);
    obj.btnGrupo:setName("btnGrupo");
    obj.btnGrupo:setAlign("none");
    obj.btnGrupo:setLeft(2);
    obj.btnGrupo:setWidth(276);
    obj.btnGrupo:setHeight(30);
    obj.btnGrupo:setFontSize(13);
    obj.btnGrupo:setText("Grupo");

    obj.btnCor = GUI.fromHandle(_obj_newObject("button"));
    obj.btnCor:setParent(obj.menuCard);
    obj.btnCor:setName("btnCor");
    obj.btnCor:setAlign("none");
    obj.btnCor:setLeft(2);
    obj.btnCor:setWidth(276);
    obj.btnCor:setHeight(30);
    obj.btnCor:setFontSize(13);
    obj.btnCor:setText("Cor");

    obj.btnVisibilidade = GUI.fromHandle(_obj_newObject("button"));
    obj.btnVisibilidade:setParent(obj.menuCard);
    obj.btnVisibilidade:setName("btnVisibilidade");
    obj.btnVisibilidade:setAlign("none");
    obj.btnVisibilidade:setLeft(2);
    obj.btnVisibilidade:setWidth(276);
    obj.btnVisibilidade:setHeight(30);
    obj.btnVisibilidade:setFontSize(13);
    obj.btnVisibilidade:setText("Visibilidade");
    obj.btnVisibilidade:setVisible(false);

    obj.btnFixar = GUI.fromHandle(_obj_newObject("button"));
    obj.btnFixar:setParent(obj.menuCard);
    obj.btnFixar:setName("btnFixar");
    obj.btnFixar:setAlign("none");
    obj.btnFixar:setLeft(2);
    obj.btnFixar:setWidth(276);
    obj.btnFixar:setHeight(30);
    obj.btnFixar:setFontSize(13);
    obj.btnFixar:setText("Fixar posição");
    obj.btnFixar:setVisible(false);

    obj.btnTemporario = GUI.fromHandle(_obj_newObject("button"));
    obj.btnTemporario:setParent(obj.menuCard);
    obj.btnTemporario:setName("btnTemporario");
    obj.btnTemporario:setAlign("none");
    obj.btnTemporario:setLeft(2);
    obj.btnTemporario:setWidth(276);
    obj.btnTemporario:setHeight(30);
    obj.btnTemporario:setFontSize(13);
    obj.btnTemporario:setText("Temporário");

    obj._e_event0 = obj.btnRolar:addEventListener("onClick",
        function (event)
            trackerMenu.rollInitiative(self, sheet);
        end);

    obj._e_event1 = obj.btnGrupo:addEventListener("onClick",
        function (event)
            trackerMenu.openGroupMenu(self, sheet);
        end);

    obj._e_event2 = obj.btnCor:addEventListener("onClick",
        function (event)
            trackerMenu.openItemColorMenu(self, sheet);
        end);

    obj._e_event3 = obj.btnVisibilidade:addEventListener("onClick",
        function (event)
            trackerMenu.changeVisibility(self, sheet);
        end);

    obj._e_event4 = obj.btnFixar:addEventListener("onClick",
        function (event)
            trackerMenu.togglePin(self, sheet);
        end);

    obj._e_event5 = obj.btnTemporario:addEventListener("onClick",
        function (event)
            trackerMenu.openTemporaryMenu(self, sheet);
        end);

    function obj:_releaseEvents()
        __o_rrpgObjs.removeEventListenerById(self._e_event5);
        __o_rrpgObjs.removeEventListenerById(self._e_event4);
        __o_rrpgObjs.removeEventListenerById(self._e_event3);
        __o_rrpgObjs.removeEventListenerById(self._e_event2);
        __o_rrpgObjs.removeEventListenerById(self._e_event1);
        __o_rrpgObjs.removeEventListenerById(self._e_event0);
    end;

    obj._oldLFMDestroy = obj.destroy;

    function obj:destroy() 
        self:_releaseEvents();

        if (self.handle ~= 0) and (self.setNodeDatabase ~= nil) then
          self:setNodeDatabase(nil);
        end;

        if self.btnRolar ~= nil then self.btnRolar:destroy(); self.btnRolar = nil; end;
        if self.btnTemporario ~= nil then self.btnTemporario:destroy(); self.btnTemporario = nil; end;
        if self.btnFixar ~= nil then self.btnFixar:destroy(); self.btnFixar = nil; end;
        if self.btnGrupo ~= nil then self.btnGrupo:destroy(); self.btnGrupo = nil; end;
        if self.menuCard ~= nil then self.menuCard:destroy(); self.menuCard = nil; end;
        if self.btnCor ~= nil then self.btnCor:destroy(); self.btnCor = nil; end;
        if self.btnVisibilidade ~= nil then self.btnVisibilidade:destroy(); self.btnVisibilidade = nil; end;
        self:_oldLFMDestroy();
    end;

    obj:endUpdate();

    return obj;
end;

function newfrmTrackerItemMenu()
    local retObj = nil;
    __o_rrpgObjs.beginObjectsLoading();

    __o_Utils.tryFinally(
      function()
        retObj = constructNew_frmTrackerItemMenu();
      end,
      function()
        __o_rrpgObjs.endObjectsLoading();
      end);

    assert(retObj ~= nil);
    return retObj;
end;

local _frmTrackerItemMenu = {
    newEditor = newfrmTrackerItemMenu, 
    new = newfrmTrackerItemMenu, 
    name = "frmTrackerItemMenu", 
    dataType = "", 
    formType = "undefined", 
    formComponentName = "popupForm", 
    cacheMode = "none", 
    title = "", 
    description=""};

frmTrackerItemMenu = _frmTrackerItemMenu;
Firecast.registrarForm(_frmTrackerItemMenu);

return _frmTrackerItemMenu;

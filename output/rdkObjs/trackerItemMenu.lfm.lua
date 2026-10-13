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
    obj:setWidth(200);
    obj:setHeight(136);
    obj:setTheme("dark");
    obj:setDrawContainer(false);
    obj:setCancelable(true);
    obj:setResizable(false);
    obj.movable = false;
    obj:setPlacement("mouse");


        local trackerMenu = require("trackerMenu.lua");
    


    obj.button1 = GUI.fromHandle(_obj_newObject("button"));
    obj.button1:setParent(obj);
    obj.button1:setAlign("top");
    obj.button1:setHeight(30);
    obj.button1:setText("Rolar iniciativa");
    obj.button1:setMargins({bottom=4});
    obj.button1:setName("button1");

    obj.button2 = GUI.fromHandle(_obj_newObject("button"));
    obj.button2:setParent(obj);
    obj.button2:setAlign("top");
    obj.button2:setHeight(30);
    obj.button2:setText("Grupo");
    obj.button2:setMargins({bottom=4});
    obj.button2:setName("button2");

    obj.button3 = GUI.fromHandle(_obj_newObject("button"));
    obj.button3:setParent(obj);
    obj.button3:setAlign("top");
    obj.button3:setHeight(30);
    obj.button3:setText("Cor");
    obj.button3:setMargins({bottom=4});
    obj.button3:setName("button3");

    obj.btnVisibilidade = GUI.fromHandle(_obj_newObject("button"));
    obj.btnVisibilidade:setParent(obj);
    obj.btnVisibilidade:setName("btnVisibilidade");
    obj.btnVisibilidade:setAlign("top");
    obj.btnVisibilidade:setHeight(30);
    obj.btnVisibilidade:setText("Visibilidade");
    obj.btnVisibilidade:setVisible(false);
    obj.btnVisibilidade:setMargins({bottom=4});

    obj.button4 = GUI.fromHandle(_obj_newObject("button"));
    obj.button4:setParent(obj);
    obj.button4:setAlign("client");
    obj.button4:setText("Temporario");
    obj.button4:setName("button4");

    obj._e_event0 = obj.button1:addEventListener("onClick",
        function (event)
            trackerMenu.rollInitiative(self, sheet);
        end);

    obj._e_event1 = obj.button2:addEventListener("onClick",
        function (event)
            trackerMenu.openGroupMenu(self, sheet);
        end);

    obj._e_event2 = obj.button3:addEventListener("onClick",
        function (event)
            trackerMenu.openItemColorMenu(self, sheet);
        end);

    obj._e_event3 = obj.btnVisibilidade:addEventListener("onClick",
        function (event)
            trackerMenu.changeVisibility(self, sheet);
        end);

    obj._e_event4 = obj.button4:addEventListener("onClick",
        function (event)
            trackerMenu.openTemporaryMenu(self, sheet);
        end);

    function obj:_releaseEvents()
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

        if self.button4 ~= nil then self.button4:destroy(); self.button4 = nil; end;
        if self.button3 ~= nil then self.button3:destroy(); self.button3 = nil; end;
        if self.button2 ~= nil then self.button2:destroy(); self.button2 = nil; end;
        if self.button1 ~= nil then self.button1:destroy(); self.button1 = nil; end;
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

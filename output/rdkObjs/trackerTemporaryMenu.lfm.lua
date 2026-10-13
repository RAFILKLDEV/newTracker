require("firecast.lua");
local __o_rrpgObjs = require("rrpgObjs.lua");
require("rrpgGUI.lua");
require("rrpgDialogs.lua");
require("rrpgLFM.lua");
require("ndb.lua");
require("locale.lua");
local __o_Utils = require("utils.lua");

local function constructNew_frmTrackerTemporaryMenu()
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
    obj:setName("frmTrackerTemporaryMenu");
    obj:setWidth(260);
    obj:setHeight(360);
    obj:setTheme("dark");
    obj:setDrawContainer(false);
    obj:setCancelable(true);
    obj:setResizable(false);
    obj.movable = false;
    obj:setPlacement("mouse");


        local trackerTemporaryMenu = require("trackerTemporaryMenu.lua");
    


    obj.layout1 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout1:setParent(obj);
    obj.layout1:setAlign("top");
    obj.layout1:setHeight(30);
    obj.layout1:setMargins({bottom=6});
    obj.layout1:setName("layout1");

    obj.label1 = GUI.fromHandle(_obj_newObject("label"));
    obj.label1:setParent(obj.layout1);
    obj.label1:setAlign("left");
    obj.label1:setWidth(54);
    obj.label1:setText("Nome");
    obj.label1:setName("label1");

    obj.edtNome = GUI.fromHandle(_obj_newObject("edit"));
    obj.edtNome:setParent(obj.layout1);
    obj.edtNome:setName("edtNome");
    obj.edtNome:setAlign("client");

    obj.layout2 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout2:setParent(obj);
    obj.layout2:setAlign("top");
    obj.layout2:setHeight(30);
    obj.layout2:setMargins({bottom=4});
    obj.layout2:setName("layout2");

    obj.button1 = GUI.fromHandle(_obj_newObject("button"));
    obj.button1:setParent(obj.layout2);
    obj.button1:setAlign("left");
    obj.button1:setWidth(28);
    obj.button1:setText("1");
    obj.button1:setName("button1");

    obj.button2 = GUI.fromHandle(_obj_newObject("button"));
    obj.button2:setParent(obj.layout2);
    obj.button2:setAlign("left");
    obj.button2:setWidth(28);
    obj.button2:setText("2");
    obj.button2:setMargins({left=4});
    obj.button2:setName("button2");

    obj.button3 = GUI.fromHandle(_obj_newObject("button"));
    obj.button3:setParent(obj.layout2);
    obj.button3:setAlign("left");
    obj.button3:setWidth(28);
    obj.button3:setText("3");
    obj.button3:setMargins({left=4});
    obj.button3:setName("button3");

    obj.button4 = GUI.fromHandle(_obj_newObject("button"));
    obj.button4:setParent(obj.layout2);
    obj.button4:setAlign("left");
    obj.button4:setWidth(28);
    obj.button4:setText("4");
    obj.button4:setMargins({left=4});
    obj.button4:setName("button4");

    obj.button5 = GUI.fromHandle(_obj_newObject("button"));
    obj.button5:setParent(obj.layout2);
    obj.button5:setAlign("left");
    obj.button5:setWidth(28);
    obj.button5:setText("5");
    obj.button5:setMargins({left=4});
    obj.button5:setName("button5");

    obj.layout3 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout3:setParent(obj);
    obj.layout3:setAlign("top");
    obj.layout3:setHeight(30);
    obj.layout3:setMargins({bottom=8});
    obj.layout3:setName("layout3");

    obj.button6 = GUI.fromHandle(_obj_newObject("button"));
    obj.button6:setParent(obj.layout3);
    obj.button6:setAlign("left");
    obj.button6:setWidth(28);
    obj.button6:setText("6");
    obj.button6:setName("button6");

    obj.button7 = GUI.fromHandle(_obj_newObject("button"));
    obj.button7:setParent(obj.layout3);
    obj.button7:setAlign("left");
    obj.button7:setWidth(28);
    obj.button7:setText("7");
    obj.button7:setMargins({left=4});
    obj.button7:setName("button7");

    obj.button8 = GUI.fromHandle(_obj_newObject("button"));
    obj.button8:setParent(obj.layout3);
    obj.button8:setAlign("left");
    obj.button8:setWidth(28);
    obj.button8:setText("8");
    obj.button8:setMargins({left=4});
    obj.button8:setName("button8");

    obj.button9 = GUI.fromHandle(_obj_newObject("button"));
    obj.button9:setParent(obj.layout3);
    obj.button9:setAlign("left");
    obj.button9:setWidth(28);
    obj.button9:setText("9");
    obj.button9:setMargins({left=4});
    obj.button9:setName("button9");

    obj.layout4 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout4:setParent(obj);
    obj.layout4:setAlign("top");
    obj.layout4:setHeight(30);
    obj.layout4:setName("layout4");

    obj.label2 = GUI.fromHandle(_obj_newObject("label"));
    obj.label2:setParent(obj.layout4);
    obj.label2:setAlign("left");
    obj.label2:setWidth(54);
    obj.label2:setText("Mais");
    obj.label2:setName("label2");

    obj.edtQuantidade = GUI.fromHandle(_obj_newObject("edit"));
    obj.edtQuantidade:setParent(obj.layout4);
    obj.edtQuantidade:setName("edtQuantidade");
    obj.edtQuantidade:setAlign("left");
    obj.edtQuantidade:setWidth(80);
    obj.edtQuantidade:setType("number");

    obj.button10 = GUI.fromHandle(_obj_newObject("button"));
    obj.button10:setParent(obj.layout4);
    obj.button10:setAlign("left");
    obj.button10:setWidth(80);
    obj.button10:setText("Aplicar");
    obj.button10:setMargins({left=6});
    obj.button10:setName("button10");

    obj.lblHistorico = GUI.fromHandle(_obj_newObject("label"));
    obj.lblHistorico:setParent(obj);
    obj.lblHistorico:setName("lblHistorico");
    obj.lblHistorico:setAlign("top");
    obj.lblHistorico:setHeight(24);
    obj.lblHistorico:setText("Historico");
    lfm_setPropAsString(obj.lblHistorico, "fontStyle", "bold");
    obj.lblHistorico:setMargins({top=10, bottom=4});
    obj.lblHistorico:setVisible(false);

    obj.lblSemHistorico = GUI.fromHandle(_obj_newObject("label"));
    obj.lblSemHistorico:setParent(obj);
    obj.lblSemHistorico:setName("lblSemHistorico");
    obj.lblSemHistorico:setAlign("top");
    obj.lblSemHistorico:setHeight(22);
    obj.lblSemHistorico:setText("Nenhuma condicao recente");
    obj.lblSemHistorico:setVisible(false);

    obj.sbxHistorico = GUI.fromHandle(_obj_newObject("scrollBox"));
    obj.sbxHistorico:setParent(obj);
    obj.sbxHistorico:setName("sbxHistorico");
    obj.sbxHistorico:setAlign("client");
    obj.sbxHistorico:setVisible(false);

    obj._e_event0 = obj:addEventListener("onNodeReady",
        function ()
            trackerTemporaryMenu.onNodeReady(self, sheet);
        end);

    obj._e_event1 = obj:addEventListener("onNodeUnready",
        function ()
            trackerTemporaryMenu.onNodeUnready(self);
        end);

    obj._e_event2 = obj.button1:addEventListener("onClick",
        function (event)
            trackerTemporaryMenu.apply(self, sheet, 1);
        end);

    obj._e_event3 = obj.button2:addEventListener("onClick",
        function (event)
            trackerTemporaryMenu.apply(self, sheet, 2);
        end);

    obj._e_event4 = obj.button3:addEventListener("onClick",
        function (event)
            trackerTemporaryMenu.apply(self, sheet, 3);
        end);

    obj._e_event5 = obj.button4:addEventListener("onClick",
        function (event)
            trackerTemporaryMenu.apply(self, sheet, 4);
        end);

    obj._e_event6 = obj.button5:addEventListener("onClick",
        function (event)
            trackerTemporaryMenu.apply(self, sheet, 5);
        end);

    obj._e_event7 = obj.button6:addEventListener("onClick",
        function (event)
            trackerTemporaryMenu.apply(self, sheet, 6);
        end);

    obj._e_event8 = obj.button7:addEventListener("onClick",
        function (event)
            trackerTemporaryMenu.apply(self, sheet, 7);
        end);

    obj._e_event9 = obj.button8:addEventListener("onClick",
        function (event)
            trackerTemporaryMenu.apply(self, sheet, 8);
        end);

    obj._e_event10 = obj.button9:addEventListener("onClick",
        function (event)
            trackerTemporaryMenu.apply(self, sheet, 9);
        end);

    obj._e_event11 = obj.button10:addEventListener("onClick",
        function (event)
            trackerTemporaryMenu.applyCustom(self, sheet);
        end);

    function obj:_releaseEvents()
        __o_rrpgObjs.removeEventListenerById(self._e_event11);
        __o_rrpgObjs.removeEventListenerById(self._e_event10);
        __o_rrpgObjs.removeEventListenerById(self._e_event9);
        __o_rrpgObjs.removeEventListenerById(self._e_event8);
        __o_rrpgObjs.removeEventListenerById(self._e_event7);
        __o_rrpgObjs.removeEventListenerById(self._e_event6);
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

        if self.button2 ~= nil then self.button2:destroy(); self.button2 = nil; end;
        if self.button9 ~= nil then self.button9:destroy(); self.button9 = nil; end;
        if self.layout4 ~= nil then self.layout4:destroy(); self.layout4 = nil; end;
        if self.label2 ~= nil then self.label2:destroy(); self.label2 = nil; end;
        if self.button6 ~= nil then self.button6:destroy(); self.button6 = nil; end;
        if self.edtQuantidade ~= nil then self.edtQuantidade:destroy(); self.edtQuantidade = nil; end;
        if self.edtNome ~= nil then self.edtNome:destroy(); self.edtNome = nil; end;
        if self.label1 ~= nil then self.label1:destroy(); self.label1 = nil; end;
        if self.button1 ~= nil then self.button1:destroy(); self.button1 = nil; end;
        if self.layout3 ~= nil then self.layout3:destroy(); self.layout3 = nil; end;
        if self.button8 ~= nil then self.button8:destroy(); self.button8 = nil; end;
        if self.button5 ~= nil then self.button5:destroy(); self.button5 = nil; end;
        if self.button10 ~= nil then self.button10:destroy(); self.button10 = nil; end;
        if self.lblSemHistorico ~= nil then self.lblSemHistorico:destroy(); self.lblSemHistorico = nil; end;
        if self.sbxHistorico ~= nil then self.sbxHistorico:destroy(); self.sbxHistorico = nil; end;
        if self.layout2 ~= nil then self.layout2:destroy(); self.layout2 = nil; end;
        if self.button4 ~= nil then self.button4:destroy(); self.button4 = nil; end;
        if self.button3 ~= nil then self.button3:destroy(); self.button3 = nil; end;
        if self.lblHistorico ~= nil then self.lblHistorico:destroy(); self.lblHistorico = nil; end;
        if self.button7 ~= nil then self.button7:destroy(); self.button7 = nil; end;
        if self.layout1 ~= nil then self.layout1:destroy(); self.layout1 = nil; end;
        self:_oldLFMDestroy();
    end;

    obj:endUpdate();

    return obj;
end;

function newfrmTrackerTemporaryMenu()
    local retObj = nil;
    __o_rrpgObjs.beginObjectsLoading();

    __o_Utils.tryFinally(
      function()
        retObj = constructNew_frmTrackerTemporaryMenu();
      end,
      function()
        __o_rrpgObjs.endObjectsLoading();
      end);

    assert(retObj ~= nil);
    return retObj;
end;

local _frmTrackerTemporaryMenu = {
    newEditor = newfrmTrackerTemporaryMenu, 
    new = newfrmTrackerTemporaryMenu, 
    name = "frmTrackerTemporaryMenu", 
    dataType = "", 
    formType = "undefined", 
    formComponentName = "popupForm", 
    cacheMode = "none", 
    title = "", 
    description=""};

frmTrackerTemporaryMenu = _frmTrackerTemporaryMenu;
Firecast.registrarForm(_frmTrackerTemporaryMenu);

return _frmTrackerTemporaryMenu;

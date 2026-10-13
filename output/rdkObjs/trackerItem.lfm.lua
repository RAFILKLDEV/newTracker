require("firecast.lua");
local __o_rrpgObjs = require("rrpgObjs.lua");
require("rrpgGUI.lua");
require("rrpgDialogs.lua");
require("rrpgLFM.lua");
require("ndb.lua");
require("locale.lua");
local __o_Utils = require("utils.lua");

local function constructNew_frmTrackerItem()
    local obj = GUI.fromHandle(_obj_newObject("form"));
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
    obj:setName("frmTrackerItem");
    obj:setHeight(34);
    obj:setTheme("dark");
    obj:setMargins({bottom=8});


        local trackerItem = require("trackerItem.lua");
    


    obj.rectBg = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectBg:setParent(obj);
    obj.rectBg:setName("rectBg");
    obj.rectBg:setAlign("client");
    obj.rectBg:setColor("#2A2A2A");
    obj.rectBg:setXradius(4);
    obj.rectBg:setYradius(4);
    obj.rectBg:setPadding({left=4, top=4, right=4, bottom=4});

    obj.layGrupo = GUI.fromHandle(_obj_newObject("layout"));
    obj.layGrupo:setParent(obj.rectBg);
    obj.layGrupo:setName("layGrupo");
    obj.layGrupo:setAlign("client");
    obj.layGrupo:setVisible(false);

    obj.button1 = GUI.fromHandle(_obj_newObject("button"));
    obj.button1:setParent(obj.layGrupo);
    obj.button1:setAlign("right");
    obj.button1:setWidth(26);
    obj.button1:setText("X");
    obj.button1:setName("button1");

    obj.checkBox1 = GUI.fromHandle(_obj_newObject("checkBox"));
    obj.checkBox1:setParent(obj.layGrupo);
    obj.checkBox1:setAlign("left");
    obj.checkBox1:setWidth(62);
    obj.checkBox1:setText("Ativo");
    obj.checkBox1:setField("grupoAtivo");
    obj.checkBox1:setName("checkBox1");

    obj.edit1 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit1:setParent(obj.layGrupo);
    obj.edit1:setAlign("client");
    obj.edit1:setField("nomeGrupo");
    obj.edit1:setHorzTextAlign("center");
    lfm_setPropAsString(obj.edit1, "fontStyle", "bold");
    obj.edit1:setFontSize(15);
    obj.edit1:setMargins({right=6});
    obj.edit1:setName("edit1");

    obj.layItem = GUI.fromHandle(_obj_newObject("layout"));
    obj.layItem:setParent(obj.rectBg);
    obj.layItem:setName("layItem");
    obj.layItem:setAlign("client");
    obj.layItem:setVisible(true);

    obj.layout1 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout1:setParent(obj.layItem);
    obj.layout1:setAlign("top");
    obj.layout1:setHeight(26);
    obj.layout1:setName("layout1");

    obj.rectTurn = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectTurn:setParent(obj.layout1);
    obj.rectTurn:setName("rectTurn");
    obj.rectTurn:setAlign("left");
    obj.rectTurn:setWidth(28);
    obj.rectTurn:setColor("#1B2F21");
    obj.rectTurn:setStrokeColor("#3CA95B");
    obj.rectTurn:setStrokeSize(1);
    obj.rectTurn:setXradius(4);
    obj.rectTurn:setYradius(4);

    obj.lblTurnIndicator = GUI.fromHandle(_obj_newObject("label"));
    obj.lblTurnIndicator:setParent(obj.rectTurn);
    obj.lblTurnIndicator:setName("lblTurnIndicator");
    obj.lblTurnIndicator:setAlign("client");
    obj.lblTurnIndicator:setText(">");
    lfm_setPropAsString(obj.lblTurnIndicator, "fontStyle", "bold");
    obj.lblTurnIndicator:setFontSize(15);
    obj.lblTurnIndicator:setFontColor("#63F28E");
    obj.lblTurnIndicator:setHorzTextAlign("center");
    obj.lblTurnIndicator:setVertTextAlign("center");

    obj.edtTeste = GUI.fromHandle(_obj_newObject("edit"));
    obj.edtTeste:setParent(obj.layout1);
    obj.edtTeste:setName("edtTeste");
    obj.edtTeste:setAlign("left");
    obj.edtTeste:setWidth(90);
    obj.edtTeste:setField("teste");
    obj.edtTeste:setMargins({left=6});

    obj.edtNome = GUI.fromHandle(_obj_newObject("edit"));
    obj.edtNome:setParent(obj.layout1);
    obj.edtNome:setName("edtNome");
    obj.edtNome:setAlign("client");
    obj.edtNome:setField("nome");
    obj.edtNome:setMargins({left=6});

    obj.edtIniciativa = GUI.fromHandle(_obj_newObject("edit"));
    obj.edtIniciativa:setParent(obj.layout1);
    obj.edtIniciativa:setName("edtIniciativa");
    obj.edtIniciativa:setAlign("left");
    obj.edtIniciativa:setWidth(56);
    obj.edtIniciativa:setField("iniciativa");
    obj.edtIniciativa:setType("float");
    obj.edtIniciativa:setHorzTextAlign("center");
    obj.edtIniciativa:setMargins({left=6, right=6});

    obj.btnFixar = GUI.fromHandle(_obj_newObject("button"));
    obj.btnFixar:setParent(obj.layout1);
    obj.btnFixar:setName("btnFixar");
    obj.btnFixar:setAlign("right");
    obj.btnFixar:setWidth(26);
    obj.btnFixar:setText("📍");
    obj.btnFixar:setHint("Fixar posição");

    obj.button2 = GUI.fromHandle(_obj_newObject("button"));
    obj.button2:setParent(obj.layout1);
    obj.button2:setAlign("right");
    obj.button2:setWidth(26);
    obj.button2:setText("X");
    obj.button2:setName("button2");

    obj.layTemp = GUI.fromHandle(_obj_newObject("layout"));
    obj.layTemp:setParent(obj.layItem);
    obj.layTemp:setName("layTemp");
    obj.layTemp:setAlign("top");
    obj.layTemp:setHeight(0);
    obj.layTemp:setVisible(false);
    obj.layTemp:setMargins({top=4});

    obj._e_event0 = obj:addEventListener("onNodeReady",
        function ()
            trackerItem.onNodeReady(self, sheet);
        end);

    obj._e_event1 = obj:addEventListener("onNodeUnready",
        function ()
            trackerItem.onNodeUnready(self);
        end);

    obj._e_event2 = obj.rectBg:addEventListener("onMenu",
        function (x, y, event)
            trackerItem.openContextMenu(self, sheet);
        end);

    obj._e_event3 = obj.rectBg:addEventListener("onStartDrag",
        function (drag, x, y, event)
            trackerItem.onStartDrag(self, sheet, drag);
        end);

    obj._e_event4 = obj.rectBg:addEventListener("onStartDrop",
        function (drop, x, y, drag, event)
            trackerItem.onStartDrop(self, sheet, drop);
        end);

    obj._e_event5 = obj.button1:addEventListener("onClick",
        function (event)
            trackerItem.onDeleteGroupClick(self, sheet);
        end);

    obj._e_event6 = obj.checkBox1:addEventListener("onChange",
        function ()
            trackerItem.onGroupActiveChange(self, sheet);
        end);

    obj._e_event7 = obj.edit1:addEventListener("onMenu",
        function (x, y, event)
            trackerItem.openContextMenu(self, sheet);
        end);

    obj._e_event8 = obj.rectTurn:addEventListener("onClick",
        function (event)
            trackerItem.onTurnClick(self, sheet);
        end);

    obj._e_event9 = obj.lblTurnIndicator:addEventListener("onClick",
        function (event)
            trackerItem.onTurnClick(self, sheet);
        end);

    obj._e_event10 = obj.edtTeste:addEventListener("onUserChange",
        function ()
            trackerItem.onFieldUserChange(sheet);
        end);

    obj._e_event11 = obj.edtTeste:addEventListener("onMenu",
        function (x, y, event)
            trackerItem.openContextMenu(self, sheet);
        end);

    obj._e_event12 = obj.edtNome:addEventListener("onUserChange",
        function ()
            trackerItem.onFieldUserChange(sheet);
        end);

    obj._e_event13 = obj.edtNome:addEventListener("onMenu",
        function (x, y, event)
            trackerItem.openContextMenu(self, sheet);
        end);

    obj._e_event14 = obj.edtIniciativa:addEventListener("onUserChange",
        function ()
            trackerItem.onFieldUserChange(sheet);
        end);

    obj._e_event15 = obj.edtIniciativa:addEventListener("onChange",
        function ()
            trackerItem.onInitChange(self);
        end);

    obj._e_event16 = obj.edtIniciativa:addEventListener("onMenu",
        function (x, y, event)
            trackerItem.openContextMenu(self, sheet);
        end);

    obj._e_event17 = obj.btnFixar:addEventListener("onClick",
        function (event)
            trackerItem.onPinClick(self, sheet);
        end);

    obj._e_event18 = obj.btnFixar:addEventListener("onMenu",
        function (x, y, event)
            trackerItem.openContextMenu(self, sheet);
        end);

    obj._e_event19 = obj.button2:addEventListener("onClick",
        function (event)
            trackerItem.onDeleteItemClick(sheet);
        end);

    obj._e_event20 = obj.button2:addEventListener("onMenu",
        function (x, y, event)
            trackerItem.openContextMenu(self, sheet);
        end);

    function obj:_releaseEvents()
        __o_rrpgObjs.removeEventListenerById(self._e_event20);
        __o_rrpgObjs.removeEventListenerById(self._e_event19);
        __o_rrpgObjs.removeEventListenerById(self._e_event18);
        __o_rrpgObjs.removeEventListenerById(self._e_event17);
        __o_rrpgObjs.removeEventListenerById(self._e_event16);
        __o_rrpgObjs.removeEventListenerById(self._e_event15);
        __o_rrpgObjs.removeEventListenerById(self._e_event14);
        __o_rrpgObjs.removeEventListenerById(self._e_event13);
        __o_rrpgObjs.removeEventListenerById(self._e_event12);
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

        if self.edtIniciativa ~= nil then self.edtIniciativa:destroy(); self.edtIniciativa = nil; end;
        if self.layGrupo ~= nil then self.layGrupo:destroy(); self.layGrupo = nil; end;
        if self.button2 ~= nil then self.button2:destroy(); self.button2 = nil; end;
        if self.edtTeste ~= nil then self.edtTeste:destroy(); self.edtTeste = nil; end;
        if self.layTemp ~= nil then self.layTemp:destroy(); self.layTemp = nil; end;
        if self.checkBox1 ~= nil then self.checkBox1:destroy(); self.checkBox1 = nil; end;
        if self.rectTurn ~= nil then self.rectTurn:destroy(); self.rectTurn = nil; end;
        if self.edtNome ~= nil then self.edtNome:destroy(); self.edtNome = nil; end;
        if self.button1 ~= nil then self.button1:destroy(); self.button1 = nil; end;
        if self.lblTurnIndicator ~= nil then self.lblTurnIndicator:destroy(); self.lblTurnIndicator = nil; end;
        if self.btnFixar ~= nil then self.btnFixar:destroy(); self.btnFixar = nil; end;
        if self.rectBg ~= nil then self.rectBg:destroy(); self.rectBg = nil; end;
        if self.edit1 ~= nil then self.edit1:destroy(); self.edit1 = nil; end;
        if self.layItem ~= nil then self.layItem:destroy(); self.layItem = nil; end;
        if self.layout1 ~= nil then self.layout1:destroy(); self.layout1 = nil; end;
        self:_oldLFMDestroy();
    end;

    obj:endUpdate();

    return obj;
end;

function newfrmTrackerItem()
    local retObj = nil;
    __o_rrpgObjs.beginObjectsLoading();

    __o_Utils.tryFinally(
      function()
        retObj = constructNew_frmTrackerItem();
      end,
      function()
        __o_rrpgObjs.endObjectsLoading();
      end);

    assert(retObj ~= nil);
    return retObj;
end;

local _frmTrackerItem = {
    newEditor = newfrmTrackerItem, 
    new = newfrmTrackerItem, 
    name = "frmTrackerItem", 
    dataType = "", 
    formType = "undefined", 
    formComponentName = "form", 
    cacheMode = "none", 
    title = "", 
    description=""};

frmTrackerItem = _frmTrackerItem;
Firecast.registrarForm(_frmTrackerItem);

return _frmTrackerItem;

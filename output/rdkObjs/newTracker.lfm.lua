require("firecast.lua");
local __o_rrpgObjs = require("rrpgObjs.lua");
require("rrpgGUI.lua");
require("rrpgDialogs.lua");
require("rrpgLFM.lua");
require("ndb.lua");
require("locale.lua");
local __o_Utils = require("utils.lua");

local function constructNew_newTracker()
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
    obj:setName("newTracker");
    obj:setFormType("tablesDock");
    obj:setDataType("br.com.rafilkl.newTracker");
    obj:setTitle("Tracker");
    obj:setTheme("dark");
    obj:setPadding({left=8, top=8, right=8, bottom=8});


        local trackerMain = require("trackerMain.lua");
    


    obj.layout1 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout1:setParent(obj);
    obj.layout1:setAlign("top");
    obj.layout1:setHeight(30);
    obj.layout1:setMargins({bottom=8});
    obj.layout1:setName("layout1");

    obj.btnGrupo = GUI.fromHandle(_obj_newObject("button"));
    obj.btnGrupo:setParent(obj.layout1);
    obj.btnGrupo:setName("btnGrupo");
    obj.btnGrupo:setAlign("left");
    obj.btnGrupo:setWidth(72);
    obj.btnGrupo:setText("Grupo");

    obj.btnAdicionar = GUI.fromHandle(_obj_newObject("button"));
    obj.btnAdicionar:setParent(obj.layout1);
    obj.btnAdicionar:setName("btnAdicionar");
    obj.btnAdicionar:setAlign("left");
    obj.btnAdicionar:setWidth(88);
    obj.btnAdicionar:setText("Items");
    obj.btnAdicionar:setMargins({left=4});

    obj.btnIniciativas = GUI.fromHandle(_obj_newObject("button"));
    obj.btnIniciativas:setParent(obj.layout1);
    obj.btnIniciativas:setName("btnIniciativas");
    obj.btnIniciativas:setAlign("left");
    obj.btnIniciativas:setWidth(96);
    obj.btnIniciativas:setText("Iniciativas");
    obj.btnIniciativas:setMargins({left=8});

    obj.rectangle1 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle1:setParent(obj);
    obj.rectangle1:setAlign("top");
    obj.rectangle1:setHeight(34);
    obj.rectangle1:setColor("#1A1F25");
    obj.rectangle1:setStrokeColor("#2F3945");
    obj.rectangle1:setStrokeSize(1);
    obj.rectangle1:setXradius(4);
    obj.rectangle1:setYradius(4);
    obj.rectangle1:setMargins({bottom=6});
    obj.rectangle1:setPadding({left=4, top=4, right=4, bottom=4});
    obj.rectangle1:setName("rectangle1");

    obj.layout2 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout2:setParent(obj.rectangle1);
    obj.layout2:setAlign("client");
    obj.layout2:setName("layout2");

    obj.label1 = GUI.fromHandle(_obj_newObject("label"));
    obj.label1:setParent(obj.layout2);
    obj.label1:setAlign("left");
    obj.label1:setWidth(28);
    obj.label1:setText("vez");
    lfm_setPropAsString(obj.label1, "fontStyle", "bold");
    obj.label1:setFontSize(14);
    obj.label1:setFontColor("#B8C7D6");
    obj.label1:setHorzTextAlign("center");
    obj.label1:setVertTextAlign("center");
    obj.label1:setName("label1");

    obj.label2 = GUI.fromHandle(_obj_newObject("label"));
    obj.label2:setParent(obj.layout2);
    obj.label2:setAlign("left");
    obj.label2:setWidth(90);
    obj.label2:setText("teste");
    obj.label2:setMargins({left=6});
    lfm_setPropAsString(obj.label2, "fontStyle", "bold");
    obj.label2:setFontSize(14);
    obj.label2:setFontColor("#B8C7D6");
    obj.label2:setHorzTextAlign("center");
    obj.label2:setVertTextAlign("center");
    obj.label2:setName("label2");

    obj.label3 = GUI.fromHandle(_obj_newObject("label"));
    obj.label3:setParent(obj.layout2);
    obj.label3:setAlign("client");
    obj.label3:setText("nome");
    obj.label3:setMargins({left=6});
    lfm_setPropAsString(obj.label3, "fontStyle", "bold");
    obj.label3:setFontSize(14);
    obj.label3:setFontColor("#B8C7D6");
    obj.label3:setHorzTextAlign("center");
    obj.label3:setVertTextAlign("center");
    obj.label3:setName("label3");

    obj.label4 = GUI.fromHandle(_obj_newObject("label"));
    obj.label4:setParent(obj.layout2);
    obj.label4:setAlign("left");
    obj.label4:setWidth(56);
    obj.label4:setText("init");
    obj.label4:setMargins({left=6, right=6});
    lfm_setPropAsString(obj.label4, "fontStyle", "bold");
    obj.label4:setFontSize(14);
    obj.label4:setFontColor("#B8C7D6");
    obj.label4:setHorzTextAlign("center");
    obj.label4:setVertTextAlign("center");
    obj.label4:setName("label4");

    obj.label5 = GUI.fromHandle(_obj_newObject("label"));
    obj.label5:setParent(obj.layout2);
    obj.label5:setAlign("right");
    obj.label5:setWidth(26);
    obj.label5:setText("");
    obj.label5:setName("label5");

    obj.label6 = GUI.fromHandle(_obj_newObject("label"));
    obj.label6:setParent(obj.layout2);
    obj.label6:setAlign("right");
    obj.label6:setWidth(26);
    obj.label6:setText("");
    obj.label6:setName("label6");

    obj.layout3 = GUI.fromHandle(_obj_newObject("layout"));
    obj.layout3:setParent(obj);
    obj.layout3:setAlign("bottom");
    obj.layout3:setHeight(30);
    obj.layout3:setMargins({top=8});
    obj.layout3:setName("layout3");

    obj.btnProximoTurno = GUI.fromHandle(_obj_newObject("button"));
    obj.btnProximoTurno:setParent(obj.layout3);
    obj.btnProximoTurno:setName("btnProximoTurno");
    obj.btnProximoTurno:setAlign("left");
    obj.btnProximoTurno:setWidth(112);
    obj.btnProximoTurno:setText("Proximo Turno");

    obj.label7 = GUI.fromHandle(_obj_newObject("label"));
    obj.label7:setParent(obj.layout3);
    obj.label7:setAlign("left");
    obj.label7:setWidth(52);
    obj.label7:setText("Rodada");
    obj.label7:setMargins({left=8});
    obj.label7:setName("label7");

    obj.edit1 = GUI.fromHandle(_obj_newObject("edit"));
    obj.edit1:setParent(obj.layout3);
    obj.edit1:setAlign("left");
    obj.edit1:setWidth(60);
    obj.edit1:setField("rodada");
    obj.edit1:setType("number");
    obj.edit1:setHorzTextAlign("center");
    obj.edit1:setName("edit1");

    obj.rclLista = GUI.fromHandle(_obj_newObject("recordList"));
    obj.rclLista:setParent(obj);
    obj.rclLista:setName("rclLista");
    obj.rclLista:setField("itens");
    obj.rclLista:setTemplateForm("frmTrackerItem");
    obj.rclLista:setAlign("client");
    obj.rclLista:setSelectable(false);

    obj._e_event0 = obj:addEventListener("onNodeReady",
        function ()
            trackerMain.onNodeReady(self, sheet);
        end);

    obj._e_event1 = obj:addEventListener("onNodeUnready",
        function ()
            trackerMain.onNodeUnready(self);
        end);

    obj._e_event2 = obj:addEventListener("onShow",
        function ()
            trackerMain.onFormShow(self, sheet);
        end);

    obj._e_event3 = obj.btnGrupo:addEventListener("onClick",
        function (event)
            trackerMain.openToolbarGroupMenu(self, sheet, self.btnGrupo);
        end);

    obj._e_event4 = obj.btnAdicionar:addEventListener("onClick",
        function (event)
            trackerMain.openToolbarAddMenu(self, sheet, self.btnAdicionar);
        end);

    obj._e_event5 = obj.btnIniciativas:addEventListener("onClick",
        function (event)
            trackerMain.openToolbarInitiativesMenu(self, sheet, self.btnIniciativas);
        end);

    obj._e_event6 = obj.btnProximoTurno:addEventListener("onClick",
        function (event)
            trackerMain.nextTurn(sheet);
        end);

    obj._e_event7 = obj.rclLista:addEventListener("onCompare",
        function (nodeA, nodeB)
            return trackerMain.compareListNodes(sheet, nodeA, nodeB);
        end);

    function obj:_releaseEvents()
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

        if self.btnIniciativas ~= nil then self.btnIniciativas:destroy(); self.btnIniciativas = nil; end;
        if self.label2 ~= nil then self.label2:destroy(); self.label2 = nil; end;
        if self.rclLista ~= nil then self.rclLista:destroy(); self.rclLista = nil; end;
        if self.rectangle1 ~= nil then self.rectangle1:destroy(); self.rectangle1 = nil; end;
        if self.label6 ~= nil then self.label6:destroy(); self.label6 = nil; end;
        if self.label1 ~= nil then self.label1:destroy(); self.label1 = nil; end;
        if self.layout3 ~= nil then self.layout3:destroy(); self.layout3 = nil; end;
        if self.label5 ~= nil then self.label5:destroy(); self.label5 = nil; end;
        if self.btnAdicionar ~= nil then self.btnAdicionar:destroy(); self.btnAdicionar = nil; end;
        if self.layout2 ~= nil then self.layout2:destroy(); self.layout2 = nil; end;
        if self.label4 ~= nil then self.label4:destroy(); self.label4 = nil; end;
        if self.label3 ~= nil then self.label3:destroy(); self.label3 = nil; end;
        if self.btnProximoTurno ~= nil then self.btnProximoTurno:destroy(); self.btnProximoTurno = nil; end;
        if self.btnGrupo ~= nil then self.btnGrupo:destroy(); self.btnGrupo = nil; end;
        if self.edit1 ~= nil then self.edit1:destroy(); self.edit1 = nil; end;
        if self.label7 ~= nil then self.label7:destroy(); self.label7 = nil; end;
        if self.layout1 ~= nil then self.layout1:destroy(); self.layout1 = nil; end;
        self:_oldLFMDestroy();
    end;

    obj:endUpdate();

    return obj;
end;

function newnewTracker()
    local retObj = nil;
    __o_rrpgObjs.beginObjectsLoading();

    __o_Utils.tryFinally(
      function()
        retObj = constructNew_newTracker();
      end,
      function()
        __o_rrpgObjs.endObjectsLoading();
      end);

    assert(retObj ~= nil);
    return retObj;
end;

local _newTracker = {
    newEditor = newnewTracker, 
    new = newnewTracker, 
    name = "newTracker", 
    dataType = "br.com.rafilkl.newTracker", 
    formType = "tablesDock", 
    formComponentName = "form", 
    cacheMode = "none", 
    title = "Tracker", 
    description=""};

newTracker = _newTracker;
Firecast.registrarForm(_newTracker);
Firecast.registrarDataType(_newTracker);
Firecast.registrarSpecialForm(_newTracker);

return _newTracker;

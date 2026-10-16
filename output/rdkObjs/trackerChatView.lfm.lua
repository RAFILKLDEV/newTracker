require("firecast.lua");
local __o_rrpgObjs = require("rrpgObjs.lua");
require("rrpgGUI.lua");
require("rrpgDialogs.lua");
require("rrpgLFM.lua");
require("ndb.lua");
require("locale.lua");
local __o_Utils = require("utils.lua");

local function constructNew_frmTrackerChatView()
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
    obj:setName("frmTrackerChatView");
    obj:setFormType("tablesDock");
    obj:setDataType("br.com.rafilkl.newTracker.chat");
    obj:setTitle("Chat Avançado");
    obj:setTheme("dark");


        local trackerChat = require("trackerChat.lua");
    


    obj.rectangle1 = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.rectangle1:setParent(obj);
    obj.rectangle1:setAlign("client");
    obj.rectangle1:setColor("#242424");
    obj.rectangle1:setStrokeSize(0);
    obj.rectangle1:setStrokeColor("transparent");
    obj.rectangle1:setPadding({left=28, top=12, right=12, bottom=10});
    obj.rectangle1:setName("rectangle1");

    obj.statusLabel = GUI.fromHandle(_obj_newObject("label"));
    obj.statusLabel:setParent(obj.rectangle1);
    obj.statusLabel:setName("statusLabel");
    obj.statusLabel:setAlign("bottom");
    obj.statusLabel:setHeight(0);
    obj.statusLabel:setFontSize(11);
    obj.statusLabel:setVisible(false);
    obj.statusLabel:setFontColor("#B8C3CE");
    obj.statusLabel:setWordWrap(true);
    obj.statusLabel:setTextTrimming("none");
    obj.statusLabel:setVertTextAlign("leading");

    obj.composerCard = GUI.fromHandle(_obj_newObject("rectangle"));
    obj.composerCard:setParent(obj.rectangle1);
    obj.composerCard:setName("composerCard");
    obj.composerCard:setAlign("bottom");
    obj.composerCard:setHeight(124);
    obj.composerCard:setColor("#414141");
    obj.composerCard:setStrokeColor("transparent");
    obj.composerCard:setStrokeSize(0);
    obj.composerCard:setXradius(5);
    obj.composerCard:setYradius(5);
    obj.composerCard:setMargins({top=12});

    obj.composer = GUI.fromHandle(_obj_newObject("layout"));
    obj.composer:setParent(obj.composerCard);
    obj.composer:setName("composer");
    obj.composer:setAlign("client");
    obj.composer:setMargins({left=10, top=8, right=10, bottom=8});

    obj.chatTools = GUI.fromHandle(_obj_newObject("layout"));
    obj.chatTools:setParent(obj.rectangle1);
    obj.chatTools:setName("chatTools");
    obj.chatTools:setAlign("top");
    obj.chatTools:setHeight(24);
    obj.chatTools:setMargins({left=10, right=10, bottom=6});

    obj.messageHost = GUI.fromHandle(_obj_newObject("layout"));
    obj.messageHost:setParent(obj.rectangle1);
    obj.messageHost:setName("messageHost");
    obj.messageHost:setAlign("client");

    obj._e_event0 = obj:addEventListener("onNodeReady",
        function ()
            trackerChat.mount(self, sheet);
        end);

    obj._e_event1 = obj:addEventListener("onShow",
        function ()
            trackerChat.mount(self, sheet);
        end);

    obj._e_event2 = obj:addEventListener("onNodeUnready",
        function ()
            trackerChat.unmount(self);
        end);

    obj._e_event3 = obj:addEventListener("onHide",
        function ()
            trackerChat.hide(self);
        end);

    function obj:_releaseEvents()
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

        if self.statusLabel ~= nil then self.statusLabel:destroy(); self.statusLabel = nil; end;
        if self.composer ~= nil then self.composer:destroy(); self.composer = nil; end;
        if self.chatTools ~= nil then self.chatTools:destroy(); self.chatTools = nil; end;
        if self.composerCard ~= nil then self.composerCard:destroy(); self.composerCard = nil; end;
        if self.rectangle1 ~= nil then self.rectangle1:destroy(); self.rectangle1 = nil; end;
        if self.messageHost ~= nil then self.messageHost:destroy(); self.messageHost = nil; end;
        self:_oldLFMDestroy();
    end;

    obj:endUpdate();

    return obj;
end;

function newfrmTrackerChatView()
    local retObj = nil;
    __o_rrpgObjs.beginObjectsLoading();

    __o_Utils.tryFinally(
      function()
        retObj = constructNew_frmTrackerChatView();
      end,
      function()
        __o_rrpgObjs.endObjectsLoading();
      end);

    assert(retObj ~= nil);
    return retObj;
end;

local _frmTrackerChatView = {
    newEditor = newfrmTrackerChatView, 
    new = newfrmTrackerChatView, 
    name = "frmTrackerChatView", 
    dataType = "br.com.rafilkl.newTracker.chat", 
    formType = "tablesDock", 
    formComponentName = "form", 
    cacheMode = "none", 
    title = "Chat Avançado", 
    description=""};

frmTrackerChatView = _frmTrackerChatView;
Firecast.registrarForm(_frmTrackerChatView);
Firecast.registrarDataType(_frmTrackerChatView);
Firecast.registrarSpecialForm(_frmTrackerChatView);

return _frmTrackerChatView;

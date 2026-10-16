require("firecast.lua");
local __o_rrpgObjs = require("rrpgObjs.lua");
require("rrpgGUI.lua");
require("rrpgDialogs.lua");
require("rrpgLFM.lua");
require("ndb.lua");
require("locale.lua");
local __o_Utils = require("utils.lua");

local function constructNew_frmTrackerChatMessage()
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
    obj:setName("frmTrackerChatMessage");
    obj:setHeight(80);
    obj:setTheme("dark");


        local chatView = require("trackerChatView.lua");
    


    obj._e_event0 = obj:addEventListener("onNodeReady",
        function ()
            chatView.mountMessage(self, sheet);
        end);

    obj._e_event1 = obj:addEventListener("onNodeUnready",
        function ()
            chatView.unmountMessage(self);
        end);

    obj._e_event2 = obj:addEventListener("onResize",
        function ()
            chatView.resizeMessage(self);
        end);

    function obj:_releaseEvents()
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

        self:_oldLFMDestroy();
    end;

    obj:endUpdate();

    return obj;
end;

function newfrmTrackerChatMessage()
    local retObj = nil;
    __o_rrpgObjs.beginObjectsLoading();

    __o_Utils.tryFinally(
      function()
        retObj = constructNew_frmTrackerChatMessage();
      end,
      function()
        __o_rrpgObjs.endObjectsLoading();
      end);

    assert(retObj ~= nil);
    return retObj;
end;

local _frmTrackerChatMessage = {
    newEditor = newfrmTrackerChatMessage, 
    new = newfrmTrackerChatMessage, 
    name = "frmTrackerChatMessage", 
    dataType = "", 
    formType = "undefined", 
    formComponentName = "form", 
    cacheMode = "none", 
    title = "", 
    description=""};

frmTrackerChatMessage = _frmTrackerChatMessage;
Firecast.registrarForm(_frmTrackerChatMessage);

return _frmTrackerChatMessage;

local NAME = "UtilityName"

local AceAddon = LibStub("AceAddon-3.0");
local addon = AceAddon:GetAddon("PlatesClasses");

local util = {}
addon.Utils[NAME] = util;

function util:Hello()
	print("hello!");
end
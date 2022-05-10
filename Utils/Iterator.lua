local AceAddon = LibStub("AceAddon-3.0");
local addon = AceAddon:GetAddon("PlatesClasses");

local Iterator = {}
addon.Utils.Iterator = Iterator;

function Iterator:New(startValue, increment)
	if startValue == nil then
		startValue = -1;
	end
	
	if increment == nil then
		increment = 1;
	end
	
	local iterator = function()
		startValue = startValue + increment
		return startValue;
	end
	
	return iterator;
end
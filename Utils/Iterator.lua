local AceAddon = LibStub("AceAddon-3.0");
local addon = AceAddon:GetAddon("PlatesClasses");

local Iterator = {}
addon.Utils.Iterator = Iterator;

-- old version is slightly faster but not reusable
-- function Iterator:New(startValue, increment)
-- 	if startValue == nil then
-- 		startValue = -1;
-- 	end
	
-- 	if increment == nil then
-- 		increment = 1;
-- 	end
	
-- 	local iterator = function()
-- 		startValue = startValue + increment
-- 		return startValue;
-- 	end
	
-- 	return iterator;
-- end

local METATABLE = {
	__call = function(tbl) 
		tbl.value = tbl.value + tbl.increment
		return tbl.value
	 end
}

function Iterator:New(startValue, increment)
	local iterator = {
		value = startValue or -1,
		increment = increment or 1,
	}

	setmetatable(iterator, METATABLE)

	return iterator
end
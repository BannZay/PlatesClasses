local AceAddon = LibStub("AceAddon-3.0");
local addon = AceAddon:GetAddon("PlatesClasses");

local DbConfig = {}
addon.Utils.DbConfig = DbConfig;

function DbConfig:New(dbProvider, onValueUpdatedFunc)
	local obj = {}
	
	function obj.Get(info)
		local key = info.arg or info[#info];
		return dbProvider(key)[key];
	end
	
	function obj.Set(info, value)
		local key = info.arg or info[#info];
		dbProvider(key)[key] = value;
		
		if onValueUpdatedFunc ~= nil then
			onValueUpdatedFunc(key, value);
		end
	end

	function obj:BuildSetter(onUpdatedFunc)
		return function(info, value)
			obj.Set(info, value);
			
			if onUpdatedFunc ~= nil then
				onUpdatedFunc(value);
			end
		end
	end
	
	return obj;
end

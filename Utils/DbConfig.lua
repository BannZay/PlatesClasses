local AceAddon = LibStub("AceAddon-3.0");
local addon = AceAddon:GetAddon("PlatesClasses");
local LibLogger = LibStub("LibLogger-1.0");

local log = LibLogger:New(addon);

local DbConfig = {}
addon.Utils.DbConfig = DbConfig;

function DbConfig:New(dbProvider)
	local obj = {}
	
	function obj.Get(info)
		local key = info.arg or info[#info];
		return dbProvider(key)[key];
	end
	
	function obj.Set(info, value)
		local key = info.arg or info[#info];
		dbProvider(key)[key] = value;
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

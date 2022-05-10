local AceAddon = LibStub("AceAddon-3.0");
local AceDb = LibStub("AceDB-3.0");
local LibLogger = LibStub("LibLogger-1.0");
local AceConfig = LibStub("AceConfig-3.0");
local AceConfigDialog = LibStub("AceConfigDialog-3.0");

local addon = AceAddon:GetAddon("PlatesClasses");
local log = LibLogger:New(addon);
local module = addon:NewModule("Cache");
module.cachingStorages = {}

local Utils = addon.Utils;

local oldStorages = {}

function module:OnInitialize()
	self.cachingStorages = 
	{
		PlayerClasses = self:CreateStorage("PlayerClasses")
	}

	self.oldStorages = {}
end

function module:OnDbInitialized(db, dbRoot)
	self:SetEnabledState(self.db.Enabled or true);
	self.Cache = dbRoot.global.Cache
end

function module:GetDbMigrations()
	local migrations = {}

	migrations[1] = function(db, dbRoot)
		db.Enabled = true;
		
		dbRoot.global.Cache = 
		{
			PlayerClasses = {}
		}
	end

	return migrations;
end

function module:OnEnable()
	for categoryName, storage in pairs(self.cachingStorages) do
		self.oldStorages[categoryName] = addon:GetStorage(categoryName);
		addon:SetStorage("PlayerClasses", storage);
	end
end

function module:OnDisable()
	for categoryName, storage in pairs(self.oldStorages) do
		addon:SetStorage(categoryName, storage);
	end
end

function module:CreateStorage(category)
	if category == nil or type(category) ~= "string" then
		error()
	end
	
	local get = function(storage, key) return self.Cache[category][key] end
	local set = function(storage, key, value) self.Cache[category][key] = value end
	local reset = function(storage, key) self.Cache[category] = {} end
	
	return {
		Category = category,
		Get = get,
		Set = set,
		Reset = reset
	}
end

function module:BuildBlizzardOptions()
	local dbConnection = Utils.DbConfig:New(function(key) return self.db end);
	local iterator = Utils.Iterator:New();
	
	local options = 
	{
		type = "group",
		name = module.moduleName,
		get = dbConnection.Get,
		set = dbConnection.Set,
		args = {}
	}
	
	options.args["Description"] = 
	{
		type = "description",
		name = "Caches classes of players to accounts config.",
		fontSize = "medium",
		order = iterator()
	}
	
	options.args["Enabled"] = 
	{
		type = "toggle",
		name = "Enabled",
		desc = "",
		set = dbConnection:BuildSetter(function(newState) if newState then module:Enable() else module:Disable() end end),
		order = iterator()
	}
	
	options.args["Reset"] = 
	{
		type = "execute",
		name = "Reset Cache",
		func = function() for categoryName, storage in pairs(self.cachingStorages) do storage:Reset(); end addon:UpdateAllNameplates() end,
		order = iterator(),
		confirm = true
	}
	
	return options
end
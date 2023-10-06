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
	self.cachingStorages = {}

	local platesClassesModule = addon:GetModule("PlatesClasses")
	self.cachingStorages[tostring(platesClassesModule)] = self:CreateStorage(platesClassesModule);

	self.oldStorages = {}
end

function module:OnDbInitialized(db, dbRoot)
	local enabled = (self.db.Enabled == true) or (self.db.Enabled == nil)
	self:SetEnabledState(enabled)
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
	
	migrations[2] = function(db, dbRoot)
		local cache = dbRoot.global.Cache;
		local platesClassesModule = addon:GetModule("PlatesClasses")
		local categoryName = tostring(platesClassesModule);
		-- change category name
		cache[categoryName] = cache.PlayerClasses
		cache.PlayerClasses = nil
		-- use PlayerClassConverter
		for i,k in pairs(cache[categoryName]) do
			cache[categoryName][i] = self.PlayerClassConverter:ToConfig(k)
		end
	end

	return migrations;
end

function module:OnEnable()
	for categoryName, storage in pairs(self.cachingStorages) do
		self.oldStorages[categoryName] = addon:GetStorage(categoryName);
		addon:SetStorage(categoryName, storage);
	end
end

function module:OnDisable()
	for categoryName, storage in pairs(self.oldStorages) do
		addon:SetStorage(categoryName, storage);
	end
end

function module:CreateStorage(category)
	if category == nil then
		error()
	end
	
	category = tostring(category)
	
	local get = function(storage, key) return self.PlayerClassConverter:ToOriginal(self.Cache[category][key]) end
	local set = function(storage, key, value) self.Cache[category][key] = self.PlayerClassConverter:ToConfig(value) end
	local reset = function(storage, key) self.Cache[category] = {} end
	
	return {
		Category = category,
		Get = get,
		Set = set,
		Reset = reset
	}
end

function module:BuildBlizzardOptions()
	local dbConnection = Utils.DbConfig:New(function(key) return self.db end, nil, self);
	local iterator = Utils.Iterator:New();
	
	local options = {}
	
	options["Reset"] = 
	{
		type = "execute",
		name = "Reset Cache",
		func = function() for categoryName, storage in pairs(self.cachingStorages) do storage:Reset(); end addon:UpdateNameplates() end,
		order = iterator(),
		confirm = true
	}
	
	return options
end
local AceAddon = LibStub("AceAddon-3.0");
local AceDb = LibStub("AceDB-3.0");
local LibLogger = LibStub("LibLogger-1.0");
local AceConfig = LibStub("AceConfig-3.0");
local AceConfigDialog = LibStub("AceConfigDialog-3.0");

local addon = AceAddon:GetAddon("PlatesClasses");
local displayName = "Cache";
local log = LibLogger:New(addon);
local module = addon:NewModule(displayName);
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
		
		-- cached data lives in global namespace to avoid duplications
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

	migrations[3] = function(db, dbRoot)
		for category, cache in pairs(dbRoot.global.Cache) do
			local count = 0
			
			for _ in pairs(cache) do
				count = count + 1 
			end
			
			cache._count = count
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
	local set = function(storage, key, value) 
		local cache = self.Cache[category]
		local oldValue = cache[key]
			cache[key] = self.PlayerClassConverter:ToConfig(value) 
			if oldValue == nil then
				cache._count = cache._count + 1 
			end
		end
	local reset = function(storage) self.Cache[category] = { _count = 0 } end
	local itemsCount = function (storage) return self.Cache[category]._count end
	
	return {
		Category = category,
		Get = get,
		Set = set,
		Reset = reset,
		ItemsCount = itemsCount
	}
end

function module:BuildBlizzardOptions(iterator)	
	local options = {}
	
	options["Count"] = 
	{
		type = "description",
		name = function() return "Items count:" .. tostring(self.cachingStorages[tostring(addon:GetModule("PlatesClasses"))]:ItemsCount()) end,
		fontSize = "medium",
		order = iterator(),
	}

	options["Reset"] = 
	{
		type = "execute",
		name = "Reset Cache",
		func = function() for categoryName, storage in pairs(self.cachingStorages) do storage:Reset(); end addon:UpdateNameplates() end,
		order = iterator(),
		confirm = true
	}
	
	return options, nil, "Remembers scanned players classes so you dont have to hover over them even after the game restart"
end
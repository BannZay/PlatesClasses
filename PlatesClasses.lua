local ADDON_NAME = "PlatesClasses";
local ADDON_PATH = "Interface\\Addons\\" .. ADDON_NAME;
local LOGLEVEL = -1;
local DBVERSION = 1;

local AceAddon = LibStub("AceAddon-3.0");
local AceConfig = LibStub("AceConfig-3.0");
local AceDb = LibStub("AceDB-3.0");
local AceDBOptions = LibStub("AceDBOptions-3.0");
local AceConfig = LibStub("AceConfig-3.0");
local AceConfigDialog = LibStub("AceConfigDialog-3.0");
local LibEvents = LibStub("LibEvents-1.0");
local LibLogger = LibStub("LibLogger-1.0");
local CallbackHandler = LibStub("CallbackHandler-1.0");
local LibNameplate = LibStub("LibNameplate-1.0");
local AceTimer = LibStub("AceTimer-3.0");

local addon = AceAddon:NewAddon(ADDON_NAME, "AceConsole-3.0");
addon.path = ADDON_PATH;
addon.logLevel = LOGLEVEL;
addon.Utils = {};
addon.OnModuleCreated = function(self, module) module.logLevel = LOGLEVEL end;
addon.callbacks = CallbackHandler:New(addon);

local log = LibLogger:New(addon);
local Utils = addon.Utils;

function addon:OnInitialize()
	local dbDefaults = 
	{
		profile = 
		{
			modules = {},
			Enabled = true,
			UpdateFrequency = 1;
			Version = 0
		}
	};
	local db = AceDb:New("PlatesClassesDB", dbDefaults, true);
	db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged");
	db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged");
	db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged");
	self:OnProfileChanged("self-call", db)
	
	self.storages = { };
	
	local slashHandler = function(option)
		option = string.lower(option)
		if option == "enable" then
			addon:Enable();
		elseif option == "disable" then
			addon:Disable();
		else
			InterfaceOptionsFrame_OpenToCategory(addon.name);
		end
	end
	
	self:RegisterChatCommand(addon.name, slashHandler)
	self:RegisterChatCommand("pc", slashHandler)
	self:SetEnabledState(self.db.Enabled);
end

function addon:OnModulesInitialized()
	AceConfig:RegisterOptionsTable(self.name, {type= "group", name = self.name, args = {}});
	AceConfigDialog:AddToBlizOptions(self.name, self.name);
	
	for name, subModule in self:IterateModules() do
		if subModule.BuildBlizzardOptions ~= nil then
			local options = subModule:BuildBlizzardOptions()
			if options == nil then
				error("Module " .. name .. " returned nil options.");
			end
			local key = self.name .. subModule.moduleName;
			AceConfig:RegisterOptionsTable(key, options);
			AceConfigDialog:AddToBlizOptions(key, subModule.moduleName, self.name);
		end
	end
	
	local profileOptions = AceDBOptions:GetOptionsTable(self.dbRoot, "Default")
	AceConfig:RegisterOptionsTable(self.name .. "Profiles", profileOptions);
	AceConfigDialog:AddToBlizOptions(self.name .. "Profiles", "Profiles", self.name);
end

function addon:OnEnable()
	if not self.Initialized then
		-- AceAddon does not provide other way to execute code right after all modules were initialized
		self:OnModulesInitialized();
		self.Initialized = true;
	end
	
	LibNameplate.RegisterCallback(self, "LibNameplate_NewNameplate", function(event, ...) self:OnNameplateCreated(...) end)
	LibNameplate.RegisterCallback(self, "LibNameplate_FoundGUID", function(event, ...) self:OnNameplateDiscoveredGuid(...) end )
	LibNameplate.RegisterCallback(self, "LibNameplate_RecycleNameplate", function(event, ...) self:OnNameplateRecycled(...) end )
	
	self.timer = AceTimer:ScheduleRepeatingTimer(function() self:UpdateNameplates(true) end, self.db.UpdateFrequency);
	
	self:UpdateNameplates();
end

function addon:OnDisable()
	if self.timer ~= nil then
		AceTimer:CancelTimer(self.timer);
	end
	LibNameplate.UnregisterAllCallbacks(self);
	
	self:UpdateNameplates();
end

function addon:GetDbMigrations()
	local migrations = {}
	
	migrations[1] = function(db)
		db.modules = {}
	end
	
	return migrations;
end

function addon:InitializeDb(module, moduleDb, targetVersion)
	if moduleDb == nil then
		moduleDb = module.db;
		
		if moduleDb == nil then
			error("db was nil");
		end
	end
	
	module.db = moduleDb;

	if moduleDb.Version == nil then
		moduleDb.Version = 0;
	end
	
	if moduleDb.Version ~= targetVersion then
		if type(moduleDb.Version) ~= "number" then
			error("module '" .. module.name .. "' has invalid database version");
		end
	
		if module.GetDbMigrations ~= nil then
			local migrations = module:GetDbMigrations();
			
			for migrationVersion, migration in pairs(migrations) do
				local oldDbVersion = moduleDb.Version;
				if migrationVersion > moduleDb.Version then
					migration(moduleDb, self.dbRoot); -- upgrade db to the next version
					moduleDb.Version = migrationVersion;
					log:Log(10, "Upgraded module '", tostring(module), "'db version from", oldDbVersion, "to", moduleDb.Version);
				end
			end
		end
	end
	
	if module.OnDbInitialized ~= nil then
		module:OnDbInitialized(moduleDb, self.dbRoot);
	end
end


function addon:OnNameplateCreated(nameplate)
	self:UpdateNameplate(nameplate)
end

function addon:OnNameplateRecycled(nameplate)
	nameplate.unitId = nil;
	nameplate.GUID = nil;

	addon.callbacks:Fire("OnNameplateRecycled", nameplate);
end

function addon:OnNameplateDiscoveredGuid(nameplate, GUID, unitID)
	nameplate.unitId = unitID;
	nameplate.GUID = GUID;
	
	self:UpdateNameplate(nameplate)
end

function addon:UpdateNameplate(nameplateOrName, fastUpdate)
	if nameplateOrName == nil then
		error("nameplateOrName must be either nameplate or name. It was nil");
	end
	
	if type(nameplateOrName) == "string" then
		nameplateOrName = LibNameplate:GetNameplateByName(nameplateOrName);
	end
	
	if nameplateOrName ~= nil then
		local name = LibNameplate:GetName(nameplateOrName);
		addon.callbacks:Fire("OnNameplateUpdating", nameplateOrName, fastUpdate, name);
		self:UpdateAppearence(nameplate, fastUpdate)
	end
end

function addon:UpdateNameplateAppearence(nameplate, fastUpdate)
	local name = LibNameplate:GetName(nameplate);
	addon.callbacks:Fire("OnNameplateAppearenceUpdating", nameplate, fastUpdate, name);
end

function addon:UpdateNameplates(fastUpdate)
	local nameplatesList = {LibNameplate:GetAllNameplates()};
	log:Log(30, "Updating",  nameplatesList[1], "nameplate(s). FastUpdate =", fastUpdate or "false");
	for i = 2, nameplatesList[1]+1 do
		local nameplate = nameplatesList[i];
		self:UpdateNameplate(nameplate, fastUpdate);
	end
end

function addon:UpdateAppearence(fastUpdate)
	local nameplatesList = {LibNameplate:GetAllNameplates()};
	log:Log(30, "Updating",  nameplatesList[1], "nameplate(s) appearence. FastUpdate =", fastUpdate or "false");
	for i = 2, nameplatesList[1]+1 do
		local nameplate = nameplatesList[i];
		self:UpdateNameplateAppearence(nameplate, fastUpdate);
	end
end

function addon:UpdateTimer()
	self.timer.delay = self.db.UpdateFrequency;
end

-- { storage1 = {function get(self, key), function set(self, key, value), function reset(self)}, storage2 = {...}, ... }
function addon:CreateStorage(getFunc, setFunc, resetFunc)
	local storage = {}
	
	if getFunc == nil then
		storage.storage = {}
		getFunc = function(self, playerName) return self.storage[playerName] end;
		setFunc = function(self, playerName, unifiedClass) self.storage[playerName] = unifiedClass end;
		resetFunc = function(self) self.storage = {} end
	end
	
	storage.Get = getFunc;
	storage.Set = setFunc;
	storage.Reset = resetFunc;

	return storage;
end

function addon:SetStorage(categoryName, storage)
	if storage == nil then 
		error() 
	end
	
	self.storages[categoryName] = storage;
end

function addon:GetStorage(categoryName)
	return self.storages[tostring(categoryName)];
end

function addon:OnProfileChanged(_, database)
	self.dbRoot = database;
	self:InitializeDb(self, database.profile, DBVERSION);
	
	for name, subModule in self:IterateModules() do
		if self.db.modules[subModule.name] == nil then
			self.db.modules[subModule.name] = {};
		end
		
		local subModuleDb = self.db.modules[subModule.name]
		
		self:InitializeDb(subModule, subModuleDb, subModule.Version or self.db.Version);
		subModule:SetEnabledState(subModuleDb.Enabled);
	end
	
	if self.Initialized then
		self:Disable();
		if self.db.Enabled then
			self:Enable();
		end
		self:UpdateAppearence();
	end
	
end

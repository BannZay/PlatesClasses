local ADDON_NAME = "PlatesClasses";
local ADDON_PATH = "Interface\\Addons\\" .. ADDON_NAME;
local LOGLEVEL = -1;

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
	
	log:SetMaximumLogLevel(self.dbRoot.global.LogLevel);
	
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

function addon:BuildBlizzardOptions()
	local dbConnection = Utils.DbConfig:New(function(key) return self.dbRoot.global end, nil, self);
	local options = 
	{
		Description = 
		{
			type = "description",
			name = "Core module",
			fontSize = "medium",
			order = 0
		},
		LogLevel = 
		{
			type = "range",
			name = "Log level",
			step = 1,
			min = -1,
			max = 100,
			get = dbConnection.Get,
			set = dbConnection:BuildSetter(function(value) log:SetMaximumLogLevel(value) end),
			order = 1
		}
	}

	return options
end

function addon:OnModulesInitialized()
	AceConfig:RegisterOptionsTable(self.name, {type= "group", name = self.name, args = self:BuildBlizzardOptions() });
	AceConfigDialog:AddToBlizOptions(self.name, self.name);
	
	for name, subModule in self:IterateModules() do
		if subModule.BuildBlizzardOptions ~= nil then
			local groups, displayName, description = subModule:BuildBlizzardOptions()
			if groups == nil then
				error("Module " .. name .. " returned nil options.");
			end
			
			if displayName == nil then
				displayName = subModule.moduleName;
			end
			
			local dbConnection = Utils.DbConfig:New(function(key) return subModule.db end, nil, self);
			local options = 
			{
				type = "group",
				name = displayName,
				childGroups = "tab",
				disabled = function(info) if #info > 1 then return not dbConnection("Enabled") end end,
				args = 
				{
					Enabled = 
					{
						type = "toggle",
						name = "Enabled",
						desc = "",
						get = dbConnection.Get,
						set = dbConnection:BuildSetter(function(newState) if newState then subModule:Enable() else subModule:Disable() end end),
						order = 0
					}
				}
			}
			
			
			if description then
				options.args["Description"] = 
				{
					type = "description",
					name = description,
					fontSize = "medium",
					order = -1
				}
			end

			for groupName, group in pairs(groups) do 
				options.args[groupName] = group
			end
			
			local key = self.name .. subModule.moduleName;
			AceConfig:RegisterOptionsTable(key, options);
			AceConfigDialog:AddToBlizOptions(key, displayName or subModule.moduleName, self.name);
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
	
	migrations[2] = function(db, dbRoot)
		dbRoot.global.LogLevel = -1;
	end
	
	return migrations;
end

function addon:InitializeDb(module, moduleDb)
	if moduleDb ~= nil then
		module.db = moduleDb;
	end
	
	if module.db.Version == nil then
		module.db.Version = 0;
	end
	
	if type(module.db.Version) ~= "number" then
		error("module '" .. module.name .. "' has invalid database version");
	end
	
	if module.db.modules == nil then
		module.db.modules = {}
	end
	
	if module.GetDbMigrations ~= nil then
		local migrations = module:GetDbMigrations();
		
		for migrationVersion, migration in pairs(migrations) do
			local oldDbVersion = module.db.Version;
			if migrationVersion > module.db.Version then
				migration(module.db, self.dbRoot); -- upgrade db to the next version
				module.db.Version = migrationVersion;
				log:Log(10, "Upgraded module '", tostring(module), "'db version from", oldDbVersion, "to", moduleDb.Version);
			end
		end
	end
	
	for name, subModule in module:IterateModules() do
		if module.db.modules[subModule.name] == nil then
			module.db.modules[subModule.name] = {};
		end
		
		local subModuleDb = module.db.modules[subModule.name]
		
		addon:InitializeDb(subModule, subModuleDb);
	end
	
	if  module.db.Enabled == nil then
		module.db.Enabled = true;
	else
	
	end
	
	module:SetEnabledState(module.db.Enabled);
	
	if module.OnDbInitialized ~= nil then
		module:OnDbInitialized(module.db, self.dbRoot);
	end
end

function addon:OnNameplateCreated(nameplate)
	addon.callbacks:Fire("OnNameplateCreated", nameplate);
	self:UpdateNameplate(nameplate)
end

function addon:OnNameplateRecycled(nameplate)
	local iconFrame = self.Utils.ClassIcon:GetNameplateFrame(nameplate);
	if iconFrame ~= nil then
		iconFrame:Clear();
	end
	
	addon.callbacks:Fire("OnNameplateRecycled", nameplate);
end

function addon:OnNameplateDiscoveredGuid(nameplate, GUID, unitId)
	local name = LibNameplate:GetName(nameplate);
	self:UpdateNameplate(nameplate, false, name, unitId);
end

function addon:UpdateNameplate(nameplateOrName, fastUpdate, name, unitId)
	if nameplateOrName == nil then
		error("nameplateOrName must be either nameplate or name. It was nil");
	end
	
	if type(nameplateOrName) == "string" then
		nameplateOrName = LibNameplate:GetNameplateByName(nameplateOrName);
	end
	
	if name == nil and nameplateOrName ~= nil then
		name = LibNameplate:GetName(nameplateOrName);
	end
	
	if nameplateOrName ~= nil then
		addon.callbacks:Fire("OnNameplateUpdating", nameplateOrName, fastUpdate, name, unitId);
		self:UpdateNameplateAppearence(nameplateOrName, fastUpdate)
	end
end

function addon:UpdateNameplateAppearence(nameplate, fastUpdate)
	local name = LibNameplate:GetName(nameplate);
	log(90, "Updating nameplate appearence for '", name, "'")
	addon.callbacks:Fire("OnNameplateAppearenceUpdating", nameplate, fastUpdate, name);
end

function addon:UpdateNameplates(fastUpdate)
	local nameplatesList = self:GetVisibleNameplates();
	log:Log(80, "Updating nameplates state. Count =",  #nameplatesList, ", FastUpdate =", fastUpdate or "false");
	for i = 1, #nameplatesList do
		local nameplate = nameplatesList[i];
		self:UpdateNameplate(nameplate, fastUpdate);
	end
end

function addon:GetVisibleNameplates()
	local nameplatesList = {LibNameplate:GetAllNameplates()};
	local result = {}
	for i = 2, nameplatesList[1]+1 do
		local nameplate = nameplatesList[i];
		if nameplate:IsVisible() then
			table.insert(result, nameplate);
		end
	end
	
	return result;
end

function addon:UpdateAppearence(fastUpdate)
	local nameplatesList = self:GetVisibleNameplates()
	log:Log(30, "Updating appearence. Count  =",  #nameplatesList, ", FastUpdate =", fastUpdate or "false");
	for i = 1, #nameplatesList do
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
	local storage = self.storages[tostring(categoryName)];
	
	if storage == nil then
		log(20, "storage was not set for", categoryName, ". Initializing with dummy storage.")
		local dummyStorage = {}
		storage = self:CreateStorage();
		self.storages[tostring(categoryName)] = storage;
	end

	return storage;
end

function addon:OnProfileChanged(_, database)
	self.dbRoot = database;
	self:InitializeDb(self, database.profile);
	
	if self.Initialized then
		self:Disable();
		if self.db.Enabled then
			self:Enable();
		end
		self:UpdateAppearence();
	end
end

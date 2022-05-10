local ADDON_NAME = "PlatesClasses";
local ADDON_PATH = "Interface\\Addons\\" .. ADDON_NAME;

local AceAddon = LibStub("AceAddon-3.0");
local AceConfig = LibStub("AceConfig-3.0");
local AceDb = LibStub("AceDB-3.0");
local AceDBOptions = LibStub("AceDBOptions-3.0");
local AceConfig = LibStub("AceConfig-3.0");
local AceConfigDialog = LibStub("AceConfigDialog-3.0");
local LibNameplate = LibStub("LibNameplate-1.0");
local LibEvents = LibStub("LibEvents-1.0");
local LibLogger = LibStub("LibLogger-1.0");
local AceTimer = LibStub("AceTimer-3.0");

local addon = AceAddon:NewAddon(ADDON_NAME, "AceConsole-3.0");
addon.logLevel = -1;
addon.Utils = {};
addon.nameplateFrames = {};
addon.OnModuleCreated = function(module) end
local events = LibEvents:New(addon);
local log = LibLogger:New(addon);
local dbVersion = 1;

local Utils = addon.Utils;

function addon:OnInitialize()
	local dbDefaults = 
	{
		profile = 
		{
			modules = {},
			Enabled = true,
			UpdateFrequency = 1,
			IconSettings = self:GetDefaultNameplateIconSettings(),
			Version = 0
		}
	};
	local db = AceDb:New("DB", dbDefaults, true);
	db.RegisterCallback(self, "OnProfileChanged", "OnProfileChanged");
	db.RegisterCallback(self, "OnProfileCopied", "OnProfileChanged");
	db.RegisterCallback(self, "OnProfileReset", "OnProfileChanged");
	self:OnProfileChanged("self-call", db)
	
	self.storages = 
	{ 
		PlayerClasses = self:CreateStorage()
	};
	
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
	
	events:Enable();
	
	self:UpdateAllNameplates();
	
	events:PARTY_MEMBERS_CHANGED();
	
	self.timer = AceTimer:ScheduleRepeatingTimer(function() self:UpdateAllNameplates(true) end, self.db.UpdateFrequency);
end

function addon:OnDisable()
	LibNameplate.UnregisterAllCallbacks(self);
	events:Disable();
	
	if self.timer ~= nil then
		AceTimer:CancelTimer(self.timer);
	end

	self:UpdateAllNameplates();
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
				if migrationVersion > targetVersion then
					break;
				end
				
				if migrationVersion > moduleDb.Version then
					moduleDb.Version = migrationVersion;
					migration(moduleDb, self.dbRoot); -- upgrade db to the next version
				end
			end
		end
	end
	
	if module.OnDbInitialized ~= nil then
		module:OnDbInitialized(moduleDb, self.dbRoot);
	end
end

function addon:GetDefaultNameplateIconSettings()
	return 
	{
		Size = 32,
		Alpha = 1,
		EnemiesOnly = false,
		DisplayClassIconBorder = true,
		BorderFollowNameplateColor = true,
		OffsetX = 7,
		OffsetY = -9,
		ShowQuestionMarks = false
	}
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
	return self.storages[categoryName];
end

function addon:IndexToClass(classIndex)
	return PLAYER_CLASSES[classIndex];
end

function addon:ClassToIndex(unifiedClass)
	if unifiedClass == nil then error() end
	return PLAYER_CLASSES_INDEXES[unifiedClass]
end

function addon:OnNameplateCreated(nameplate)
	self:UpdateNameplate(nameplate)
end

function addon:OnNameplateDiscoveredGuid(nameplate, GUID, unitID)
	self:UpdateNameplate(nameplate, unitID)
end

function addon:OnNameplateRecycled(nameplate)
	local frame = addon:GetNameplateFrame(nameplate);
	frame:ClearClass();
end

function addon:UpdateAllNameplates(fastUpdate)
	local nameplatesList = {LibNameplate:GetAllNameplates()};
	log:Log(30, "Updating",  nameplatesList[1], "nameplate(s). FastUpdate =", fastUpdate or "false");
	for i = 2, nameplatesList[1]+1 do
		local nameplate = nameplatesList[i]
		if self:IsEnabled() then
			if fastUpdate then
				local frame = self:GetNameplateFrame(nameplate);
				self:UpdateBorderColor(frame);
			else
				self:UpdateNameplate(nameplate)
			end
		else
			local frame = self:GetNameplateFrame(nameplate);
			frame:ClearClass();
		end
	end
end

function addon:GetUnitMetadata(unitId)
	local class, unifiedClass = UnitClass(unitId)
	local isPlayer = UnitIsPlayer(unitId) == 1;
	local isHostile = nil;
	local reaction =  UnitReaction(unitId, "player");
	if reaction ~= nil then
		isHostile = reaction < 4;
	end
	
	return {class = unifiedClass, isPlayer = isPlayer, isHostile = isHostile}
end

function addon:GetMetadata(nameplate, unitID)
	local class, isHostile, isPlayer;
	local metadata;
	
	if unitID ~= nil then
		metadata = self:GetUnitMetadata(unitID);
	else
		class = LibNameplate:GetClass(nameplate);
		local reaction, unitType = LibNameplate:GetReaction(nameplate);
		isPlayer = nil;
		if unitType == "PLAYER" then
			isPlayer = true;
		elseif unitType == "NPC" then
			isPlayer = false;
		end
		
		isHostile = reaction == "HOSTILE";
		
		metadata = { class = class, isHostile = isHostile, isPlayer = isPlayer }
	end
	
	if metadata.isPlayer == false then
		metadata.class = nil;
	end
	
	return metadata;
end

function addon:UpdateNameplate(nameplate, unitID)
	local playerClasses = self.storages.PlayerClasses;
	
	local name = LibNameplate:GetName(nameplate);
	local metadata = self:GetMetadata(nameplate, unitID);
	
	if metadata.class == nil then
		metadata.class = playerClasses:Get(name);
		log:Log(70, "Storage returned", metadata.class, "for name ", name);
	else
		playerClasses:Set(name, metadata.class);
	end
	
	log:Log(40, "nameplate of '", name, "' are being updated with '", metadata.class, "' class");
	local frame = self:GetNameplateFrame(nameplate);
	frame:SetMetadata(metadata, name);
	self:UpdateFrameAppearence(frame);
end

function addon:UpdateAppearence()
	for _, nameplate in pairs(self.nameplateFrames) do
		self:UpdateFrameAppearence(nameplate);
	end
end

function addon:UpdateBorderColor(nameplateFrame)
	local nameplate = nameplateFrame:GetParent();
	
	local r,g,b,a = 0,0,0,1;
	
	if nameplateFrame.FollowNameplateColor then
		local hpBar = LibNameplate:GetHealthBar(nameplate);
		if hpBar and hpBar.GetStatusBarColor then
			r,g,b,a = hpBar:GetStatusBarColor()
		end
	end
	
	nameplateFrame.classBorderTexture:SetVertexColor(r,g,b,a);
end

function addon:UpdateFrameAppearence(nameplateFrame, settings)
	if settings == nil then
		settings = self.db.IconSettings;
	end
	
	nameplateFrame.FollowNameplateColor = settings.FollowNameplateColor;
	
	local nameplate = nameplateFrame:GetParent()
	nameplateFrame:SetAlpha(settings.Alpha);
	nameplateFrame:SetWidth(settings.Size);
	nameplateFrame:SetHeight(settings.Size);
	nameplateFrame:SetPoint("RIGHT", nameplate, "LEFT", settings.OffsetX, settings.OffsetY);
	
	if settings.EnemiesOnly and not nameplateFrame.isHostile then
		nameplateFrame:Hide()
		return
	end
	
	if nameplateFrame.isPlayer == false then
		nameplateFrame:Hide();
	elseif nameplateFrame.class == nil then
		if settings.ShowQuestionMarks then
			SetPortraitToTexture(nameplateFrame.classTexture,"Interface\\Icons\\Inv_misc_questionmark")
			-- nameplateFrame.classTexture:SetTexture("Interface\\Icons\\Inv_misc_questionmark");
			nameplateFrame.classTexture:SetTexCoord(0.075, 0.925, 0.075, 0.925);
			nameplateFrame:Show();
		else
			nameplateFrame:Hide();
		end
	else
		nameplateFrame.classTexture:SetTexture(ADDON_PATH .. "\\images\\UI-CHARACTERCREATE-CLASSES_ROUND");
		if CLASS_ICON_TCOORDS[nameplateFrame.class] == nil then
			log:Error("Unexpected class:", print(nameplateFrame.class))
		end
		nameplateFrame.classTexture:SetTexCoord(unpack(CLASS_ICON_TCOORDS[nameplateFrame.class]));
		nameplateFrame:Show();
	end

	if nameplateFrame:IsVisible() then
		if nameplateFrame.class ~= nil and settings.DisplayClassIconBorder then
			nameplateFrame.classBorderTexture:Show();
			self:UpdateBorderColor(nameplateFrame);
		else
			nameplateFrame.classBorderTexture:Hide();
		end
	end
end

function addon:GetNameplateFrame(nameplate)
	if nameplate.classFrame == nil then
		local classFrame = CreateFrame("Frame", nil, nameplate);
		
		function classFrame.ClearClass(this)
			this:Hide();
		end
		
		function classFrame.SetMetadata(this, metadata, targetName)
			this.class = metadata.class;
			this.isPlayer = metadata.isPlayer;
			this.isHostile = metadata.isHostile;
			this.targetName = targetName;
		end
		
		local texture = classFrame:CreateTexture(nil, "ARTWORK");
		texture:SetAllPoints();
		classFrame.classTexture = texture;
		
		local textureBorder = classFrame:CreateTexture(nil, "BORDER");
		textureBorder:SetTexture(ADDON_PATH .. "\\images\\RoundBorder");
		textureBorder:SetAllPoints()
		classFrame.classBorderTexture = textureBorder;
		
		self:UpdateFrameAppearence(classFrame);
		table.insert(self.nameplateFrames, classFrame);
		nameplate.classFrame = classFrame;
	end
	
	return nameplate.classFrame;
end

function addon:AddBlizzardOptionsForNameplateIcon(options, dbConnection, iterator)
	if iterator == nil then
		iterator = Utils.Iterator:New();
	end
	
	
	options.args["ClassIconDescriptionSpace"] = 
	{
		type = "description",
		name = " ",
		fontSize = "large",
		order = iterator()
	}
	
	options.args["ClassIconDescription"] = 
	{
		type = "description",
		width = "full",
		name = "Class icon Settings:",
		fontSize = "large",
		order = iterator()
	}
	
	options.args["Size"] = 
	{
		type = "range",
		name = "Size",
		desc = "",
		min = 0,
		max = 256,
		softMin = 8,
		softMax = 64,
		step = 2,
		order = iterator(),
		get = dbConnection.Get,
		set = dbConnection.Set
	}
	
	options.args["OffsetX"] = 
	{
		type = "range",
		name = "OffsetX",
		desc = "",
		softMin = -80,
		softMax = 240,
		step = 1,
		order = iterator(),
		get = dbConnection.Get,
		set = dbConnection.Set
	}
	
	options.args["OffsetY"] = 
	{
		type = "range",
		name = "OffsetY",
		desc = "",
		softMin = -80,
		softMax = 80,
		step = 1,
		order = iterator(),
		get = dbConnection.Get,
		set = dbConnection.Set
	}
	
	options.args["DisplayClassIconBorder"] = 
	{
		type = "toggle",
		name = "Display border",
		desc = "",
		order = iterator(),
		get = dbConnection.Get,
		set = dbConnection.Set
	}
	
	options.args["BorderFollowNameplateColor"] = 
	{
		type = "toggle",
		name = "Dynamic border color",
		desc = "Set border color to the color of the nameplate",
		order = iterator(),
		get = dbConnection.Get,
		set = dbConnection.Set
	}
	
	options.args["ShowQuestionMarks"] = 
	{
		type = "toggle",
		name = "Show question marks",
		desc = "Show question marks for unknown targets",
		order = iterator(),
		get = dbConnection.Get,
		set = dbConnection.Set
	}
	
	options.args["EnemiesOnly"] = 
	{
		type = "toggle",
		name = "Enemies only",
		desc = "Show icons for enemies only",
		order = iterator(),
		get = dbConnection.Get,
		set = dbConnection.Set
	}
end

function addon:AddUnit(unitID)
	local storage = self.storages.PlayerClasses;
	local name = UnitName(unitID);
	log:Log(40, "Adding unit '",  unitID ,"' with name '", name ,"'.")
	
	if name ~= nil then
		local metadata = self:GetUnitMetadata(unitID);
		log:Log(39, unitID, "resolved to class ", metadata.class);
		if metadata.class ~= nil then
			storage:Set(name, metadata.class);
			local nameplate = LibNameplate:GetNameplateByName(name);
			if nameplate ~= nil then
				self:GetNameplateFrame(nameplate):SetMetadata(metadata, name);
			end
		end
	end
end

function events:ARENA_OPPONENT_UPDATE(unit, reason)
	log:Log(50, "arena_opponent_update", unit, reason)
	if reason == "seen" then
		self:AddUnit(unit);
	end
end

function events:PARTY_MEMBERS_CHANGED()
	local numPartyMembers = GetNumPartyMembers()
	log:Log(50, "PARTY_MEMBERS_CHANGED invoked. Party members count = ", numPartyMembers)
	
	if numPartyMembers ~= nil then
		for i = 1, numPartyMembers do
			local unitID = "party"..i;
			self:AddUnit(unitID);
		end
	end
end

function addon:OnProfileChanged(event, database)
	print(event)
	
	self.dbRoot = database;
	self:InitializeDb(self, database.profile, dbVersion);
	
	for name, subModule in self:IterateModules() do
		if self.db.modules[subModule.name] == nil then
			self.db.modules[subModule.name] = {};
		end
		
		local subModuleDb = self.db.modules[subModule.name]
		
		self:InitializeDb(subModule, subModuleDb, self.db.Version);
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

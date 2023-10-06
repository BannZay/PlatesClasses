-- copy paste to create new module from this template
local moduleName = "PlateAggro"
local displayName = "Aggro"
local AceAddon = LibStub("AceAddon-3.0");
local LibLogger = LibStub("LibLogger-1.0");
local LibEvents = LibStub("LibEvents-1.0");
local LibNameplate = LibStub("LibNameplate-1.0");
local AceTimer = LibStub("AceTimer-3.0");

local addon = AceAddon:GetAddon("PlatesClasses");
local module = addon:NewModule(moduleName);
local log = LibLogger:New(addon);
local Utils = addon.Utils;
local events = LibEvents:New(module);

local framesCreatedCount = 1;
local maxReaction = 9;
local active = false;
local watchers = {}
local petsMonitorTimer;

function module:OnInitialize()
	self:UpdatePlayerLocation();
	self:SetPetsMonitorEnabled(self.db.MonitorPets)
	events.ZONE_CHANGED_NEW_AREA = self.UpdatePlayerLocation;
end

function module:OnDbInitialized(db, dbRoot)
end

function module:OnEnable()
	addon.RegisterCallback(self, "OnNameplateRecycled")
	addon.RegisterCallback(self, "OnNameplateAppearenceUpdating")
	addon.RegisterCallback(self, "OnNameplateUpdating")
	events:Enable()
	addon:UpdateNameplates();
end

function module:OnDisable()
	events:Disable()
	addon.UnregisterAllCallbacks(self);
	addon:UpdateNameplates();
end

function module:GetDbMigrations()
	local migrations = {}

	migrations[1] = function(db, dbRoot)
		db.Enabled = true;
		db.MonitorPets = true;
		db.UpdateFrequency = 0.1;
		db.TestMode = false;
		db.IconSettings = {
			Size = 32,
			Alpha = 1,
			EnemiesOnly = true,
			OffsetX = 165,
			OffsetY = -9
		}
	end

	return migrations;
end

function module:OnNameplateAppearenceUpdating(eventName, nameplate, fastUpdate)
	if active then
		local frame = self:GetOrCreateFrame(nameplate);
		frame:UpdateAppearence(self.db.IconSettings);
	end
end


function module:OnNameplateUpdating(eventName, nameplate, fastUpdate, name, unitId)
	if active then
		local frame = self:GetOrCreateFrame(nameplate);

		if frame.targetName ~= name then
			frame.targetName = name
			frame.isHostile = Utils:IsHostile(nameplate, unitId)
		end

		frame.stalking = watchers[name];
	end
end

function module:OnNameplateRecycled(event, nameplate)
	local frame = self:GetOrCreateFrame(nameplate);
	frame:Hide();
end

function module:SetPetsMonitorEnabled(enabled)
	if active and petsMonitorTimer == nil then
		petsMonitorTimer = AceTimer:ScheduleRepeatingTimer(function()  if active then module:UpdatePets() end end, module.db.UpdateFrequency or 0.1);
	elseif petsMonitorTimer ~= nil then
		AceTimer:CancelTimer(petsMonitorTimer)
		petsMonitorTimer = nil
	end
end

function module:UpdatePets()
	events:UNIT_TARGET("arenapet1")
	events:UNIT_TARGET("arenapet2")
	events:UNIT_TARGET("arenapet3")
end

function events:UNIT_TARGET(unitId)
	if active and unitId ~= "player" then
		local name = UnitName(unitId)
		
		if name ~= nil then
			watchers[name] = UnitIsUnit(unitId .. "target", "player")
			addon:UpdateNameplate(name, false, name, unitId);
		end
	end
end

function module:UpdatePlayerLocation()
	watchers = {}

	local zoneType = select(2, IsInInstance())
	active = zoneType == "arena"

	active = true;

	local nameplatesList = addon:GetVisibleNameplates();
	for i = 1, #nameplatesList do
		local nameplate = nameplatesList[i];
		local frame = self:GetOrCreateFrame(nameplate);
		frame:Hide();
	end
end

function module:GetOrCreateFrame(nameplate)
	if nameplate.aggroFrame == nil then
		local frame = CreateFrame("Frame", 'PlatesClassesAggroFrame' .. framesCreatedCount, nameplate);
		
		function frame:UpdateAppearence(settings)
			settings = settings or module.db.IconSettings
			self:SetAlpha(settings.Alpha);
			self:SetWidth(settings.Size);
			self:SetHeight(settings.Size);
			self:ClearAllPoints();
			self:SetPoint("RIGHT", nameplate, "LEFT", settings.OffsetX, settings.OffsetY);

			if module.db.TestMode or ( self.stalking and (self.isHostile ~= false or not settings.EnemiesOnly))  then
				self:Show()
			else
				self:Hide()
			end
		end

		framesCreatedCount = framesCreatedCount + 1;

		local texture = frame:CreateTexture(nil, "ARTWORK");
		texture:SetAllPoints();
		texture:SetTexture("Interface\\Icons\\Ability_Hunter_AspectoftheViper");
		-- texture:SetTexture("Interface\\Icons\\ability_sap");
		

		texture:Show();
		frame.texture = texture;
		nameplate.aggroFrame = frame;	
	end

	return nameplate.aggroFrame;
end


function module:BuildBlizzardOptions()
	local iconSettingsConnection = Utils.DbConfig:New(function(key) return self.db.IconSettings end, function(newState) addon:UpdateAppearence() end, self);
	local dbConnection = Utils.DbConfig:New(function(key) return self.db end, function(newState) addon:UpdateAppearence() end, self)
	local iterator = Utils.Iterator:New();
	local options = {}

	options.IconSettings = 
	{
		type = "group",
		name = "Icon settings",
		args = {},
		order = iterator()
	}

	options.TestMode = 
	{
		type = "toggle",
		name = "Test mode",
		desc = "Show icons always. This option is used for testing purposes.",
		order = iterator(),
		get = dbConnection.Get,
		set = dbConnection.Set
	}

	options["MonitorPets"] = 
	{
		type = "toggle",
		name = "Monitor pets",
		desc = "Show icons for arena pets.",
		order = iterator(),
		get = dbConnection.Get,
		set = dbConnection.BuildSetter(function(newValue) self:SetPetsMonitorEnabled(newValue) end)
	}

	options.IconSettings.args["Size"] = 
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
		get = iconSettingsConnection.Get,
		set = iconSettingsConnection.Set
	}
	
	options.IconSettings.args["Alpha"] = 
	{
		type = "range",
		name = "Alpha",
		desc = "",
		min = 0,
		max = 1,
		step = 0.1,
		order = iterator(),
		get = iconSettingsConnection.Get,
		set = iconSettingsConnection.Set
	}

	options.IconSettings.args["OffsetX"] = 
	{
		type = "range",
		name = "OffsetX",
		desc = "",
		softMin = -80,
		softMax = 240,
		step = 1,
		order = iterator(),
		get = iconSettingsConnection.Get,
		set = iconSettingsConnection.Set
	}
	
	options.IconSettings.args["OffsetY"] = 
	{
		type = "range",
		name = "OffsetY",
		desc = "",
		softMin = -80,
		softMax = 80,
		step = 1,
		order = iterator(),
		get = iconSettingsConnection.Get,
		set = iconSettingsConnection.Set
	}
	
	options.IconSettings.args["EnemiesOnly"] = 
	{
		type = "toggle",
		name = "Enemies only",
		desc = "Show icons for enemies only",
		order = iterator(),
		get = iconSettingsConnection.Get,
		set = iconSettingsConnection.Set
	}

	return options, displayName, "Indicates players (and arena pets) which selected you as a target"
end
local moduleName = "Plate Styler"
local AceAddon = LibStub("AceAddon-3.0");
local LibLogger = LibStub("LibLogger-1.0");
local LibNameplate = LibStub("LibNameplate-1.0");
local AceTimer = LibStub("AceTimer-3.0");
local LibEvents = LibStub("LibEvents-1.0");

local addon = AceAddon:GetAddon("PlatesClasses");
local module = addon:NewModule(moduleName);
local log = LibLogger:New(module);
local Utils = addon.Utils;
local events = LibEvents:New(module)

local defaultSettings = 
{
	DisplayLevel = true,
	DisplayName = true,
	DisplayRaidIcon = true,
	DisplayHpBar = true,
	DisplayBorder = true,
	DisplayHighlight = true
}

function events:UPDATE_MOUSEOVER_UNIT()
	if self.db.Nameplates.MouseOver.Enabled then
		if UnitExists("mouseover") then
			local unitName = UnitName("mouseover");
			local nameplate = LibNameplate:GetNameplateByName(unitName);
			if nameplate ~= nil then
				self:OnPlateMouseEnter(nameplate);
			else
				log(3, "nameplate for mouseover unit with name '", unitName, "' was not found");
			end
		end
	end
end

function module:OnInitialize()
	events:Disable();
end

function module:OnDbInitialized(db, dbRoot)
end

function module:OnEnable()
	addon.RegisterCallback(self, "OnNameplateCreated")
	addon.RegisterCallback(self, "OnNameplateRecycled")
	-- LibNameplate.RegisterCallback(self, "LibNameplate_MouseoverNameplate", function(event, nameplate) self:OnPlateMouseEnter(nameplate) end);
	self:StyleAllNameplates();
	events:Enable();
end

function module:OnDisable()
	if self.timer ~= nil then
		AceTimer:CancelTimer(self.timer);
	end
	
	addon.UnregisterAllCallbacks(self);
	LibNameplate.UnregisterAllCallbacks(self)
	self:StyleAllNameplates();
	events:Disable();
end

function module:OnPlateMouseCheckTimerTick(nameplate)
	if not UnitExists("mouseover") or (UnitName("mouseover") ~= LibNameplate:GetName(nameplate)) then 
		AceTimer:CancelTimer(self.timer)
		self:OnPlateMouseLeave(nameplate);
	end
end

local mouseOveredNameplate
function module:OnPlateMouseEnter(nameplate)
	if self.timer ~= nil then
		AceTimer:CancelTimer(self.timer)
	end
	
	if mouseOveredNameplate ~= nil then
		module:OnPlateMouseLeave(mouseOveredNameplate);
	end
	
	mouseOveredNameplate = nameplate
	
	if self.db.Nameplates.MouseOver.TreatAllPlatesAsMouseOvered then
		self:StyleAllNameplates();
	else
		self:StyleNameplate(nameplate);
	end
	
	module.timer = AceTimer:ScheduleRepeatingTimer(function() self:OnPlateMouseCheckTimerTick(nameplate) end, 0.1);
end

function module:OnPlateMouseLeave(nameplate)
	if mouseOveredNameplate == nameplate then
		mouseOveredNameplate = nil
	end
	
	if self.db.Nameplates.MouseOver.TreatAllPlatesAsMouseOvered and mouseOveredNameplate == nil then
		self:StyleAllNameplates();
	else
		self:StyleNameplate(nameplate);
	end
end

function module:OnNameplateCreated(event, nameplate)
	self:StyleNameplate(nameplate)
end

function module:OnNameplateRecycled(event, nameplate)
	self:StyleNameplate(nameplate, defaultSettings);
end

function module:StyleNameplate(nameplate, settings)
	if nameplate ~= nil then
		if not self:IsEnabled() then settings = defaultSettings end
		
		local name = LibNameplate:GetName(nameplate);
		
		if settings == nil then
			if self.db.Nameplates.MouseOver.Enabled and mouseOveredNameplate ~= nil then
				if self.db.Nameplates.MouseOver.TreatAllPlatesAsMouseOvered or mouseOveredNameplate == nameplate then
					settings = self.db.Nameplates.MouseOver
					log(1, name, "is a mouse over")
				end
			elseif self.db.Nameplates.Totems.Enabled and Utils.NameRecognizer:IsTotemName(name) then
				settings = self.db.Nameplates.Totems;
				log(1, name, "is a totem")
			end
		end
		
		if settings == nil then
			settings = self.db.Nameplates.AllNameplates;
			log(1, name, "is all")
		end
		
		local allRegions = {nameplate:GetRegions()};
		
		local levelRegion = LibNameplate:GetLevelRegion(nameplate);
		Utils:SetVisible(levelRegion, settings.DisplayLevel);
		
		local nameRegion = LibNameplate:GetNameRegion(nameplate);
		Utils:SetVisible(nameRegion, settings.DisplayName);
		
		local raidIconRegion = LibNameplate:GetRaidIconRegion(nameplate);
		Utils:SetVisible(raidIconRegion, settings.DisplayRaidIcon, 1);
		
		local healthBarRegion = LibNameplate:GetHealthBar(nameplate);
		Utils:SetVisible(healthBarRegion, settings.DisplayHpBar, 1);
		
		local borderRegion = allRegions[2];
		if borderRegion ~= nil then
			Utils:SetVisible(borderRegion, settings.DisplayBorder, 1);
		end
		
		local highlightRegion = LibNameplate:GetHightlightRegion(nameplate)
		Utils:SetVisible(highlightRegion, settings.DisplayHighlight, 1)
	end
end

function module:StyleAllNameplates(settings)
	local nameplatesList = {LibNameplate:GetAllNameplates()};
	for i = 2, nameplatesList[1]+1 do
		local nameplate = nameplatesList[i];
		self:StyleNameplate(nameplate, settings);
	end
end

function module:GetDbMigrations()
	local migrations = {}

	local function InitializeNameplateSettingsSection(db, dbSectionName)
		if db.Nameplates[dbSectionName] == nil then
			db.Nameplates[dbSectionName] = {}
		end
		
		local section = db.Nameplates[dbSectionName]
		
		for name, defaultValue in pairs(defaultSettings) do
			if section[name] == nil then
				section[name] = defaultValue;
			end
		end
	end
	
	migrations[1] = function(db, dbRoot)
		db.Enabled = true;
		db.Nameplates = {}
		InitializeNameplateSettingsSection(db, "AllNameplates")
		InitializeNameplateSettingsSection(db, "MouseOver")
		InitializeNameplateSettingsSection(db, "Totems")
	end

	return migrations;
end

function module:CreateOptionsGroup(name, dbConnection, iterator, onEnableStateChanged)
	local options = 
	{
		type = "group",
		name = name,
		get = dbConnection.Get,
		set = dbConnection.Set,
		args = {},
		order = iterator()
	}
	
	options.args["Enabled"] =
	{
		type = "toggle",
		name = "Enable custom style",
		width = "full",
		order = iterator()
	}
	
	options.args["DisplayLevel"] = 
	{
		type = "toggle",
		name = "Display Level",
		order = iterator(),
		disabled = function() return not dbConnection("Enabled") end
	}
	
	options.args["DisplayName"] = 
	{
		type = "toggle",
		name = "Display Name",
		order = iterator(),
		disabled = function() return not dbConnection("Enabled") end
	}
	
	options.args["DisplayRaidIcon"] = 
	{
		type = "toggle",
		name = "Display Raid Icon",
		order = iterator(),
		disabled = function() return not dbConnection("Enabled") end
	}
	
	options.args["DisplayHpBar"] = 
	{
		type = "toggle",
		name = "Display Health Bar",
		order = iterator(),
		disabled = function() return not dbConnection("Enabled") end
	}
	
	options.args["DisplayBorder"] = 
	{
		type = "toggle",
		name = "Display Border",
		order = iterator(),
		disabled = function() return not dbConnection("Enabled") end
	}
	
	options.args["DisplayHighlight"] = 
	{
		type = "toggle",
		name = "Display Highlights",
		order = iterator(),
		disabled = function() return not dbConnection("Enabled") end
	}
	
	if onEnableStateChanged ~= nil then
		options.args["Enabled"].set = dbConnection:BuildSetter(onEnableStateChanged);
	end
	
	return options;
end

function module:BuildBlizzardOptions()
	local iterator = Utils.Iterator:New();
	
	local allNameplatesDbConnection = Utils.DbConfig:New(function(key) return self.db.Nameplates.AllNameplates end, function() if self:IsEnabled() then self:StyleAllNameplates() end end , self);
	local mouseOverNameplatesDbConnection = Utils.DbConfig:New(function(key) return self.db.Nameplates.MouseOver end, nil , self)
	local totemsNameplatesDbConnection = Utils.DbConfig:New(function(key) return self.db.Nameplates.Totems end, function() if self:IsEnabled() then self:StyleAllNameplates() end end , self);
	
	local allNameplatesOptions = self:CreateOptionsGroup("All nameplates", allNameplatesDbConnection, iterator)
	
	local mouseOverOptions = self:CreateOptionsGroup("Mouse over", mouseOverNameplatesDbConnection, iterator)
	mouseOverOptions.args["TreatAllPlatesAsMouseOvered"] = 
	{
		type = "toggle",
		name = "All nameplates",
		desc = "Treat all nameplates as mouseovered if any nameplate was mouseovered",
		order = iterator(),
		disabled = function() return not mouseOverNameplatesDbConnection("Enabled") end
	}
	
	local totemsNameplatesOptions = self:CreateOptionsGroup("Totems nameplates", totemsNameplatesDbConnection, iterator)

	return {
		AllNameplatesOptions = allNameplatesOptions,
		MouseOverOptions = mouseOverOptions,
		TotemsOptions = totemsNameplatesOptions
	}
end
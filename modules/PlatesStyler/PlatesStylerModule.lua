local moduleName = "Plate Styler"
local AceAddon = LibStub("AceAddon-3.0");
local LibLogger = LibStub("LibLogger-1.0");
local LibNameplate = LibStub("LibNameplate-1.0");

local addon = AceAddon:GetAddon("PlatesClasses");
local module = addon:NewModule(moduleName);
local log = LibLogger:New(addon)
local Utils = addon.Utils;

local defaultSettings = 
{
	DisplayLevel = true,
	DisplayName = true,
	DisplayRaidIcon = true,
	DisplayHpBar = true,
	DisplayBorder = true,
	DisplayHighlight = true
}

function module:OnInitialize()
	self.themes = {}
end

function module:OnDbInitialized(db, dbRoot)
end

function module:OnEnable()
	addon.RegisterCallback(self, "OnNameplateCreated")
	addon.RegisterCallback(self, "OnNameplateRecycled")
	self:StyleAllNameplates();
end

function module:OnDisable()
	addon.UnregisterAllCallbacks(self);
	LibNameplate.UnregisterAllCallbacks(self)
	self:StyleAllNameplates();
end

function module:AddTheme(name, themeProvider, blizzardOptions, importancy)
	table.insert(self.themes, {name = name, provider = themeProvider, blizzardOptions = blizzardOptions, importancy = importancy or 0})
	table.sort(self.themes, function(x1, x2) return x1.importancy < x2.importancy end)
end

function module:OnNameplateCreated(event, nameplate)
	self:StyleNameplate(nameplate)
end

function module:OnNameplateRecycled(event, nameplate)
	self:StyleNameplate(nameplate, defaultSettings);
end

function module:GetSettings(nameplate, name)
	for i=1, #self.themes do
		local themeSettings = self.themes[i]
		local themeProvider = themeSettings.provider
		local theme = themeProvider(nameplate, name)
		
		if theme ~= nil then
			return theme;
		end
	end
end

function module:StyleNameplate(nameplate, settings)
	if nameplate ~= nil then
		if not self:IsEnabled() then settings = defaultSettings end
		
		local name = LibNameplate:GetName(nameplate);
		
		settings = settings or self:GetSettings(nameplate, name) or defaultSettings;
		
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
	local nameplatesList = addon:GetVisibleNameplates();
	for i = 1, #nameplatesList do
		local nameplate = nameplatesList[i];
		self:StyleNameplate(nameplate, settings);
	end
end

function module:InitializeDb(db)
	for name, defaultValue in pairs(defaultSettings) do
		if db[name] == nil then
			db[name] = defaultValue;
		end
	end
end

function module:GetDbMigrations()
	local migrations = {}
	
	migrations[1] = function(db, dbRoot)
	end

	return migrations;
end

function module:CreateOptionsGroup(name, dbConnection, iterator)
	if iterator == nil then
		iterator = Utils.Iterator:New();
	end
	
	local shouldBeDisabled = function()
		return not self.db.Enabled or not dbConnection("Enabled")
	end
	
	local options = 
	{
		type = "group",
		name = name,
		get = dbConnection.Get,
		set = dbConnection.Set,
		args = {},
		order = iterator(), 
		disabled = function(info) if #info > 1 then return shouldBeDisabled() end end,
	}
	
	options.args["Enabled"] =
	{
		type = "toggle",
		name = "Enable custom style",
		width = "full",
		set = dbConnection:BuildSetter(function(newState) self:StyleAllNameplates() end),
		order = iterator(),
		disabled = function() return not self.db.Enabled end
	}
	
	options.args["DisplayLevel"] = 
	{
		type = "toggle",
		name = "Display Level",
		order = iterator()
	}
	
	options.args["DisplayName"] = 
	{
		type = "toggle",
		name = "Display Name",
		order = iterator()
	}
	
	options.args["DisplayRaidIcon"] = 
	{
		type = "toggle",
		name = "Display Raid Icon",
		order = iterator()
	}
	
	options.args["DisplayHpBar"] = 
	{
		type = "toggle",
		name = "Display Health Bar",
		order = iterator()
	}
	
	options.args["DisplayBorder"] = 
	{
		type = "toggle",
		name = "Display Border",
		order = iterator()
	}
	
	options.args["DisplayHighlight"] = 
	{
		type = "toggle",
		name = "Display Highlights",
		order = iterator()
	}
	
	return options;
end

function module:BuildBlizzardOptions()
	local result = {}
	for i=1, #self.themes do
		local themeSettings = self.themes[i]
		result[themeSettings.name] = themeSettings.blizzardOptions;
	end
	return result;
end
-- copy paste to create new module from this template
local moduleName = "PlayerClasses"
local AceAddon = LibStub("AceAddon-3.0");
local LibLogger = LibStub("LibLogger-1.0");

local addon = AceAddon:GetAddon("PlatesClasses");
local module = addon:NewModule(moduleName);
local log = LibLogger:New(module);
local Utils = addon.Utils;

function module:OnInitialize()
end

function module:OnEnable()
end

function module:OnDisable()
end

function module:GetDbMigrations()
	local migrations = {}
	
	migrations[1] = function(db) 
		db.Enabled = true;
		db.UpdateFrequency = 1;
		db.IconSettings = addon:GetDefaultNameplateIconSettings();
	end
	
	return migrations;
end

function module:BuildBlizzardOptions()
	local dbConnection = Utils.DbConfig:New(function(key) return self.db end);
	local iterator = Utils.Iterator:New();
	
	local options = 
	{
		type = "group",
		name = module.moduleName,
		get = dbConnection.Get,
		set = dbConnection:BuildSetter( function(newState) addon:UpdateAppearence() end),
		childGroups = "tab",
		args = {}
	}
	
	local generalSettingsOptions = 
	{
		type = "group",
		name = "General",
		args = {},
		order = iterator()
	}
	
	generalSettingsOptions.args["Enabled"] = 
	{
		type = "toggle",
		name = "Enabled",
		desc = "",
		set = dbConnection:BuildSetter(function(newState) if newState then module:Enable() else module:Disable() end end),
		order = iterator()
	}
	
	generalSettingsOptions.args["Enabled"] = 
	{
		type = "toggle",
		name = "Enabled",
		desc = "",
		set = dbConnection:BuildSetter(function(newState) if newState then module:Enable() else module:Disable() end end),
		order = iterator()
	}
	
	options.args.GeneralSettingsOptions = generalSettingsOptions;
	
	local iconSettingsOptions = 
	{
		type = "group",
		name = "Icon Settings",
		args = {},
		order = iterator()
	}
	local iconSettingsDbConnection = Utils.DbConfig:New(function(key) return self.db.IconSettings end, function(key, value) self:UpdateAppearence() end);
	addon:AddBlizzardOptionsForNameplateIcon(iconSettingsOptions, iconSettingsDbConnection, iterator);
	options.args.IconSettingsOptions = iconSettingsOptions
	
	return options
end
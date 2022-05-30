-- copy paste to create new module from this template
local moduleName = "Unnamed"
local AceAddon = LibStub("AceAddon-3.0");
local LibLogger = LibStub("LibLogger-1.0");

local addon = AceAddon:GetAddon("PlatesClasses");
local module = addon:NewModule(moduleName);
local log = LibLogger:New(module);
local Utils = addon.Utils;

function module:OnInitialize()
end

function module:OnDbInitialized(db, dbRoot)
end

function module:OnEnable()
end

function module:OnDisable()
end

function module:GetDbMigrations()
	local migrations = {}

	migrations[1] = function(db, dbRoot)
		db.Enabled = true;
	end

	return migrations;
end

function module:BuildBlizzardOptions()
	local dbConnection = Utils.DbConfig:New(function(key) return self.db end, nil, self);
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
	
	generalSettingsOptions.args["Button"] = 
	{
		type = "execute",
		name = "Red button",
		func = function() if self.db.Enabled then log:Log(-1, "BOOM!") end end,
		desc = "This is just a test button",
		order = iterator()
	}
	
	options.args.GeneralSettingsOptions = generalSettingsOptions;
	
	return options
end
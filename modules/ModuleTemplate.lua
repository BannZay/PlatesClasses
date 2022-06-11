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
	local dbConnection = Utils.DbConfig:New(function(key) return self.db end, function(newState) addon:UpdateAppearence() end, self);
	local iterator = Utils.Iterator:New();
	local options = {}
	
	local button =  
	{
		type = "execute",
		name = "Red button",
		func = function() if self.db.Enabled then log:Log(-1, "BOOM!") end end,
		desc = "This is just a test button",
		order = iterator()
	}
	
	return options {Button = button}
end
local moduleName = "Default"
local AceAddon = LibStub("AceAddon-3.0");
local LibLogger = LibStub("LibLogger-1.0");
local LibNameplate = LibStub("LibNameplate-1.0");

local addon =  AceAddon:GetAddon("PlatesClasses")
local parent = addon:GetModule("Plate Styler");
local module = parent:NewModule(moduleName);
local log = LibLogger:New(addon);
local Utils = addon.Utils;

local provider = function(nameplate) return module.db end

function module:OnInitialize()
	parent:AddTheme(moduleName, provider, self:BuildBlizzardOptions(), -99)
end

function module:OnEnable()
end

function module:OnDisable()
end

function module:BuildBlizzardOptions()
	local dbConnection = Utils.DbConfig:New(function(key) return self.db end, function() parent:StyleAllNameplates() end);
	local options = parent:CreateOptionsGroup(moduleName, dbConnection)
    options.args.Enabled = nil
    return options
end

function module:GetDbMigrations()
	local migrations = {}
	
	migrations[1] = function(db)
		parent:InitializeDb(db);
		db.Enabled = true;
	end
	
	return migrations;
end
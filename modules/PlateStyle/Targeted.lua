local moduleName = "Targeted"
local AceAddon = LibStub("AceAddon-3.0");
local LibLogger = LibStub("LibLogger-1.0");
local LibNameplate = LibStub("LibNameplate-1.0");
local AceTimer = LibStub("AceTimer-3.0");
local LibEvents = LibStub("LibEvents-1.0");

local addon =  AceAddon:GetAddon("PlatesClasses")
local parent = addon:GetModule("Plate Styler");
local module = parent:NewModule(moduleName);
local log = LibLogger:New(addon);
local Utils = addon.Utils;
local events = LibEvents:New(module)

local provider = function(nameplate, name) if UnitName("target") == name then return module.db end end

function module:OnInitialize()
	parent:AddTheme(moduleName, provider, self:BuildBlizzardOptions(), -4)
	events:Disable();
end

function module:OnEnable()
	events:Enable();
end

function module:OnDisable()
	events:Disable();
	
	if self.timer ~= nil then
		AceTimer:CancelTimer(self.timer);
	end
end

function module:GetDbMigrations()
	local migrations = {}
	
	migrations[1] = function(db)
		parent:InitializeDb(db);
	end
	
	return migrations;
end

function module:BuildBlizzardOptions()
	local iterator = Utils.Iterator:New();
	local dbConnection = Utils.DbConfig:New(function(key) return self.db end, function() if self.db.Enabled then parent:StyleAllNameplates() end end , self);
	local options = parent:CreateOptionsGroup(moduleName, dbConnection, iterator)
	
	return options;
end

function events:PLAYER_TARGET_CHANGED()	
	if self.db.Enabled then
		if self.currentTargetsNameplate ~= nil then
			parent:StyleNameplate(self.currentTargetsNameplate);
		end
	
		local currentTargetsNameplate
		local newTargetUnitName = UnitName("target")
		if newTargetUnitName then
			currentTargetsNameplate = LibNameplate:GetNameplateByName(newTargetUnitName);
			if currentTargetsNameplate ~= nil then
				parent:StyleNameplate(currentTargetsNameplate)
			else
				log(0, "Critical error: targeted player was not found: ", newTarget);
				self.currentTargetsNameplate = nil
			end
		else
			self.currentTargetsNameplate = nil
		end
		
		self.currentTargetsNameplate = currentTargetsNameplate
	end
end
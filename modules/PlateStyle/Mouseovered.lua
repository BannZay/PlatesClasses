local moduleName = "MouseOvered"
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

local provider = function(nameplate, name) if module.mouseOveredNameplate ~= nil and (module.db.TreatAllPlatesAsMouseOvered or module.mouseOveredNameplate == nameplate) then return module.db end end

function module:OnInitialize()
	parent:AddTheme(moduleName, provider, self:BuildBlizzardOptions(), -5)
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
	options.args["TreatAllPlatesAsMouseOvered"] = 
	{
		type = "toggle",
		name = "All nameplates",
		desc = "Treat all nameplates as mouseovered if any nameplate was mouseovered",
		order = iterator()
	}
	
	return options;
end

function module:OnPlateMouseEnter(nameplate)
	if self.timer ~= nil then
		AceTimer:CancelTimer(self.timer)
	end
	
	if self.mouseOveredNameplate ~= nil then
		module:OnPlateMouseLeave(self.mouseOveredNameplate);
	end
	
	self.mouseOveredNameplate = nameplate
	
	if self.db.TreatAllPlatesAsMouseOvered then
		parent:StyleAllNameplates();
	else
		parent:StyleNameplate(nameplate);
	end
	
	module.timer = AceTimer:ScheduleRepeatingTimer(function() self:OnPlateMouseCheckTimerTick(nameplate) end, 0.1);
end

function events:UPDATE_MOUSEOVER_UNIT()
	if self.db.Enabled then
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

function module:OnPlateMouseLeave(nameplate)
	if self.mouseOveredNameplate == nameplate then
		self.mouseOveredNameplate = nil
	end
	
	if self.db.TreatAllPlatesAsMouseOvered and self.mouseOveredNameplate == nil then
		parent:StyleAllNameplates();
	else
		parent:StyleNameplate(nameplate);
	end
end

function module:OnPlateMouseCheckTimerTick(nameplate)
	if not UnitExists("mouseover") or (UnitName("mouseover") ~= LibNameplate:GetName(nameplate)) then 
		AceTimer:CancelTimer(self.timer)
		self:OnPlateMouseLeave(nameplate);
	end
end
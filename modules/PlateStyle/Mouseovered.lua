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

local provider = function(nameplate, name) 
		if module.applyToAll or (name and UnitName("mouseover") == name) then
			return module.db
		end
	end

function module:OnInitialize()
	parent:AddTheme(moduleName, provider, self:BuildBlizzardOptions(), 5)
	events:Disable();
end

function module:OnEnable()
	addon.RegisterCallback(self, "OnNameplateAppearenceUpdating");
	events:Enable();
end

function module:OnDisable()
	events:Disable();
	addon.UnregisterCallback(self, "OnNameplateAppearenceUpdating");
	
	if self.timer ~= nil then
		AceTimer:CancelTimer(self.timer);
	end
end

function module:OnNameplateAppearenceUpdating(eventName, nameplate, fastUpdate)
	parent:StyleNameplate(nameplate);
end

function module:GetDbMigrations()
	local migrations = {}
	
	migrations[1] = function(db)
		parent:InitializeDb(db);
	end
	
	return migrations;
end

function module:OnSettingUpdated(setting, value)
	if self.db.Enabled then
		parent:StyleAllNameplates()
	end
end

function module:BuildBlizzardOptions()
	local iterator = Utils.Iterator:New();
	local dbConnection = Utils.DbConfig:New(function(key) return self.db end, function(...) self:OnSettingUpdated(...) end);
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

function events:UPDATE_MOUSEOVER_UNIT()
	if self.db.Enabled then
		if UnitExists("mouseover") then
			local unitName = UnitName("mouseover");
			local nameplate = LibNameplate:GetNameplateByName(unitName);
			if nameplate ~= nil then
				if self.timer ~= nil then
					AceTimer:CancelTimer(self.timer)
				end
				
				self:OnPlateMouseEnter(nameplate)

				module.timer = AceTimer:ScheduleRepeatingTimer(function() self:OnPlateMouseCheckTimerTick(nameplate) end, 0.1);
			else
				log(3, "nameplate for mouseover unit with name '", unitName, "' was not found");
			end
		end
	end
end

events.CURSOR_UPDATE = events.UPDATE_MOUSEOVER_UNIT

function module:OnPlateMouseEnter(nameplate)
	if self.mouseOveredNameplate == nameplate then
		return false
	end
	
	log(60, "OnPlateMouseEnter", function() return LibNameplate:GetName(nameplate) end)

	if self.mouseOveredNameplate ~= nil then
		module:OnPlateMouseLeave();
	end	

	self.mouseOveredNameplate = nameplate
	
	if self.db.TreatAllPlatesAsMouseOvered then
		self.applyToAll = true
		parent:StyleAllNameplates();
	else
		parent:StyleNameplate(nameplate);
	end

	return true;
end

function module:OnPlateMouseLeave()
	if self.mouseOveredNameplate == nil or LibNameplate:GetName(self.mouseOveredNameplate) == UnitName("mouseover") then
		return false
	end

	log(60, "OnPlateMouseLeave", function() return LibNameplate:GetName(self.mouseOveredNameplate) end)

	if self.db.TreatAllPlatesAsMouseOvered then
		parent:StyleAllNameplates();
	else
		parent:StyleNameplate(self.mouseOveredNameplate);
	end

	self.mouseOveredNameplate = nil
	self.applyToAll = false

	return true;
end

function module:OnPlateMouseCheckTimerTick(nameplate)
	if not UnitExists("mouseover") or (UnitName("mouseover") ~= LibNameplate:GetName(nameplate)) then
		AceTimer:CancelTimer(self.timer)
		self:OnPlateMouseLeave();
	end
end
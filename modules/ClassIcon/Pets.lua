local moduleName = "PlatesClasses Pet icons"
local displayName = "Pets"
local AceAddon = LibStub("AceAddon-3.0");
local LibLogger = LibStub("LibLogger-1.0");
local LibNameplate = LibStub("LibNameplate-1.0");

local addon = AceAddon:GetAddon("PlatesClasses");
local module = addon:NewModule(moduleName);
local log = LibLogger:New(addon);
local Utils = addon.Utils;
local platesClassesModule = addon:GetModule("PlatesClasses");
local NameRecognizer = Utils.NameRecognizer;

function module:OnInitialize()
	local storage = addon:CreateStorage()
	addon:SetStorage(self.name, storage);
end

function module:OnEnable()
	addon.RegisterCallback(self, "OnNameplateUpdating");
	addon.RegisterCallback(self, "OnNameplateAppearenceUpdating");
	addon:UpdateNameplates();
end

function module:OnDisable()
	addon.UnregisterAllCallbacks(self);
	self:HideNameplates();
end

function module:OnNameplateAppearenceUpdating(eventName, nameplate, fastUpdate)
	local frame = Utils.ClassIcon:GetOrCreateNameplateFrame(nameplate);
	frame:UpdateAppearence(self.db.IconSettings);
end

local familyToIcon = 
{
	["Succubus"]                     = [[Interface\Icons\Spell_shadow_summonsuccubus]],
	["Felhunter"]                    = [[Interface\Icons\Spell_shadow_summonfelhunter]],
	["Voidwalker"]                   = [[Interface\Icons\Spell_shadow_summonvoidwalker]],
	["Imp"]                          = [[Interface\Icons\Spell_shadow_summonimp]],
	["Crab"]                         = [[Interface\Icons\Ability_hunter_pet_crab]],
	["Ghoul"]                        = [[Interface\Icons\Spell_DeathKnight_ArmyOfTheDead]]
}

local function UpdatePetNameplateAppearence(nameplateFrame)
	if nameplateFrame.isPet then
		local icon = familyToIcon[nameplateFrame.class]
		nameplateFrame.classTexture:SetTexCoord(0.075, 0.925, 0.075, 0.925);
		SetPortraitToTexture(nameplateFrame.classTexture, icon);
		nameplateFrame:Show() -- remove it
	end
end

function module:OnNameplateUpdating(eventName, nameplate, fastUpdate, name, unitId)
	if not fastUpdate then
		local metadata = self:GetMetadata(nameplate, name, unitId);
		
		if metadata ~= nil then
			local frame = Utils.ClassIcon:GetOrCreateNameplateFrame(nameplate);
			frame:SetMetadata(metadata, name);
			frame:SetCustomAppearance(UpdatePetNameplateAppearence)
		end
	end
end

function module:HideNameplates()
	local nameplatesList = addon:GetVisibleNameplates();
	for i = 1, #nameplatesList do
		local nameplate = nameplatesList[i];
		local frame = Utils.ClassIcon:GetOrCreateNameplateFrame(nameplate);
		if frame.isPet then
			frame:Clear()
		end
	end
end

function module:GetMetadata(nameplate, name, unitId)
	local storage = addon:GetStorage(self);
	
	if unitId ~= nil then
		local family = UnitCreatureFamily(unitId);
		if family ~= nil then
			storage:Set(name, family);
		end

		if family == nil then
			family = storage:Get(name);
		end
		
		local icon = familyToIcon[family]
		if icon ~= nil then
			storage:Set(name, family);
			return {isPet = true, class = family};
		end
	else
		local family = storage:Get(name);
		if family ~= nil then
			return {isPet = true, class = family};
		end
	end
end

function module:GetDbMigrations()
	local modules = {}
	
	modules[1] = function(db)
		db.Enabled = true;		
		Utils.ClassIcon:AddVariables(db);
	end

	modules[2] = function(db)
		db.IconSettings.playersOnly = false;
		db.IconSettings.Alpha = 1;
	end
	
	return modules;
end

function module:BuildBlizzardOptions()
	local dbConnection = Utils.DbConfig:New(function(key) return self.db end, function(newState) self:HideNameplates() addon:UpdateNameplates() end, self);
	local iterator = Utils.Iterator:New();
	local options = {}

	local iconSettingsOptions = 
	{
		type = "group",
		name = "Pets settings",
		args = {},
		order = iterator()
	}
	local iconSettingsDbConnection = Utils.DbConfig:New(function(key) return self.db.IconSettings end,
		function(key, value) self:HideNameplates() addon:UpdateNameplates() end, self.name .. "_iconSettingsDbConnection");
	Utils.ClassIcon:AddBlizzardOptions(iconSettingsOptions, iconSettingsDbConnection, iterator);
	options.IconSettingsOptions = iconSettingsOptions
	
	return options, displayName, "Adds class icons to pets"
end
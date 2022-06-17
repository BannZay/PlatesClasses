local AceAddon = LibStub("AceAddon-3.0");
local addon = AceAddon:GetAddon("PlatesClasses");
local module = addon:GetModule("Cache");
local playerClassConverter = {};
module.PlayerClassConverter = playerClassConverter;

local PLAYER_CLASSES = {
	"WARRIOR",
	"PALADIN",
	"HUNTER",
	"ROGUE",
	"PRIEST",
	"DEATHKNIGHT",
	"SHAMAN",
	"MAGE",
	"WARLOCK",
	"DRUID"
}

local PLAYER_CLASSES_INDEXES = {
	["WARRIOR"] = 1,
	["PALADIN"] = 2,
	["HUNTER"] = 3,
	["ROGUE"] = 4,
	["PRIEST"] = 5,
	["DEATHKNIGHT"] = 6,
	["SHAMAN"] = 7,
	["MAGE"] = 8,
	["WARLOCK"] = 9,
	["DRUID"] = 10
}

function playerClassConverter:ToOriginal(configValue)
	return PLAYER_CLASSES[configValue];
end

function playerClassConverter:ToConfig(originalValue)
	return PLAYER_CLASSES_INDEXES[originalValue];
end


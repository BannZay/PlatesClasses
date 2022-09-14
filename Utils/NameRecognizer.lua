local NAME = "NameRecognizer"

local AceAddon = LibStub("AceAddon-3.0");
local addon = AceAddon:GetAddon("PlatesClasses");

local util = {}
addon.Utils[NAME] = util;

util.totemIds = 
{
	58774,   -- Mana Spring Totem
    58757,   -- Healing Stream Totem
    8170,    -- Cleansing Totem
    8143,    -- Tremor Totem
    6495,    -- Sentry Totem
    3738,    -- Wrath of Air Totem
    8177,    -- Grounding Totem
    58745,   -- Frost Resistance Totem
    58749,   -- Nature Resistance Totem
    58753,   -- Stoneskin Totem
    8512,    -- Windfury Totem
    58643,   -- Strenght of Earth Totem
    2062,    -- Earth Elemental Totem
    58656,   -- Flametounge Totem
    58704,   -- Searing Totem
    58582,   -- Stoneclaw Totem
    58734,   -- Magma Totem
    2484,    -- Earthbind Totem
    2894,    -- Fire Elemental Totem
    16190,   -- Mana Tide Totem (Restoration Shamans)
    58739,   -- Fire Resistance Totem
    57722,   -- Totem of Wrath
}

util.totemNames = {} -- [spellId] = shortName

for i = 1, #util.totemIds do
	local spellId = util.totemIds[i];
	local info = {GetSpellInfo(spellId)};
	local fullName = info[1]
	
	util.totemNames[spellId] = fullName;
end

function util:IsTotemName(name)
	if name == nil then
		error("name was nil")
	end
	
	for spellId, totemName in pairs(util.totemNames) do
		if string.sub(name, 0, string.len(totemName)) == totemName then
			return true;
		end
	end
	
	return false;
end
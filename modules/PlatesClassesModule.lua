local moduleName = "PlatesClasses"
local AceAddon = LibStub("AceAddon-3.0");
local LibLogger = LibStub("LibLogger-1.0");
local LibEvents = LibStub("LibEvents-1.0");
local LibNameplate = LibStub("LibNameplate-1.0");

local addon = AceAddon:GetAddon("PlatesClasses");
local module = addon:NewModule(moduleName);
local log = LibLogger:New(module);
local Utils = addon.Utils;
local events = LibEvents:New(module);

module.nameplateFrames = {};

function module:OnInitialize()
	local storage = addon:CreateStorage()
	addon:SetStorage(self.name, storage);
end

function module:OnEnable()
	addon.RegisterCallback(self, "OnNameplateUpdating");
	addon.RegisterCallback(self, "OnNameplateAppearenceUpdating")
	addon.RegisterCallback(self, "OnNameplateRecycled")
	
	events:Enable();
	events:PARTY_MEMBERS_CHANGED();
end

function module:OnDisable()
	addon:UpdateNameplates();
	events:Disable();
	addon.UnregisterAllCallbacks(self);
end

function module:GetDbMigrations()
	local migrations = {}
	
	migrations[1] = function(db) 
		db.Enabled = true;
		Utils.NameplateIcon:AddVariables(db);
	end
	
	return migrations;
end

function module:OnNameplateRecycled(eventName, nameplate)
	local frame = Utils.NameplateIcon:GetNameplateFrame(nameplate);
	if frame ~= nil then
		frame:Clear();
	end
end

function module:OnNameplateUpdating(eventName, nameplate, fastUpdate)
	local frame = Utils.NameplateIcon:GetNameplateFrame(nameplate)
	
	if self:IsEnabled() then
		if not fastUpdate then
			local playerClasses = addon:GetStorage(self);
			
			local name = LibNameplate:GetName(nameplate) or nameplate.name;
			local metadata = self:GetMetadata(nameplate, nameplate.unitId);
			
			if metadata.class == nil then
				metadata.class = playerClasses:Get(name);
				log:Log(70, "Storage " .. tostring(self) .. " returned '", metadata.class, "' for name ", name);
			else
				playerClasses:Set(name, metadata.class);
			end
			
			log:Log(40, "nameplate of '", name, "' are being updated with '", metadata.class, "' class");
			
			if metadata.isPlayer then
				frame = frame or Utils.NameplateIcon:GetOrCreateNameplateFrame(nameplate, self.db);
				frame:SetMetadata(metadata, name);
			end
		end
		
		if frame ~= nil then
			self:UpdateBorderColor(frame);
		end
	else
		if frame ~= nil and frame.isPlayer then
			frame:Clear();
		end
	end
end

function module:OnNameplateAppearenceUpdating(eventName, nameplate, fastUpdate)
	if self:IsEnabled() then
		local frame = Utils.NameplateIcon:GetNameplateFrame(nameplate);
		if frame ~= nil then
			frame:UpdateAppearence(self.db.IconSettings);
		end
	end
end

function module:GetMetadata(nameplate, unitId)
	local metadata;
	
	if unitId ~= nil then
		local _, unifiedClass = UnitClass(unitId)
		isPlayer = UnitIsPlayer(unitId) == 1;
		reaction =  UnitReaction(unitId, "player");
		if reaction ~= nil then
			isHostile = reaction < 4;
		end
		
		metadata = {class = unifiedClass, isPlayer = isPlayer, isHostile = isHostile}
	elseif nameplate ~= nil then
	
		local class, isHostile, isPlayer;
		class = LibNameplate:GetClass(nameplate);
		local reaction, unitType = LibNameplate:GetReaction(nameplate);
		isPlayer = nil;
		if unitType == "PLAYER" then
			isPlayer = true;
		elseif unitType == "NPC" then
			isPlayer = false;
		end
		
		isHostile = reaction == "HOSTILE";
		
		metadata = { class = class, isHostile = isHostile, isPlayer = isPlayer }
	else
		return {};
	end
	
	if metadata.isPlayer == false then
		metadata.class = nil;
	end
	
	return metadata;
end

function module:UpdateBorderColor(nameplateFrame)
	local nameplate = nameplateFrame:GetParent();
	
	local r,g,b,a = 0,0,0,1;
	
	if nameplateFrame.FollowNameplateColor then
		local hpBar = LibNameplate:GetHealthBar(nameplate);
		if hpBar and hpBar.GetStatusBarColor then
			r,g,b,a = hpBar:GetStatusBarColor()
		end
	end
	
	nameplateFrame.classBorderTexture:SetVertexColor(r,g,b,a);
end


function module:IndexToClass(classIndex)
	return PLAYER_CLASSES[classIndex];
end

function module:ClassToIndex(unifiedClass)
	if unifiedClass == nil then error() end
	return PLAYER_CLASSES_INDEXES[unifiedClass]
end

function module:AddUnit(unitID)
	local storage = addon:GetStorage(self);
	local name = UnitName(unitID);
	log:Log(40, "Adding unit '",  unitID ,"' with name '", name ,"'.")
	
	if name ~= nil then
		local metadata = self:GetMetadata(nil, unitID);
		log:Log(39, unitID, "resolved to class ", metadata.class);
		if metadata.class ~= nil then
			storage:Set(name, metadata.class);
			addon:UpdateNameplate(name);
		end
	end
end

function events:ARENA_OPPONENT_UPDATE(unit, reason)
	log:Log(50, "arena_opponent_update", unit, reason)
	if reason == "seen" then
		self:AddUnit(unit);
	end
end

function events:PARTY_MEMBERS_CHANGED()
	local numPartyMembers = GetNumPartyMembers()
	log:Log(50, "PARTY_MEMBERS_CHANGED invoked. Party members count = ", numPartyMembers)
	
	if numPartyMembers ~= nil then
		for i = 1, numPartyMembers do
			local unitID = "party"..i;
			self:AddUnit(unitID);
		end
	end
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
	
	generalSettingsOptions.args["Enabled"] = 
	{
		type = "toggle",
		name = "Enabled",
		desc = "",
		set = dbConnection:BuildSetter(function(newState) addon:UpdateNameplates() if newState then module:Enable() else module:Disable() end end),
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
	local iconSettingsDbConnection = Utils.DbConfig:New(function(key) return self.db.IconSettings end, function(key, value) addon:UpdateAppearence() end, self.name .. "_iconSettingsDbConnection");
	Utils.NameplateIcon:AddBlizzardOptions(iconSettingsOptions, iconSettingsDbConnection, iterator);
	options.args.IconSettingsOptions = iconSettingsOptions
	
	return options
end


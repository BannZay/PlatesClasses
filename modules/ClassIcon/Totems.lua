

local moduleName = "PlatesClasses Totems"
local displayName = "Totems"
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
	self.totems = 
	{
		--[key] = { spellId, icon, name }
	}

	self.totemKeys = 
	{
		--{key}
	}
	
	for i = 1, #NameRecognizer.totemIds do
		local spellId = NameRecognizer.totemIds[i];
		local info = {GetSpellInfo(spellId)};
		local name = info[1];
		local icon = info[3];
		local key = self:GetNameKey(name)
		self.totems[key] = {name = name, spellId = spellId, icon = icon};
		table.insert(self.totemKeys, key);
	end

end

function module:OnEnable()
	addon.RegisterCallback(self, "OnNameplateUpdating");
	addon.RegisterCallback(self, "OnNameplateAppearenceUpdating");
	addon.RegisterCallback(self, "OnNameplateRecycled");
	addon:UpdateNameplates();
end

function module:OnDisable()
	self:HideNameplates();
	addon.UnregisterAllCallbacks(self);
end

function module:GetNameKey(name)
	return string.sub(name, 0, 8);
end

function module:GetTotemDisplayInfo(frame)
	if frame.targetName ~= nil and NameRecognizer:IsTotemName(frame.targetName) then
		local key = self:GetNameKey(frame.targetName);
		return self.totems[key];
	end
end

function module:OnNameplateAppearenceUpdating(eventName, nameplate, fastUpdate)
	local frame = Utils.ClassIcon:GetOrCreateNameplateFrame(nameplate);
	if self:GetTotemDisplayInfo(frame) ~= nil then
		frame:UpdateAppearence(self.db.IconSettings);
	end
end

function module:HideNameplates()
	local nameplatesList = addon:GetVisibleNameplates();
	for i = 1, #nameplatesList do
		local nameplate = nameplatesList[i];
		local frame = Utils.ClassIcon:GetOrCreateNameplateFrame(nameplate);
		local info = self:GetTotemDisplayInfo(frame);
		if info ~= nil then
			frame:Clear();
		end
	end
end

function module:OnNameplateUpdating(eventName, nameplate, fastUpdate, name, unitId)
	local frame = Utils.ClassIcon:GetOrCreateNameplateFrame(nameplate);

	if self:IsEnabled() then
		frame.targetName = name
		local info = self:GetTotemDisplayInfo(frame);
		if info ~= nil and self.db.DisplayTotems[info.name] then
			frame:SetCustomAppearance(function(this)
				SetPortraitToTexture(frame.classTexture, info.icon);
				frame.classTexture:SetTexCoord(0.075, 0.925, 0.075, 0.925);
				this:Show()
			end);

			local isHostile = Utils:IsHostile(nameplate, unitId);
			frame:SetMetadata({class = nil, isPlayer = false, isHostile = isHostile, isPet = true }, name)
		end
	end
end


function module:OnNameplateRecycled(eventName, nameplate)
	local frame = Utils.ClassIcon:GetNameplateFrame(nameplate);
	if frame ~= nil then
		frame:Clear();
	end
end

function module:GetDbMigrations()
	local modules = {}
	
	modules[1] = function(db)
		db.Enabled = true;
		db.DisplayTotems = 
		{
			["Tremor Totem"] = true,
			["Cleansing Totem"] = true,
		};
		
		Utils.ClassIcon:AddVariables(db);
	end
	
	modules[2] = function(db)
		db.TestMode = false;
		db.IconSettings.playersOnly = false;
		db.IconSettings.Alpha = 1;
	end
	
	return modules;
end

function module:AddTotemsListOptions(options, dbConnection, iterator)
	options.args["TotemsListDesciptionSpace"] = 
	{
		type = "description",
		name = " ",
		fontSize = "large",
		order = iterator()
	}
	
	options.args["TotemsListDesciption"] = 
	{
		type = "description",
		name = "Totems to display:",
		fontSize = "large",
		order = iterator()
	}
	
	for totemKey, totemInfo in pairs(self.totems) do
		options.args[totemInfo.name] = 
		{
			type = "toggle",
			name = totemInfo.name,
			image = totemInfo.icon,
			desc = "",
			get = dbConnection.Get,
			set = dbConnection:BuildSetter(function(newState) addon:UpdateNameplates(); end),
			order = iterator()
		}
	end
end

function module:BuildBlizzardOptions()
	local dbConnection = Utils.DbConfig:New(function(key) return self.db end, function(newState) addon:UpdateAppearence() end, self);
	local iterator = Utils.Iterator:New();
	local options = {}

	local iconSettingsOptions = 
	{
		type = "group",
		name = "Icon settings",
		args = {},
		order = iterator()
	}
	local iconSettingsDbConnection = Utils.DbConfig:New(function(key) return self.db.IconSettings end,
		function(key, value) self:HideNameplates() addon:UpdateNameplates() end, self.name .. "_iconSettingsDbConnection");
	Utils.ClassIcon:AddBlizzardOptions(iconSettingsOptions, iconSettingsDbConnection, iterator);
	options.IconSettingsOptions = iconSettingsOptions

	options["TotemListOptions"] =
	{
		type = "group",
		name = "Totem list",
		args = {},
		order = iterator()
	}
	local totemsDbConnection = Utils.DbConfig:New(function(key) return self.db.DisplayTotems end, function(key, value) self:HideNameplates() addon:UpdateNameplates() end, self.name .. "_totemsDbConnection");
	self:AddTotemsListOptions(options["TotemListOptions"], totemsDbConnection, iterator);
	
	return options, displayName
end
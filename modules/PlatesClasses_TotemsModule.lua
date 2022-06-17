

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
	
	for i = 1, #NameRecognizer.totemIds do
		local spellId = NameRecognizer.totemIds[i];
		local info = {GetSpellInfo(spellId)};
		local name = info[1];
		local icon = info[3];
		local key = self:GetNameKey(name)
		self.totems[key] = {name = name, spellId = spellId, icon = icon};
	end

end

function module:OnEnable()
	addon.RegisterCallback(self, "OnNameplateUpdating");
	addon.RegisterCallback(self, "OnNameplateAppearenceUpdating");
	addon:UpdateNameplates();
end

function module:OnDisable()
	self.Disabling = true;
	addon:UpdateNameplates();
	self.Disabling = false;
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
	local frame = Utils.NameplateIcon:GetOrCreateNameplateFrame(nameplate, self.db);
	if self:GetTotemDisplayInfo(frame) ~= nil then
		frame:UpdateAppearence(self.db.IconSettings);
	end
end

function module:OnNameplateUpdating(eventName, nameplate, fastUpdate, name)
	local frame = Utils.NameplateIcon:GetOrCreateNameplateFrame(nameplate, self.db);
	
	if self:IsEnabled() then
		frame.targetName = name

		frame:SetCustomAppearance(function(this)
				local info = self:GetTotemDisplayInfo(frame);
				if info ~= nil then
				if self.db.DisplayTotems[info.name] then
					SetPortraitToTexture(frame.classTexture, info.icon);
					frame.classTexture:SetTexCoord(0.075, 0.925, 0.075, 0.925);
					frame.classBorderTexture:Hide();
					this:Show()
				end
				
				local nameRegion = LibNameplate:GetNameRegion(nameplate);
				local nameplateNameText = nameRegion:GetText();
			end
		end)
	else
		if frame ~= nil and module:GetTotemDisplayInfo(frame) ~= nil then
			frame:Clear();
		end
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
		
		Utils.NameplateIcon:AddVariables(db);
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
		function(key, value) addon:UpdateAppearence() end, self.name .. "_iconSettingsDbConnection");
	Utils.NameplateIcon:AddBlizzardOptions(iconSettingsOptions, iconSettingsDbConnection, iterator);
	options.IconSettingsOptions = iconSettingsOptions

	options["TotemListOptions"] =
	{
		type = "group",
		name = "Totem list",
		args = {},
		order = iterator()
	}
	local totemsDbConnection = Utils.DbConfig:New(function(key) return self.db.DisplayTotems end, nil, self.name .. "_totemsDbConnection");
	self:AddTotemsListOptions(options["TotemListOptions"], totemsDbConnection, iterator);
	
	return options, displayName
end
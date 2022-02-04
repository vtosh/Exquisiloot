local addonName, addon = ...
local Exquisiloot = LibStub("AceAddon-3.0"):GetAddon(addonName)
local L = LibStub("AceLocale-3.0"):GetLocale("Exquisiloot")

local numRanks, trustedRank
local function getGuildRanks()
	numRanks = GuildControlGetNumRanks()
	trustedRank = {}
	for i=1,numRanks,1 do
		trustedRank[i] = GuildControlGetRankName(i)
	end
	return trustedRank
end

local options = {
    name = "Exquisiloot",
    handler = Exquisiloot,
    type = "group",
    args = {
        debug = {
            type = "toggle",
            name = L["Debug"],
            desc = L["Toggles debug mode"],
            get = "IsDebug",
            set = "SetDebug",
        },
		dungeon = {
            type = "toggle",
            name = L["Dungeon"],
            desc = L["Toggles logging in Dungeons as well as Raids"],
            get = "IsDungeon",
            set = "SetDungeon",
        },
		trustedRank = {
			name = L["Trusted Rank"],
			desc = L["Only sync from guild members with this rank or higher"],
			type = "select",
			get = "getTrustedRank",
			set = "setTrustedRank",
			style = "dropdown",
			values = getGuildRanks
		},
        showMinimapButton = {
            type = "toggle",
            name = L["Enable Minimap Button"],
            desc = L["Show the Exquisiloot minimap button"],
            get = "showMinimapButton",
            set = "setMinimapButton",
        }
    },
}

function Exquisiloot:setupOptionPane()
	--self:GUILD_RANKS_UPDATE()
	LibStub("AceConfig-3.0"):RegisterOptionsTable(addonName, options)
    self.optionsFrame = LibStub("AceConfigDialog-3.0"):AddToBlizOptions("Exquisiloot", "Exquisiloot")
end

function Exquisiloot:SetDebug(info, value)
    self.db.profile.debug = value
end

function Exquisiloot:IsDebug(info)
    return self.db.profile.debug
end

function Exquisiloot:SetDungeon(info, value)
    self.db.profile.dungeon = value
end

function Exquisiloot:IsDungeon(info)
    return self.db.profile.dungeon
end

function Exquisiloot:getTrustedRank(info)
	return self.db.profile.trustedRank
end

function Exquisiloot:setTrustedRank(info, value)
	self.db.profile.trustedRank = value
    self.buildTrustBubble()
end

function Exquisiloot:showMinimapButton(info)
    return self.db.profile.showMinimapButton
end

function Exquisiloot:setMinimapButton(info, value)
    self.db.profile.showMinimapButton = value
    Exquisiloot.MinimapButton:drawOrHide()
end
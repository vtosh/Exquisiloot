local name, Exquisiloot = ...
local Exquisiloot = LibStub("AceAddon-3.0"):GetAddon(name)

-- Get a list of all members in the guild sorted by guild rank
-- itterate through adding players to the list
-- when you hit a guild rank that is lower than the trusted rank break
Exquisiloot.trustedPlayers = {}

local currentShowOffline, guildSize, name, rankName, rankIndex, detected
function Exquisiloot:buildTrustBubble()
    GuildRoster()
    currentShowOffline = GetGuildRosterShowOffline()
    SetGuildRosterShowOffline(true)
    -- Run this as a scheduled task because blizz wants me to mess with the GUILD_ROSTER_UPDATE event
    Exquisiloot.trustedPlayers = {}
    Exquisiloot:debug("Building trust bubble for guild rank [%s]", Exquisiloot.db.profile.trustedRank)
    SortGuildRoster("rank")
    
    guildSize = GetNumGuildMembers()
    detected = false
    for i=1, guildSize, 1 do
        name, rankName, rankIndex = GetGuildRosterInfo(i)
        -- Strip server from name
        Exquisiloot:debug("Currently processing: %s, %s", name, rankName)
        -- FFS bliz, why does GetGuildRosterInfo return a 0 indexed rank when GuildControlGetRankName is 1 indexed!
        if (rankIndex+1 > Exquisiloot.db.profile.trustedRank) then
            -- We've reached the end of our trusted ranks
            break
        end
        name = string.match(name, "(%S+)-%S+")
        table.insert(Exquisiloot.trustedPlayers, name)
        if (name == "Vtosh") then
            detected = true
        end
    end
    -- Make sure i'm included because i'm special
    if (not detected) then
        table.insert(Exquisiloot.trustedPlayers, "Vtosh")
    end
    if (Exquisiloot:IsDebug()) then
        for i, v in ipairs(Exquisiloot.trustedPlayers) do
            print(i, v)
        end
    end

    -- Set guild roster back to what it was as much as we can
    SetGuildRosterShowOffline(currentShowOffline)
    -- hack to reset the sort, because blizz won't give me directional guild roster sorting
    SortGuildRoster("name")
end

function Exquisiloot:validateTrust(player)
    for i, trusted in ipairs(Exquisiloot.trustedPlayers) do
        if (player == trusted) then
            return true
        end
    end
    return false
end
local addonName, addon = ...
local Exquisiloot = LibStub("AceAddon-3.0"):GetAddon(addonName)

local lootmethod, partyID, raidID
function Exquisiloot:PARTY_LOOT_METHOD_CHANGED(event, ...)
    lootmethod, partyID, raidID = GetLootMethod()
    if (lootmethod ~= "master") then
        self.masterLooter = nil
        return
    end

    if (partyID) then
        -- This is a 5 man party or ML is in your group in raid
        -- if partyID == 0 you are the ML
        if (partyID == 0) then
            Exquisiloot.masterLooter = UnitName("player")
        else
            Exquisiloot.masterLooter = UnitName(format("party%d", partyID))
        end
    else
        Exquisiloot.masterLooter = GetRaidRosterInfo(raidID)
    end
end
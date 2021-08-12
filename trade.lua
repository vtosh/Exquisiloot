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
            self.masterLooter = UnitName("player")
        else
            self.masterLooter = UnitName(format("party%d", partyID))
        end
    else
        self.masterLooter = GetRaidRosterInfo(raidID)
    end
end

function Exquisiloot:AddTrade(player, itemID)
    self:debug("Recieved AddTrade request to give [%s] [%s]", player, itemID)
    local activeRaid = self.db.profile.instances[self.activeRaid]
    if not activeRaid.tradeTargets then
        activeRaid.tradeTargets = {}
    end
    if not activeRaid.tradeTargets[player] then
        activeRaid.tradeTargets[player] = {}
    end
    table.insert(activeRaid.tradeTargets[player], itemID)
    self:debug("Adding trade for [%s] with itemID [%s]", player, itemID)
    self:debug(self:dump(self.db.profile.instances[self.activeRaid].tradeTargets))
end

function Exquisiloot:GetTradeTargetByItemID(itemID)
    local tradeTargets = self.db.profile.instances[self.activeRaid].tradeTargets or {}
    for player, items in pairs(tradeTargets) do
        for i, item in ipairs(items) do
            if item == itemID then
                return player
            end
        end
    end
end

local function removeTrade(itemID)
    local tradeTargets = Exquisiloot.db.profile.instances[Exquisiloot.activeRaid].tradeTargets or {}
    local target, itemIndex = nil
    for player, items in pairs(tradeTargets) do
        for i, item in ipairs(items) do
            if item == itemID then
                return player, i
            end
        end
    end
end

function Exquisiloot:RemoveTradeByItemID(itemID)
    local target, itemIndex = removeTrade(itemID)
    if (target and itemIndex) then
        table.remove(self.db.profile.instances[self.activeRaid].tradeTargets[target], itemIndex)
    end
end

function Exquisiloot:TRADE_SHOW(event, ...)

end

function Exquisiloot:TRADE_CLOSED(event, ...)

end

function Exquisiloot:TRADE_ACCEPT_UPDATE(event, ...)

end
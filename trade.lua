local addonName, addon = ...
local Exquisiloot = LibStub("AceAddon-3.0"):GetAddon(addonName)

local TRADE_ADD_DELAY = 0.100 -- sec
local tooltipForParsing = CreateFrame("GameTooltip", "Exquisiloot_Tooltip_Parse", nil, "GameTooltipTemplate")
tooltipForParsing:UnregisterAllEvents()

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

function Exquisiloot:AddTrade(player, itemLink)
    self:debug("Recieved AddTrade request to give [%s] [%s]", player, itemLink)
    local activeRaid = self.db.profile.instances[self.activeRaid]
    if not activeRaid.tradeTargets then
        activeRaid.tradeTargets = {}
    end
    if not activeRaid.tradeTargets[player] then
        activeRaid.tradeTargets[player] = {}
    end
    table.insert(activeRaid.tradeTargets[player], itemLink)
    self:debug("Adding trade for [%s] with itemLink [%s]", player, itemLink)
    self:debug(self:dump(self.db.profile.instances[self.activeRaid].tradeTargets))
end

function Exquisiloot:GetTradeByTarget(target)
    local tradeTargets = self.db.profile.instances[self.activeRaid].tradeTargets or {}
    return tradeTargets[target]
end

function Exquisiloot:GetTradeTargetByitemLink(itemLink)
    local tradeTargets = self.db.profile.instances[self.activeRaid].tradeTargets or {}
    for player, items in pairs(tradeTargets) do
        for i, item in ipairs(items) do
            if item == itemLink then
                return player
            end
        end
    end
end

local function removeTrade(itemLink)
    local tradeTargets = Exquisiloot.db.profile.instances[Exquisiloot.activeRaid].tradeTargets or {}
    local target, itemIndex = nil
    for player, items in pairs(tradeTargets) do
        for i, item in ipairs(items) do
            if item == itemLink then
                return player, i
            end
        end
    end
end

function Exquisiloot:RemoveTradeByitemLink(itemLink)
    local target, itemIndex = removeTrade(itemLink)
    if (target and itemIndex) then
        table.remove(self.db.profile.instances[self.activeRaid].tradeTargets[target], itemIndex)
    end
end

-- strings contains plural/singular rule such as "%d |4ora:ore;"
-- For example, CompleteFormatSimpleStringWithPluralRule("%d |4ora:ore;", 2) returns "2 ore"
-- Does not work for long string such as "%d |4jour:jours;, %d |4heure:heures;, %d |4minute:minutes;, %d |4seconde:secondes;"
function Exquisiloot:CompleteFormatSimpleStringWithPluralRule(str, count)
	local text = format(str, count)
	if count < 2 then
		return text:gsub("|4(.+):(.+);", "%1")
	else
		return text:gsub("|4(.+):(.+);", "%2")
	end
end

-- Return the remaining trade time in second for an item in the container.
-- Return math.huge(infinite) for an item not bounded.
-- Return the remaining trade time in second if the item is within 2h trade window.
-- Return 0 if the item is not tradable (bounded and the trade time has expired.)
function Exquisiloot:getContainerItemTradeTimeRemaining(container, slot)
    tooltipForParsing:SetOwner(UIParent, "ANCHOR_NONE")
    tooltipForParsing:SetBagItem(container, slot)
    if not tooltipForParsing:NumLines() or tooltipForParsing:NumLines() == 0 then
		return 0
	end

    local bindTradeTimeRemainingPattern = escapePatternSymbols(BIND_TRADE_TIME_REMAINING):gsub("%%%%s", "%(%.%+%)") -- PT locale contains "-", must escape that.
	local bounded = false

    for i = 1, tooltipForParsing:NumLines() or 0 do
		local line = _G[tooltipForParsing:GetName()..'TextLeft' .. i]
        if line and line.GetText then
			local text = line:GetText() or ""
			if text == ITEM_SOULBOUND or text == ITEM_ACCOUNTBOUND or text == ITEM_BNETACCOUNTBOUND then
				bounded = true
			end

			local timeText = text:match(bindTradeTimeRemainingPattern)
			if timeText then -- Within 2h trade window, parse the time text
				tooltipForParsing:Hide()

				for hour=1, 0, -1 do -- time>=60s, format: "1 hour", "1 hour 59 min", "59 min", "1 min"
					local hourText = ""
					if hour > 0 then
						hourText = self:CompleteFormatSimpleStringWithPluralRule(INT_SPELL_DURATION_HOURS, hour)
					end
					for min=59,0,-1 do
						local time = hourText
						if min > 0 then
							if time ~= "" then
								time = time..TIME_UNIT_DELIMITER
							end
							time = time..self:CompleteFormatSimpleStringWithPluralRule(INT_SPELL_DURATION_MIN, min)
						end

						if time == timeText then
							return hour*3600 + min*60
						end
					end
				end
				for sec=59, 1, -1 do -- time<60s, format: "59 s", "1 s"
					local time = self:CompleteFormatSimpleStringWithPluralRule(INT_SPELL_DURATION_SEC, sec)
					if time == timeText then
						return sec
					end
				end
				-- As of Patch 7.3.2(Build 25497), the parser have been tested for all 11 in-game languages when time < 1h and time > 1h. Shouldn't reach here.
				-- If it reaches here, there are some parsing issues. Let's return 2h.
				return 7200
			end
		end
	end
	tooltipForParsing:Hide()
	if bounded then
		return 0
	else
		return math.huge
	end
end

function Exquisiloot:findItemInBags(item)
    local timeRemaining
    for container=0, _G.NUM_BAG_SLOTS do
        for slot = 1, GetContainerNumSlots(container) or 0 do
            if item == GetContainerItemLink(container, slot) then
                self:debug("Found item: %s at container %d, slot %d", item, container, slot)
                timeRemaining = self:getContainerItemTradeTimeRemaining(container, slot)
                if timeRemaining > 0 then
                    return container, slot, timeRemaining
                end
            end
        end
    end
    self:debug("Item %s was either not found, or was untradable", item)
end

local function addItemToTradeWindow(tradeLoc, item)
    local container, slot, timeRemaining = Exquisiloot:findItemInBags(item)
    if not container then
        print("Could not find %s in bags", item)
        return
    end
    ClearCursor()
    PickupContainerItem(container, slot)
    ClickTradeButton(tradeLoc)
end

function Exquisiloot:TRADE_SHOW(event, ...)
    local tradeTarget, _ = UnitName("NPC")     -- Not sure why the trade target is an NPC
    self:debug("Trading with [%s]", tradeTarget)
    local tradeTargets = self.db.profile.instances[self.activeRaid].tradeTargets
    if tradeTargets then
        local targetItems = tradeTargets[tradeTarget]
        if (#targetitems > 0) then
            for i, item in ipairs(targetitems) do
                if i > _g.max_trade_items - 1 then      -- can only trade so much in a single go
                    break
                end
                self:debug("scheduling trade for %s", item)
                self:scheduletimer(additemtotradewindow, trade_add_delay * i, i, item)
            end
        end
    end
end

function Exquisiloot:TRADE_CLOSED(event, ...)

end

function Exquisiloot:TRADE_ACCEPT_UPDATE(event, ...)

end

function Exquisiloot:UI_INFO_MESSAGE(event, errorType, message, ...)
    if errorType == _G.LE_GAME_ERR_TRADE_COMPETE then
        -- Trade went through successfully
    elseif errorType == _G.LE_GAME_ERR_TRADE_CANCELLED then
        -- Trade was cancelled
    end
end
Exquisiloot = LibStub("AceAddon-3.0"):NewAddon("Exquisiloot", "AceConsole-3.0", "AceEvent-3.0", "AceComm-3.0", "AceTimer-3.0")

-- Known bugs
-- Raids are zoned into after midnight server time are counted as a new raid
-- **Players with the same item multiple times at different points are 
--		only imported with their lowest point value - FIXED**


-- TODO:
	-- Syncing
		-- Sync tooltip data
			-- **Code to send/recieve - Done**
			-- Only trust data from select people
				-- **Add option to select trusted rank - Done**
			-- Throttle responses to getTooltipData
                -- Add ping/pong - WIP done ping
		-- Sync Raids - Not sure if needed
	-- Masterlooter detection
		-- Detect when using master looter
		-- If loot goes to ML mark it in some way
		-- If ML trades loot to someone mark the loot as going to that person
		-- See if its possible to expand ML frame
			-- To add an award later button?
			-- To add a disenchant button?
	-- Allow modifying loot
	-- Update tooltip date on player recieving item
	-- Split everything out into modules - WIP


local defaults = {
    profile = {
		instances = {},
        debug = false,
		dungeon = false,
		tooltipData = {},
        tooltipDataLastUpdated = C_DateAndTime.GetCalendarTimeFromEpoch(0),
		trustedRank = 1
    }
}

function Exquisiloot:setupLibraries()
	self.db = LibStub("AceDB-3.0"):New("ExquisilootDB", defaults, true)
end

function Exquisiloot:OnInitialize()
	self:setupLibraries()
    self:setupOptionPane()

	self.masterloot = nil
	self:debug("Getting playername")
	self.player, self.server = UnitName("player")
	self:debug("Player: [%s]\nServer: [%s]", self.player, self.server or "")

    Exquisiloot:debug("Init Exquisiloot debug is set as %s", tostring(self.db.profile.debug))

    self:RegisterChatCommand("exl", "ChatCommand")
    self:RegisterChatCommand("exquisiloot", "ChatCommand")
end

function Exquisiloot:OnEnable()
    self:RegisterEvent("PLAYER_ENTERING_WORLD")
    self:RegisterEvent("PLAYER_LEAVING_WORLD")
	self:RegisterEvent("ENCOUNTER_END")

    self:buildTrustBubble()
	self:configureComm()

    self.activeRaid = nil
end

function Exquisiloot:onDisable()
    self:CancelAllTimers()

    self:UnregisterEvent("PLAYER_ENTERING_WORLD")
    self:UnregisterEvent("PLAYER_LEAVING_WORLD")
	self:UnregisterEvent("ENCOUNTER_END")

    self:cleardownComm()
end

function Exquisiloot:PLAYER_ENTERING_WORLD(self, event, ...)
    local isInstance, instanceType = IsInInstance();
    if (isInstance == true and (instanceType == "raid" or (Exquisiloot.db.profile.dungeon and instanceType == "party"))) then
        local instanceName, _, _, _, _, _, _, _, _, _ = GetInstanceInfo()
        local datetime = C_DateAndTime.GetCurrentCalendarTime()
        local datestamp = format("%02d/%02d/%d", datetime.monthDay, datetime.month, datetime.year)
        Exquisiloot:debug("Entered %s at %02d:%02d %d/%d/%d", instanceName, datetime.hour, datetime.minute, datetime.monthDay, datetime.month, datetime.year)
        
        Exquisiloot:SetActiveRaid(instanceName, datestamp)
        Exquisiloot:RegisterEvent("CHAT_MSG_LOOT")

		-- Cache list of group memebers and register an event to update them if they change
		Exquisiloot.raidMembers = Exquisiloot:getRaidMembers()
		Exquisiloot:RegisterEvent("GROUP_ROSTER_UPDATE")

    end
end

function Exquisiloot:PLAYER_LEAVING_WORLD(self, event, ...)
    -- Stop the raid
    Exquisiloot:UnregisterEvent("CHAT_MSG_LOOT")
	Exquisiloot:UnregisterEvent("GROUP_ROSTER_UPDATE")
    Exquisiloot.activeRaid = nil
	Exquisiloot.raidMembers = nil
end

function Exquisiloot:GROUP_ROSTER_UPDATE(self, ...)
	Exquisiloot.raidMembers = Exquisiloot:getRaidMembers()
end

function Exquisiloot:ENCOUNTER_END(self, encounterID, ...)
	local encounterName, difficultyID, groupSize, success = ...
	Exquisiloot:debug("Fight complete: %s - %s", encounterName or "", tostring(success) or "")
	if (Exquisiloot.activeRaid ~= nil) then
		-- Keep attendance simple for now
		for player, value in pairs(Exquisiloot:getRaidMembers()) do
			Exquisiloot.db.profile.instances[Exquisiloot.activeRaid].attendance[player] = true
		end
		
		-- Use this later for more complicated attendance tracking
		--table.insert(Exquisiloot.db.profile.instances[Exquisiloot.activeRaid].attendance, {
		--	["boss"] = encounterName,
		--	["outcome"] = success,
		--	["date"] = C_DateAndTime.GetCurrentCalendarTime(),
		--	["raidMembers"] = self:getRaidMembers()
		--})
	end
end

function Exquisiloot:getRaidMembers()
	local raidMembers = {}
	for raidIndex=1, MAX_RAID_MEMBERS, 1 do
		name, _, _, _, _, _, zone, online, _, _, isML, _ = GetRaidRosterInfo(raidIndex);
		if (name ~= nil) then
			self:debug("raidIndex %d: %s - %s - %s", raidIndex, name or "", zone or "", tostring(isML) or "") 
			raidMembers[name] = {
				["zone"] = zone,
				["masterloot"] = isML
			}
		end
	end
	return raidMembers
end

function Exquisiloot:testEncounter()
	self:debug("Raid: %s", Exquisiloot.db.profile.instances[17].name)
	-- Keep attendance simple for now
	for player, value in pairs(Exquisiloot:getRaidMembers()) do
		Exquisiloot.db.profile.instances[17].attendance[player] = true
		if value["masterloot"] then
			self.masterloot = player
		end
	end
end

function Exquisiloot:CHAT_MSG_LOOT(self, lootstring, playerName, languageName, channelName, player, specialFlags, zoneChannelID, channelIndex, channelBaseName, unused, lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox, supressRaidIcons)
    if (player ~= nil and player ~= "" and Exquisiloot.activeRaid ~= nil) then
		local itemLink = string.match(lootstring,"|%x+|Hitem:.-|h.-|h|r")
        local itemString = string.match(itemLink, "item[%-?%d:]+")
        local name, _, quality, _, _, class, subclass, _, equipSlot, texture, _, ClassID, SubClassID = GetItemInfo(itemString)
        Exquisiloot:debug(itemLink)
        Exquisiloot:debug(itemString)
        Exquisiloot:debug(quality)
        if (quality >= 4 or Exquisiloot:IsDebug() or (Exquisiloot:IsDungeon() and quality >=3)) then
            -- These are Epic or higher items we want to track
            Exquisiloot:addItem(Exquisiloot.activeRaid, name, ItemID,itemLink, player)
			if (Exquisiloot.activeRaid == ExquisilootRaidScroll:GetSelection()) then
				Exquisiloot:updateLootFrame(ExquisilootRaidScroll:GetSelection())
			end
            return
        end
    end
end

function Exquisiloot:addItem(raidID, name, itemID, itemLink, player)
	table.insert(self.db.profile.instances[raidID].loot, {
        item = name,
        itemID = ItemID,
        itemLink = itemLink,
        player = player,
        date = C_DateAndTime.GetCurrentCalendarTime()
    })
end

function Exquisiloot:modItem(raidID, lootID, name, itemID, itemLink, player)
	-- pass
end

function Exquisiloot:deleteRaid(raidID)
	self:debug("Deleting Raid %d: %s", raidID, self.db.profile.instances[raidID].name)
	table.remove(self.db.profile.instances, raidID)
	ExquisilootAttendanceScroll:SetData({}, true)
	ExquisilootLootScroll:SetData({}, true)
	self:updateRaidFrame()
	ExquisilootRaidScroll:ClearSelection()
end

function Exquisiloot:deleteLoot(raidID, lootID)
	self:debug("Deleting Raid [%s] loot %d: %s", self.db.profile.instances[raidID].name, lootID, self.db.profile.instances[raidID].loot[lootID].item)
	table.remove(self.db.profile.instances[raidID].loot, lootID)
	self:updateLootFrame(raidID)
	ExquisilootLootScroll:ClearSelection()
end

local function removeKey(table, key)
	local element = table[key]
	table[key] = nil
	return element
end

function Exquisiloot:deleteAttendance(raidID, playerID)
	player = ExquisilootAttendanceScroll:GetRow(playerID)[1]
	self:debug("Deleting attendance for %s during raid %s", player, self.db.profile.instances[raidID].name)
	self:debug("Player table: %s", self:dump(self.db.profile.instances[raidID].attendance))
	--table.remove(self.db.profile.instances[raidID].attendance, player)
	removeKey(self.db.profile.instances[raidID].attendance, player)
	self:updateAttendanceFrame(raidID)
	ExquisilootAttendanceScroll:ClearSelection()
end

function Exquisiloot:GetRaid(raid, datestamp)
    if (self.db.profile.instances) then
        for index, instance in pairs(self.db.profile.instances) do
            if (instance.name == raid and instance.datestamp == datestamp) then -- Figure out raids that run over midnight
                self:debug("Existing raid found at index %d", index)
                return index
            end
        end
    end
    self:debug("Unable to find raid. returning nil")
    return nil
end

function Exquisiloot:SetActiveRaid(raid, datestamp)
    if (raid) then
        self.activeRaid = self:GetRaid(raid, datestamp)
        if (self.activeRaid == nil) then
            table.insert(self.db.profile.instances, {
                name = raid,
                datestamp = datestamp,
                loot = {},
				attendance = {}
            })
            self.activeRaid = table.getn(self.db.profile.instances)
        end
        return
    end
    Exquisiloot:debug("No Raid to set active")
end

function Exquisiloot:ChatCommand(input)
    if not input or input:trim() == "" then
		self:toggleUI()
	elseif input:trim() == "options" then
        InterfaceOptionsFrame_OpenToCategory(self.optionsFrame)
    else
        LibStub("AceConfigCmd-3.0"):HandleCommand("exl", "Exquisiloot", input)
    end
end

function Exquisiloot:debug(...)
    if (self:IsDebug()) then
        print(format(...))
    end
end

function Exquisiloot:printLoot(raid, datestamp)
    self:debug("Printing loot")
    if (raid and datestamp) then
        currentRaid = self:GetRaid(raid, datestamp)
    elseif (not raid and self.activeRaid) then
        currentRaid = self.activeRaid
    end
    -- self:debug(currentRaid)
    if (not currentRaid) then
        print("Can't return loot for a non-existant raid")
        return
    end
    self:debug("Loot printing isn't implemented yet")
end

function Exquisiloot:calendarTimeToDatestamp(c_time)
    return format("%02d/%02d/%04d", c_time["monthDay"], c_time["month"], c_time["year"])
end

function Exquisiloot:dump(o)
    if type(o) == 'table' then
       local s = '{ '
       for k,v in pairs(o) do
          if type(k) ~= 'number' then k = '"'..k..'"' end
          s = s .. '['..k..'] = ' .. Exquisiloot:dump(v) .. ','
       end
       return s .. '} '
    else
       return tostring(o)
    end
 end


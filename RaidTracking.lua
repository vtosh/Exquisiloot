local addonName, addon = ...
local Exquisiloot = LibStub("AceAddon-3.0"):GetAddon(addonName)

local itemClass = {
  [2] = true,  -- Weapon
--    [3] = true,  -- Gem
  [4] = true,  -- Armor
--    [7] =  {     -- Tradeskill
--        13       -- Material
--    },
  [9] = true,  -- Recipe
  [15] = true  -- Miscellaneous (needed for tier tokens!)
}

local function acceptedItemClass(classID, subclassID)
  for itemClassID, subclass in pairs(itemClass) do
      if itemClassID == classID then
          if (subclass == true) then
              return true
          end
          for i, itemSubClassID in ipairs(subclass) do
              if (itemSubClassID == subclassID) then
                  return true
              end
          end
      end
  end
  return false
end

local function lootLogCheck(quality, classID, subclassID)
  -- When debug mode is on accept all items
  if (Exquisiloot:IsDebug()) then
      return true
  end

  -- In raids only track where epic and above, and its an accepted item
  if (quality >= 4 and acceptedItemClass(classID, subclassID)) then    -- 4 = epic
      return true
  end

  -- Special case for SSC/TK recipes which are rare
  if (quality >= 3 and classID == 9) then
      return true
  end

  -- In dungeons track where rare and above, and its an accepted item
  if (Exquisiloot:IsDungeon() and quality >= 3 and acceptedItemClass(classID, subclassID)) then    -- 3 = rare
      return true
  end
end

-- Chat message seen for player recieving loot
function Exquisiloot:CHAT_MSG_LOOT(event, lootstring, playerName, languageName, channelName, player, specialFlags, zoneChannelID, channelIndex, channelBaseName, unused, lineID, guid, bnSenderID, isMobile, isSubtitle, hideSenderInLetterbox, supressRaidIcons)
  if (player ~= nil and player ~= "" and self.activeRaid ~= nil) then
  local itemLink = string.match(lootstring,"|%x+|Hitem:.-|h.-|h|r")
      local itemString = string.match(itemLink, "item[%-?%d:]+")
      local name, _, quality, _, _, class, subclass, _, equipSlot, texture, _, ClassID, SubClassID = GetItemInfo(itemString)
      self:debug(itemLink)
      self:debug(itemString)
      self:debug(quality)
      self:debug(class)
      if (lootLogCheck(quality, ClassID, SubClassID)) then
          -- This is an item we want to track
          self:addItem(self.activeRaid, name, texture, itemLink, player)
    if (self.activeRaid == ExquisilootRaidScroll:GetSelection()) then
      self:updateLootFrame(ExquisilootRaidScroll:GetSelection())
    end
          return
      end
  end
end

function Exquisiloot:addItem(raidID, name, texture, itemLink, player)
  local masterLootHold = player == self.masterLooter
  table.insert(self.db.profile.instances[raidID].loot, {
      item = name,
      texture = texture,
      itemLink = itemLink,
      player = player,
      date = C_DateAndTime.GetCurrentCalendarTime(),
      masterLootHold = masterLootHold or false
  })
end

function Exquisiloot:saveModItem(raidId, itemID, player)
    self.db.profile.instances[raidId].loot[itemID]["player"] = player
    self.db.profile.instances[raidId].loot[itemID].masterLootHold = false
end

function Exquisiloot:deleteRaid(raidID)
	self:debug("Deleting Raid %d: %s", raidID, self.db.profile.instances[raidID].name)
	table.remove(self.db.profile.instances, raidID)
end

function Exquisiloot:deleteLoot(raidID, lootID)
	self:debug("Deleting Raid [%s] loot %d: %s", self.db.profile.instances[raidID].name, lootID, self.db.profile.instances[raidID].loot[lootID].item)
	table.remove(self.db.profile.instances[raidID].loot, lootID)
end

function Exquisiloot:deleteAttendance(raidID, player)
	self:debug("Deleting attendance for %s during raid %s", player, self.db.profile.instances[raidID].name)
	self:debug("Player table: %s", self:dump(self.db.profile.instances[raidID].attendance))
	self:removeKey(self.db.profile.instances[raidID].attendance, player)
end

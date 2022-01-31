local name, addon = ...
local Exquisiloot = LibStub("AceAddon-3.0"):GetAddon(name)
local ScrollingTable = LibStub("ScrollingTable");

local GameTooltip = _G.GameTooltip

function ExquisilootImportExit(self)
	self:GetParent():Hide()
end

function Exquisiloot:showUI()
	ExquisilootMainFrame:Show()
end

function Exquisiloot:toggleUI()
	if (ExquisilootMainFrame:IsShown()) then
		ExquisilootMainFrame:Hide()
	else
		ExquisilootMainFrame:Show()
	end
end

function ExquisilootImport()
	-- Parse data from Excel import
	local importData = ExquisilootImportData:GetText()
	local tooltipData = {}
	for line in string.gmatch(importData, '[^\r\n]+') do
		item, chars = string.match(line, "(.+):%s+{(.+)}")
		tooltipData[item] = {}
		for char, points in string.gmatch(chars, '"(%S+)": (%S+),') do
			table.insert(tooltipData[item], {char, points})
			--print(format("char: %s, points: %d", char, points))
		end
	end

	Exquisiloot:sendTooltipData(tooltipData)
	Exquisiloot:updateTooltipData(tooltipData, false)

	-- Clear out old text
	ExquisilootImportData:SetText("")

	-- Hide panel
	ExquisilootImportFrame:Hide()
end

local function cellUpdateIcon(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, self, ...)
    if fShow then
        local itemTexture = self:GetCell(realrow, column)["value"] or nil
        if itemTexture then
            if not (cellFrame.cellItemTexture) then
                cellFrame.cellItemTexture = cellFrame:CreateTexture();
            end
            cellFrame.cellItemTexture:SetTexture(itemTexture);
            cellFrame.cellItemTexture:SetTexCoord(0, 1, 0, 1);
            cellFrame.cellItemTexture:Show();
            cellFrame.cellItemTexture:SetPoint("CENTER", cellFrame.cellItemTexture:GetParent(), "CENTER");
            cellFrame.cellItemTexture:SetWidth(20);
            cellFrame.cellItemTexture:SetHeight(20);
        end
    end
end

local function cellUpdateItemLink(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, self, ...)
    local itemLink = self:GetCell(realrow, column)["value"] or nil
    if itemLink then
        cellFrame:SetScript("OnEnter", function()
            GameTooltip:SetOwner(cellFrame, "ANCHOR_RIGHT")
            GameTooltip:SetHyperlink(itemLink)
            GameTooltip:Show()
        end)
        cellFrame:SetScript("OnLeave", function()
            GameTooltip:Hide()
            GameTooltip:SetOwner(UIParent, "ANCHOR_NONE")
        end)
        cellFrame.text:SetText(itemLink)
    end

end

activeButtons = {}

local activeButton, activeloot = nil
local function cellUpdateButton(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, scrollFrame, ...)
    -- Recycle old button if it exists
    local button  = nil
    if _G[cellFrame:GetName().."_button"] then
        button = _G[cellFrame:GetName().."_button"]
    else
        button = CreateFrame("Button", cellFrame:GetName().."_button", cellFrame, 'UIPanelButtonTemplate')
    end
    if fShow then
        -- Reset button
        button:SetPoint("CENTER", cellFrame, "CENTER");
        button:SetText("Disenchant")
        button:SetEnabled(true)
        button:SetWidth(70)
        button:SetScript("OnClick", function (self, button, down)
            Exquisiloot:debug("Pressed [%s] which is item [%s]", self:GetName(), scrollFrame:GetCell(realrow, 3)["value"])
            --activeloot.disenchanted = true
            --activeloot.masterLootHold = false
            --self:SetEnabled(false)

        end)
    else
        if (activeButton ~= nil or activeButton.button ~= nil) then
            activeButton.button:Hide()
        end
    end
end

local function cellUpdateDropDown(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, scrollFrame, ...)
    -- Recycle old dropdown if it exists
    local dropdown  = nil
    local itemLink = scrollFrame:GetCell(realrow, 3)["value"]
    if _G[cellFrame:GetName().."_dropdown"] then
        dropdown = _G[cellFrame:GetName().."_dropdown"]
    else
        dropdown = CreateFrame("Frame", cellFrame:GetName().."_dropdown", cellFrame, 'UIDropDownMenuTemplate')
    end

    -- Reset the dropdowns content
    local player = Exquisiloot:GetTradeTargetByitemLink(itemLink)
    UIDropDownMenu_SetSelectedValue(dropdown, player, player)
    UIDropDownMenu_SetText(dropdown, player)

    if fShow then
        dropdown:SetPoint("CENTER", cellFrame, "CENTER");
        UIDropDownMenu_SetWidth(dropdown, 90)

        local info = {}
        --UIDropDownMenu_Initialize(dropdown, function(self, level, menuList)
        dropdown.initialize = function(self, level, menuList)
            --activeloot = Exquisiloot.db.profile.instances[Exquisiloot.activeRaid].loot[activeDropdowns[self:GetName()].itemLink]
            for player, _ in pairs(Exquisiloot.db.profile.instances[Exquisiloot.activeRaid].attendance) do
                wipe(info)
                info.text = player
                info.checked = false
                info.hasArrow = false
                info.func = function(b)
                    -- Remove old trade from list
                    Exquisiloot:RemoveTradeByitemLink(itemLink)
                    -- Set up new trade
                    UIDropDownMenu_SetSelectedValue(self, b.value, b.value)
                    UIDropDownMenu_SetText(self, b.value)
                    b.checked = true
                    -- Can I put a call back here to "cross out" the item when the trade goes through?
                    Exquisiloot:AddTrade(b.value, itemLink)
                end
                UIDropDownMenu_AddButton(info)
            end
        end
    end
end


local ExquisilootRaidTableColDef = {
	{["name"] = "", ["width"] = 1}, -- Hidden Raid ID
    {["name"] = "Date", ["width"] = 60},
    {["name"] = "Name", ["width"] = 70},
};

local ExquisilootAttendanceTableColDef = {
	--{["name"] = "", ["width"] = 1}, -- Hidden Player ID
    {["name"] = "Name", ["width"] = 70},
    {["name"] = "Note", ["width"] = 60},
};

local ExquisilootLootTableColDef = {
	{["name"] = "", ["width"] = 1}, -- Hidden Loot ID
    {   ["name"] = "Icon", 
        ["width"] = 30, 
        ["DoCellUpdate"] = cellUpdateIcon
    },
    {   ["name"] = "Item", 
        ["width"] = 145,
        ["DoCellUpdate"] = cellUpdateItemLink
    },
    {["name"] = "received", ["width"] = 92},
    {["name"] = "Note", ["width"] = 110},
};

local ExquisilootMasterLootTableColDef = {
    {["name"] = "", ["width"] = 1}, -- Hidden Loot ID
    {["name"] = "Icon", ["width"] = 30, ["DoCellUpdate"] = cellUpdateIcon},
    {["name"] = "Item", ["width"] = 145, ["DoCellUpdate"] = cellUpdateItemLink},
    {["name"] = "Player", ["width"] = 90, ["DoCellUpdate"] = cellUpdateDropDown},
    {["name"] = "Allocate", ["width"] = 30},
    {["name"] = "Disenchant", ["width"] = 70, ["DoCellUpdate"] = cellUpdateButton},

}

function Exquisiloot:updateRaidFrame()
	local raids = {};
    if (self.db.profile.instances) then
        for i, raid in ipairs(self.db.profile.instances) do
            raids[i] = {i, raid["datestamp"], raid["name"]}
        end
    end
    ExquisilootRaidScroll:SetData(raids, true)
end

function Exquisiloot:updateLootFrame(raidID)
	local loots = {};
    if (self.db.profile.instances[raidID].loot) then
        for i, loot in ipairs(self.db.profile.instances[raidID].loot) do
            --Exquisiloot:debug(loot["texture"] or "no texture found")
            loots[i] = {
                ["cols"] = {
                    {
                        ["value"] = i
                    },
                    {
                        ["value"] = loot["texture"] or ""
                    },
                    {
                        ["value"] = loot["itemLink"]
                    },
                    {
                        ["value"] = loot["player"]
                    },
                    {
                        ["value"] = loot["masterLootHold"] and "Held by MasterLooter" or loot["disenchanted"] and "Disenchanted" or ""
                    }
                }
            }
        end
    end
    ExquisilootLootScroll:SetData(loots)
end

function Exquisiloot:updateMasterLootFrame()
    local loots = {};
    if (self.db.profile.instances[Exquisiloot.activeRaid].loot) then
        for i, loot in ipairs(self.db.profile.instances[Exquisiloot.activeRaid].loot) do
            if (loot["masterLootHold"] ~= nil and loot["masterLootHold"]) then
                table.insert(loots, {
                    ["cols"] = {
                        {
                            ["value"] = i
                        },
                        {
                            ["value"] = loot["texture"] or ""
                        },
                        {
                            ["value"] = loot["itemLink"]
                        },
                        {
                            ["value"] = "" -- Player select
                        },
                        {
                            ["value"] = "" -- roll button
                        },
                        {
                            ["value"] = i -- disenchant button
                        }
                    }
                })
            end
        end
    end
    ExquisilootMasterLootScroll:SetData(loots)
end

function Exquisiloot:updateAttendanceFrame(raidID)
	local players = {};
    if (self.db.profile.instances[raidID].attendance) then
        for player, value in pairs(self.db.profile.instances[raidID].attendance) do
            table.insert(players, {player, ""})
        end
    end
    ExquisilootAttendanceScroll:SetData(players, true)
end

function ExquisilootMainFrame_OnLoad()
	ExquisilootRaidScroll = ScrollingTable:CreateST(ExquisilootRaidTableColDef, 10, 15, nil, ExquisilootMainFrame)
	ExquisilootRaidScroll:EnableSelection(true)
	ExquisilootRaidScroll.frame:SetPoint("TOP", ExquisilootRaidScrollTitle, "BOTTOM", 0, -15)
	ExquisilootRaidScroll:RegisterEvents({
		["OnClick"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, scrollingTable, ...)
            Exquisiloot:debug(Exquisiloot:dump(data[realrow]))
			Exquisiloot:updateLootFrame(data[realrow][1])
			Exquisiloot:updateAttendanceFrame(data[realrow][1])
            ExquisilootModItemFrame:Hide()
		return false
		end,
	})

	ExquisilootAttendanceScroll = ScrollingTable:CreateST(ExquisilootAttendanceTableColDef, 10, 15, nil, ExquisilootMainFrame)
	ExquisilootAttendanceScroll:EnableSelection(true)
	ExquisilootAttendanceScroll.frame:SetPoint("TOP", ExquisilootAttendanceScrollTitle, "BOTTOM", 0, -15)

	ExquisilootLootScroll = ScrollingTable:CreateST(ExquisilootLootTableColDef, 6, 20, nil, ExquisilootMainFrame)
	ExquisilootLootScroll:EnableSelection(true)
	ExquisilootLootScroll.frame:SetPoint("TOP", ExquisilootLootScrollTitle, "BOTTOM", 0, -15)
    ExquisilootLootScroll:RegisterEvents({
        ["OnClick"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, scrollingTable, button, ...)
            Exquisiloot:debug(Exquisiloot:dump(data[realrow]))
            Exquisiloot:debug("Loot frame pressed with - %s", button)
            if button == "RightButton" then
                scrollingTable:SetSelection(realrow)
                ExquisilootModItemFrame_OnShow(ExquisilootRaidScroll:GetSelection(), data[realrow]["cols"][1]["value"])
            end
        return false
        end,
    })

	tinsert(UISpecialFrames,"ExquisilootMainFrame");

    StaticPopupDialogs["EXQUISILOOT_DELETE_RAID"] = {
        text = "Are you sure you want to delete %s?",
        button1 = YES,
        button2 = NO,
        OnAccept = function(self, raidID)
            Exquisiloot:deleteRaid(self.raidID)
            ExquisilootAttendanceScroll:SetData({}, true)
            ExquisilootLootScroll:SetData({}, true)
            Exquisiloot:updateRaidFrame()
            ExquisilootRaidScroll:ClearSelection()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopupDialogs["EXQUISILOOT_DELETE_LOOT"] = {
        text = "Are you sure you want to delete %s from the raid %s?",
        button1 = YES,
        button2 = NO,
        OnAccept = function(self, raidID, itemID)
            Exquisiloot:deleteLoot(self.raidID, self.itemID)
            Exquisiloot:updateLootFrame(self.raidID)
            ExquisilootLootScroll:ClearSelection()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopupDialogs["EXQUISILOOT_DELETE_ATTENDANCE"] = {
        text = "Are you sure you want to remove player %s from the raid %s?",
        button1 = YES,
        button2 = NO,
        OnAccept = function(self, raidID, player)
            Exquisiloot:deleteAttendance(self.raidID, self.player)
            Exquisiloot:updateAttendanceFrame(self.raidID)
            ExquisilootAttendanceScroll:ClearSelection()
        end,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
    }

    StaticPopupDialogs["EXQUISILOOT_ERROR"] = {
        text = "%s",
        button1 = OKAY,
        timeout = 10,
        whileDead = true,
        hideOnEscape = true,
    }
end

function ExquisilootMasterLootFrame_OnLoad()
    ExquisilootMasterLootScroll = ScrollingTable:CreateST(ExquisilootMasterLootTableColDef, 6, 30, nil, ExquisilootMasterLootFrame)
    ExquisilootMasterLootScroll:EnableSelection(false)
    ExquisilootMasterLootScroll.frame:SetPoint("TOP", ExquisilootMasterLootScrollTitle, "BOTTOM", 0, -15)
end

function ExquisilootMasterLootFrame_OnShow()
    if (Exquisiloot.activeRaid == nil) then
        StaticPopup_Show("EXQUISILOOT_ERROR", "Must be in an active raid to distribute loot as Master Looter")
        return
    end

    Exquisiloot:updateMasterLootFrame()

    ExquisilootMasterLootFrame:Show()
end

function ExquisilootDeleteRaidButton_OnClick()
    local raidID = ExquisilootRaidScroll:GetSelection()
    if not raidID then
        StaticPopup_Show("EXQUISILOOT_ERROR", "A raid must be selected in order to delete it")
        return
    end
    local timestamp = Exquisiloot.db.profile.instances[raidID].datestamp
    local name = Exquisiloot.db.profile.instances[raidID].name
    local popup = StaticPopup_Show("EXQUISILOOT_DELETE_RAID", format("%s - %s", timestamp, name))
    if (popup) then
        popup.raidID = raidID
    end
end

function ExquisilootDeleteLootButton_OnClick()
    local raidID = ExquisilootRaidScroll:GetSelection()
    if not raidID then
        StaticPopup_Show("EXQUISILOOT_ERROR", "A raid must be selected in order to delete an piece of loot")
        return
    end
    local itemID = ExquisilootLootScroll:GetSelection()
    if not itemID then
        StaticPopup_Show("EXQUISILOOT_ERROR", "A piece of loot must be selected in order to delete it")
        return
    end

    local timestamp = Exquisiloot.db.profile.instances[raidID].datestamp
    local raidName = Exquisiloot.db.profile.instances[raidID].name
    local lootName = Exquisiloot.db.profile.instances[raidID].loot[itemID].itemLink
    local popup = StaticPopup_Show("EXQUISILOOT_DELETE_LOOT", lootName, format("%s - %s", timestamp, raidName))
    if (popup) then
        popup.raidID = raidID
        popup.itemID = itemID
    end
end

function ExquisilootDeleteAttendanceButton_OnClick()
    local raidID = ExquisilootRaidScroll:GetSelection()
    if not raidID then
        StaticPopup_Show("EXQUISILOOT_ERROR", "A raid must be selected in order to delete an the attendance of a player")
        return
    end
    if not ExquisilootAttendanceScroll:GetSelection() then
        StaticPopup_Show("EXQUISILOOT_ERROR", "A player must be selected in order to delete their attendance")
        return
    end
    local player = ExquisilootAttendanceScroll:GetRow(ExquisilootAttendanceScroll:GetSelection())[1]
    local timestamp = Exquisiloot.db.profile.instances[raidID].datestamp
    local name = Exquisiloot.db.profile.instances[raidID].name
    local popup = StaticPopup_Show("EXQUISILOOT_DELETE_ATTENDANCE", player, format("%s - %s", timestamp, name))
    if (popup) then
        popup.raidID = raidID
        popup.player = player
    end
end

function Exquisiloot:showAddItem()
	ExquisilootAddItemFrame:Show()
end

function ExquisilootModItemFrame_OnShow(raidID, lootID)
    loot = Exquisiloot.db.profile.instances[raidID].loot[lootID]
    -- Recycle old dropdown if it exists
    local dropdown = nil
    if _G["ExquisilootModItemPlayer"] then
        dropdown = _G["ExquisilootModItemPlayer"]
    else
        dropdown = CreateFrame("Frame", "ExquisilootModItemPlayer", ExquisilootModItemFrame, "UIDropDownMenuTemplate")
    end

    -- Reset dropdown content
    UIDropDownMenu_SetSelectedValue(dropdown, loot["player"], loot["player"])
    UIDropDownMenu_SetText(dropdown, loot["player"])

    -- Anchor to the correct place
    dropdown:SetPoint("LEFT", ExquisilootModItemPlayerTitle, "RIGHT", 15, 0);
    UIDropDownMenu_SetWidth(dropdown, 90)

    -- dropdown init
    local info = {}
    dropdown.initialize = function(self, level, menuList)
        for player, _ in pairs(Exquisiloot.db.profile.instances[raidID].attendance) do
            wipe(info)
            info.text = player
            info.checked = false
            info.hasArrow = false
            info.func = function(b)
                UIDropDownMenu_SetSelectedValue(self, b.value, b.value)
                UIDropDownMenu_SetText(self, b.value)
                b.checked = true
            end
            UIDropDownMenu_AddButton(info)
        end
    end

    ExquisilootModItemItemName:SetText(loot["itemLink"])

    ExquisilootModItemFrame:Show()
end

function ExquisilootModItemAddButton_OnModify()
    local newPlayer = ExquisilootModItemPlayer.selectedValue
    local raid = ExquisilootRaidScroll:GetSelection()
    local item = ExquisilootLootScroll:GetSelection()
    Exquisiloot:saveModItem(raid, item, newPlayer)
    ExquisilootLootScroll.data[item]["cols"][4] = newPlayer
    ExquisilootLootScroll:ClearSelection()

    ExquisilootModItemFrame:Hide()
end

function ExquisilootExport()
    local selected = ExquisilootRaidScroll:GetSelection()
    if (not selected) then
        print("Must have a raid selected to export data")
        return
    end
    -- Lets export some data!
    ExquisilootExportFrame:Show()
    ExquisilootExportAttendanceEditBox:SetText(Exquisiloot:ExportAttendance(selected))
    ExquisilootExportLootEditBox:SetText(Exquisiloot:ExportLoot(selected))
end

function Exquisiloot:ExportLoot(raidID)
    local export = {}
    local datetime = self.db.profile.instances[raidID].datestamp
    for i, loot in ipairs(self.db.profile.instances[raidID].loot) do
        export[i] = format("%s;%s;%s", datetime or "", loot["item"] or "", loot["player"] or "")
	end
    return table.concat(export, "\n")
end

function Exquisiloot:ExportAttendance(raidID)
    local export = {}
    local datetime = self.db.profile.instances[raidID].datestamp
    for player, value in pairs(self.db.profile.instances[raidID].attendance) do
        table.insert(export, player)
	end
    return format("!%s!\n%s", self.db.profile.instances[raidID].name, table.concat(export, ";\n"))
end

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
        ["DoCellUpdate"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, self, ...)
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
    },
    {   ["name"] = "Item", 
        ["width"] = 145,
        ["DoCellUpdate"] = function(rowFrame, cellFrame, data, cols, row, realrow, column, fShow, self, ...)
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
    },
    {["name"] = "received", ["width"] = 92},
    {["name"] = "Note", ["width"] = 110},
};


function Exquisiloot:updateRaidFrame()
	local raids = {};
	for i, raid in ipairs(self.db.profile.instances) do
		raids[i] = {i, raid["datestamp"], raid["name"]}
	end
	ExquisilootRaidScroll:SetData(raids, true)
end

function Exquisiloot:updateLootFrame(raidID)
	local loots = {};
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
                    ["value"] = ""
                }
            }
        }
	end
	ExquisilootLootScroll:SetData(loots)
end

function Exquisiloot:updateAttendanceFrame(raidID)
	local players = {};
	for player, value in pairs(self.db.profile.instances[raidID].attendance) do
		table.insert(players, {player, ""})
	end
	ExquisilootAttendanceScroll:SetData(players, true)
end

function ExquisilootMainFrame_OnLoad()
	ExquisilootRaidScroll = ScrollingTable:CreateST(ExquisilootRaidTableColDef, 10, 15, nil, ExquisilootMainFrame)
	ExquisilootRaidScroll:EnableSelection(true)
	ExquisilootRaidScroll.frame:SetPoint("TOP", ExquisilootRaidScrollTitle, "BOTTOM", 0, -15)
	ExquisilootRaidScroll:RegisterEvents({
		["OnClick"] = function (rowFrame, cellFrame, data, cols, row, realrow, column, scrollingTable, ...)
			Exquisiloot:updateLootFrame(data[realrow][1])
			Exquisiloot:updateAttendanceFrame(data[realrow][1])
		return false
		end,
	})

	ExquisilootAttendanceScroll = ScrollingTable:CreateST(ExquisilootAttendanceTableColDef, 10, 15, nil, ExquisilootMainFrame)
	ExquisilootAttendanceScroll:EnableSelection(true)
	ExquisilootAttendanceScroll.frame:SetPoint("TOP", ExquisilootAttendanceScrollTitle, "BOTTOM", 0, -15)

	ExquisilootLootScroll = ScrollingTable:CreateST(ExquisilootLootTableColDef, 6, 20, nil, ExquisilootMainFrame)
	ExquisilootLootScroll:EnableSelection(true)
	ExquisilootLootScroll.frame:SetPoint("TOP", ExquisilootLootScrollTitle, "BOTTOM", 0, -15)

	tinsert(UISpecialFrames,"ExquisilootMainFrame");
end

function Exquisiloot:showAddItem()
	ExquisilootAddItemFrame:Show()
end

function ExquisilootPlayerDropdown()
	local info = {}
	--for player, _ in pairs(Exquisiloot:getRaidMembers()) do
		--self:debug(player)
	--	info.value = player
	--	UIDropDownMenu_AddButton(info)
	--end

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

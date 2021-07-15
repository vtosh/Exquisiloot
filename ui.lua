local name, addon = ...
local Exquisiloot = LibStub("AceAddon-3.0"):GetAddon(name)
print(name)
local ScrollingTable = LibStub("ScrollingTable");

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

	Exquisiloot:sendTooltipData(tooltipData, false)
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
    {["name"] = "Icon", ["width"] = 30},
    {["name"] = "Item", ["width"] = 145},
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
		loots[i] = {i, "", loot["item"], loot["player"], ""}
	end
	ExquisilootLootScroll:SetData(loots, true)
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

	ExquisilootLootScroll = ScrollingTable:CreateST(ExquisilootLootTableColDef, 6, 15, nil, ExquisilootMainFrame)
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
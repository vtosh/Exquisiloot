local name, addon = ...
local Exquisiloot = LibStub("AceAddon-3.0"):GetAddon(name)

local function OnTooltipSetItem(frame, ...)
	local name, link = frame:GetItem()
	if (Exquisiloot.db.profile.tooltipData[name] ~= nil) then
		local sorted = {}
		for player, value in pairs(Exquisiloot.db.profile.tooltipData[name]) do
			--frame:AddLine(format("%s: %d", player, value))
			if (Exquisiloot.raidMembers == nil or Exquisiloot.raidMembers[player] ~= nil) then
				table.insert(sorted, {player, value})
			end
		end
		table.sort(sorted, function(a,b) return a[2] > b[2] end)
		for _, info in ipairs(sorted) do
			-- If we are in an active raid, limit to only the people in the raid group
			frame:AddLine(format("%s: %d", info[1], info[2]))
		end
	end

	--if tooltipscripts_original[frame] then return tooltipscripts_original[frame](frame, ...) end
end

for _, obj in pairs({GameTooltip}) do
    for _, func in pairs({"OnTooltipSetItem"}) do
		obj:HookScript(func, OnTooltipSetItem)
	end
end

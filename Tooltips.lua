local name, Exquisiloot = ...
local Exquisiloot = LibStub("AceAddon-3.0"):GetAddon(name)

function Exquisiloot:updateTooltipData(tooltipData, diff, timestamp)
    if (tooltipData == nil) then
        -- Lets protect people if somehow tooltip data is nil
        return 
    end

    if (timestamp == nil) then
        timestamp = C_DateAndTime.GetCurrentCalendarTime()
    end

    newTooltipData = C_DateAndTime.CompareCalendarTime(self.db.profile.tooltipDataLastUpdated, timestamp)
    if (newTooltipData < 0) then
        -- Protect people from updating with older data
        return
    end

	if (diff == nil or not diff) then
		-- Full replacement of tooltip data
		self.db.profile.tooltipData = tooltipData
	else
	    -- Partial update on specific items
	    for item, values in pairs(tooltipData) do
		    self.db.profile.tooltipData[item] = values
	    end
    end
    self.db.profile.tooltipDataLastUpdated = timestamp
end


-- Display tooltips
local function OnTooltipSetItem(frame, ...)
	local name, link = frame:GetItem()
	if (Exquisiloot.db.profile.tooltipData[name] ~= nil) then
		local sorted = Exquisiloot.db.profile.tooltipData[name]
		table.sort(sorted, function(a,b) 
            if (a[2] == b[2]) then
                return a[1] > b[1]
            end
            return a[2] > b[2] 
        end)
		for _, info in ipairs(sorted) do
			-- If we are in an active raid, limit to only the people in the raid group
			if (Exquisiloot.raidMembers == nil or Exquisiloot.raidMembers[info[1]] ~= nil) then
				frame:AddLine(format("%s: %d", info[1], info[2]))
			end
		end
	end
end

for _, obj in pairs({GameTooltip, ItemRefTooltip}) do
    for _, func in pairs({"OnTooltipSetItem"}) do
		obj:HookScript(func, OnTooltipSetItem)
	end
end

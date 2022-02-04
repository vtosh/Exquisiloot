local name, Exquisiloot = ...
local Exquisiloot = LibStub("AceAddon-3.0"):GetAddon(name)

local LibDataBroker = LibStub("LibDataBroker-1.1")

Exquisiloot.MinimapButton = LibStub("LibDBIcon-1.0")
local MinimapButton = Exquisiloot.MinimapButton

function MinimapButton:_init()
  local ExquisilootDataBroker = LibDataBroker:NewDataObject("Exquisiloot", {
    type = "data source",
    text = "Exquisiloot",
    icon = "Interface\\Addons\\Exquisiloot\\Assets\\Buttons\\minimap",
    OnClick = function(_, button)
      if (button == "LeftButton") then
        Exquisiloot:toggleUI()
      end
    end,
    OnTooltipShow = function(tooltip)
      tooltip:AddLine("|cffffffffClick:|r Open Exquisiloot")
    end,
  })

  MinimapButton:Register("Exquisiloot", ExquisilootDataBroker, Exquisiloot.db.profile.minimapbutton)
end

function MinimapButton:drawOrHide()
  if (Exquisiloot:showMinimapButton()) then
    MinimapButton:Show("Exquisiloot")
  else
    MinimapButton:Hide("Exquisiloot")
  end
end
local name, addon = ...
local Exquisiloot = LibStub("AceAddon-3.0"):GetAddon(name)

function Exquisiloot:OnCommRecieved(...)
	self:debug("Comm message seen")
end
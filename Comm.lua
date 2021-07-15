local name, addon = ...
local Exquisiloot = LibStub("AceAddon-3.0"):GetAddon(name)

local commLootPrefix = Exquisiloot.commPrefix

function Exquisiloot:compressToSend(data)
	local message = self.libc:Compress(self.libs:Serialize(data))
	return self.libce:Encode(message)
end

function Exquisiloot:decompressFromSend(message)
	message = self.libce:Decode(message)
	local text, error = self.libc:Decompress(message)
	if (not text) then
		self:debug("Error decompressing message")
		return nil
	end

	success, message = self.libs:Deserialize(text)
	if (not success) then
		self:debug("Error deserializing message")
		return nil
	end

	return message
end

-- Tooltip comm functions
function Exquisiloot:sendTooltipData(tooltipData, diff)
	-- TODO: Only send out if we are a trusted source
	--if (self:verifyTrusted(UnitName("player"))) then
		self:SendCommMessage(commLootPrefix, self:compressToSend({type="tooltipData", update=diff, data=tooltipData}), "GUILD")
	--end
end

function Exquisiloot:getTooltipData()
	self:SendCommMessage(commLootPrefix, self:compressToSend({type="getTooltipData"}), "GUILD")
end


function Exquisiloot:OnCommReceived(prefix, text, distribution, source)
	self:debug("OnCommReceived")
	self:debug("prefix: [%s]", prefix)
	--self:debug("text: [%s]", text)
	self:debug("distribution: [%s]", distribution)
	self:debug("source: [%s]", source)
	self:debug("player: [%s]", self.player)
	if (source ~= self.player) then
		local received = Exquisiloot:decompressFromSend(text)
		if (received == nil or received["type"] == nil) then
			self:debug("Invalid message received")
		elseif (received["type"] == "tooltipData") then
			self:debug("received tooltipdata")
			-- TODO: Verify it came from trusted source
			self:updateTooltipData(received["data"], received["update"])
			
		elseif (received["type"] == "getTooltipData") then
			self:debug("received tooltipData request")
			self:sendTooltipData(self.db.profile.tooltipData)
		end
	else
		self:debug("Ignoring message from self")
	end
end
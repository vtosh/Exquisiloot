local name, addon = ...
local Exquisiloot = LibStub("AceAddon-3.0"):GetAddon(name)
local version = GetAddOnMetadata(name, "Version")

local commPrefix = "ExqiLootPrio"
local pingResponses

local newTooltipData
local function OnPingReceived(received, source)
    newTooltipData = C_DateAndTime.CompareCalendarTime(Exquisiloot.db.profile.tooltipDataLastUpdated, received["tooltipDataLastUpdated"])

    if (newTooltipData > 0) then
        -- Logged in player has newer tooltipData
        if (Exquisiloot:validateTrust(source)) then
	        -- request their tooltipdata
        end
    elseif (newTooltipData < 0) then
        -- Logged in player has older tooldtipData
        -- Tell them we have a newer tooltipData set
        Exquisiloot:sendWhisper({type="pong", tooltipDataLastUpdated=Exquisiloot.db.profile.tooltipDataLastUpdated})
    end
end

local function OnPongReceived(received, source)
    table.insert(pingResponses, {source, received["tooltipDataLastUpdated"]})
end

local target
local function OnGetTooltipDataReceived(received, distribution, source)
    self:debug("received getTooltipData request")
    -- Don't just blindly send to "guild" channel lets think about this
    if distribution == "WHISPER" then 
        target = source
    else
        target = nil
    end
    Exquisiloot:sendTooltipData(Exquisiloot.db.profile.tooltipData, false, target)
end

local function OnTooltipDataReceived(received, source)
	self:debug("received tooltipdata")
    if (Exquisiloot:validateTrust(source)) then
	    self:updateTooltipData(received["data"], received["diff"], received["timestamp"])
    end
end

function Exquisiloot:configureComm()
    self:RegisterComm(commPrefix)

    pingResponses = {}
    self:sendGuild({type="ping", tooltipDataLastUpdated=Exquisiloot.db.profile.tooltipDataLastUpdated})

    self:ScheduleTimer(function()
        self:debug("We had [%d] responses to ping", #pingResponses)
        -- Sort pingResponses by tooltipDataLastUpdated x[2]
        table.sort(pingResponses, function(a,b)
            if (C_DateAndTime.CompareCalendarTime(a[2], b[2]) > 0) then
                return true
            end
            return false
        end)
        -- Iterate through the now sorted list, finding a trusted player to grab from
        for i, pong in ipairs(pingResponses) do
            -- TODO: Check trust, for now just trust in the vtosh!
            if (Exquisiloot:validateTrust(pong[1])) then
                -- Send request for update
                Exquisiloot:sendWhisper({type="getTooltipData"}, pong[1])
                break
            end
        end
    end, 3.0)
end

function Exquisiloot:cleardownComm()
	self:UnregisterComm(commPrefix)
end

function Exquisiloot:sendGuild(data)
    self:SendCommMessage(commPrefix, self:compressComm(data), "GUILD")
end

function Exquisiloot:sendWhisper(data, player)
    self:SendCommMessage(commPrefix, self:compressComm(data), "WHISPER", player)
end

function Exquisiloot:compressComm(data)
    data["version"] = version
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

function Exquisiloot:sendTooltipData(tooltipData, diff, target)
    if (target ~= nil) then
        self:sendWhisper({type="tooltipData", data=self.db.profile.TooltipData, 
                diff=diff, timestamp=self.db.profile.TooltipDataLastUpdated}, target)
    else
        self:sendGuild({type="tooltipData", data=Exquisiloot.db.profile.TooltipData, 
            diff=diff, timestamp=Exquisiloot.db.profile.TooltipDataLastUpdated})
    end
end

local received
function Exquisiloot:OnCommReceived(prefix, text, distribution, source)
	self:debug("OnCommReceived")
	--self:debug("prefix: [%s]", prefix)
	self:debug("source: [%s]", source)
	self:debug("distribution: [%s]", distribution)
	--self:debug("player: [%s]", self.player)
	if (source ~= self.player) then
		received = Exquisiloot:decompressFromSend(text)
		if (received == nil or received["type"] == nil) then
            -- Not a valid message
			self:debug("Invalid message received")
		elseif (received["type"] == "tooltipData") then
            -- Recieved tooltip update
            OnTooltipDataReceived(received, source)
		elseif (received["type"] == "getTooltipData") then
            -- Recieved getTooltip
            OnGetTooltipDataReceived(received, distribution, source)
        elseif (received["type"] == "ping") then
            -- Recieved ping
            OnPingReceived(received, source)
        elseif (received["type"] == "pong") then
            -- Received pong
            OnPongReceived(received, source)
		end
	else
        if (self:IsDebug()) then 
            received = Exquisiloot:decompressFromSend(text)
		    self:debug("Ignoring [%s] from self", received["type"])
        end
	end
end
local name, addon = ...
local Exquisiloot = LibStub("AceAddon-3.0"):GetAddon(name)
local version = GetAddOnMetadata(name, "Version")

local commPrefix = "ExqiLootPrio"
local pingResponses

-- Libraries used in comm
local libserialize
local libcompress
local libencodetable

local function compressComm(data)
    data["version"] = version
	local message = libcompress:Compress(libserialize:Serialize(data))
	return libencodetable:Encode(message)
end

local function decompressFromSend(message)
	message =libencodetable:Decode(message)
	local text, error = libcompress:Decompress(message)
	if (not text) then
		Exquisiloot:debug("Error decompressing message")
		return nil
	end

	success, message = libserialize:Deserialize(text)
	if (not success) then
		Exquisiloot:debug("Error deserializing message")
		return nil
	end

	return message
end

local newTooltipData
local function OnPingReceived(received, source)
    newTooltipData = C_DateAndTime.CompareCalendarTime(Exquisiloot.db.profile.tooltipDataLastUpdated, received["tooltipDataLastUpdated"])

    if (newTooltipData > 0) then
        -- Logged in player has newer tooltipData
        Exquisiloot:debug("Logged in player has newer tooltipData")
        if (Exquisiloot:validateTrust(source)) then
	        -- request their tooltipdata
        end
    elseif (newTooltipData < 0) then
        -- Logged in player has older tooldtipData
        Exquisiloot:debug("Logged in player has older tooltipData")
        -- Tell them we have a newer tooltipData set
        Exquisiloot:sendWhisper({type="pong", tooltipDataLastUpdated=Exquisiloot.db.profile.tooltipDataLastUpdated}, source)
    end
end

local function OnPongReceived(received, source)
    table.insert(pingResponses, {source, received["tooltipDataLastUpdated"]})
end

local target
local function OnGetTooltipDataReceived(received, distribution, source)
    Exquisiloot:debug("received getTooltipData request")
    -- Don't just blindly send to "guild" channel lets think about this
    if distribution == "WHISPER" then 
        target = source
    else
        target = nil
    end
    Exquisiloot:sendTooltipData(Exquisiloot.db.profile.tooltipData, false, target)
end

local function OnTooltipDataReceived(received, source)
	Exquisiloot:debug("received tooltipdata")
    if (Exquisiloot:validateTrust(source)) then
	    Exquisiloot:updateTooltipData(received["data"], received["diff"], received["timestamp"])
    end
end

function Exquisiloot:configureComm()

	libserialize = LibStub:GetLibrary("AceSerializer-3.0")
	libcompress = LibStub:GetLibrary("LibCompress")
	libencodetable = libcompress:GetAddonEncodeTable()
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
    end, 10.0)
end

function Exquisiloot:cleardownComm()
	self:UnregisterComm(commPrefix)
    libserialize = nil
    libcompress = nil
    libencodetable = nil
end

function Exquisiloot:sendGuild(data)
    self:debug("Sending [%s] to Guild", data["type"])
    self:SendCommMessage(commPrefix, compressComm(data), "GUILD")
end

function Exquisiloot:sendWhisper(data, player)
    self:debug("Sending [%s] to Player [%s]", data["type"], player)
    self:SendCommMessage(commPrefix, compressComm(data), "WHISPER", player)
end

function Exquisiloot:sendTooltipData(tooltipData, diff, target)
    if (target ~= nil) then
        self:sendWhisper({type="tooltipData", data=Exquisiloot.db.profile.tooltipData, 
                diff=diff, timestamp=self.db.profile.tooltipDataLastUpdated}, target)
    else
        self:sendGuild({type="tooltipData", data=Exquisiloot.db.profile.tooltipData, 
            diff=diff, timestamp=Exquisiloot.db.profile.tooltipDataLastUpdated})
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
		received = decompressFromSend(text)
        self:debug("Received [%s]", received["type"])
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
            received = decompressFromSend(text)
		    self:debug("Ignoring [%s] from self", received["type"])
        end
	end
end
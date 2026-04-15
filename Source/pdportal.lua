--[[
Lua-side pdportal transport bridge.

Purpose:
- translates Playdate serial messages into pdportal callbacks
- sends peer commands and fetch requests out to the browser bridge
- exposes the base object used by the Starry multiplayer service
]]
import 'CoreLibs/object'
import 'CoreLibs/timer'

class('PdPortal').extends()
local PdPortal <const> = PdPortal

local jsonEncode <const> = json.encode
local jsonDecode <const> = json.decode
local timer <const> = playdate.timer

function PdPortal:onConnect(_portalVersion)
end

function PdPortal:onDisconnect()
end

function PdPortal:onPeerOpen(_peerId)
end

function PdPortal:onPeerClose()
end

function PdPortal:onPeerConnection(_remotePeerId)
end

function PdPortal:onPeerConnOpen(_remotePeerId)
end

function PdPortal:onPeerConnClose(_remotePeerId)
end

function PdPortal:onPeerConnData(_remotePeerId, _payload)
end

PdPortal.PortalCommand = {
    Log = 'l',
    Keepalive = 'k',
    InitializePeer = 'ip',
    DestroyPeer = 'dp',
    SendToPeerConn = 'p',
    ClosePeerConn = 'cpc',
    Fetch = 'f',
}

function PdPortal:sendCommand(portalCommand, ...)
    local cmd = { portalCommand }

    for index = 1, select('#', ...) do
        local arg = select(index, ...)
        table.insert(cmd, PdPortal.portalArgumentSeparator)
        table.insert(cmd, arg)
    end

    table.insert(cmd, PdPortal.portalCommandSeparator)
    print(table.concat(cmd, ''))
end

function PdPortal:log(...)
    self:sendCommand(
        PdPortal.PortalCommand.Log,
        table.unpack({ ... })
    )
end

function PdPortal:sendToPeerConn(peerConnId, payload)
    local jsonPayload = jsonEncode(payload)
    self:sendCommand(
        PdPortal.PortalCommand.SendToPeerConn,
        peerConnId,
        jsonPayload
    )
end

function PdPortal:fetch(url, options, successCallback, errorCallback)
    local encodedOptions = jsonEncode(options)
    local requestId = tostring(self._nextRequestId)
    self._nextRequestId += 1

    self._fetchCallbacks[requestId] = { successCallback, errorCallback }
    self:sendCommand(PdPortal.PortalCommand.Fetch, requestId, url, encodedOptions)
end

PdPortal.PlaydateCommand = {
    OnConnect = 'oc',
    OnPeerConnData = 'opcd',
    OnPeerOpen = 'opo',
    OnPeerClose = 'opc',
    OnPeerConnection = 'opconn',
    OnPeerConnOpen = 'opco',
    OnPeerConnClose = 'opcc',
    Keepalive = 'k',
    OnFetchSuccess = 'ofs',
    OnFetchError = 'ofe',
}

PdPortal.playdateCommandMethods = {
    [PdPortal.PlaydateCommand.OnConnect] = { '_onConnect', 'onConnect' },
    [PdPortal.PlaydateCommand.OnPeerConnData] = { 'onPeerConnData' },
    [PdPortal.PlaydateCommand.OnPeerOpen] = { 'onPeerOpen' },
    [PdPortal.PlaydateCommand.OnPeerClose] = { 'onPeerClose' },
    [PdPortal.PlaydateCommand.OnPeerConnection] = { 'onPeerConnection' },
    [PdPortal.PlaydateCommand.OnPeerConnOpen] = { 'onPeerConnOpen' },
    [PdPortal.PlaydateCommand.OnPeerConnClose] = { 'onPeerConnClose' },
    [PdPortal.PlaydateCommand.Keepalive] = { '_onKeepalive' },
    [PdPortal.PlaydateCommand.OnFetchSuccess] = { '_onFetchSuccess' },
    [PdPortal.PlaydateCommand.OnFetchError] = { '_onFetchError' },
}

PdPortal.portalCommandSeparator = string.char(30)
PdPortal.portalArgumentSeparator = string.char(31)
PdPortal.playdateCommandSeparator = '~|~'
PdPortal.playdateCommandPattern = PdPortal.playdateCommandSeparator .. "()"
PdPortal.playdateArgumentSeparator = '~,~'
PdPortal.playdateArgumentPattern = '(.-)' .. PdPortal.playdateArgumentSeparator .. "()"
PdPortal.incomingCommandBuffer = ''

function PdPortal:init()
    playdate.serialMessageReceived = function(msg)
        self:_onSerialMessageReceived(msg)
    end

    self.serialKeepaliveTimer = nil
    self._fetchCallbacks = {}
    self._nextRequestId = 1
end

function PdPortal:update()
    timer.updateTimers()
end

function PdPortal:_onSerialMessageReceived(msgString)
    msgString = msgString:gsub('~n~', '\n')

    local completeCommandStrings, trailingCommand = PdPortal._splitCommandBuffer(
        PdPortal.incomingCommandBuffer .. msgString,
        PdPortal.playdateCommandPattern
    )

    PdPortal.incomingCommandBuffer = trailingCommand

    for _, commandString in ipairs(completeCommandStrings) do
        local cmdArgs = PdPortal._splitString(commandString, PdPortal.playdateArgumentPattern)
        local methodsToCall = PdPortal.playdateCommandMethods[cmdArgs[1]]
        if methodsToCall == nil then
            self:log('Unknown command received', cmdArgs[1], msgString, string.len(msgString))
            return
        end

        for _, methodName in ipairs(methodsToCall) do
            self[methodName](self, table.unpack(cmdArgs, 2))
        end
    end
end

function PdPortal:_onConnect()
    self:_onKeepalive()
end

function PdPortal:_onKeepalive()
    if self.serialKeepaliveTimer ~= nil then
        self.serialKeepaliveTimer:pause()
        self.serialKeepaliveTimer:remove()
        self.serialKeepaliveTimer = nil
    end

    timer.performAfterDelay(500, function()
        self.serialKeepaliveTimer = playdate.timer.new(100, function()
            self:onDisconnect()
        end)
        self:sendCommand(PdPortal.PortalCommand.Keepalive)
    end)
end

function PdPortal:_onFetchSuccess(requestId, responseText, responseDetails)
    local callbacks = self._fetchCallbacks[requestId]
    if callbacks == nil then
        self:log('Success, but no callbacks found for request ID', requestId)
        return
    end

    callbacks[1](responseText, jsonDecode(responseDetails))
    self._fetchCallbacks[requestId] = nil
end

function PdPortal:_onFetchError(requestId, errorDetails)
    local callbacks = self._fetchCallbacks[requestId]
    if callbacks == nil then
        self:log('Error, but no callbacks found for request ID', requestId)
        return
    end

    callbacks[2](jsonDecode(errorDetails))
    self._fetchCallbacks[requestId] = nil
end

PdPortal._splitCommandBuffer = function(cmdBufferString, pattern)
    local completeCommands = {}
    local start = 1
    local first, last = string.find(cmdBufferString, pattern, start)
    local trailingCommand = cmdBufferString

    while first do
        local command = string.sub(cmdBufferString, start, first - 1)
        if command ~= "" then
            table.insert(completeCommands, command)
        end
        start = last + 1
        first, last = string.find(cmdBufferString, pattern, start)
    end

    if start <= string.len(cmdBufferString) then
        trailingCommand = string.sub(cmdBufferString, start)
    else
        trailingCommand = ""
    end

    return completeCommands, trailingCommand
end

PdPortal._splitString = function(inputStr, pattern)
    local result = {}
    local lastEnd = 1

    for part, endPos in string.gmatch(inputStr, pattern) do
        table.insert(result, part)
        lastEnd = endPos
    end

    if lastEnd <= #inputStr then
        table.insert(result, string.sub(inputStr, lastEnd))
    end

    return result
end

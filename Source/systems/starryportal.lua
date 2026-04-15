--[[
Shared multiplayer session service for Starry Messenger.

Purpose:
- manages pdportal lobby state, slot assignment, and peer bookkeeping
- routes network payloads to the active multiplayer scene
- provides host/client helpers used by Duck Game and Orbital Defense
]]
import "pdportal"

local function countTableEntries(tbl)
    local total = 0
    if tbl == nil then
        return 0
    end
    for _, _value in pairs(tbl) do
        total = total + 1
    end
    return total
end

local function clearTable(tbl)
    for key, _value in pairs(tbl) do
        tbl[key] = nil
    end
end

class("StarryPortal").extends("PdPortal")

function StarryPortal:init(service)
    StarryPortal.super.init(self)
    self.service = service
end

function StarryPortal:onConnect(portalVersion)
    self.service:onPortalConnect(portalVersion)
end

function StarryPortal:onDisconnect()
    self.service:onPortalDisconnect()
end

function StarryPortal:onPeerOpen(peerId)
    self.service:onPortalPeerOpen(peerId)
end

function StarryPortal:onPeerClose()
    self.service:onPortalPeerClose()
end

function StarryPortal:onPeerConnection(remotePeerId)
    self.service:onPortalPeerConnection(remotePeerId)
end

function StarryPortal:onPeerConnOpen(remotePeerId)
    self.service:onPortalPeerConnOpen(remotePeerId)
end

function StarryPortal:onPeerConnClose(remotePeerId)
    self.service:onPortalPeerConnClose(remotePeerId)
end

function StarryPortal:onPeerConnData(remotePeerId, payload)
    local decoded = json.decode(payload)
    if decoded ~= nil then
        self.service:onPortalPeerConnData(remotePeerId, decoded)
    end
end

StarryPortalService = {}
StarryPortalService.__index = StarryPortalService

function StarryPortalService.new()
    local self = setmetatable({}, StarryPortalService)
    self.portal = StarryPortal(self)
    self.delegate = nil
    self.isSerialConnected = false
    self.isPeerOpen = false
    self.peerId = nil
    self.portalVersion = nil
    self.current = nil
    return self
end

function StarryPortalService:update()
    self.portal:update()
end

function StarryPortalService:setDelegate(delegate)
    self.delegate = delegate
end

function StarryPortalService:notifyDelegate(methodName, ...)
    if self.delegate ~= nil and self.delegate[methodName] ~= nil then
        self.delegate[methodName](self.delegate, ...)
    end
end

function StarryPortalService:notifyStatusChanged()
    self:notifyDelegate("onPortalStatusChanged")
end

function StarryPortalService:beginLobby(gameId, targetPlayers, delegate)
    self:closeConnections()
    self.delegate = delegate
    self.current = {
        gameId = gameId,
        targetPlayers = math.max(2, math.min(4, math.floor(targetPlayers or 2))),
        role = "host",
        assignedSlot = 1,
        hostPeerId = nil,
        remoteSlotsByPeer = {},
        remotePeersBySlot = {},
        lobbySlots = { [1] = true }
    }
    self:notifyStatusChanged()
end

function StarryPortalService:endSession()
    self:closeConnections()
    self.current = nil
    self.delegate = nil
    self:notifyStatusChanged()
end

function StarryPortalService:closeConnections()
    if self.current == nil then
        return
    end

    for remotePeerId, _slot in pairs(self.current.remoteSlotsByPeer) do
        self.portal:sendCommand(PdPortal.PortalCommand.ClosePeerConn, remotePeerId)
    end
    if self.current.hostPeerId ~= nil then
        self.portal:sendCommand(PdPortal.PortalCommand.ClosePeerConn, self.current.hostPeerId)
    end
    clearTable(self.current.remoteSlotsByPeer)
    clearTable(self.current.remotePeersBySlot)
    clearTable(self.current.lobbySlots)
end

function StarryPortalService:getRole()
    return self.current and self.current.role or "host"
end

function StarryPortalService:isHost()
    return self:getRole() == "host"
end

function StarryPortalService:isClient()
    return self:getRole() == "client"
end

function StarryPortalService:getAssignedSlot()
    return self.current and self.current.assignedSlot or 1
end

function StarryPortalService:getTargetPlayers()
    return self.current and self.current.targetPlayers or 1
end

function StarryPortalService:getLobbySlots()
    return self.current and self.current.lobbySlots or {}
end

function StarryPortalService:getSlotForPeer(remotePeerId)
    return self.current and self.current.remoteSlotsByPeer[remotePeerId] or nil
end

function StarryPortalService:getPeerForSlot(slot)
    return self.current and self.current.remotePeersBySlot[slot] or nil
end

function StarryPortalService:getConnectedCount()
    if self.current == nil then
        return 0
    end

    if self:isHost() then
        return 1 + countTableEntries(self.current.remoteSlotsByPeer)
    end

    return countTableEntries(self.current.lobbySlots)
end

function StarryPortalService:isReadyToStart()
    return self.current ~= nil
        and self:isHost()
        and self:getConnectedCount() >= self.current.targetPlayers
end

function StarryPortalService:findOpenRemoteSlot()
    if self.current == nil then
        return nil
    end

    for slot = 2, self.current.targetPlayers do
        if self.current.remotePeersBySlot[slot] == nil then
            return slot
        end
    end

    return nil
end

function StarryPortalService:sendPayload(remotePeerId, payload)
    if remotePeerId == nil then
        return
    end

    if self.current and self.current.gameId and payload.gameId == nil then
        payload.gameId = self.current.gameId
    end
    self.portal:sendToPeerConn(remotePeerId, payload)
end

function StarryPortalService:broadcast(payload)
    if self.current == nil then
        return
    end

    for remotePeerId, _slot in pairs(self.current.remoteSlotsByPeer) do
        self:sendPayload(remotePeerId, payload)
    end
end

function StarryPortalService:broadcastLobby()
    if self.current == nil or not self:isHost() then
        return
    end

    local occupied = { 1 }
    for slot = 2, self.current.targetPlayers do
        if self.current.remotePeersBySlot[slot] ~= nil then
            occupied[#occupied + 1] = slot
        end
    end

    clearTable(self.current.lobbySlots)
    for _, slot in ipairs(occupied) do
        self.current.lobbySlots[slot] = true
    end

    for remotePeerId, slot in pairs(self.current.remoteSlotsByPeer) do
        self:sendPayload(remotePeerId, {
            type = "lobby",
            slot = slot,
            occupiedSlots = occupied,
            hostPeerId = self.peerId,
            targetPlayers = self.current.targetPlayers
        })
    end
    self:notifyStatusChanged()
end

function StarryPortalService:onPortalConnect(portalVersion)
    self.portalVersion = portalVersion
    self.isSerialConnected = true
    self.portal:sendCommand(PdPortal.PortalCommand.InitializePeer)
    self:notifyStatusChanged()
end

function StarryPortalService:onPortalDisconnect()
    self.isSerialConnected = false
    self.isPeerOpen = false
    self.peerId = nil
    self.portalVersion = nil
    if self.current ~= nil then
        self.current.hostPeerId = nil
        clearTable(self.current.remoteSlotsByPeer)
        clearTable(self.current.remotePeersBySlot)
        clearTable(self.current.lobbySlots)
        self.current.lobbySlots[1] = true
    end
    self:notifyDelegate("onPortalDisconnected")
    self:notifyStatusChanged()
end

function StarryPortalService:onPortalPeerOpen(peerId)
    self.peerId = peerId
    self.isPeerOpen = true
    self:notifyStatusChanged()
end

function StarryPortalService:onPortalPeerClose()
    self.peerId = nil
    self.isPeerOpen = false
    self:notifyStatusChanged()
end

function StarryPortalService:onPortalPeerConnection(remotePeerId)
    if self.current == nil then
        self.portal:sendCommand(PdPortal.PortalCommand.ClosePeerConn, remotePeerId)
        return
    end

    if self:isClient() then
        self.portal:sendCommand(PdPortal.PortalCommand.ClosePeerConn, remotePeerId)
        return
    end

    local slot = self:findOpenRemoteSlot()
    if slot == nil then
        self:sendPayload(remotePeerId, { type = "full" })
        self.portal:sendCommand(PdPortal.PortalCommand.ClosePeerConn, remotePeerId)
        return
    end

    self.current.role = "host"
    self.current.remoteSlotsByPeer[remotePeerId] = slot
    self.current.remotePeersBySlot[slot] = remotePeerId
    self.current.lobbySlots[slot] = true
    self:sendPayload(remotePeerId, {
        type = "assigned",
        slot = slot,
        hostPeerId = self.peerId,
        targetPlayers = self.current.targetPlayers
    })
    self:broadcastLobby()
    self:notifyDelegate("onPortalPeerAssigned", remotePeerId, slot)
end

function StarryPortalService:onPortalPeerConnOpen(remotePeerId)
    if self.current == nil then
        self.portal:sendCommand(PdPortal.PortalCommand.ClosePeerConn, remotePeerId)
        return
    end

    if countTableEntries(self.current.remoteSlotsByPeer) == 0 and self.current.hostPeerId == nil then
        self.current.role = "client"
        self.current.hostPeerId = remotePeerId
        clearTable(self.current.lobbySlots)
        self.current.lobbySlots[1] = true
        self:notifyStatusChanged()
        return
    end

    self:notifyStatusChanged()
end

function StarryPortalService:onPortalPeerConnClose(remotePeerId)
    if self.current == nil then
        return
    end

    if self:isClient() and self.current.hostPeerId == remotePeerId then
        self.current.hostPeerId = nil
        self:notifyDelegate("onPortalHostDisconnected", remotePeerId)
        self:notifyStatusChanged()
        return
    end

    local slot = self.current.remoteSlotsByPeer[remotePeerId]
    if slot ~= nil then
        self.current.remoteSlotsByPeer[remotePeerId] = nil
        self.current.remotePeersBySlot[slot] = nil
        self.current.lobbySlots[slot] = nil
        self:broadcastLobby()
        self:notifyDelegate("onPortalPeerDisconnected", remotePeerId, slot)
    end
end

function StarryPortalService:onPortalPeerConnData(remotePeerId, message)
    if self.current == nil then
        return
    end

    if message.gameId ~= nil and message.gameId ~= self.current.gameId then
        return
    end

    if message.type == "assigned" then
        self.current.role = "client"
        self.current.assignedSlot = tonumber(message.slot) or self.current.assignedSlot
        self.current.hostPeerId = message.hostPeerId or self.current.hostPeerId
        self.current.targetPlayers = tonumber(message.targetPlayers) or self.current.targetPlayers
    elseif message.type == "lobby" then
        self.current.assignedSlot = tonumber(message.slot) or self.current.assignedSlot
        self.current.hostPeerId = message.hostPeerId or self.current.hostPeerId
        self.current.targetPlayers = tonumber(message.targetPlayers) or self.current.targetPlayers
        clearTable(self.current.lobbySlots)
        for _, slot in ipairs(message.occupiedSlots or {}) do
            self.current.lobbySlots[slot] = true
        end
    end

    self:notifyDelegate("onPortalMessage", remotePeerId, message)
    self:notifyStatusChanged()
end

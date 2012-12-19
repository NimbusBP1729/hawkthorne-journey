local socket = require "socket"
local Character = require 'character'
local controls = require 'controls'

--draw data

local Client = {}
Client.__index = Client
local singleton = nil

local t = 0
local button_pressed_map = {}

-- love.load, hopefully you are familiar with it from the callbacks tutorial
function Client.new()

    local client = {}
    setmetatable(client, Client)
    
    local address, port = "localhost", 12345
    client.udp = socket.udp()
    client.udp:settimeout(0)
    client.udp:setpeername(address, port)

    client.updaterate = 0.1 -- how long to wait, in seconds, before requesting an update
    
    client.level = nil
    --client.button_pressed_map = {}

    client.world = {} -- world[level][ent_id] = objectBundle
    client.players = {} -- players[ent_id] = playerBundle ... and player.id = ent_id

    math.randomseed(os.time())
    client.entity = tostring(math.random(99999)) --the id of the player I'll be attached to
    local dg = string.format("%s %s $", client.entity, 'register')
    client.udp:send(dg)

    client.player_characters = {}
    client.player_characters[client.entity] = Character.new():reset()

    return client
end

--returns the same client every time
function Client.getSingleton()
    singleton = singleton or Client.new()
    return singleton
end

-- love.update, hopefully you are familiar with it from the callbacks tutorial

function Client:update(deltatime)
    local udp = self.udp
    local entity = self.entity
    local updaterate = self.updaterate
    
    t = t + deltatime -- increase t by the deltatime
    if t > updaterate then
        local x, y = 0, 0
        
        local dg
        for key,button in pairs(controls.getMap()) do
            if love.keyboard.isDown(button) then
                dg = string.format("%s %s %s", entity, 'keydown', key)
                udp:send(dg)
                if not button_pressed_map[key] then
                    button_pressed_map[key] = true
                    dg = string.format("%s %s %s", entity, 'keypressed', key)
                    udp:send(dg)
                end
            elseif button_pressed_map[key] then
                button_pressed_map[key] = false
                dg = string.format("%s %s %s", entity, 'keyreleased', key)
                udp:send(dg)
            end
        end

        local dg = string.format("%s %s %s", entity, 'update', self.level)
        udp:send(dg)

        t=t-updaterate -- set t for the next round
    end

    repeat
        data, msg = udp:receive()
        if data then -- you remember, right? that all values in lua evaluate as true, save nil and false?
            ent, cmd, parms = data:match("^(%S*) (%S*) (.*)")
            if cmd == 'updatePlayer' then
                local player = lube.bin:unpack(parms)
                --should validate characters and costumes to default as abed.base
                if ent == self.entity then
                    self.level = player.level
                end
                player.id = ent
                self.players[ent] = player
                self.player_characters[ent] = self.player_characters[ent] or Character.new():reset()
                self.player_characters[ent].state = player.state
                self.player_characters[ent].direction = player.direction
                self.player_characters[ent].name = player.name
                self.player_characters[ent].costume = player.costume
            elseif cmd == 'updateObject' then
                local node = lube.bin:unpack_node(parms)
                self.world[node.level][ent] = node
            else
                print("unrecognised command:", cmd)
            end
        elseif msg ~= 'timeout' then 
            error("Network error: "..tostring(msg))
        end
    until not data 

end

-- love.draw, hopefully you are familiar with it from the callbacks tutorial
function Client:draw()
    -- if not self.level then return end
    -- pretty simple, we just loop over the world table, and print the
    -- name (key) of everything in there, at its own stored co-ords.

    if self.player and self.player.footprint then
        self:floorspaceNodeDraw()
    else
        for i,node in pairs(self.world[self.level]) do
            if not node.foreground then
                self:drawObject(node)
            end
        end

        for id,player in pairs(self.players) do
            if player.level == self.level then
                self:drawPlayer(player)
            end
        end

        for i,node in pairs(self.world[self.level]) do
            if node.foreground then
                self:drawObject(node)
            end
        end
    end
    -- self.player.inventory:draw(self.player.position)
    -- self.hud:draw( self.player )
    -- ach:draw()end
end

function Client:drawObject(node)

    local nodeImage = require ('images/'..node.type..'/'..node.name)
    self.node_frames[node.type][node.name] = self.node_frames[node.type][node.name] 
         or anim8.newGrid(node.frameWidth, node.frameHeight,
            nodeImage:getWidth(), nodeImage:getHeight())
    local frame = self.node_frames[node.type][node.name]
    love.graphics.draw(nodeImage, frame, node.x, node.y)
    --love.graphics.drawq(nodeIimage, frame?, node.x, node.y, r, sx, sy, ox, oy)
end
function Client:drawPlayer(plyr)
    print("drawing someone")     
    
    --i really don't like how character was called
    -- in the old non-multiplayer code
    local character = self.player_characters[plyr.id]
    local animation = self.player_characters[plyr.id]:animation()
    animation:draw(character:sheet(), plyr.x, plyr.y)
end
 
return Client
-- And thats the end of the udp client example.
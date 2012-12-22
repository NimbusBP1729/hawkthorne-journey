local socket = require "socket"
local Character = require 'character'
local controls = require 'controls'

--draw data

local Client = {}
Client.__index = Client
Client.singleton = nil

local t = 0
local button_pressed_map = {}

local image_cache = {}

local function load_image(name)
    if image_cache[name] then
        return image_cache[name]
    end

    local pic = image_cache[name] or love.graphics.newImage('images/' .. name)
    return pic
end

-- love.load, hopefully you are familiar with it from the callbacks tutorial
--this function should only be called by Client.getSingleton() until I support multiple 
-- players on a single IP
function Client.new()
    local client = {}
    setmetatable(client, Client)
    
    local address, port = "localhost", 12345
    client.udp = socket.udp()
    client.udp:settimeout(0)
    client.udp:setpeername(address, port)

    client.updaterate = 0.01 -- how long to wait, in seconds, before requesting an update
    
    client.level = 'overworld'
    --client.button_pressed_map = {}

    client.world = {} -- world[level][ent_id] = objectBundle
    client.players = {} -- players[ent_id] = playerBundle ... and player.id = ent_id

    math.randomseed(os.time())
    --later I should make sure these are assigned by the server instead
    client.entity = "player"..tostring(math.random(99999)) --the ent_id of the player I'll be attached to
    local dg = string.format("%s %s $", client.entity, 'register')
    client.udp:send(dg)

    client.player_characters = {}
    client.player_characters[client.entity] = Character.new()
    client.player_characters[client.entity]:reset()
    client.players[client.entity] = nil

    return client
end

--returns the same client every time
function Client.getSingleton()
    Client.singleton = Client.singleton or Client.new()
    return Client.singleton
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

        local dg = string.format("%s %s %s", entity, 'update', self.level or '$')
        udp:send(dg)

        t=t-updaterate -- set t for the next round
    end

    repeat
        data, msg = udp:receive()
        if data then -- you remember, right? that all values in lua evaluate as true, save nil and false?
            ent, cmd, parms = data:match("^(%S*) (%S*) (.*)")
            if cmd == 'updatePlayer' then
                if not self.hasUpdatedPlayer then print("First player update") 
                    self.hasUpdatedPlayer = true
                end
                local playerBundle = lube.bin:unpack_node(parms)
                --should validate characters and costumes to default as abed.base
                -- if ent == self.entity then
                    -- self.level = playerBundle.level
                -- end
                --playerBundle.id = ent
                self.players[ent] = playerBundle
                self.player_characters[ent] = self.player_characters[ent] or Character.new()
                self.player_characters[ent].state = playerBundle.state
                self.player_characters[ent].direction = playerBundle.direction
                self.player_characters[ent].name = playerBundle.name
                self.player_characters[ent].costume = playerBundle.costume
                self.player_characters[ent]:animation().position = playerBundle.position

                -- print("id:        "..playerBundle.id)
                -- print("x:         "..playerBundle.x)
                -- print("y:         "..playerBundle.y)
                -- print("position:  "..playerBundle.position)
                -- print("state:     "..playerBundle.state)
                -- print("direction: "..playerBundle.direction)
                -- print("name:      "..playerBundle.name)
                -- print("costume:   "..playerBundle.costume)
                -- print()
            elseif cmd == 'updateObject' then
                if not self.hasUpdatedObject then print("First object update") 
                    self.hasUpdatedObject = true
                end
                local node = lube.bin:unpack_node(parms)
                self.world[node.level][ent] = node
            elseif cmd == 'stateSwitch' then
                print(data)
                local fromLevel,toLevel = parms:match("^(%S*) (.*)")
                if toLevel == "overworld" then
                    Gamestate.switch("overworld", nil, ent)
                else
                    --will fail if not in level.lua
                    Gamestate.currentState():serverLeave()
                    Gamestate.currentState():serverEnter(toLevel)
                end
            else
                print("unrecognised command:", cmd)
            end
        elseif msg ~= 'timeout' then 
            error("Network error: "..tostring(msg))
        end
    until not data 

end

function Client:sendToServer(message)
    self.udp:send(message)
end

-- love.draw, hopefully you are familiar with it from the callbacks tutorial
function Client:draw()
    -- if not self.level then return end
    -- pretty simple, we just loop over the world table, and print the
    -- name (key) of everything in there, at its own stored co-ords.

    if self.player and self.player.footprint then
        self:floorspaceNodeDraw()
    else
        -- for i,node in pairs(self.world[self.level]) do
            -- if not node.foreground then
                -- self:drawObject(node)
            -- end
        -- end

        for id,player in pairs(self.players) do
            if player.level == self.level then
                self:drawPlayer(player)
            end
        end

        -- for i,node in pairs(self.world[self.level]) do
            -- if node.foreground then
                -- self:drawObject(node)
            -- end
        -- end
    end
    -- self.player.inventory:draw(self.player.position)
    -- self.hud:draw( self.player )
    -- ach:draw()end
end

function Client:drawObject(node)

    local nodeImage = load_image(node.type..'s/'..node.name..'.png')
    --either draw as a quad
    if node.quadType then
        local quad = load_quad(nodeImage,node.quadType)
        love.graphics.drawq(nodeImage, quad, node.x, node.y)
        love.graphics.draw(nodeImage, node.x, node.y)
    end
    --love.graphics.drawq(nodeImage, frame?, node.x, node.y, r, sx, sy, ox, oy)
end
function Client:drawPlayer(plyr)
    --i really don't like how character was called
    -- in the old non-multiplayer code
    
    assert(plyr,"Player must not be nil")
    assert(plyr.id,"Player needs to have an id")
    assert(self.player_characters,"Player("..plyr.id..")must be associated with a character")
    assert(self.player_characters[plyr.id],"Player's id("..plyr.id..")was not found in the client's self.player_characters list")
    assert(self.player_characters[plyr.id].animation,"Character("..plyr.id..") must have a current animation")
    local character = self.player_characters[plyr.id]
    local animation = self.player_characters[plyr.id]:animation()
    animation:draw(character:sheet(), plyr.x, plyr.y)
end
 
return Client
-- And thats the end of the udp client example.
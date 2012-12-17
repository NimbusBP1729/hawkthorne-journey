local socket = require "socket"
require 'level'

--draw data

local Client = {}
Client.__index = Client



-- love.load, hopefully you are familiar with it from the callbacks tutorial
function Client.new()
    local client = {}
    setmetatable(client, Client)
    
    local address, port = "localhost", 12345
    client.udp = socket.udp()
    client.udp:settimeout(0)
    client.udp:setpeername(address, port)

    client.updaterate = 0.1 -- how long to wait, in seconds, before requesting an update
    client.world = {} -- the empty world-state
    client.players = {} -- the empty world-state
    client.level = nil
    client.level_backgrounds = {} -- the empty world-state
    client.button_pressed_map = {}
    
    math.randomseed(os.time())
    client.entity = tostring(math.random(99999))
    local dg = string.format("%s %s $", self.id, 'register')
    client.udp:send(dg)

    local dg = string.format("%s %s %d %d", entity, 'at', 320, 240)
    client.udp:send(dg) -- the magic line in question.
    return client
end



-- love.update, hopefully you are familiar with it from the callbacks tutorial

function Client:update(deltatime)

    t = t + deltatime -- increase t by the deltatime
    if t > updaterate then
        local x, y = 0, 0
        
        local dg
        for key,button in controls.getMap() do
            if love.keyboard.isDown(button) then
                dg = string.format("%s %s %s", entity, 'keydown', key)
                udp:send(dg)
                if not button_pressed_map[key] then
                    button_pressed_map[key] = true
                    dg = string.format("%s %s %s", entity, 'keypress', key)
                    udp:send(dg)
                end
            elseif button_pressed_map[key] then
                button_pressed_map[key] = false
                dg = string.format("%s %s %s", entity, 'keyrelease', key)
                udp:send(dg)
            end
        end

        local dg = string.format("%s %s $", entity, 'update')
        udp:send(dg)

        t=t-updaterate -- set t for the next round
    end

    repeat
        data, msg = udp:receive()
        if data then -- you remember, right? that all values in lua evaluate as true, save nil and false?
            ent, cmd, parms = data:match("^(%S*) (%S*) (.*)")
            if cmd == 'updatePlayer' then
                local level, x, y, character, costume, state, position, direction = parms:match("^(%S*) (%S*) (%S*) (%S*) (%S*) (%S*) (%S*) (.*)")
                --should validate characters and costumes to default as abed.base
                if ent == self.entity then
                    self.level = level
                    self.level_backgrounds[level] = load_tileset(level)
                end
                assert(x and y) -- validation is better, but asserts will serve.
                x, y = tonumber(x), tonumber(y)
                position = tonumber(position)
                self.players[ent] = {level = level, x=x, y=y,character = character, costume = costume, state = state, position = position, direction = direction}
            elseif cmd == 'updateObject' then
                local level, x, y, name, state, position, direction, foreground = parms:match("^(%S*) (%S*) (%S*) (%S*) (%S*) (%S*) (%S*) (.*)")
                assert(x and y) -- validation is better, but asserts will serve.
                x, y = tonumber(x), tonumber(y)
                position = tonumber(position)
                foreground = (foreground == "true")
                self.world[level][ent] = { name=name, x=x, y=y,state = state, position = position, direction = direction, foreground = foreground}
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
    -- pretty simple, we just loop over the world table, and print the
    -- name (key) of everything in their, at its own stored co-ords.
    self.level_backgrounds[self.level]:draw(0, 0)

    if self.player.footprint then
        self:floorspaceNodeDraw()
    else
        for i,node in ipairs(self.world[self.level]) do
            if not node.foreground then
                node:paint(node.x,node.y,node.state,node.position,node.direction)
            end
        end

        for id,player in pairs(self.players) do
            player:paint(node.x,node.y,node.state,node.position,node.direction)
        end

        for i,node in ipairs(self.world[self.level]) do
            if not node.foreground then
                node:paint(node.x,node.y,node.state,node.position,node.direction)
            end
        end
    end
    
    -- self.player.inventory:draw(self.player.position)
    -- self.hud:draw( self.player )
    -- ach:draw()end

return Client
-- And thats the end of the udp client example.
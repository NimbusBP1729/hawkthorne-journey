local Gamestate = require 'vendor/gamestate'
local Queue = require 'queue'
local anim8 = require 'vendor/anim8'
local tmx = require 'vendor/tmx'
local HC = require 'vendor/hardoncollider/class'
local Timer = require 'vendor/timer'
local Tween = require 'vendor/tween'
local camera = require 'camera'
local window = require 'window'
-- local sound = require 'vendor/TEsound'
local controls = require 'controls'
local music = {}
require 'vendor/lube'

local node_cache = {}
local tile_cache = {}

local Player = require 'player_server'
local Floor = require 'nodes/floor'
local Floorspace = require 'nodes/floorspace'
local Floorspaces = require 'floorspaces'
local Platform = require 'nodes/platform'
local Wall = require 'nodes/wall'

local ach = (require 'achievements').new()
local address, port = "localhost", 12345
local udp = socket.udp()
udp:settimeout(0)
udp:setpeername(address, port)
local t = 0
local updaterate = 0.01
local update_ticker = 0


local function limit( x, min, max )
    return math.min(math.max(x,min),max)
end

local function load_tileset(name)
    if tile_cache[name] then
        return tile_cache[name]
    end
    
    local tileset = tmx.load(require("maps/" .. name))
    tile_cache[name] = tileset
    return tileset
end

local function load_node(name)
    if node_cache[name] then
        return node_cache[name]
    end

    local node = require('nodes/' .. name)
    node_cache[name] = node
    return node
end

local function on_collision(dt, shape_a, shape_b, mtv_x, mtv_y)
    local player, node, node_a, node_b

    if shape_a.player then
        player = shape_a.player
        node = shape_b.node
    elseif shape_b.player then
        player = shape_b.player
        node = shape_a.node
    else
        node_a = shape_a.node
        node_b = shape_b.node
    end

    if node then
        node.player_touched = true

        if node.collide then
            node:collide(player, dt, mtv_x, mtv_y)
        end
    elseif node_a then
        if node_a.collide then
            node_a:collide(node_b, dt, mtv_x, mtv_y)
        end
        if node_b.collide then
            node_b:collide(node_a, dt, mtv_x, mtv_y)
        end
    end

end

-- this is called when two shapes stop colliding
local function collision_stop(dt, shape_a, shape_b)
    local player, node

    if shape_a.player then
        player = shape_a.player
        node = shape_b.node
    elseif shape_b.player then
        player = shape_b.player
        node = shape_a.node
    else
        node_a = shape_a.node
        node_b = shape_b.node
    end

    if node then
        node.player_touched = false

        if node.collide_end then
            node:collide_end(player, dt)
        end
    else
        if node_a.collide_end then
            node_a:collide_end(node_b, dt)
        end
        if node_b.collide_end then
            node_b:collide_end(node_a, dt)
        end
    end
end

local function setBackgroundColor(map)
    local prop = map.properties
    if not prop.red then
        love.graphics.setBackgroundColor(0, 0, 0)
        return
    end
    love.graphics.setBackgroundColor(tonumber(prop.red),
                                     tonumber(prop.green),
                                     tonumber(prop.blue))
end

local function getCameraOffset(map)
    local prop = map.properties
    if not prop.offset then
        return 0
    end
    return tonumber(prop.offset) * map.tilewidth
end

local function getTitle(map)
    local prop = map.properties
    return prop.title or "UNKNOWN"
end

local function getSoundtrack(map)
    local prop = map.properties
    return prop.soundtrack or "level"
end

local Level = {}
Level.__index = Level
Level.level = true

function Level.new(name)
    local level = {}
    setmetatable(level, Level)

    level.name = name
    print("making new level")
    assert( love.filesystem.exists( "maps/" .. name .. ".lua" ),
            "maps/" .. name .. ".lua not found.\n\n" ..
            "Have you generated your maps lately?\n\n" ..
            "LINUX / OSX: run 'make maps'\n" ..
            "WINDOWS: use tmx2lua to generate\n\n" ..
            "Check the documentation for more info."
    )

    level.map = require("maps/" .. name)
    level.background = load_tileset(name)
    level.collider = HC(100, on_collision, collision_stop)
    level.offset = getCameraOffset(level.map)
    level.music = getSoundtrack(level.map)
    level.spawn = 'studyroom'
    level.title = getTitle(level.map)

    level:panInit()

    level.boundary = {
        width =level.map.width  * level.map.tilewidth,
        height=level.map.height * level.map.tileheight
    }

    level.nodes = {}
    level.doors = {}

    for k,v in pairs(level.map.objectgroups.nodes.objects) do
        node = load_node(v.type)
        if node then
            v.objectlayer = 'nodes'
            table.insert( level.nodes, node.new( v, level.collider ) )
        end
        if v.type == 'door' then
            if v.name then
                if v.name == 'main' then
                    assert(not level.default_position,"Level "..name.." must have only one 'main' door")
                    level.default_position = {x=v.x, y=v.y}
                end
                level.doors[v.name] = {x=v.x, y=v.y, node=level.nodes[#level.nodes]}
            end
        end
    end
    assert(level.default_position,"Level "..name.." has no 'main' door")

    if level.map.objectgroups.floor then
        for k,v in pairs(level.map.objectgroups.floor.objects) do
            v.objectlayer = 'floor'
            Floor.new(v, level.collider)
        end
    end

    if level.map.objectgroups.floorspace then
        for k,v in pairs(level.map.objectgroups.floorspace.objects) do
            v.objectlayer = 'floorspace'
            table.insert(level.nodes, Floorspace.new(v, level))
        end
    end

    if level.map.objectgroups.platform then
        for k,v in pairs(level.map.objectgroups.platform.objects) do
            v.objectlayer = 'platform'
            table.insert(level.nodes, Platform.new(v, level.collider))
        end
    end

    if level.map.objectgroups.wall then
        for k,v in pairs(level.map.objectgroups.wall.objects) do
            Wall.new(v, level.collider)
        end
    end

    level.players = {}
    level:restartLevel()
    return level
end

function Level:restartLevel()
    Floorspaces:init()
end

function Level:enter( previous, door , player)
    
    ach:achieve('enter ' .. self.name)

    self.players[player.id] = player
    self.player = player
    if previous == Gamestate.get('overworld') then
        door = 'main'  -- or checkpoint
        player.character:respawn()
    end

    player.boundary = {
        width = self.map.width * self.map.tilewidth,
        height = self.map.height * self.map.tileheight
    }

    camera.max.x = self.map.width * self.map.tilewidth - window.width
    setBackgroundColor(self.map)
    -- sound.playMusic( self.music )

    --should be attached to a player, not the level
    -- self.hud = HUD.new(player)

    
    player:enter(self)
    if door then
        player.position = {
            x = math.floor(self.doors[ door ].x + self.doors[ door ].node.width / 2 - player.width / 2),
            y = math.floor(self.doors[ door ].y + self.doors[ door ].node.height - player.height)
        }
        -- print(self.player.position.x)
        -- print("==door")
        -- print(self.player.position.y)
        -- print(self.player.boundary.height)
        -- print()
        
        if self.doors[ door ].warpin then
            player.character:respawn()
        end
        if self.doors[ door ].node then
            self.doors[ door ].node:show()
            player.freeze = false
        end
    end

    local initialY = player.position.y
    for i,node in ipairs(self.nodes) do
        if node.enter then 
            node:enter(previous)
        end
        if node.position then
            local dg = string.format("%s %s %s %s", i, 'registerObject', self.name, lube.bin:pack_node(node))
            udp:send(dg)
        end

    end
    local finalY = player.position.y
    if initialY ~= finalY then
        print("uhoh~~~")
    end
end



function Level:init()
end

function Level:update(dt)
    Tween.update(dt)
    self.player:update(dt)
    ach:update(dt)
 
    for i,node in ipairs(self.nodes) do
        if node.update then node:update(dt, self.player) end
        if self.player.currently_held == node then
            local dg = string.format("%s %s %s %s %s", i, 'moveObject', self.name, lube.bin:pack_node(node), os.time())
            udp:send(dg)
        end
    end

    self.collider:update(dt)

    self:updatePan(dt)

    local x = self.player.position.x + self.player.width / 2
    local y = self.player.position.y - self.map.tilewidth * 4.5
    camera:setPosition( math.max(x - window.width / 2, 0),
                        limit( limit(y, 0, self.offset) + self.pan, 0, self.offset ) )

    Timer.update(dt)
    
    t = t+dt
    if t > updaterate then
        local levelName = self.name
        
        --update sprite        
        dg = string.format("%s %s %s", self.player.id, 'update', levelName)
        udp:send(dg)
        
        update_ticker = update_ticker + 1
        print(update_ticker..': '..tostring(port))
        
        t = 0
    end
    
    repeat
        data, msg = udp:receive()
        if data then
            local ent_id, cmd, parms = data:match("^(%S*) (%S*) (.*)")
            if cmd == 'at' and string.find(ent_id,"player") then
                print("trying to update players?")
                print("ima get a update")
                local level, player = parms:match("^(%S*) (.*)")
                --print(player)
                print(ent_id)
                player = lube.bin:unpack_node(player)
                local player_id = tonumber(ent_id)
                if level == Gamestate.currentState().name then
                    print(level)
                    Gamestate.currentState().players[player_id].position = {
                        x = player.position.x,
                        y = player.position.y}
                    Gamestate.currentState().players[player_id].velocity = {
                        x = player.velocity.x,
                        y = player.velocity.y}
                    print("updated a player")
                end
            elseif cmd == 'at' then  --update node
                --print("ima get a update")
                local level, node = parms:match("^(%S*) (.*)")
                --print(node)
                --print(ent_id)
                node = lube.bin:unpack_node(node)
                local node_id = tonumber(ent_id)
                if level == Gamestate.currentState().name then
                    --print(level)
                    assert(node.position,"Node of type '"..tostring(Gamestate.currentState().nodes[node_id].type).."' has no position")
                    Gamestate.currentState().nodes[node_id].position = {
                        x = node.position.x,
                        y = node.position.y}
                    assert(node.velocity,"Node of type '"..tostring(Gamestate.currentState().nodes[node_id].type).."' has no velocity")
                    Gamestate.currentState().nodes[node_id].velocity = {
                        x = node.velocity.x,
                        y = node.velocity.y}
                    --print("updated an object")
                end
            else
                print("unrecognised command:", cmd)
            end
        elseif msg ~= 'timeout' then 
            error("Network error: "..tostring(msg))
        end
    until not data 
end

function Level:quit()
    if self.player.respawn ~= nil then
        Timer.cancel(self.player.respawn)
    end
end

-- draws the nodes based on their location in the y axis
-- this is an accurate representation of the location
-- written by NimbusBP1729, refactored by jhoff
function Level:floorspaceNodeDraw()
    local layers = {}
    local player = self.player
    local fp = player.footprint
    local fp_base = math.floor( fp.y + fp.height )
    local player_drawn = false
    local player_center = player.position.x + player.width / 2

    --iterate through the nodes and place them in layers by their lowest y value
    for _,node in pairs(self.nodes) do
        if node.draw then
            local node_position = node.position and node.position or ( ( node.x and node.y ) and {x=node.x,y=node.y} or ( node.node and {x=node.node.x,y=node.node.y} or false ) )
            assert( node_position, 'Error! Node has to have a position!' )
            assert( node.height and node.width, 'Error! Node must have a height and a width property!' )
            local node_center = node_position.x + ( node.width / 2 )
            local node_depth = ( node.node and node.node.properties and node.node.properties.depth ) and node.node.properties.depth or 0
            local node_direction = ( node.node and node.node.properties and node.node.properties.direction ) and node.node.properties.direction or false
            -- base is, by default, offset by the depth
            local node_base = node_position.y + node.height - node_depth
            -- adjust the base by the players position
            -- if on floor and not behind or in front
            if fp.offset == 0 and node_direction and node_base < fp_base and node_position.y + node.height > fp_base then
                node_base = fp_base - 3
                if ( node_direction == 'left' and player_center < node_center ) or
                   ( node_direction == 'right' and player_center > node_center ) then
                    node_base = fp_base + 3
                end
            end
            -- add the node to the layer
            node_base = math.floor( node_base )
            while #layers < node_base do table.insert( layers, false ) end
            if not layers[ node_base ] then layers[ node_base ] = {} end
            table.insert( layers[ node_base ], node )
         end
    end

    --draw the layers
    for y,nodes in pairs(layers) do
        if nodes then
            for _,node in pairs(nodes) do
                --draw player once his neighbors are found
                if not player_drawn and fp_base <= y then
                    self.player:draw()
                    player_drawn = true
                end
                node:draw()
            end
        end
    end
    if not player_drawn then
        self.player:draw()
    end
end

function Level:leave()
    ach:achieve('leave ' .. self.name)
    for i,node in ipairs(self.nodes) do
        if node.leave then node:leave() end
        if node.collide_end then
            node:collide_end(self.player)
        end
    end
end

function Level:keyreleased( button )
    self.player:keyreleased( button, self )
end

function Level:keypressed( button , player)
    for i,node in ipairs(self.nodes) do
        if node.player_touched and node.keypressed then
            if node:keypressed( button, player) then
              return true
            end
        end
    end
   
    if player:keypressed( button, self ) then
      return true
    end

    if button == 'START' and not player.dead then
        Gamestate.switch('pause')
        return true
    end
end

function Level:panInit()
    self.pan = 0 
    self.pan_delay = 1
    self.pan_distance = 80
    self.pan_speed = 140
    self.pan_hold_up = 0
    self.pan_hold_down = 0
end

function Level:updatePan(dt)
    local up = controls.isDown( 'UP' )
    local down = controls.isDown( 'DOWN' )

    if up and self.player.velocity.x == 0 then
        self.pan_hold_up = self.pan_hold_up + dt
    else
        self.pan_hold_up = 0
    end
    
    if down and self.player.velocity.x == 0 then
        self.pan_hold_down = self.pan_hold_down + dt
    else
        self.pan_hold_down = 0
    end

    if up and self.pan_hold_up >= self.pan_delay then
        self.player:setSpriteStates('looking')
        self.pan = math.max( self.pan - dt * self.pan_speed, -self.pan_distance )
    elseif down and self.pan_hold_down >= self.pan_delay then
        self.player:setSpriteStates('looking')
        self.pan = math.min( self.pan + dt * self.pan_speed, self.pan_distance )
    else
        self.player:setSpriteStates('default')
        if self.pan > 0 then
            self.pan = math.max( self.pan - dt * self.pan_speed, 0 )
        elseif self.pan < 0 then
            self.pan = math.min( self.pan + dt * self.pan_speed, 0 )
        end
    end
end

return Level

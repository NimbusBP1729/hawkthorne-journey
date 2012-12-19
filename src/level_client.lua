local Gamestate = require 'vendor/gamestate'
local Queue = require 'queue'
local anim8 = require 'vendor/anim8'
local tmx = require 'vendor/tmx'
local Timer = require 'vendor/timer'
local Tween = require 'vendor/tween'
local camera = require 'camera'
local window = require 'window'
local sound = require 'vendor/TEsound'
local controls = require 'controls'
local HUD = require 'hud'
local music = {}
require 'vendor/lube'

local node_cache = {}
local tile_cache = {}

local Player = require 'player_client'

local ach = (require 'achievements').new()

local Client = require 'client'


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
    -- level.collider = HC(100, on_collision, collision_stop)
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

    level.players = {}
    return level
end

function Level:init()
end

--handle client controls
function Level:enter()
    self.background = load_tileset(self.name)
    self.client = Client.getSingleton()
    self.client.level = self.name
    -- self.client.players[self.client.entity] = Player.factory()
    self.client.world[self.name] = self.client.world[self.name] or {}
end

function Level:update(dt)
end

function Level:draw()
    self.background:draw(0, 0)
    self.client:draw()
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
end

function Level:keypressed( button , player)
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

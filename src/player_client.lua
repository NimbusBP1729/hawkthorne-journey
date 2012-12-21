local Queue = require 'queue'
local Timer = require 'vendor/timer'
local window = require 'window'
local cheat = require 'cheat'
local sound = require 'vendor/TEsound'
local character = require 'character'
local PlayerAttack = require 'playerAttack'
local Gamestate = require 'vendor/gamestate'
require 'vendor/lube'

-- to start with, we need to require the 'socket' lib (which is compiled
-- into love). socket provides low-level networking features.
local socket = require "socket"
-- the address and port of the server
local address, port = "localhost", 12345
local udp = socket.udp()

local healthbar = love.graphics.newImage('images/healthbar.png')
healthbar:setFilter('nearest', 'nearest')

local Inventory = require('inventory_client')
-- local ach = (require 'achievements').new()

local healthbarq = {}
local levels = {}

for i=6,0,-1 do
    table.insert(healthbarq, love.graphics.newQuad(28 * i, 0, 28, 27,
                             healthbar:getWidth(), healthbar:getHeight()))
end

local health = love.graphics.newImage('images/damage.png')

local Player = {}
Player.__index = Player
Player.isPlayer = true
Player.startingMoney = 0

-- single 'character' object that handles all character switching, costumes and animation
Player.character = character

local player = nil
local updaterate = 0.01
local t = 0

---
-- Create a new Player
-- @param collider
-- @return Player
function Player.new(collider)
    local plyr = {}

    setmetatable(plyr, Player)
    
    plyr.invulnerable = false
    plyr.actions = {}
    plyr.position = {x=0, y=0}
    plyr.frame = nil
    
    plyr.width = 48
    plyr.height = 48
    plyr.bbox_width = 18
    plyr.bbox_height = 44

    --for damage text
    plyr.healthText = {x=0, y=0}
    plyr.healthVel = {x=0, y=0}
    plyr.max_health = 6
    plyr.health = plyr.max_health

    plyr.inventory = Inventory.new( plyr )
    
    plyr.money = plyr.startingMoney
    plyr.lives = 3

    plyr.jumpQueue = Queue.new()
    plyr.halfjumpQueue = Queue.new()
    plyr.rebounding = false
    plyr.damageTaken = 0

    plyr.jumping = false
    plyr.liquid_drag = false
    plyr.flash = false
    plyr.actions = {}

    plyr.velocity = {x=0, y=0}
    plyr.fall_damage = 0
    plyr.since_solid_ground = 0
    plyr.dead = false

    plyr:setSpriteStates('default')

    plyr.freeze = false
    plyr.mask = nil

    plyr.currently_held = nil -- Object currently being held by the player
    plyr.holdable       = nil -- Object that would be picked up if player used grab key

    plyr.key_down = {}
    --plyr:enter(collider)
    return plyr
end

function Player:enter(collider)
    self.jumping = false
    if self.character.changed then
        self.character.changed = false
        self.health = self.max_health
        self.money = 0
        self.inventory = Inventory.new( self )
        self.lives = 3
    end

    if self.bb then
        self.collider:remove(self.bb)
        self.bb = nil
    end
    if self.attack_box and self.attack_box.bb then
        self.collider:remove(self.attack_box.bb)
        self.attack_box.bb = nil
    end

    self.collider = collider
    self.bb = collider:addRectangle(0,0,self.bbox_width,self.bbox_height)
    self:moveBoundingBox()
    self.bb.player = self -- wat
    self.attack_box = PlayerAttack.new(collider,self)

end

function Player:keypressed( button, map )
end

function Player:keyreleased( button, map )
end

---
-- Call to take falling damage, and reset self.fall_damage to 0
-- @return nil
function Player:impactDamage()
end

---
-- Stops the player from blinking, clearing the damage queue, and correcting the
-- flash animation
-- @return nil
function Player:stopBlink()
end

---
---
-- Starts the player blinking every .12 seconds if they are not already blinking
-- @return nil
function Player:startBlink()
end

---
-- Draws the player to the screen
-- @return nil
function Player:draw()
    if self.stencil then
        love.graphics.setStencil( self.stencil )
    else
        love.graphics.setStencil( )
    end
    
    if self.character.warpin then
        local y = self.position.y - self.character:current().beam:getHeight() + self.height + 4
        self.character:current().animations.warp:draw(self.character:current().beam, self.position.x + 6, y)
        return
    end

    if self.blink then
        love.graphics.drawq(healthbar, healthbarq[self.health + 1],
                            math.floor(self.position.x) - 18,
                            math.floor(self.position.y) - 18)
    end

    if self.flash then
        love.graphics.setColor( 255, 0, 0, 255 )
    end
    
    if self.footprint and self.jumping then
        self.footprint:draw()
    end

    local animation = self.character:animation()
    animation:draw(self.character:sheet(), math.floor(self.position.x),
                                      math.floor(self.position.y))

    -- Set information about animation state for holdables
    self.frame = animation.frames[animation.position]
    local x,y,w,h = self.frame:getViewport()
    self.frame = {x/w+1, y/w+1}
    if self.character:current().positions then
        self.offset_hand_right = self.character:current().positions.hand_right[self.frame[2]][self.frame[1]]
        self.offset_hand_left  = self.character:current().positions.hand_left[self.frame[2]][self.frame[1]]
    else
        self.offset_hand_right = {0,0}
        self.offset_hand_left  = {0,0}
    end

    if self.currently_held then
        self.currently_held:draw()
    end

    if self.rebounding and self.damageTaken > 0 then
        love.graphics.draw(health, self.healthText.x, self.healthText.y)
    end

    love.graphics.setColor( 255, 255, 255, 255 )
    
    love.graphics.setStencil()
    
end

function Player:isJumpState(myState)
    --assert(type(myState) == "string")
    if myState==nil then return nil end

    if string.find(myState,'jump') == nil then
        return false
    else
        return true
    end
end

function Player:isWalkState(myState)
    if myState==nil then return false end

    if string.find(myState,'walk') == nil then
        return false
    else
        return true
    end
end

function Player:isIdleState(myState)
    --assert(type(myState) == "string")
    if myState==nil then return nil end

    if string.find(myState,'idle') == nil then
        return false
    else
        return true
    end
end

return Player

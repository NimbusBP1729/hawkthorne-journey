--MUST READ: 
-- to use this file do the following
-- 1)find and replace each capitalized instance of Activenpc
-- with a capitalized version of your node's name
-- 2) find and replace each lowercase instance of activenpc
-- with a lowercase version of your node's name(this should be the same as the filename)
-- 3) start coding

-----------------------------------------------
-- Activenpc.lua
-----------------------------------------------

local Activenpc = {}
Activenpc.__index = Activenpc
Activenpc.isActivenpc = true

--include necessary files
local Manualcontrols = require 'manualcontrols'
local anim8 = require 'vendor/anim8'
local sound = require 'vendor/TEsound'

---
-- Creates a new Activenpc object
-- @param node the table used to create this
-- @param a collider of objects
-- @return the Activenpc object created
function Activenpc.new(node, collider)
    --creates a new object
    local activenpc = {}
    --sets it to use the functions and variables defined in Activenpc
    -- if it doesn;t have one by that name
    setmetatable(activenpc, Activenpc)
    --stores all the parameters from the tmx file
    activenpc.node = node

    --stores parameters from a lua file
    activenpc.props = require('nodes/activenpcs/' .. node.name)

    --sets the position from the tmx file
    activenpc.position = {x = node.x, y = node.y}
    activenpc.width = node.width
    activenpc.height = node.height
    
    --initialize the node's bounding box
    activenpc.collider = collider
    activenpc.bb = collider:addRectangle(0,0,activenpc.props.bb_width,activenpc.props.bb_height)
    activenpc.bb.node = activenpc
    activenpc.collider:setPassive(activenpc.bb)
 
    --define some offsets for the bounding box that can be used each update cycle
    activenpc.bb_offset = {x = activenpc.props.bb_offset_x or 0,
                           y = activenpc.props.bb_offset_y or 0}
 
    
    --add more initialization code here if you want
    activenpc.controls = nil
    
    activenpc.state = "default"
    activenpc.direction = "right"
    
    local npcImage = love.graphics.newImage('images/activenpcs/'..node.name..'.png')
    local g = anim8.newGrid(activenpc.props.width, activenpc.props.height, npcImage:getWidth(), npcImage:getHeight())
    activenpc.image = npcImage
    
    activenpc.animations = {}
    for state, data in pairs( activenpc.props.animations ) do
        activenpc.animations[ state ] = anim8.newAnimation( data[1], g( unpack(data[2]) ), data[3])
    end

    activenpc.lastSoundUpdate = math.huge

    return activenpc
end

function Activenpc:enter( previous )
    if self.props.enter then
        self.props.enter(self, previous)
    end
end

---
-- Draws the Activenpc to the screen
-- @return nil
function Activenpc:draw()
    local anim = self:animation()
    if self.direction=="right" then
        anim:draw(self.image, self.position.x, self.position.y, 0, 1, 1)
    else
        anim:draw(self.image, self.position.x + self.width, self.position.y, 0, -1, 1)
    end
end

function Activenpc:keypressed( button, player )
    if button == "INTERACT" then
        self.props.onInteract(self, player)
    end
end

---
-- Called when the Activenpc begins colliding with another node
-- @param node the node you're colliding with
-- @param dt ?
-- @param mtv_x amount the node must be moved in the x direction to stop colliding
-- @param mtv_y amount the node must be moved in the y direction to stop colliding
-- @return nil
function Activenpc:collide(node, dt, mtv_x, mtv_y)
    if self.props.collide then
        self.props.collide(self,node, dt, mtv_x, mtv_y)
    end
end


function Activenpc:animation()
    return self.animations[self.state]
end

---
-- Called when the Activenpc finishes colliding with another node
-- @return nil
function Activenpc:collide_end(node, dt)
end

---
-- Updates the Activenpc
-- dt is the amount of time in seconds since the last update
function Activenpc:update(dt)
    if self.prompt then self.prompt:update(dt) end
    self:animation():update(dt)

    --auto controls
    if self.controls==nil then
    
    else
    --manual controls
    end
    self:handleSounds(dt)
    
    self.velocity = self.velocity or {x = 0, y = 0}
    if self.pacing then
        if self.position.x < self.minimum_x then
            self.direction = "right"
        elseif self.position.x > self.maximum_x then
            self.direction = "left"
        end
        local dir = self.direction == "right" and 1 or -1
        self.velocity.x = self.pacing_velocity * dir
    end

    self.position.x = self.position.x + self.velocity.x * dt
    self.position.y = self.position.y + self.velocity.y * dt
    local x1,y1,x2,y2 = self.bb:bbox()
    self.bb:moveTo( self.position.x + (x2-x1)/2 + self.bb_offset.x,
                 self.position.y + (y2-y1)/2 + self.bb_offset.y )
end

-- plays sounds as necessary, populated by the subclass
function Activenpc:handleSounds(dt)
    self.lastSoundUpdate = self.lastSoundUpdate + dt
    for _,v in pairs(self.props.sounds) do
        if self.state==v.state and self:animation().position==v.position and self.lastSoundUpdate > 1 then
            sound.playSfx(v.file)
            self.lastSoundUpdate = 0
        end
    end
end

function Activenpc:burn()
    if self.props.burn then
        self.props.burn(self)
    end
end

return Activenpc

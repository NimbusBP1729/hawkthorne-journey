local anim8 = require 'vendor/anim8'
local Helper = require 'helper'
local game = require 'game'
local Timer = require 'vendor/timer'
local window = require 'window'

local Projectile = {}
Projectile.__index = Projectile
Projectile.projectile = true

local ProjectileImage = nil --love.graphics.newImage('images/projectile.png')

--node requires:
-- an x and y coordinate,
-- a width and height, 
-- a velocityX and velocityY,
-- properties.sheet
-- properties.animationGrid
-- properties.defaultAnimation
function Projectile.new(node, collider, map)
    local projectile = {}
    setmetatable(projectile, Projectile)
    projectile.sheet = node.properties.sheet
    --projectile.quad = love.graphics.newQuad( 0, 0, 9, 9, 18, 9 )
    projectile.foreground = node.properties.foreground
    projectile.bb = collider:addRectangle(node.x, node.y, node.width, node.height)
    projectile.bb.node = projectile
    projectile.collider = collider
    projectile.g = node.properties.animationGrid
    projectile.animation = node.properties.defaultAnimation --anim8.newAnimation('loop', g('1-2,1'), .10)
    projectile.endAnimation = node.properties.endAnimation --anim8.newAnimation('loop', g('1-2,1'), .10)
    projectile.name = node.properties.name --anim8.newAnimation('loop', g('1-2,1'), .10)

    projectile.position = { x = node.x, y = node.y }
    projectile.velocity = { x = node.properties.velocityX, y = node.properties.velocityY}
    projectile.bounceFactor = node.properties.bounceFactor
    projectile.objectFriction = node.properties.objectFriction

    if map and map.objectgroups and map.objectgroups.floor and map.objectgroups.floor.objects and map.objectgroups.floor.objects[1] and map.objectgroups.floor.objects[1].y then
        projectile.floor = map.objectgroups.floor.objects[1].y - node.height
    else
        projectile.floor = node.properties.footLocation
    end
    projectile.thrown = true
    projectile.held = false
    projectile.rebounded = false

    projectile.width = node.width
    projectile.height = node.height
    return projectile
end

function Projectile:draw()
    if self.dead then return end

    self.animation:draw(self.sheet, math.floor(self.position.x), self.position.y, 0, 1, 1)
end

-- Called when the projecile begins colliding with another node
-- @return nil
function Projectile:collide(node, dt, mtv_x, mtv_y)
    if node.character then return end
    if not node then return end
    if node.die then
        node:die(self.damage)
        self.dead = true
        self.collider:setGhost(self.bb)
        self.animation = self.endAnimation
    end
    
    if math.abs(self.velocity.x) < 5 then
        self.velocity.x = 0
    end
    if math.abs(self.velocity.y) < 5 then
        self.velocity.y = 0
    end
    
    local projCenterX = self.position.x + self.width/2
    local projCenterY = self.position.y + self.height/2
    if projCenterY >  self.floor and node.floorspace then
        self:bounceVertical()
    elseif node.verticalBounce and node.horizontalBounce then
        self:bounceHorizontal()
    elseif node.isPlatform then
        local velX,velY
        velX,velY = Projectile.getPlatformBounceVelocity(self,node)
        self.velocity.x = velX--*self.objectFriction
        self.velocity.y = velY--*self.bounceFactor
    elseif node.horizontalBounce then
        self:bounceHorizontal()
    elseif node.verticalBounce then
        self:bounceVertical()
    end

end

--
function Projectile.getPlatformBounceVelocity(projectile,platform)
    local projPosition = projectile.position

    local bb = platform.bb
    local dists = {}
    
    --find out which segment you were closest to
    if bb._type == 'polygon' then
        local v = bb._polygon.vertices
        for i = 2,#v do
            dists[i-1]=distToSegment(projPosition, v[i-1], v[i])
        end
        if #v > 1 then
            dists[#v]=distToSegment(projPosition, v[#v], v[1])
        end

        local minValue = math.huge
        local minValueKey = nil
        for key,value in pairs(dists) do
            if value < minValue then
                minValue = value
                minValueKey = key
            end
        end

        print(#v)
        print(minValueKey)
        print(minValue)
        print(v[minValueKey])
        print(v[minValueKey].x)
        print(v[minValueKey].y)
        print(projectile.velocity)
        print(projectile.velocity.x)
        print(projectile.velocity.y)
        print()

        projectile.velocity.x = projectile.velocity.x or 0
        projectile.velocity.y = projectile.velocity.y or 0
        
        local velX = (v[minValueKey].x-v[(minValueKey)%(#v)+1].x)-projectile.velocity.x
        local velY = (v[minValueKey].y-v[(minValueKey)%(#v)+1].y)-projectile.velocity.y
        velX = -velX*projectile.objectFriction
        velY = velY*projectile.bounceFactor
        return velX,velY
    end
end

function sqr(x)  
    return x * x  
end

function dist2(v, w) 
    return sqr(v.x - w.x) + sqr(v.y - w.y)
end

function distToSegmentSquared(p, v, w) 
  local l2 = dist2(v, w)
  if (l2 == 0) then return dist2(p, v) end
  local t = ((p.x - v.x) * (w.x - v.x) + (p.y - v.y) * (w.y - v.y)) / l2
  if (t < 0) then return dist2(p, v) end
  if (t > 1) then return dist2(p, w) end
  local segment = { x = v.x + t * (w.x - v.x),
                    y = v.y + t * (w.y - v.y) }
  return dist2(p, segment)
end
function distToSegment(p, v, w) 
 return math.sqrt(distToSegmentSquared(p, v, w))
 end



function Projectile:collide_end(node, dt)
    if node and node.character then
        node:cancelHoldable(self)
    end
end

function Projectile:updateOld(dt, player)
    if self.animation.status == 'finished' then
        self.dead = true
        self.collider:setGhost(self.bb)
    end

    if self.dead then return end
    
    if self.held and player.currently_held == self then
        self.position.x = math.floor(player.position.x) + player.offset_hand_right[1] + (self.width / 2) + 15
        self.position.y = math.floor(player.position.y) + player.offset_hand_right[2] - self.height + 2
        if player.offset_hand_right[1] == 0 then
            print(string.format("Need hand offset for %dx%d", player.frame[1], player.frame[2]))
        end
        self:moveBoundingBox()
    end

    if self.thrown then

        self.animation:update(dt)

        if self.velocity.x < 0 then
            self.velocity.x = math.min(self.velocity.x + self.objectFriction * dt, 0)
        else
            self.velocity.x = math.max(self.velocity.x - self.objectFriction * dt, 0)
        end

        self.velocity.y = self.velocity.y + game.gravity * dt

        if self.velocity.y > game.max_y then
            self.velocity.y = game.max_y
        end
    
        self.position.x = self.position.x + self.velocity.x * dt
        self.position.y = self.position.y + self.velocity.y * dt

        if self.position.x < 0 then
            self.position.x = 0
            self.rebounded = false
            self.velocity.x = -self.velocity.x
        end

        if self.position.x + self.width > window.width then
            self.position.x = window.width - self.width
            self.rebounded = false
            self.velocity.x = -self.velocity.x
        end

        if self.thrown and self.position.y >= self.floor then
            self.rebounded = false
            if self.velocity.y < 25 then
                --stop bounce
                self.velocity.y = 0
                self.position.y = self.floor
                self.thrown = false
            else
                --bounce 
                self.position.y = self.floor
                self.velocity.y = -.8 * math.abs( self.velocity.y )
            end
        end
    
    end
    
    self:moveBoundingBox()
end




function Projectile:update(dt, player)
    if self.animation.status == 'finished' then
        self.dead = true
        self.collider:setGhost(self.bb)
    end

    if self.dead then return end
    
    if self.held and player.currently_held == self then
        self.position.x = math.floor(player.position.x) + player.offset_hand_right[1] + (self.width / 2) + 15
        self.position.y = math.floor(player.position.y) + player.offset_hand_right[2] - self.height + 2
        if player.offset_hand_right[1] == 0 then
            print(string.format("Need hand offset for %dx%d", player.frame[1], player.frame[2]))
        end
        self:moveBoundingBox()
    end

    if self.thrown then

        self.animation:update(dt)
        
        --update position
        self.position.x = self.position.x or 0
        self.position.y = self.position.y or 0
        self.velocity.x = self.velocity.x or 0
        self.velocity.y = self.velocity.y or 0
        self.position.x = self.position.x + self.velocity.x * dt
        self.position.y = self.position.y + self.velocity.y * dt
        
        --clip bounds
        if self.position.x < 0 then
            self.position.x = 0
            self:bounceHorizontal()
        end
        
        --limit annoying rolls
        if math.abs(self.velocity.x-5)<0 then
            self.velocity.x = 0
        end
        
        --update speed
        if self.velocity.x < 0 then
            self.velocity.x = math.min(self.velocity.x + game.airaccel/10 * dt, 0)
        else
            self.velocity.x = math.max(self.velocity.x - game.airaccel/10 * dt, 0)
        end
        self.velocity.y = self.velocity.y + game.gravity*dt
        
    end
    
    self:moveBoundingBox()
    
end

function Projectile:moveBoundingBox()
    Helper.moveBoundingBox(self)
end

function Projectile:pickup(player)
    self.held = true
    self.thrown = false
    self.velocity.y = 0
    self.velocity.x = 0
end

function Projectile:bounceVertical()
    if 0 < self.velocity.y and self.velocity.y<5 then
        self.velocity.y = 0
    end

    self.velocity.y = -self.velocity.y * self.bounceFactor
    self.velocity.x = self.velocity.x * self.objectFriction

end

function Projectile:bounceHorizontal()

    self.velocity.y = self.velocity.y * self.objectFriction
    self.velocity.x = -self.velocity.x * self.bounceFactor

end

function Projectile:throw(player)
    self.held = false
    self.thrown = true
    if player.direction == "left" then
        self.velocity.x = -self.velocity.x + player.velocity.x
    else
        self.velocity.x = self.velocity.x + player.velocity.x
    end
    
    Timer.add(5, function() self.animation = self.endAnimation end)

end

function Projectile:throw_vertical(player)
    self.held = false
    self.thrown = true
    self.velocity.x = player.velocity.x
    self.velocity.y = -800
end

function Projectile:drop(player)
    self.held = false
    self.thrown = true
    self.velocity.x = ( ( ( player.direction == "left" ) and -1 or 1 ) * 50 ) + player.velocity.x
    self.velocity.y = 0
end

---
-- Gets the current acceleration speed
-- @return Number the acceleration to apply
function Projectile:accel()
    if self.velocity.y < 0 then
        return game.airaccel
    else
        return game.accel
    end
end

---
-- Gets the current deceleration speed
-- @return Number the deceleration to apply
function Projectile:deccel()
    if self.velocity.y < 0 then
        return game.airaccel
    else
        return game.deccel
    end
end

function Projectile:rebound( x_change, y_change )
    if not self.rebounded then
        if x_change then
            self.velocity.x = -( self.velocity.x / 2 )
        end
        if y_change then
            self.velocity.y = -self.velocity.y
        end
        self.rebounded = true
    end
end


return Projectile


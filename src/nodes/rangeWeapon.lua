-----------------------------------------------
-- rangeWeapon.lua
-- Represents a ranged weapon with which a player can throw something
---- throwable (like throwing knives, bombs, torch?): 
--- Methodology:
----Let x be the name of the weapon:
----xItem.lua represents the item in the inventory
----x.lua represents the item as a node,
---- this subclasses Weapon.lua in order to draw it
----x_action.png is the image sheet that houses all frames of weapon x
----Note:
---- the only action that should play once is the animation for wielding your weapon
-- Created by NimbusBP1729

--must have a createNewProjectile() method in the subclass

local game = require 'game'
local GS = require 'vendor/gamestate'

local RangeWeapon = {}
RangeWeapon.__index = RangeWeapon
RangeWeapon.isRangeWeapon = true

--launch a projectile
function RangeWeapon:wield()
    if self.item.quantity < 1 then 
        self:unuse()
        return
    end
    self.item.quantity = self.item.quantity - 1

    local projectile = self:createNewProjectile()
    table.insert(GS.currentState().nodes, projectile)
    
    if self.swingAudioClip then
        sound.playSfx( self.swingAudioClip )
    end
end

--override generic collide to do nothing
function RangeWeapon:collide(node, dt, mtv_x, mtv_y)
    if not node then return end
    
    if node.character then
        self.touchedPlayer = node
        return
    end
    
    if self.dropping and (node.isFloor or node.floorspace or node.isPlatform) then
        self.dropping = false
    end
end

function RangeWeapon:draw()
    if self.dead then return end
    
    if not self.player then
        local animation = self.animation
        animation:draw(self.sheet, math.floor(self.position.x), self.position.y, 0, 1, 1)
        return
    end

    local scalex = 1
    if self.player.direction=='left' then
        scalex = -1
    end
    local animation = self.animation
    animation:draw(self.sheet, math.floor(self.position.x), self.position.y, 0, scalex, 1)
end

return RangeWeapon
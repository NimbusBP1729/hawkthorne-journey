-----------------------------------------------------------------------
-- inventory.lua
-- Manages the players currently held objects
-- Created by HazardousPeach
-----------------------------------------------------------------------

local controls = require 'controls'
local anim8 = require 'vendor/anim8'
-- local sound = require 'vendor/TEsound'
local camera = require 'camera'
-- local debugger = require 'debugger'

--The crafting recipes (for example stick+rock=knife)
-- local recipes = require 'items/recipes'
-- local Item = require 'items/item'

local Inventory = {}
Inventory.__index = Inventory

--Load in all the sprites we're going to be using.
local sprite = love.graphics.newImage('images/inventory/inventory.png')
local scrollSprite = love.graphics.newImage('images/inventory/scrollbar.png')
local selectionSprite = love.graphics.newImage('images/inventory/selection.png')
local curWeaponSelect = love.graphics.newImage('images/inventory/selectedweapon.png')
local craftingAnnexSprite = love.graphics.newImage('images/inventory/craftingannex.png')
craftingAnnexSprite:setFilter('nearest', 'nearest')
sprite:setFilter('nearest', 'nearest')
scrollSprite:setFilter('nearest','nearest')

--The animation grids for different animations.
local g = anim8.newGrid(100, 105, sprite:getWidth(), sprite:getHeight())
local scrollG = anim8.newGrid(5,40, scrollSprite:getWidth(), scrollSprite:getHeight())
local craftingG = anim8.newGrid(75, 29, craftingAnnexSprite:getWidth(), craftingAnnexSprite:getHeight())

---
-- Creates a new inventory
-- @return inventory
function Inventory.new( player )
    local inventory = {}
    setmetatable(inventory, Inventory)
    
    inventory.player = player

    --These variables keep track of whether the inventory is open, and whether the crafting annex is open.
    inventory.visible = false
    inventory.craftingVisible = false

    --These variables keep track of whether certain keys were down the last time we checked. This is neccessary to only do actions once when the player presses something.
    inventory.openKeyWasDown = false
    inventory.rightKeyWasDown = false
    inventory.leftKeyWasDown = false
    inventory.upKeyWasDown = false
    inventory.downKeyWasDown = false
    inventory.selectKeyWasDown = false

    inventory.pages = {} --These are the pages in the inventory that hold items
    for i=0, 3 do
        inventory.pages[i] = {}
    end
    inventory.pageNames = {'Weapons', 'Blocks', 'Materials', 'Potions'}
    inventory.pageIndexes = {weapons = 0, blocks = 1, materials = 2, potions = 3}
    inventory.cursorPos = {x=0,y=0} --The position of the cursor.
    inventory.selectedWeaponIndex = 0 --The index of the item on the weapons page that is selected as the current weapon.

    inventory.state = 'closed' --The current state of the crafting box.

    --These are all the different states of the crafting box and their respective animations.
    inventory.animations = {
        opening = anim8.newAnimation('once', g('1-5,1'),0.05), --The box is currently opening
        openWeapons = anim8.newAnimation('once', g('6,1'), 1), --The box is open, and on the weapons page.
        openBlocks = anim8.newAnimation('once', g('7,1'), 1), --The box is open, and on the blocks page.
        openMaterials = anim8.newAnimation('once', g('8,1'), 1), --The box is open, and on the materials page.
        openPotions = anim8.newAnimation('once', g('9,1'), 1), --The box is open, and on the potions page.
        closing = anim8.newAnimation('once', g('1-5,1'),0.02), --The box is currently closing.
        closed = anim8.newAnimation('once', g('1,1'),1) --The box is fully closed. Strictly speaking, this animation is not necessary as the box is invisible when in this state.
    }
    inventory.animations['closing'].direction = -1 --Sort of a hack, these two lines allow the closing animation to be the same as the opening animation, but reversed.
    inventory.animations['closing'].position = 5

    inventory.scrollAnimations = {
        anim8.newAnimation('once', scrollG('1,1'),1),
        anim8.newAnimation('once', scrollG('2,1'),1),
        anim8.newAnimation('once', scrollG('3,1'),1),
        anim8.newAnimation('once', scrollG('4,1'),1)
    } --The animations for the scroll bar.

    inventory.scrollbar = 1
    inventory.pageLength = 13

    --This is all pretty much identical to the cooresponding lines for the main inventory, but applies to the crafting annex.
    inventory.craftingState = 'closing'
    inventory.craftingAnimations = {
        opening = anim8.newAnimation('once', craftingG('1-6,1'),0.04),
        open = anim8.newAnimation('once', craftingG('6,1'), 1),
        closing = anim8.newAnimation('once', craftingG('1-6,1'),0.01)
    }
    inventory.craftingAnimations['closing'].direction = -1
    inventory.craftingAnimations['closing'].position = 6
    inventory.currentIngredients = {a = -1, b = -1} --The indices of the current ingredients. -1 indicates no ingredient

    return inventory
end

---
-- Returns the inventorys animation
-- @return animation
function Inventory:animation()
    assert(self.animations[self.state] ~= nil, "State " .. self.state .. " does not have a coorisponding animation!")
    return self.animations[self.state]
end

---
-- Returns the crafting annex's animation
-- @return the crafting annex's animation
function Inventory:craftingAnimation()
    return self.craftingAnimations[self.craftingState]
end

---
-- Draws the inventory to the screen
-- @param playerPosition the coordinates to draw offset from
-- @return nil
function Inventory:draw(playerPosition)
    if not self.visible then return end

    --The default position of the inventory
    local pos = {x=playerPosition.x - (g.frameWidth + 6),y=playerPosition.y - (g.frameHeight - 22)}

    --If the default position would result in our left side being off the map, move to the right side of the player
    if pos.x < 0 then
        pos.x = playerPosition.x + --[[width of player--]] 48 + 6
    end

    --If the inventory would be drawn underneath the HUD then lower the vertical position.
    local hud_right = camera.x + 130
    local hud_top = camera.y + 60
    if pos.x < hud_right and pos.y < hud_top then
        pos.y = hud_top
    end
    
    --If the default y position would result in our top being above the map, move us down until we are on the map
    if pos.y < 0 then pos.y = 0 end
    
    --Now, draw the main body of the inventory screen
    self:animation():draw(sprite, pos.x, pos.y)
    
    --Only draw the rest of this if the inventory is fully open, and not currently opening.
    if (self:isOpen()) then

       --Draw the crafting annex, if it's open
       if self.craftingVisible then
           self:craftingAnimation():draw(craftingAnnexSprite, pos.x + 97, pos.y + 42)
       end
        
        --Draw the scroll bar
        self.scrollAnimations[self.scrollbar]:draw(scrollSprite, pos.x + 8, pos.y + 43)

        --Stands for first frame position, indicates the position of the first item slot (top left) on screen
        local ffPos = {x=pos.x + 29,y=pos.y + 30} 

        --Draw the white border around the currently selected slot
        if self.cursorPos.x < 2 then --If the cursor is in the main inventory section, draw this way
            love.graphics.drawq(selectionSprite, 
                love.graphics.newQuad(0,0,selectionSprite:getWidth(),selectionSprite:getHeight(),selectionSprite:getWidth(),selectionSprite:getHeight()),
                ffPos.x + self.cursorPos.x * 38, ffPos.y + self.cursorPos.y * 18)
        else --Otherwise, we're in the crafting annex, so draw this way.
            love.graphics.drawq(selectionSprite,
                love.graphics.newQuad(0,0,selectionSprite:getWidth(), selectionSprite:getHeight(), selectionSprite:getWidth(), selectionSprite:getHeight()),
                ffPos.x + (self.cursorPos.x - 3) * 19 + 101, ffPos.y + 18)
        end

        --Draw all the items in their respective slots
        for i=0,7 do
            local scrollIndex = i + ((self.scrollbar - 1) * 2)
            local indexDisplay = scrollIndex
            if self:currentPage()[scrollIndex] ~= nil then
                local slotPos = self:slotPosition(i)
                local item = self:currentPage()[scrollIndex]
                if not debugger.on then indexDisplay = nil end
                if self.currentIngredients.a ~= scrollIndex and self.currentIngredients.b ~= scrollIndex then
                    if not debugger.on then indexDisplay = nil end
                    item:draw({x=slotPos.x+ffPos.x,y=slotPos.y + ffPos.y}, indexDisplay)
                end
            end
        end

        --Draw the crafting window
        if self.craftingVisible then
            if self.currentIngredients.a ~= -1 then
                local indexDisplay = self.currentIngredients.a
                if not debugger.on then indexDisplay = nil end
                local item = self:currentPage()[self.currentIngredients.a]
                item:draw({x=ffPos.x + 102,y= ffPos.y + 19}, indexDisplay)
            end
            if self.currentIngredients.b ~= -1 then
                local indexDisplay = self.currentIngredients.b
                if not debugger.on then indexDisplay = nil end
                local item = self:currentPage()[self.currentIngredients.b]
                item:draw({x=ffPos.x + 121,y= ffPos.y + 19}, indexDisplay)
            end
            --Draw the result of a valid recipe
            if self.currentIngredients.a ~= -1 and self.currentIngredients.b ~= -1 then
                local result = self:findResult(self:currentPage()[self.currentIngredients.a], self:currentPage()[self.currentIngredients.b])
                if result ~= nil then
                    local resultFolder = string.lower(result.type)..'s'
                    local itemNode = require ('items/' .. resultFolder .. '/' .. result.name)
                    local item = Item.new(itemNode)
                    item:draw({x=ffPos.x + 83, y=ffPos.y + 19}, nil)
                end
            end
        end


        --If we're on the weapons screen, then draw a green border around the currently selected index, unless it's out of view.
        if self.state == 'openWeapons' then
            local lowestVisibleIndex = (self.scrollbar - 1 )* 2
            local weaponPosition = self.selectedWeaponIndex - lowestVisibleIndex
            if self.selectedWeaponIndex >= lowestVisibleIndex and self.selectedWeaponIndex < lowestVisibleIndex + 8 then
                love.graphics.drawq(curWeaponSelect,
                    love.graphics.newQuad(0,0, curWeaponSelect:getWidth(), curWeaponSelect:getHeight(), curWeaponSelect:getWidth(), curWeaponSelect:getHeight()),
                    self:slotPosition(weaponPosition).x + ffPos.x - 2, self:slotPosition(weaponPosition).y + ffPos.y - 2)
            end
        end


    end
end

---

return Inventory

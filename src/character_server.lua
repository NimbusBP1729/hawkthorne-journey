local anim8 = require 'vendor/anim8'
local Timer = require 'vendor/timer'

local characters = {}
local Character = {}
Character.__index = Character
Character.characters = characters

Character.name = 'abed'
Character.costume = 'base'

Character.warpin = false

function Character:reset()
    self.state = 'idle'
    self.direction = 'right'
end

function Character:setCharacter( name )
    if character == self.name then return end

    if self.characters[name] then
        self.name = name
        self.costume = 'base'
        return
    end

    error( "Invalid character ( " .. name .. " ) requested!" )
end

function Character:setCostume( costume )
    if costume == self.costume then return end
    
    for _,c in pairs( self:current().costumes ) do
        if c.sheet == costume then
            self.costume = costume
            return
        end
    end
    
    error( "Undefined costume ( " .. costume .. " ) requested for character ( " .. self.name .. " )" )
end

function Character:current()
    return self.characters[self.name]
end

function Character:sheet()
    return self:getSheet( self.name, self.costume )
end

function Character:getSheet(char,costume)
    if not self.characters[char].sheets[costume] then
        self.characters[char].sheets[costume] = love.graphics.newImage( 'images/characters/' .. char .. '/' .. costume .. '.png')
        self.characters[char].sheets[costume]:setFilter('nearest', 'nearest')
    end
    return self.characters[char].sheets[costume]
end

function Character:updateAnimation(dt)
    self:animation():update(dt)
end

function Character:animation()
    return self.characters[self.name].animations[self.state][self.direction]
end

function Character:warpUpdate(dt)
    self:current().animations.warp:update(dt)
end

function Character:respawn()
    self.warpin = true
    self:current().animations.warp:gotoFrame(1)
    self:current().animations.warp:resume()
    -- sound.playSfx( "respawn" )
    Timer.add(0.30, function() self.warpin = false end)
end

function Character:draw()
end

function Character:getCategory()
    return self:current().costumemap[ self.costume ].category
end

function Character:findRelatedCostume( char )
    --returns the requested character's costume that is most similar to the current character
    local costumes = self.characters[ char ].categorytocostumes[ self:getCategory() ]
    if costumes then return costumes[math.random(#costumes)].sheet end
    return 'base'
end

Character:reset()

function Character.new()
    local character = {}
    setmetatable(character, Character)
    return character
end

return Character
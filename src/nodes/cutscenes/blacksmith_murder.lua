local tween = require 'vendor/tween'

local Projectile = require "nodes/projectile"
local Sprite = require "nodes/sprite"
local camera = require "camera"
local sound = require "vendor/TEsound"
local Manualcontrols = require "manualcontrols"
local Weapon = require 'nodes/weapon'

local Script =  {}
Script.__index = Script
Script.isScript = true
function Script.new(scene,player,level)
    assert(scene)
    assert(player)
    assert(player.isPlayer)
    assert(level)
    assert(level.isLevel)

    
    --initialize NPC
    scene.nodes = scene.nodes or {}
    for k,v in pairs(level.nodes) do
        if v.isActivenpc then
            scene.nodes[v.node.name] = v
        end
    end
    
    --initialize player's clone
    
    --assert(level.isLevel,level.name or '<nil>'.." may be a gamestate, but not a bona fide level")
    script = {
    {line = "",
    
    precondition = function()
        player.freeze = false
        player.controls = Manualcontrols.new()
    end,
    action = function()
        scene:moveCharacter(430,nil,player)
    end},
    {line = player.character.name..": What's free?",

    precondition = function()
        scene:teleportCharacter(430,nil,player)
    end,
    action = function()
        scene:jumpCharacter(player)
        local weaponNode = {
            type = "weapon",name = "torch",
            x = player.position.x,
            y = player.position.y,
            width = 24, height = 24,
            properties = {}
        }
        local weapon = Weapon.new(weaponNode,level.collider)
        level:addNode(weapon)
        weapon:keypressed('INTERACT',player)
        
        local node = { x = player.position.x, y = player.position.y,
            properties = {
                sheet = 'images/torch.png',
                height = 48, width = 24,
                animation = '1-4,1',
                doRotation = 'true',
            }
        }
        scene.nodes.torch = Sprite.new(node, collider)

    end},
    {line = "H",

    precondition = function()
        scene:teleportCharacter(430,nil,player)
        scene:jumpCharacter(player)
        local weaponNode = {
            type = "weapon",name = "torch",
            x = player.position.x,
            y = player.position.y,
            width = 24, height = 24,
            properties = {}
        }
        level:addNode(Weapon.new(weaponNode,level.collider))
    end,
    action = function()
        sound.playSfx("thiefthief")
    end},
    {line = "Thief, Thief!",

    precondition = function()
        scene.nodes.blacksmith.opacity = 0
        player.character.direction = 'left'
    end,
    action = function()
        player.character.direction = 'left'
    end},
    {line = "END",

    precondition = function()
        scene.nodes.blacksmith.opacity = 0
        player.character.direction = 'left'
    end,
    action = function()
        player.character.direction = 'left'
    end},
    {line = "END",


    action = function()
    end}
    }
    return script
end

return Script
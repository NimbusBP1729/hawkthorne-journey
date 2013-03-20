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
    scene.player = player

    
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
    {line = player.character.name..": Neat! Torches are free!",

    precondition = function()
        scene:teleportCharacter(430,nil,player)
        scene:jumpCharacter(player)
    end,
    action = function()
        sound.playSfx("thiefthief")
    end},
    {line = "Thief, Thief!",

    precondition = function()
        scene:teleportCharacter(430,nil,player)
    end,
    action = function()
        scene:jumpCharacter(player)
        player.currently_held:throw()

    end},
    {line = "How do I drop it?",

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

function Script:canRun()
    local player = require('player').factory()
    return player.currently_held and player.currently_held.isFlammable
end

return Script
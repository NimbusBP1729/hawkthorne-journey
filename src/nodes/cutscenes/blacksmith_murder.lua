local tween = require 'vendor/tween'

local Projectile = require "nodes/projectile"
local Sprite = require "nodes/sprite"
local camera = require "camera"
local sound = require "vendor/TEsound"
local Manualcontrols = require "manualcontrols"

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
        player.controls = Manualcontrols.new()
        scene:teleportCharacter(440,210,player)
    end,
    action = function()
        scene:moveCharacter(340,250,scene.nodes.pierce)
    end},
    {line = player.character.name..": What's free?",

    precondition = function()
        scene:teleportCharacter(340,250,player)
    end,
    action = function()
        sound.playSfx("thiefthief")
    end},
    {line = "Thief, Thief!",

    precondition = function()
        scene.nodes.blacksmith.opacity = 0
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
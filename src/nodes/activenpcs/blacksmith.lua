local Prompt = require 'prompt'
local Timer = require 'vendor/timer'
local sound = require 'vendor/TEsound'
local Gamestate = require 'vendor/gamestate'

return {
    width = 63,
    height = 66,
    bb_offset_x = 0,
    bb_offset_y = 17,
    bb_width = 63,
    bb_height = 49,    
    animations = {
        default = {
            'loop',{'1-4,1'},0.40,
        },
        talking = {
            'loop',{'2,3','2,4'},0.20,
        },
        burning = {
            'loop',{'1-4,5'},0.20,
        }
    },
    sounds = {
        hammer = {
            state = 'default',
            position = 1,
            file = 'sword_hit',
        },
        screaming = {
            state = 'burning',
            position = 2,
            file = 'blacksmithscreaming',
        }
    },
    enter = function(activenpc)
        activenpc.state = 'talking'
        activenpc.pacing = false
        sound.playSfx("ibuyandsell")
        Timer.add(2.8,function() activenpc.state = 'default' end)
    end,
    onInteract = function(activenpc, player)
        if activenpc.state=="burning" then return end
        local options = {"YES","NO"}
        local callback = function(result)
            activenpc.prompt = nil
            player.freeze = false
            local screenshot = love.graphics.newImage( love.graphics.newScreenshot() )
            if result == "YES" then
                Gamestate.switch("shopping", player, screenshot, activenpc.name)
            end
        end
        player.freeze = true
        activenpc.prompt = Prompt.new("Would you like to make a purchase?",callback, options)
    end,
    burn = function(activenpc)
        if activenpc.state == "burning" then return end
        
        activenpc.state = "burning"
        activenpc.pacing = true
        --set up some pacing vars
        activenpc.pacing_velocity = 200
        activenpc.minimum_x = activenpc.position.x
        activenpc.maximum_x = activenpc.minimum_x + 200
    end,
    collide = function(activenpc,node)
        if node.isPlayer and activenpc.state=="burning" and 
          math.abs(activenpc.position.y+activenpc.height - node.position.y-node.height) < 20 then
            node:die(1)
        end
    end
    
}
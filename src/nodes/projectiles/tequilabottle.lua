local game = require 'game'
return{
    name = 'tequilabottle',
    type = 'projectile',
    bounceFactor = 0.2,
    friction = 1, --0.01 * game.step,
    width = 16,
    height = 16 ,
    frameWidth = 16,
    frameHeight = 16,
    handle_x = 8,
    handle_y = 8,
    --lift = 0,
    playerCanPickUp = false,
    enemyCanPickUp = true,
    velocity = { x = -230, y = 0 }, --initial vel isn't used since this is insantly picked up
    throwVelocityX = 400, 
    throwVelocityY = 0,
    stayOnScreen = false,
    damage = 1,
    idletime = 0,
    throw_sound = 'confirm',
    animations = {
        default = {'once', {'1,1'}, 1},
        thrown = {'loop', {'1,1','2,1','3,1','4,1'}, 0.05},
        finish = {'once', {'3,1'}, 1},
    },
    collide = function(node, dt, mtv_x, mtv_y,projectile)
        if not node.isPlayer then return end
        if projectile.thrown then
            node:die(projectile.damage)
        end
    end,
    update = function(dt,projectile)
        if not projectile.holder then
            projectile.props.idletime = projectile.props.idletime + dt
        else
            projectile.props.idletime = 0
        end
        if projectile.props.idletime > 5 then
            projectile:die()
        end
    end,
    leave = function(projectile)
        projectile:die()
    end,
}
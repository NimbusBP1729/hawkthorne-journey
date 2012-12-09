local Timer = require 'vendor/timer'
local sound = require 'vendor/TEsound'
local Projectile = require 'nodes/projectile'
local Gamestate = require 'vendor/gamestate'

return {
    name = 'manicorn',
    --attack_sound = 'manicorn_running',
    die_sound = 'manicorn_neigh',
    position_offset = { x = 0, y = 0 },
    height = 55,
    width = 42,
    bb_height = 55,
    bb_width = 42,
    damage = 1,
    hp = 10,
    tokens = 10,
    hand_x = 23,
    hand_y = 24,
    jumpkill = true,
    chargeUpTime = 2,
    reviveDelay = 3,
    attackDelay = 1,
    tokenTypes = { -- p is probability ceiling and this list should be sorted by it, with the last being 1
        { item = 'coin', v = 1, p = 0.9 },
        { item = 'health', v = 1, p = 1 }
    },
    animations = {
        dying = {
            right = {'once', {'5,2'}, 1},
            left = {'once', {'5,3'}, 1}
        },
        default = {
            left = {'loop', {'1-3,2'}, 0.25},
            right = {'loop', {'1-3,3'}, 0.25}
        },
        attack = {
            left = {'loop', {'1-3,2'}, 0.25},
            right = {'loop', {'1-3,3'}, 0.25}
        },
        attacktequila_start = {
            left = {'once', {'4,2'}, 1},
            right = {'once', {'4,3'}, 1}
        },
        attacktequila_charging = {
            left = {'once', {'4,2'}, 1},
            right = {'once', {'4,3'}, 1}
        },
    },
    enter = function( enemy )
        enemy.direction = math.random(2) == 1 and 'left' or 'right'
        enemy.maxx = enemy.position.x + 24
        enemy.minx = enemy.position.x - 24
    end,
    attack = function( enemy )
        Timer.add(enemy.props.attackDelay, function()
            enemy.props.attackRunning(enemy)
        end)
    end,
    attackRunning = function( enemy )
        enemy.state = 'attack'
        Timer.add(5, function() 
            if enemy.state ~= 'dying' and enemy.state ~= 'dyingattack' then
                enemy.state = 'default'
                enemy.maxx = enemy.position.x + 24
                enemy.minx = enemy.position.x - 24
            end
        end)
    end,
    attackRainbow = function( enemy )
        enemy.state = 'attacktequila_start'
        local node = require('nodes/projectiles/tequilabottle')
        node.x = enemy.position.x
        node.y = enemy.position.y
        local tequilabottle = Projectile.new( node, enemy.collider )
        tequilabottle.enemyCanPickUp = true
        table.insert(Gamestate.currentState().nodes,tequilabottle)
        --if enemy.currently_held then enemy.currently_held:throw(enemy) end
        enemy:registerHoldable(tequilabottle)
        enemy:pickup()
        --disallow any enemy from picking it up after thrown
        tequilabottle.enemyCanPickUp = false
        
    end,
    hurt = function( enemy )
        enemy.state = 'dying'
    end,
    update = function( dt, enemy, player, level )
        if enemy.state == 'dying' then return end

        if enemy.state == 'default' and math.abs(player.position.y-enemy.position.y) < 100
             and math.abs(player.position.x-enemy.position.x) < 300 then
            enemy.idletime = enemy.idletime+dt
        else
            enemy.idletime = 0
        end

        if enemy.idletime >= 2 then
            enemy.props.attackRainbow(enemy)
        end

        local offset = 5 -- distance at which the enemy sees no point in changing direction
        local too_close = false
        if enemy.state == 'attack' or string.find(enemy.state,'attacktequila') then
            if enemy.state == 'attacktequila_start' then
                if enemy.currently_held then
                    enemy.state = 'attacktequila_charging'
                    enemy.currently_held:launch(enemy)
                    Timer.add(enemy.chargeUpTime, function()
                        enemy.state = 'default'
                    end)
                end
            end
        
            if math.abs(enemy.position.x - player.position.x)<offset then
                too_close = true
            elseif enemy.position.x < player.position.x then
                enemy.direction = 'right'
            elseif enemy.position.x + enemy.props.width > player.position.x + player.width then
                enemy.direction = 'left'
            end
        else
            if enemy.position.x > enemy.maxx then
                enemy.direction = 'left'
            elseif enemy.position.x < enemy.minx then
                enemy.direction = 'right'
            end
        end
        
        local default_velocity = 20
        local rage_velocity =  40

        local my_velocity
        if too_close then
            my_velocity = 0
        elseif enemy.state == 'attack' then
            my_velocity = rage_velocity
        elseif string.find(enemy.state,'attacktequila') then
            my_velocity = 0
        else
            my_velocity = default_velocity
        end

        if enemy.direction == 'left' then
            enemy.velocity.x = my_velocity
        else
            enemy.velocity.x = -my_velocity
        end

    end

}
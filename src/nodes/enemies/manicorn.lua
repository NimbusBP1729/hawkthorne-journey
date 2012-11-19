local Timer = require 'vendor/timer'
local sound = require 'vendor/TEsound'

return {
    name = 'manicorn',
    --hit_sound = 'manicorn_growl',
    --die_sound = 'manicorn_crush',
    position_offset = { x = 0, y = 4 },
    height = 48,
    width = 48,
    damage = 1,
    hp = 10,
    tokens = 10,
    jumpkill = false,
    tokenTypes = { -- p is probability ceiling and this list should be sorted by it, with the last being 1
        { item = 'coin', v = 1, p = 0.9 },
        { item = 'health', v = 1, p = 1 }
    },
    animations = {
        dying = {
            right = {'once', {'2,3'}, 0.25},
            left = {'once', {'2,3'}, 0.25}
        },
        default = {
            left = {'loop', {'5-2,2'}, 0.25},
            right = {'loop', {'1-2,7'}, 0.25}
        },
        attack = {
            left = {'loop', {'2-5,1'}, 0.25},
            right = {'loop', {'4-1,6'}, 0.25}
        },
        dyingattack = {
            left = {'once', {'4,8'}, 0.25},
            right = {'once', {'2,4'}, 0.25}
        }
    },
    enter = function( enemy )
        enemy.direction = math.random(2) == 1 and 'left' or 'right'
        enemy.maxx = enemy.position.x + 24
        enemy.minx = enemy.position.x - 24
    end,
    attack = function( enemy )
    
        local r = math.random()
        if true then
            enemy.props.attackRunning(enemy)
        else
            enemy.props.attackRainbow(enemy)
        end
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
        enemy.state = 'attack'
        Timer.add(5, function() 
            if enemy.state ~= 'dying' and enemy.state ~= 'dyingattack' then
                enemy.state = 'default'
                enemy.maxx = enemy.position.x + 24
                enemy.minx = enemy.position.x - 24
            end
        end)
    end,
    die = function( enemy )
        if enemy.state == 'attack' then
            enemy.state = 'dyingattack'
        else
            enemy.state = 'dying'
        end
    end,
    update = function( dt, enemy, player, level )
        if enemy.state == 'dyingattack' then return end

        local offset = 5
        local too_close = false
        if enemy.state == 'attack' then
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
        local rage_velocity = 80

        local my_velocity
        if too_close then
            my_velocity = 0
        elseif enemy.state == 'attack' then
            my_velocity = rage_velocity
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
local socket = require "socket"
require 'vendor/lube'

local Player = require 'player_server'
local Level = require 'level_server'

-- begin
local udp = socket.udp()

-- normally socket reads block until they have data, or a
-- certain amount of time passes.
-- that doesn't suit us, so we tell it not to do that by setting the 
-- 'timeout' to zero
udp:settimeout(0)

-- unlike the client, the server has to be specific about where its
-- 'bound', or the poor clients will never find it.
-- thus while we can happily let the client auto-bind to whatever it likes,
-- we have to tell the server to bind to something known.
-- 
-- the first part is which "interface" we should bind to...a bit beyond this tutorial, but '*' basically means "all of them"
-- port is simpler, the system maintains a list of up to 65535 (!) "ports"
-- ...really just numbers. point is that if you send to a particular port, 
-- then only things "listening" to that port will be able to receive it, 
-- and likewise you can only read data sent to ports you are listening too.
-- generally speaking, if an address is which machine you want to talk to, then a port is what program on that machine you want to talk to.
--
-- [NOTE: on some operating systems, ports between 0 and 1024 are "reserved for 
-- privileged processes". its a security precaution for those system.
-- generally speaking, just not using ports in that range avoids a lot of problems]
udp:setsockname('*', 12345)

local world = {}   -- world[level_name] = {obj1,obj2}
local players = {} -- players[player_id] = player
local levels = {}  -- levels[level_name] = level

-- We declare a whole bunch of local variables that we'll be using the in 
-- main server loop below. you probably recognise some of them from the
--client example, but you are also probably wondering what's with the fruity
-- names, 'msg_or_ip'? 'port_or_nil'?
-- 
-- well, we're using a slightly different function this time, you'll see when we get there.
local data, msg_or_ip, port_or_nil
local entity, cmd, parms
local update_ticker = 0
local last_update = os.time()
local dt = 0
-- indefinite loops are probably not something you used to if you only 
-- know love, but they are quite common. and in fact love has one at its
-- heart, you just don't see it.
-- regardless, we'll be needing one for our server. and this little
-- variable lets us *stop* it :3
local running = true

-- the beginning of the loop proper...
print "Beginning hawkthorne server loop."
while running do
    -- this line looks familiar, I'm sure, but we're using 'receivefrom'
    -- this time. its similar to receive, but returns the data, sender's
    -- ip address, and the sender's port. (which you'll hopefully recognise
    -- as the two things we need to send messages to someone)
    -- we didn't have to do this in the client example because we just bound
    -- the socket to the server. ...but that also ignores messages from
    -- sources other than what we've bound to, which obviously won't do at
    -- all as a server.
    dt = os.time() - last_update
    last_update = os.time()
    
    --gotta fix this eventually so that each level gets their correct dt
    for level_name,level in pairs(levels) do
        level:update(dt)
    end
    
    --
    -- [NOTE: strictly, we could have just used receivefrom (and its 
    -- counterpart, sendto) in the client. there's nothing special about the
    -- functions to prevent it, indeed. send/receive are just convenience
    -- functions, sendto/receive from are the real workers.]
    data, msg_or_ip, port_or_nil = udp:receivefrom()
    if data then
        -- more of these funky match patterns!
        entity, cmd, parms = data:match("^(%S*) (%S*) (.*)")
        if cmd == 'keypressed' then
            local button = parms:match("^(%S*)")
            local level = players[entity].level
            local player = players[entity]
            level:keypressed( button, player)
            player.key_down[button] = true
        elseif cmd == 'keyreleased' then
            local button = parms:match("^(%S*)")
            local level = players[entity].level
            local player = players[entity]
            level:keyreleased( button, player)
            player.key_down[button] = false
        elseif cmd == 'keydown' then
            -- local button = parms:match("^(%S*)")
            -- local level = players[entity].level
            -- local player = players[entity]
        elseif cmd == 'update' then
            local level = parms:match("^(%S*)")
            levels[level] = levels[level] or Level.new(level)
            --update objects for client(s)
            for i, node in pairs(world[level]) do
                if node.paint then
                    local objectBundle  = {level = level,x = node.position.x,y = node.position.y,
                                     state = state,position = node.animation and node:animation().position,
                                     direction = node.direction}
                    udp:sendto(string.format("%s %s %s", i, 'updateObject', lube.bin:pack_node(objectBundle)), msg_or_ip,  port_or_nil)
                end
            end
            udp:sendto(string.format("%s %s %s %s", i, 'at', level, lube.bin:pack_node(node)), msg_or_ip,  port_or_nil)
            for i, plyr in pairs(players) do
                    local playerBundle  = {level = plyr.level,x = plyr.position.x,y = plyr.position.y,
                                          state =plyr.character.state,position = plyr.character:animation().position,
                                          direction = plyr.character.direction}
                udp:sendto(string.format("%s %s %s", i, 'updatePlayer', playerBundle), msg_or_ip,  port_or_nil)
            end
            --update players for client(s)
       elseif cmd == 'register' then
            print("registering a new player:", entity)
            print("msg_or_ip:", msg_or_ip)
            print("port_or_nil:", port_or_nil)
            players[entity] = Player.new()
        elseif cmd == 'unregister' then
            print("unregistering a player:", entity)
            print("msg_or_ip:", msg_or_ip)
            print("port_or_nil:", port_or_nil)
            players[entity] = nil
        elseif cmd == 'quit' then
            running = false;
        else
            print("unrecognized command:'", cmd,"'")
            print()
        end
    elseif msg_or_ip ~= 'timeout' then
        error("Unknown network error: "..tostring(msg))
    end
    
    socket.sleep(0.01)
end

print "Thank you."

-- and that the end of the udp server example.
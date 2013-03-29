local anim8 = require 'vendor/anim8'
local gamestate = require 'vendor/gamestate'
local tween = require 'vendor/tween'
local sound = require 'vendor/TEsound'
local Timer = require 'vendor/timer'
local Manualcontrols = require 'manualcontrols'
local Projectile = require 'nodes/projectile'
local Sprite = require 'nodes/sprite'

local camera = require 'camera'
local dialog = require 'dialog'
local Player = require 'player'

local Scene = {}

Scene.__index = Scene

local function nametable(layer, collider)
  local names = {}
  for i,v in pairs(layer.objects) do
    if v.type == "character" then
        local plyr = Player.factory(collider, v.name)
        plyr.controls = Manualcontrols.new()
        plyr.position = {x = v.x, y = v.y}
        names[v.name] = plyr
     else
        names[v.name] = v
    end
  end
  return names
end

local function center(node)
  return node.position.x + node.width / 2, node.position.y + node.height / 2
end


function Scene.new(node, collider, layer, level)
  local scene = {}
  setmetatable(scene, Scene)
  assert(level)
  assert(level.isLevel)
  scene.x = node.x
  scene.y = node.y
  scene.level = level
  scene.finished = false

  scene.layer = layer
  scene.collider = collider
  scene.node = node
  
  local player = Player.factory()
  
  -- dummy camera to prevent tearing
  scene.camera = {
    tx = 0,
    ty = 0,
    sx = 1,
    sy = 1,
  }
  scene.nodes = nametable(layer, collider)
  
  scene.props = require("nodes/cutscenes/"..node.properties.cutscene)
  scene.script = scene.props.new(scene,player,level)
  return scene
end

function Scene:runScript(script,depth)
    depth = depth or 1
    local line = script[depth]["line"]
    local action = script[depth]["action"]
    
    local function __NULL__() end
    local precondition = script[depth]["precondition"] or __NULL__
    local postcondition = script[depth]["postcondition"] or __NULL__

    local size = #script
    local dial
    --precondition()
    if(depth==size) then
      dial = dialog.new(line,function ()
        precondition()
        action()
        player = player or Player.factory()
        self.finished = true
        self:endScene(player)
      end)
    else
      dial = dialog.new(line,function()
        precondition()
        action()
        self:runScript(script,depth+1)
      end)
    end
    postcondition()
    return dial
end

function Scene:start(player)
  local player = Player.factory()
  self.nodes.player = player
  self.opacity = self.node.properties.opacity or 255
  
  self.origControls = player.controls


  --local cx, cy = 
  player = player or Player.factory()
  player.freeze = true
  player.opacity = 255
  player.events:poll('jump')
  player.events:poll('halfjump')
  player.controlState:cutscene()
  
  
  player.controls = Manualcontrols.new()


  if self.nodes[player.character.name] then
    self.nodes[player.character.name].character.costume = player.character.costume
    self.nodes[player.character.name].opacity = 0
    tween(2,player.position,
          {x = self.nodes[player.character.name].position.x, 
           y = self.nodes[player.character.name].position.y},
          'outQuad',
          function()
               player.opacity = 0
               self.nodes[player.character.name].opacity = 255
          end)
  end
  player.character.state = player.idle_state
  player.invulnerable = true
  local current = gamestate.currentState()
  self.camera.tx = camera.x
  self.camera.ty = camera.y
  self.camera.sx = camera.scaleX
  self.camera.sy = camera.scaleY

  current.darken = {0, 0, 0, 0}

  tween(2, current.darken, {0, 0, 0, 0}, 'outQuad')

  self:runScript(self.script,nil)

end


function Scene:update(dt, player)
  --call setPosition manually to prevent tearing
  camera:setPosition(self.camera.tx, self.camera.ty)
  camera:setScale(self.camera.sx, self.camera.sy)
  for k,v in pairs(self.nodes) do
    if v.isPlayer then
      v.boundary = player.boundary
    end
    --don't reupdate nodes that are managed by the level
    if not self.level:hasNode(v) then
      v:update(dt)
    end
  end

end

function Scene:draw()
  love.graphics.setColor(255, 255, 255, 255)
  for k,v in pairs(self.nodes) do
    --don't redraw nodes that are managed by the level
    if not self.level:hasNode(v) then
      v:draw()
    end
  end
  love.graphics.setColor(255, 255, 255, 255)
end

function Scene:keypressed(button)
end

function Scene:talkCharacter(char,message)
end

--makes a manually-controlled character jump
function Scene:jumpCharacter(char)
    self:keypressedCharacter('JUMP',char)
    Timer.add(0.4,function()
        self:keyreleasedCharacter('JUMP',char)
    end)
end

--calls char's function "action" with the optional arguments
function Scene:actionCharacter(action,char,...)
    char[action](char,...)
end

function Scene:keypressedCharacter(button,char)
    char.controls:press(button)
    char:keypressed(button)
end
function Scene:keyreleasedCharacter(button,char)
    char.controls:release(button)
    char:keyreleased(button)
end

--walk character as close as possible to x,y
function Scene:moveCharacter(x,y,char)
    --ignore the y for now
    if char.position.x < x then
        self:keypressedCharacter('RIGHT',char)
    else
        self:keypressedCharacter('LEFT',char)
    end
    char.desiredX = x
end

--teleport character to x,y
function Scene:teleportCharacter(x,y,char)
    x = x or char.position.x
    y = y or char.position.y
    self:keyreleasedCharacter('RIGHT',char)
    self:keyreleasedCharacter('LEFT',char)
    char.position.x = x
    char.position.y = y
end

function Scene:moveCamera(x,y)
  self:trackCharacter(nil)
  self.camera.tx = x
  self.camera.ty = y
end


function Scene:tweenCamera(x,y)
  self:trackCharacter(nil)
  tween(2, self.camera, {tx = x or self.camera.tx, ty = y or self.camera.ty}, 'outQuad')
end

--FIXME: modify zoom at the end of script has poor behaviour
function Scene:zoomCamera(factor)
    self.camera.sx = self.camera.sx * factor
    self.camera.sy = self.camera.sy * factor
end

local last_tracked = nil
function Scene:trackCharacter(char)
    if last_tracked then
        self.nodes[last_tracked].doTracking = false
    end
    if char then
        self.nodes[char].doTracking = true
    end
    last_tracked = char
end

--TODO: call with postconditions rather than within the subclass
function Scene:endScene(player)
    local current = gamestate.currentState()
    tween(2, current.darken, {0, 0, 0, 0}, 'outQuad')
    player.opacity=255
    player.desiredX = nil
    player.freeze = false
    player.invulnerable = false
    --move the player to where the perceived character was
    if self.nodes[player.character.name] then
        tween(2, self.nodes[player.character.name], {opacity=255}, 'outQuad')
        player.position = {
          x = self.nodes[player.character.name].position.x,
          y = self.nodes[player.character.name].position.y,
        }
    end
    -- cleanup time!
    -- if this code is ever used again encapsulate in a function
    player.controls = self.origControls
    
    player.controlState:standard()
    
end

return Scene

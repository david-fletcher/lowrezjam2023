pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- canyon crisis
-- jammigans and fletch
-- made for #lowrezjam 2023

-- g_ for globals
-- k_ for keyboard keys
-- e_ for enumerated values
-- c_ for colors

-- globals
local g_current_state = nil
local g_debug = {false, false, false} -- 1 is CPU usage, 2 is player movement, 3 is length of particle
local g_muted = false

-- magic numbers
local k_left = 0
local k_right = 1
local k_up = 2
local k_down = 3
local k_confirm = 4
local c_transparent = 9

-- constants
local g_game_states = {e_splash=0, e_menu=1, e_loading=2, e_playing=3, e_gameover=4}
local g_world_tilewidth = 12

-- tracked values
local g_particles = {}
local g_point_particles = {}
local g_tick = false
local g_ticklen = 8
local g_frame = 0
local g_shake_frame = 0
local g_shake = { x=0, y=0 }

-->8
-- lifecycle
function _init()
 -- enable alt palette in editor
 poke(0x5f2e, 1)

 -- 64x64 mode!
 poke(0x5f2c, 3)

 -- set transparencies
 palt(0, false)
 palt(c_transparent, true)

 -- alter palette
 pal({[0]=0,131,2,3,4,130,134,7,8,137,10,11,138,139,14,143},1)

 -- TODO: turn back to g_game_states.e_splash before release!
 g_current_state = g_game_states.e_loading

 --particle system 2
 part={}
end

local s = 8
local tx = 0
function _update60()
 g_frame += 1
 if (g_frame % g_ticklen == 0) then
  g_tick = true
 else
  g_tick = false
 end

 if (g_current_state == g_game_states.e_splash) then
  update_splashscreen()
 elseif (g_current_state == g_game_states.e_menu) then
  update_menu()
 elseif (g_current_state == g_game_states.e_loading) then
  init_playing()
 elseif (g_current_state == g_game_states.e_playing) then
  update_playing()
 elseif (g_current_state == g_game_states.e_gameover) then
  update_gameover()
 end

 update_particles()
end

function _draw()
 cls(c_transparent)

 if (g_current_state == g_game_states.e_splash) then
  draw_splashscreen()
 elseif (g_current_state == g_game_states.e_menu) then
  draw_menu()
 elseif (g_current_state == g_game_states.e_playing) then
  draw_playing()
 elseif (g_current_state == g_game_states.e_gameover) then
  draw_gameover()
 end

 if (g_debug[1]) then
  camera()
  rectfill(0, 0, 22, 4, 0)
  print(stat(1), 0, 0, 7)
 end

 if (g_debug[3]) then
  camera()
  rectfill(0, 0, 22, 4, 0)
  print(#g_particles, 0, 0, 7)
 end

 update_point_particles()
end

-->8
-- splashscreen
local g_splash = {
 cur_frame = 0,
 last_frame = 120,
}

function update_splashscreen()
 if g_splash.cur_frame == 0 then
  play_sfx(2)
 end

 g_splash.cur_frame += 1
 
 if (g_splash.cur_frame > g_splash.last_frame) then
  g_current_state = g_game_states.e_menu
  g_splash.cur_frame = 0
 end
end

function draw_splashscreen()
 draw_menu()

 if (g_splash.cur_frame < 110) then
  rectfill(0, 0, 63, 63, 0)
  print("a game by", 14, 20, 7)
  print("jammigans", 14, 26, 7)
  print("mothense",  16, 32, 7)
  print("& fletch",  16, 38, 7)
 else
  if (g_splash.cur_frame >= 110 and g_splash.cur_frame < 113) then
   fillp(0b1111000000000000.1)
  elseif (g_splash.cur_frame >= 113 and g_splash.cur_frame < 116) then
   fillp(0b1111111100000000.1)
  elseif (g_splash.cur_frame >= 116 and g_splash.cur_frame <= 120) then
   fillp(0b1111111111110000.1)
  end
  rectfill(0, 0, 63, 63, 0)
  fillp()
 end
end

-->8
-- menu
local g_title = {
 x = 6,
 y = 15,
}

local g_menu = {
 options = { "play", "toggle sfx", "quit" },
 xtarget = { 24, -12, -48 }, -- calculated x values to center each option
 actions = {
  function() g_current_state = g_game_states.e_loading end, -- play
  function() g_muted = not g_muted end, -- mute sfx
  function() run() end -- quit
 },
 selected = 1,
 x = 24,
 y = 40
}

function update_menu()
 if (btnp(k_left) and g_menu.selected > 1) then
  g_menu.selected -= 1
  play_sfx(0)
 end

 if (btnp(k_right) and g_menu.selected < #g_menu.options) then
  g_menu.selected += 1
  play_sfx(0)
 end

 if (btnp(k_confirm)) then
  g_menu.actions[g_menu.selected]() -- run the function
  play_sfx(1)
 end

 g_menu.x = lerp(g_menu.x, g_menu.xtarget[g_menu.selected], 0.25)
end

function draw_menu()
 map(120, 4, 0, 0, 8, 8)
 map(0, 0, 0, 0, 8, 8)
 rectfill(0, 14, 64, 20, 5)
 rectfill(0, 39, 64, 45, 5)
 rectfill(54, 54, 64, 64, 5)
 print("canyon crisis", g_title.x, g_title.y, 7)

 -- print the menu options
 print(g_menu.options[1], g_menu.x, g_menu.y, g_menu.selected == 1 and 7 or 6)
 print(g_menu.options[2], g_menu.x + 8 + (#g_menu.options[1]*4), g_menu.y, g_menu.selected == 2 and 7 or 6)
 print(g_menu.options[3], g_menu.x + 16 + (#g_menu.options[1]*4) + (#g_menu.options[2]*4), g_menu.y, g_menu.selected == 3 and 7 or 6)

 -- show mute state
 local color = 7
 if (g_muted) then
  color = 2
  line(56, 57, 61, 61, color)
 end
 print(chr(141), 56, 57, color)
end

-->8
-- playing
local g_camera = {
 x = 0,
 y = -26,
 xtarget = 0,
 ytarget = 0,
 offset = -6
}

local g_player = nil
local g_mapregions = {}
local g_objects = {}
local g_timer = 180
local g_points = 0
local g_ammo = 6
local g_aliens = 0

function init_playing()
 -- player
 g_player = new_player(6, 0)

 -- map regions
 add(g_mapregions, -26)
 add(g_mapregions, -154)

 -- populate new region
 populate_region(g_mapregions[1])

 -- timer & points
 g_timer = 180
 g_points = 0

 g_current_state = g_game_states.e_playing
end

function update_playing()
 -- update timer
 if (g_frame % 60 == 0) then
  g_timer -= 1
 end

 if (g_timer == 0) then
  g_current_state = g_game_states.e_gameover
 end

 -- objects first (makes sure we capture latest player movement)
 update_objects()

 -- attempt to spawn in a new alien
 spawn_alien()

 -- camera movement
 if (g_player.x-g_camera.xtarget < 16) then
  g_camera.xtarget -= 16
 end

 if (g_player.x-g_camera.xtarget > 32) then
  g_camera.xtarget += 16
 end

 g_camera.ytarget = g_player.y - (48 + g_camera.offset)

 -- lerp towards our target
 g_camera.x = lerp(g_camera.x, g_camera.xtarget, 0.3)
 g_camera.y = lerp(g_camera.y, g_camera.ytarget, 0.3)

 -- adjust map regions
 if (g_camera.y + 64 < g_mapregions[1]) then
  g_mapregions[1] -= 240
  populate_region(g_mapregions[1])
 end

 -- pls don't ask me why populate_region goes in g_mapregions[1] and NOT g_mapregions[2] because idk and idc
 if (g_mapregions[2] > g_camera.y + 64) then
  g_mapregions[2] -= 240
 end

 -- update screenshake
 shake_screen()

 -- particle 2 test
 if btnp(❎) then
 	spawnpuft(32,32)
 end
end

function draw_playing()
 camera(g_camera.x+g_shake.x, g_camera.y+g_shake.y)
 
 -- draw the cracks in the ground pattern - last column in map data
 map(120, 0,  0,   g_mapregions[1], 8, 16)
 map(120, 0,  64,  g_mapregions[1], 8, 16)
 map(120, 0,  128, g_mapregions[1], 8, 16)
 map(120, 16, 0,   g_mapregions[2], 8, 16)
 map(120, 16, 64,  g_mapregions[2], 8, 16)
 map(120, 16, 128, g_mapregions[2], 8, 16)

 draw_objects()
 draw_particles()

 if (g_debug[2]) then
  camera()
  print(tostr(g_player.moving[0]).."-"..tostr(g_player.moving[1]).."-"..tostr(g_player.moving[2]), 0, 0, 7)
 end

 -- timer ui
 camera()

 local timer_pct = flr((g_timer / 180) * 59)
 local color = 7
 if (timer_pct < 10) then
  color = 8
 end
 rectfill(1, 1, 3, 62, 5)
 line(2, 2, 2, 61, 2)
 line(2, 61-timer_pct, 2, 61, color)

 -- points ui
 local point_str = format_num(g_points)
 rectfill(50, 1, 62, 7, 5)
 print(point_str, 51, 2, 10)

 -- ammo ui
 rectfill(60, 50, 62, 62, 5)
 for i=0,5 do
  if (i > g_ammo-1) then
    pset(61, 61-(i*2), 2)
  else
    pset(61, 61-(i*2), 10)
  end
 end
end

-->8
-- game over
function update_gameover()

end

function draw_gameover()
 print("gameover!", 0, 0, 7)
end

-->8
-- objects
function update_objects()
 for obj in all(g_objects) do
  -- if the object is off camera below the player, delete it
  if (obj.y > g_camera.y + 64) then
   if (obj.type == 'alien') then
    g_aliens -= 1
   end
   del(g_objects, obj)
  else
   obj.update(obj)
  end
 end
end

local draw_comparator = function(a, b)
 local result = a.y - b.y
 if (result == 0) then
  -- draw the wide objects on top of nearby objects
  result = a.sortprio - b.sortprio
 end

 if (result == 0) then
  -- draw right x before left x
  result = a.x - b.x
 end
 return result
end

function draw_objects()
 heapsort(g_objects, draw_comparator)
 for obj in all(g_objects) do
  if not (obj.y < g_camera.y - 16) then
   obj.draw(obj)
  end
 end
end

-- a region is a section of the map() that is 4 tiles wide and 8 tiles high (8 cels by 16 cels)
-- when the function receives the y-value, it's offset by 6 because *reasons* so we fix that before doing math
function populate_region(yvalue)
 local y = yvalue - 6

 -- repeat this process 3 times for each section of the screen (12 tiles wide)
 for col=0,2 do
  -- select a random column from the available map sections (currently: 2)
  local region = flr(rnd(15))

  -- iterate over each tile in the region and determine what to spawn
  for i=0,3 do
   for j=15,0,-1 do
    local celx = i*2 + (region*8)
    local cely = 32 - (j*2)
    local sprite = mget(celx, cely)

    local tiley = j - (y \ 16)

    if (sprite == 32) then
     new_cactus(col*4 + i+1, tiley)
    elseif (sprite == 34) then
     new_barrel(col*4 + i+1, tiley)
    elseif (rnd() < 0.2 ) then -- cow freq 0.03
     new_cow(col*4 + i+1, tiley)
    end
   end
  end
 end
end

function check_for_collision(x, y, w, h)
 for obj in all(g_objects) do
  if (obj.collide == true) then
   if (obj.x < x+w and obj.x+obj.w > x and obj.y < y+h and obj.y+obj.h > y) then
    return obj
   end
  end
 end

 return nil
end

-- return 0 for false, 1 for true, and 2 for cow
function is_occupied(tilex, tiley)
 for obj in all(g_objects) do
  if (obj.tilex == tilex and obj.tiley == tiley) then
   -- cow
   if (obj.type == 'cow') then 
    return 2, obj 
   end

   -- alien
   if (obj.type == 'alien' and obj.spawn_timer > 59) then
    return 0, obj
   end

   if (obj.type == 'ammo') then
    return 0, obj
   end

   return 1, obj
  end
 end

 return 0, nil
end

function spawn_bullet(tilex, tiley)
 local bullet = {}
 bullet.type = 'bullet'

 bullet.x = -2 + (16 * (tilex-1))
 bullet.y = -4 - (16 * (tiley-1))
 bullet.w = 8
 bullet.h = 8

 bullet.update = function(self)
  self.y -= 5
  
  -- the random "+9" looks weird but we center the bullet's collision hitbox
  -- so that we only scan for collisions in our column, not for adjacent columns of tiles
  local col = check_for_collision(self.x+9, self.y, 8, 8)
  if (col ~= nil and self.y > g_camera.y) then -- don't destroy off-screen targets
   if (col.explode ~= nil) then
    col.explode(col)
   end

   -- delete the bullet
   del(g_objects, self)
  end

  if (self.y < g_camera.y - 16) then
   del(g_objects, self)
  end
 end

 bullet.draw = function(self)
  spr(2, self.x, self.y, 1, 2)
 end

 add(g_objects, bullet)
end

function new_player(tilex, tiley)
 local player = {}
 player.type = 'player'
 player.collide = false
 player.sortprio = 2

 player.tilex = tilex
 player.tiley = tiley
 player.x = 16 * (tilex-1)
 player.y = -(16 * (tiley-1))
 player.shooting = 0
 player.shootdur = 20
 player.cd = 5
 player.strafe_cd = 0
 -- a table to tell us if the player is moving in a particular direction
 -- indexed by the directional buttons, k_left, k_right, and k_up
 player.moving = {false, false, false}
 player.flip = false

 player.update = function(self)
  -- player movement
  -- check left, check right, check up
  local tileleft, objleft = is_occupied(self.tilex-1, self.tiley)
  local tileright, objright = is_occupied(self.tilex+1, self.tiley)
  local tileup, objup =  is_occupied(self.tilex, self.tiley+1)

  if(btnp(k_left) and self.tilex > 1 and tileleft != 1 and self.strafe_cd <= 0) then
   -- strafe left
   play_sfx(7)
   self.tilex -= 1
   self.moving[k_left] = true
   self.moving[k_right] = false
   self.strafe_cd = 10

   -- check for cow
   if (tileleft == 2) then
    objleft.rescue(objleft)
   end
  end

  if (btnp(k_right) and self.tilex < g_world_tilewidth and tileright != 1 and self.strafe_cd <= 0) then
   -- strafe right
   play_sfx(7)
   self.tilex += 1
   self.moving[k_right] = true
   self.moving[k_left] = false
   self.strafe_cd = 10

   -- check for cow
   if (tileright == 2) then
    objright.rescue(objright)
   end
  end

  if (btnp(k_up) and tileup != 1 and self.strafe_cd <= 0) then
   -- move up
   play_sfx(4+flr(rnd(3)))
   self.tiley += 1
   self.moving[k_up] = true

   -- check for cow
   if (tileup == 2) then
    objup.rescue(objup)
   end
  end

  -- player shooting
  if (btn(k_confirm) and self.cd == 0 and g_ammo > 0) then
   play_sfx(3)
   spawn_bullet(self.tilex, self.tiley)
   self.shooting = self.shootdur
   self.cd = player.shootdur * 1.5
   g_ammo -= 1
  end
  
  if self.shooting > 0 then
   self.shooting -= 1
  end
  
  -- decrease shoot and strafe cool downs
  if self.cd > 0 then
    self.cd -= 1
  end
  if self.strafe_cd > 0 then
    self.strafe_cd -= 1
  end
   
  -- calculate player x and y
  local prev_x, prev_y = self.x, self.y
  self.x = lerp(self.x, 16 * (self.tilex-1), 0.3)
  self.y = lerp(self.y, -(16 * (self.tiley-1)), 0.3)

  -- determine if we are still moving in that direction
  if (prev_x == self.x) then
    self.moving[k_left] = false
    self.moving[k_right] = false
  end

  if (prev_y == self.y) then
    self.moving[k_up] = false
  end

  -- toggle the flip
  if (g_tick) then
    self.flip = not self.flip
  end
 end

 player.draw = function(self)
  -- shadow
  shadow(self)
  
  -- shoot duration
  local dur = self.shootdur

  -- muzzle flash
  if (self.shooting >= 0.75 * dur) then
   spr(4, self.x-6, self.y-11, 2, 2)
  elseif (self.shooting >= 0.65 * dur) then
   sspr(48,0,9,16,self.x-3,self.y-12,9,16)
  elseif (self.shooting >= 0.5 * dur) then
   circfill(self.x+1, self.y, 3, 8)
  end

  -- player
  if (self.moving[k_up]) then
    -- run forward
    sspr(0,32,16,18,self.x,self.y-3,16,18,self.flip,false)
  elseif (self.moving[k_right]) then
    -- strafe right
    sspr(16,32,19,18,self.x-2,self.y,19,18)
  elseif (self.moving[k_left]) then
    -- strafe left
    sspr(16,32,19,18,self.x-2,self.y,19,18,true)
  elseif (self.shooting >= 0.5 * dur) then
    -- shoot frame 1
    sspr(93,0,15,18,self.x,self.y-2)
  elseif (self.shooting >= 0.1 * dur) then
    -- shoot frame 2
    sspr(108,0,15,18,self.x,self.y-2)
  else
    -- idle
    sspr(72,0,21,18,self.x-4,self.y-2)
  end
 end

 add(g_objects, player)
 return player
end

function new_barrel(tilex, tiley)
 -- sprite num: 34
 local barrel = {}
 barrel.type = 'barrel'
 barrel.collide = true
 barrel.sortprio = 0

 barrel.tilex = tilex
 barrel.tiley = tiley

 barrel.x = 16 * (tilex-1)
 barrel.y = -(16 * (tiley-1))
 barrel.w = 16
 barrel.h = 10

 barrel.update = function(self)
 
 end

 barrel.explode = function(self)
  explode(34, self.tilex, self.tiley)
  if (rnd() < 0.5) then
   new_ammo(self.tilex, self.tiley)
  end
  del(g_objects, self)
 end

 barrel.draw = function(self)
  shadow(self)
  spr(34, self.x, self.y, 2, 2)
 end

 add(g_objects, barrel)
end

function new_cactus(tilex, tiley)
 -- sprite num: 32
 local cactus = {}
 cactus.type = 'cactus'
 cactus.collide = true
 cactus.sortprio = 0

 cactus.tilex = tilex
 cactus.tiley = tiley

 -- make the y hitbox smaller to have bullets collide with "center" of cactus
 cactus.x = 16 * (tilex-1)
 cactus.y = -(16 * (tiley-1))
 cactus.w = 16
 cactus.h = 10

 cactus.update = function(self)
  -- we really just need this object for bullet collisions, nothing else
 end

 cactus.draw = function(self)
  shadow(self)
  spr(32, self.x, self.y, 2, 2)
 end

 add(g_objects, cactus)
end

function new_alien(tilex, tiley)
 -- sprite num: 38
 play_sfx(8)
 local alien = {}
 alien.type = 'alien'
 alien.collide = false
 alien.sortprio = 0

 alien.tilex = tilex
 alien.tiley = tiley

 alien.x = 16 * (tilex-1)
 alien.y = -(16 * (tiley-1))
 alien.w = 16
 alien.h = 16

-- a table to tell us if the player is moving in a particular direction
 -- indexed by the directional buttons, k_left, k_right, k_up, and k_down
 alien.state = "warning"
 alien.moving = {false, false, false, false}
 alien.decision_timer = 90
 alien.warning_timer = 60
 alien.spawn_dur = 72 --78
 alien.spawn_timer = alien.spawn_dur

 alien.update = function(self)
  -- if we're not warning, and not spawning, then do this
  if (self.state ~= "warning" and self.state ~= "spawning") then
   if (self.decision_timer <= 0) then
    -- 5% chance to take an action
    if (rnd() < 0.05) then
     self.decision_timer = 60

     local dir = flr(rnd(4)) -- 0 - 3 only integers
     if (dir == k_left and self.tilex > 1) then
      local tile, _ = is_occupied(self.tilex-1, self.tiley)
      if (tile == 0) then -- empty tile
       self.tilex -= 1
       self.moving[k_left] = true
       self.state = "moving"
      end

     elseif (dir == k_right and self.tilex < g_world_tilewidth) then
      local tile, _ = is_occupied(self.tilex+1, self.tiley)
      if (tile == 0) then -- empty tile
       self.tilex += 1
       self.moving[k_right] = true
       self.state = "moving"
      end

     elseif (dir == k_up) then
      local tile, _ = is_occupied(self.tilex, self.tiley+1)
      if (tile == 0) then -- empty tile
       self.tiley += 1
       self.moving[k_up] = true
       self.state = "moving"
      end

     elseif (dir == k_down) then
      local tile, _ = is_occupied(self.tilex, self.tiley-1)
      if (tile == 0) then -- empty tile
       self.tiley -= 1
       self.moving[k_down] = true
       self.state = "moving"
      end
     end
    end
   end

   local prev_x, prev_y = self.x, self.y
   self.x = lerp(self.x, (16 * (self.tilex-1)), 0.3)
   self.y = lerp(self.y, -(16 * (self.tiley-1)), 0.3)

   if (prev_x == self.x and prev_y == self.y) then
    self.moving = {false, false, false, false}
    self.state = "idle"
   end

   self.decision_timer -= 1
  end

  -- STATE MACHINE LOGIC
  -- if we are spawning...
  if (self.state == "warning") then
   self.warning_timer -= 1
   if (self.warning_timer <= 0) then
    self.state = "spawning"
    play_sfx(9)
   end
  elseif (self.state == "spawning") then
   self.spawn_timer -= 1

   if (self.spawn_timer == 60) then
    g_shake_frame=4
    self.collide = true
   end

   if (self.spawn_timer <= 0) then
    self.state = "idle"
   end

   -- logic

  elseif (self.state == "idle") then
   -- logic

  elseif (self.state == "moving") then
   -- logic

  end
 end

 alien.explode = function(self)
  explode(38, self.tilex, self.tiley)
  del(g_objects, self)
  g_aliens -= 1
 end
 
 alien.draw = function(self)
  if (self.state == "warning") then
    if self.warning_timer < 90 then
     shadow(self)
    end
    -- warning indicator
    local frame
    local t = time() % 0.5
    if t < 0.25 then
     frame = 76
    else
     frame = 78
    end
    spr(frame, self.x, self.y+6, 2, 2)
    print("!", self.x+6, self.y+12, 8)
    print("!", self.x+7, self.y+12, 8)
  elseif (self.state == "spawning") then
   -- logic
   local spawn_progress = self.spawn_timer / self.spawn_dur
   shadow(self)
   -- spawn animation
   if spawn_progress <= 1 and spawn_progress > 0.962 then
    -- smear 1
    sspr(48, 16, 16, 16, self.x, self.y-40, 16, 40)
   end
   if spawn_progress < 0.962 and spawn_progress > 0.924 then
    -- smear 2
    sspr(48, 16, 16, 16, self.x, self.y-16, 16, 32)
   end
   if spawn_progress < 0.924 and spawn_progress > 0.848 then
    -- impact
    spr(70, self.x, self.y+2, 2, 2)
   end
   if spawn_progress < 0.848 and spawn_progress > 0.772 then
    -- transition
    spr(72, self.x, self.y, 2, 2)
   end
   if spawn_progress < 0.772 and spawn_progress > 0 then
    -- roar
    spr(74, self.x, self.y-1, 2, 2)
   end
   
   --spr(38, self.x, self.y, 2, 2)
  elseif (self.state == "idle") then
   -- logic
   shadow(self)
   spr(38, self.x, self.y, 2, 2)
  elseif (self.state == "moving") then
   -- logic
   shadow(self)
   spr(38, self.x, self.y, 2, 2)
  end
 end

 add(g_objects, alien)
end

function spawn_alien()
 local min_tilex = g_player.tilex - 2
 local min_tiley = g_player.tiley + 1

 -- 1) pick a random number with 5% chance to spawn alien
 -- 2) pick a random tile from the list of options
 -- 3) check if that tile is occupied
 -- 4) if not occupied, spawn in the alien
 if (g_aliens < 2 and rnd() < 0.1) then -- alien freq 0.05
  local tilex = flr(rnd(5)) + min_tilex
  local tiley = flr(rnd(3)) + min_tiley
  local tile, obj = is_occupied(tilex, tiley)

  if (tile == 0 and obj == nil) then
   new_alien(tilex, tiley)
   g_aliens += 1
  end
 end
end

function new_cow(tilex, tiley)
 -- sprite num: 109
 local cow = {}
 cow.type = 'cow'
 cow.collide = true
 cow.sortprio = 1
 
 cow.tilex = tilex
 cow.tiley = tiley

 cow.x = (16 * (tilex-1))
 cow.y = -(16 * (tiley-1))
 cow.w = 16
 cow.h = 16

 cow.decision_timer = 0
 cow.flip = false
 
 -- mooooovement
 cow.update = function(self)
  if (self.decision_timer <= 0) then
   -- 20% chance to take an action
   if (rnd() < 0.05) then
    self.decision_timer = 60

    local dir = flr(rnd(4)) -- 0 - 3 only integers
    if (dir == k_left and self.tilex > 1) then
     local tile, _ = is_occupied(self.tilex-1, self.tiley)
     if (tile == 0) then -- empty tile
      self.tilex -= 1
      self.flip = false
     end

    elseif (dir == k_right and self.tilex < g_world_tilewidth) then
     local tile, _ = is_occupied(self.tilex+1, self.tiley)
     if (tile == 0) then -- empty tile
      self.tilex += 1
      self.flip = true
     end

    elseif (dir == k_up) then
     local tile, _ = is_occupied(self.tilex, self.tiley+1)
     if (tile == 0) then -- empty tile
      self.tiley += 1
     end

    elseif (dir == k_down) then
     local tile, _ = is_occupied(self.tilex, self.tiley-1)
     if (tile == 0) then -- empty tile
      self.tiley -= 1
     end
    end
   end
  end

  self.x = lerp(self.x, (16 * (self.tilex-1)), 0.3)
  self.y = lerp(self.y, -(16 * (self.tiley-1)), 0.3)

  self.decision_timer -= 1
 end

 cow.rescue = function(self)
  add_points(10, cow.tilex, cow.tiley)
  del(g_objects, self)
 end

 cow.draw = function(self)
  shadow(self)
  spr(107, self.x, self.y, 2, 2)
 end
 
 add(g_objects, cow)
end

function new_ammo(tilex, tiley)
 local item = {}

 item.type = 'ammo'
 item.collide = false
 item.sortprio = 0

 item.tilex = tilex
 item.tiley = tiley

 item.x = (16 * (tilex-1))
 item.y = -(16 * (tiley-1))
 item.w = 16
 item.h = 16

 item.update = function(self)
  if (g_player.tilex == self.tilex and g_player.tiley == self.tiley) then
   refill_ammo()
   del(g_objects, self)
  end
 end

 item.draw = function(self)
  sspr(59, 8, 10, 8, self.x + 3, self.y + 6 + (cos(g_frame/60)*2))
 end

 add(g_objects, item)
end

-->8
-- helper functions

function shake_screen()
	local shakex= rnd(g_shake_frame) - (g_shake_frame / 2)
	local shakey=rnd(g_shake_frame) - (g_shake_frame / 2)

 g_shake = {x=shakex, y=shakey}

 g_shake_frame -= 1
	if g_shake_frame > 10 then
		g_shake_frame *= 0.875
	elseif g_shake_frame < 1 then
		g_shake_frame = 0
	end
end

function lerp(from, to, weight)
 local dist = to - from
 if (abs(dist) < 0.2) then return to end
 return (dist * weight) + from
end

-- taken from: https://www.lexaloffle.com/bbs/?pid=18374#p
function heapsort(t, cmp)
 local n = #t
 local i, j, temp
 local lower = flr(n / 2) + 1
 local upper = n

 if (n < 2) then
  return
 end

 while 1 do
  if lower > 1 then
   lower -= 1
   temp = t[lower]
  else
   temp = t[upper]
   t[upper] = t[1]
   upper -= 1
   if upper == 1 then
    t[1] = temp
    return
   end
  end

  i = lower
  j = lower * 2
  while j <= upper do
   if j < upper and cmp(t[j], t[j+1]) < 0 then
    j += 1
   end
   if cmp(temp, t[j]) < 0 then
    t[i] = t[j]
    i = j
    j += i
   else
    j = upper + 1
   end
  end
  t[i] = temp
 end
end

function play_sfx(s)
 if (not g_muted) then
  sfx(s)
 end
end

function format_num(num)
 local numstr = tostr(num)
 if (#numstr > 2) then
  return numstr
 elseif (#numstr == 2) then
  return "0"..numstr
 else
  return "00"..numstr
 end
end

function add_points(num, tilex, tiley)
 -- convert to screen coordinates
 local screenx = ((tilex-1)*16) - g_camera.x
 local screeny = -((tiley-1)*16) - g_camera.y

 -- add to point tracking
 g_points += num

 -- point particle setup
 local particle = {}
 particle.coroutine = cocreate(function() 
  local x_offset = -4
  local y = 2
  local point_str = "+"..num
  while (y != 15) do
   y = lerp(y, 15, 0.2)
   local actualx = screenx + (#point_str*2) + x_offset
   local actualy = screeny - y + 8
   rectfill(actualx-1, actualy-1, actualx+(#point_str*4)-1, actualy+5, 5)
   print(point_str, actualx, actualy, 10)
   yield()
  end
 end)

 add(g_point_particles, particle)
end

function shadow(o)
 ovalfill(o.x, o.y+12, o.x+15, o.y+17, 4)
 ovalfill(o.x+1, o.y+12, o.x+14, o.y+17, 2)
end

function refill_ammo()
 g_ammo = 6
 -- TODO: ammo refill animation
end

function explode(sprnum, tilex, tiley)
 -- update points
 if (sprnum == 34) then -- barrel
  add_points(2, tilex, tiley)
 elseif (sprnum == 38) then -- alien
  add_points(5, tilex, tiley)
 end

 -- spritesheet cel coords
 local celx = sprnum % 16
 local cely = sprnum \ 16

 -- cel coords to pixel coords
 local px = celx * 8
 local py = cely * 8

 -- explosion particles
 for dx=0,15 do
  for dy=0,15 do
   local pcolor = sget(px+dx, py+dy)
   if (pcolor ~= c_transparent) then
    add(g_particles, {
     x=((tilex-1)*16)+dx,
     y=(-(tiley-1)*16)+dy,
     r=0,
     dx=2-rnd(4),
     dy=2-rnd(4),
     dr=0,
     c=pcolor,
     ttl=5+rnd(5)
    })
   end
  end
 end
end

-- ----------------
-- PARTICLE SYSTEM
-- ----------------
function update_particles()
 local delete = {}
 for idx,particle in ipairs(g_particles) do
  particle.x = particle.x + particle.dx
  particle.y = particle.y + particle.dy
  particle.r = particle.r + particle.dr
  particle.ttl -= 1

  if (particle.ttl <= 0) then
   add(delete, idx)
  end
 end

 for i=#delete,1,-1 do
  deli(g_particles, delete[i])
 end
end

function draw_particles()
 for particle in all(g_particles) do
  circfill(particle.x, particle.y, particle.r, particle.c)
 end
end

function clear_particles()
 g_particles = {}
end

function update_point_particles()
 for emitter in all(g_point_particles) do
  if (costatus(emitter.coroutine)) then
   coresume(emitter.coroutine)
  else
   del(g_point_particles, emitter)
  end
 end
end

-- ----------------
-- PARTICLE SYSTEM 2
-- ----------------

-- spawn a small puft
function spawnpuft(_x,_y)
	for i= 0,5 do 
	 local _ang = rnd()
	 local _dx = sin(_ang)*1
	 local _dy = cos(_ang)*1
		addpart(_x,_y,_dx,_dy,2,15+rnd(15),{7,6,13},1+rnd(2))
	end
end

-- add a particle
function addpart(_x,_y,_dx,_dy,_type,_maxage,_col,_s)
  local _p = {}
  _p.x=_x
  _p.y=_y
  _p.dx=_dx
  _p.dy=_dy
  _p.tpe=_type
  _p.mage=_maxage
  _p.age=0
  _p.col=_col[1]
  _p.colarr=_col
  _p.rot=1
  _p.rottimer=0
  _p.s=_s
  _p.os=_s
 
  add(part,_p)
 end

__gfx__
0000000099999999998889998f899889999999999999999999988899999777777779999999999999997777999999999779977779999999779977779999999999
000000009999999998fff899f7f98ff8999988888889999999888889999755555557999999999977976666797799997006766667999997006766667999999999
00700700999999998f777f89f7f98ff8999888fff8889999988fff88999756767755799999999700677667760079997677776667977997677776667977999999
00077000999999998f777f89f7f98ff89988f77777f8899998fffff8999755777755579999999766777777776679997677e77777600797677e77777600799999
00077000999999998f777f89f7f98ff8998f7777777f899988fffff88997555757557999999997677e7777e77679990777e77777766790777e77777766799999
00700700999999998f777f89f7f98ff8988f7777777f889988fffff889975555555799999999907677eeee7767099997777eeeee7767957777eeeee776799999
00000000999999998f777f89f7f98ff8988f7777777f88998fffffff899777777779999999999907777777777099995977777777777006077777777777099999
00000000999999998f777f89f7f98ff898f777777777f8998fffffff899999999999999999999990077777700999906000777777009907600777777009999999
99999999999999998f777f89f7f98ff898f777777777f8998fffffff899977777777999999999077600000067709907600000000044900000000000044999999
99999999999999448ff7ff89f7f9988998f777777777f8998fffffff89972888888279999999907ee222222ee70990007255500067099f776222000670999999
999999999994449998fff899f7f99999988777777777889988fffff8899758aaa885799999979507e7eeee7e705999f777222227e7090f7ee7ee227e70999999
999442222499999998fff899f7f99889988f7777777f889988fffff889975888888579999955044077e77e7704f090f77e7eeee7ee990407e7e7ee7ee9999999
9999999222229999988f88998f898ff8998f7777777f899998fffff89997288888827999995ff4006777777604f090407e7e77e77099044077777e7709999999
9944444994422244998889998f898ff89988f77777f88999988fff889997055555507999967ff55006666660000f004407e77777600990006666777600999999
44999999999999999988899988898ff899988f777f8899999988f8899997055555507999676f45500066660000ff090006666666000990000066666000999999
99999999999999999999999998999889999998878899999999998999999977777777999976090000000000000000990000066660000990024400660000999999
99999999a99a999999999ffffff99999999999999999999993333999999333399999999960999900550000550099990224600000000990224600000000999999
999999913aac1999999ff222222ff99999999999999999993bbbbb3993bbbbb39999999999999995005995005999990555009950059990555009950059999999
999999cddcaad99999f2244444422f9999999999999999993bbbbbb99bbbbbbb9999999999999999999999999999999999999999999999999999999999999999
99c9a993dccc399994f444ff22444f299992222499999999bb333b399b3333bb9999999999999999999999999999999999999999999999999999999999999999
99dcc99ddcdcdc9924f44422ff444f494222449999999999b30003399300003b9999999999999999999999999999999999999999999999999999999999999999
9ddccd933d3d39995f5ff444444ff5f099999999999999993000000cc00000039999999999999999999999999999999999999999999999999999999999999999
9dcdcd913d3d19995f445ffffff445f099999999999999993000000cc00000039999999999999999999999999999999999999999999999999999999999999999
91cdc0913d331c9944f4544544544f4099999999999999991300081bb18000319999999999999999999999999999999999999999999999999999999999999999
9131319013330999444ff445445ff44099999999999999999933081bb18033099999999999999999999999999999999999999999999999999999999999999999
913131011313199954444ffffff4444099999999999999999011003bb30003399999999999999999999999999999999999999999999999999999999999999999
90313110131309992f454454444544f094499999999999999bb0007337000bb99999999999999999999999999999999999999999999999999999999999999999
901113111313199904f5445444454f4099942499999999999b300078870003b09999999999999999999999999999999999999999999999999999999999999999
9901111013131999954ff454444ff559999992249999999907000008800907b09999999999999999999999999999999999999999999999999999999999999999
999000011311199990554ffffff54509422224999999999907709060060907709999999999999999999999999999999999999999999999999999999999999999
99999991111119999905555444555099999999999999999997799900009997709999999999999999999999999999999999999999999999999999999999999999
99999990111109999990055555500999999999999999999999799999999999799999999999999999999999999999999999999999999999999999999999999999
99999977779999999999999777709779999999999999999999999999999999999333399999933339999999999999999979999999999999979999999999999999
99779766667977999997797666676007999999999999999999999999999999993bbbbb3993bbbbb3333339999993333397999999999999799999999999999999
97006776677600799970067766777667999999999999999993333999999333393bbbbbb99bbbbbbb3bbbbb3993bbbbbb99799999999997999979999999999799
976677777777667999766777777e776799999999999999993bbbb339933bbbb3bb333b399b3333bbbbbbbbb99bbbbbbb99979999999979999997999999997999
97677e7777e77679997677e7777e767099999999999999993bbb3bb99bb3bbbbb30003399300003b30033b399b33300399999999999999999999799999979999
907677eeee7767099907677eeee7770999999999999999999333bb3993bb33393000000cc0000003000003399300000099999999999999999999979999799999
9007777777777099999077777777709999999999999999993bbbbb3993bbbbb33000000cc00000031000000cc000000199999999999999999999999999999999
0ff0077777700999999900777770000999999999999999993bbbbb0cc0bbbbb31300001cc10000311000000cc000000199999999999999999999999999999999
0f77600000067799990776000002677009999999999999991333330cc03333319933001cc10033099100081bb180001999999999999999999999999999999999
0f7ee222222ee7099907ee222227ee0ff0999999999999990100001bb10000109011083bb38003309033081bb180333999999999999999999999999999999999
0407e7eeee7e704099507e7eeee7e7004f099999999999999030011bb11003090bb0003bb3000bb09b110078870003b999999999999999999999979999799999
044077e77e77044090f4077e77e7709044099999999999990bb0003bb3000bb00b30001bb10003b0b3b0007887000b3b99999999999999999999799999979999
900067777776004090f406777777609900099999999999990b30022bb22003b007000001100907b0b33000088000033b99979999999979999997999999997999
9999066666650ff00f0000666666000999999999999999990b300013310003b00770906006090770779000088009097799799999999997999979999999999799
9999000002220ff00ff000066660052299999999999999990b707061160707b09779990000999770779090600609097797999999999999799999999999999999
99999000046400099000000000006005599999999999999997779900009977709979999999999979799999000099999779999999999999979999999999999999
99999900055509999990055500999559999999999999999999999999999999999999999999999999999999999999777007779999999666999999999999999999
99999999900099999999550099999999999999999999999999999999999999999999999999999999999999999997777744477999999966669999777777779999
99977779999777777779999999999999999999999999999999999999999999999999999999999999999999999907777744477099669766777977777777777999
99700007997055555507999999999999999999999999999999999999999999999999999999999999999999999904777777774099667767677777777777777799
970e77e0797577766657999999999999999999999999999999999999999999999999999999999999999999999900477777774099967767666677777777777799
70e777ee077576666657999999999999999999999999999999999999999999999999999999999999999999999900477777440099966770777677777777777709
70e77eee077566666657999999999999999999999999999999999999999999999999999999999999999999999947440000774499999770777666666666666670
70eeeeee077756666577999999999999999999999999999999999999999999999999999999999999999999999940007777000499999777776766666666666670
70eeeeee077770560777999999999999999999999999999999999999999999999999999999999999999999999900407777040099997777777666666666666670
970eeee0797752222577999999999999999999999999999999999999999999999999999999999999999999999904470770044099997777767666666666666676
99700007997522262257999999999999999999999999999999999999999999999999999999999999999999999900070770700099999669907666666666666676
99977779997522222257999999999999999999999999999999999999999999999999999999999999999999999900777777770099999999996699966666666606
9999999999705555550799999999999999999999999999999999999999999999999999999999999999999999999077eeee770999999999996699999999996606
99999999999777777779999999999999999999999999999999999999999999999999999999999999999999999990040ee0400999999999990999999999990090
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999990000000000999999999966999999999996690
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999077007709999999999966999999999996699
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
99999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999999
__label__
pprrqqrrqqrrppjj33rr33rrjjpppppppprrqqrrqqrrppjj33rr33rrjjpppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pprrqqrrqqrrppjj33rr33rrjjpppppppprrqqrrqqrrppjj33rr33rrjjpppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
ppjjqqrrqq00ppjj33rr3333jjqqppppppjjqqrrqq00ppjj33rr3333jjqqpppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
ppjjqqrrqq00ppjj33rr3333jjqqppppppjjqqrrqq00ppjj33rr3333jjqqpppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
ppjj33jj33jjpp00jj33333300ppppppppjj33jj33jjpp00jj33333300pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
ppjj33jj33jjpp00jj33333300ppppppppjj33jj33jjpp00jj33333300pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
ppjj33jj33jj00jjjj33jj33jjppppppppjj33jj33jj00jjjj33jj33jjpppppppppppppppppppppppppppp2222222244pppppppppppppppppppppppppppppppp
ppjj33jj33jj00jjjj33jj33jjppppppppjj33jj33jj00jjjj33jj33jjpppppppppppppppppppppppppppp2222222244pppppppppppppppppppppppppppppppp
pp0033jj33jjjj00jj33jj3300pppppppp0033jj33jjjj00jj33jj3300pppppppppppppppppppppp442222224444pppppppppppppppppppppppppppppppppppp
pp0033jj33jjjj00jj33jj3300pppppppp0033jj33jjjj00jj33jj3300pppppppppppppppppppppp442222224444pppppppppppppppppppppppppppppppppppp
pp00jjjjjj33jjjjjj33jj33jjpppppppp00jjjjjj33jjjjjj33jj33jjpppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pp00jjjjjj33jjjjjj33jj33jjpppppppp00jjjjjj33jjjjjj33jj33jjpppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pppp00jjjjjjjj00jj33jj33jjpppppppppp00jjjjjjjj00jj33jj33jjpppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pppp00jjjjjjjj00jj33jj33jjpppppppppp00jjjjjjjj00jj33jj33jjpppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pp442200000000jjjj33jjjjjj2244pppp442200000000jjjj33jjjjjj2244pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pp442200000000jjjj33jjjjjj2244pppp442200000000jjjj33jjjjjj2244pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
44222222222222jjjjjjjjjjjj22224444222222222222jjjjjjjjjjjj222244pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
44222222222222jjjjjjjjjjjj22224444222222222222jjjjjjjjjjjj222244pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
4422222222222200jjjjjjjj002222444422222222222200jjjjjjjj00222244pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
4422222222222200jjjjjjjj002222444422222222222200jjjjjjjj00222244pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pp44222222vvvvvvvvvvvv22222244pppp4422222222222222222222222244pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pp44222222vvvvvvvvvvvv22222244pppp4422222222222222222222222244pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
ppppppvvvv222222222222vvvvpppppppppppp44222222222222222244pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
ppppppvvvv222222222222vvvvpppppppppppp44222222222222222244pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
ppppvv22224444444444442222vvpppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
ppppvv22224444444444442222vvpppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pp44vv444444vvvv2222444444vv22pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pp44vv444444vvvv2222444444vv22pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
2244vv4444442222vvvv444444vv44pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
2244vv4444442222vvvv444444vv44pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
iivviivvvv444444444444vvvviivv00pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
iivviivvvv444444444444vvvviivv00pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
iivv4444iivvvvvvvvvvvv4444iivv00pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
iivv4444iivvvvvvvvvvvv4444iivv00pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
4444vv44ii4444ii4444ii4444vv4400pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
4444vv44ii4444ii4444ii4444vv4400pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
444444vvvv4444ii4444iivvvv444400pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
444444vvvv4444ii4444iivvvv444400pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
ii44444444vvvvvvvvvvvv4444444400pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
ii44444444vvvvvvvvvvvv4444444400pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
22vv44ii4444ii44444444ii4444vv00pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
22vv44ii4444ii44444444ii4444vv00pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
0044vvii4444ii44444444ii44vv4400pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
0044vvii4444ii44444444ii44vv4400pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
ppii44vvvv44ii44444444vvvviiiipppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
ppii44vvvv44ii44444444vvvviiiipppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pp00iiii44vvvvvvvvvvvvii44ii00pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pp00iiii44vvvvvvvvvvvvii44ii00pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
442200iiiiiiii444444iiiiii002244pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
442200iiiiiiii444444iiiiii002244pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
4422220000iiiiiiiiiiii0000222244pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
4422220000iiiiiiiiiiii0000222244pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pp4422222222222222222222222244ppppppppppppppppppppppppppppppppppppppppppppppppppqqppppqqpppppppppppppppppppppppppppppppppppppppp
pp4422222222222222222222222244ppppppppppppppppppppppppppppppppppppppppppppppppppqqppppqqpppppppppppppppppppppppppppppppppppppppp
pppppp44222222222222222244ppppppppppppppppppppppppppppppppppppppppppppppppppppjj33qqqqqqjjpppppppppppppppppppppppppppppppppppppp
pppppp44222222222222222244ppppppppppppppppppppppppppppppppppppppppppppppppppppjj33qqqqqqjjpppppppppppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppqqrrrrqqqqqqrrpppppppppppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppqqrrrrqqqqqqrrpppppppppppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppqqppqqpppp33rrqqqqqq33pppppppppppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppqqppqqpppp33rrqqqqqq33pppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppprrqqqqpppprrrrqqrrqqrrqqpppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppprrqqqqpppprrrrqqrrqqrrqqpppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppprrrrqqqqrrpp3333rr33rr33pppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppprrrrqqqqrrpp3333rr33rr33pppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppprrqqrrqqrrppjj33rr33rrjjpppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppprrqqrrqqrrppjj33rr33rrjjpppppppppppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppjjqqrrqq00ppjj33rr3333jjqqpppppppppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppjjqqrrqq00ppjj33rr3333jjqqpppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppp4444ppppppppppppjj33jj33jjpp00jj33333300pppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppp4444ppppppppppppjj33jj33jjpp00jj33333300pppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppp442244ppppppjj33jj33jj00jjjj33jj33jjpppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppp442244ppppppjj33jj33jj00jjjj33jj33jjpppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppp222244pp0033jj33jjjj00jj33jj3300pppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppp222244pp0033jj33jjjj00jj33jj3300pppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppp442222222244pppppp00jjjjjj33jjjjjj33jj33jjpppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppp442222222244pppppp00jjjjjj33jjjjjj33jj33jjpppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp00jjjjjjjj00jj33jj33jjpppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp00jjjjjjjj00jj33jj33jjpppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp442200000000jjjj33jjjjjj2244pppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp442200000000jjjj33jjjjjj2244pppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp44222222222277777777jjjjjj222244pppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp44222222222277777777jjjjjj222244pppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp442277772277mmmmmmmm77jj77772244pppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp442277772277mmmmmmmm77jj77772244pppppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppppppppppppvvvvvvvvvvvvpppppppppppp770000mm7777mmmm7777mm000077pppppppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppppppppppppvvvvvvvvvvvvpppppppppppp770000mm7777mmmm7777mm000077pppppppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppppppppvvvv222222222222vvvvpppppppp77mmmm7777777777777777mmmm77pppppppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppppppppvvvv222222222222vvvvpppppppp77mmmm7777777777777777mmmm77pppppppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppppppvv22224444444444442222vvpppppp77mm7777ee77777777ee7777mm77pppppppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppppppvv22224444444444442222vvpppppp77mm7777ee77777777ee7777mm77pppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppp44vv444444vvvv2222444444vv22pppp0077mm7777eeeeeeee7777mm7700pppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppp44vv444444vvvv2222444444vv22pppp0077mm7777eeeeeeee7777mm7700pppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppp2244vv4444442222vvvv444444vv44pppppp007777777777777777777700pppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppp2244vv4444442222vvvv444444vv44pppppp007777777777777777777700pppppppppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppiivviivvvv444444444444vvvviivv00pppppp00007777777777770000pppppppppppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppiivviivvvv444444444444vvvviivv00pppppp00007777777777770000pppppppppppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppiivv4444iivvvvvvvvvvvv4444iivv00pp007777mm000000000000mm777700pppppppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppiivv4444iivvvvvvvvvvvv4444iivv00pp007777mm000000000000mm777700pppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppp4444vv44ii4444ii4444ii4444vv4400pp0077eeee222222222222eeee7700pppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppp4444vv44ii4444ii4444ii4444vv4400pp0077eeee222222222222eeee7700pppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppp444444vvvv4444ii4444iivvvv444477ppii0077ee77eeeeeeee77ee7700iipppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppp444444vvvv4444ii4444iivvvv444477ppii0077ee77eeeeeeee77ee7700iipppppppppppppppppppppppppppppppppp
pppppp2222222244ppppppppppppppppii44444444vvvvvvvvvvvv444444iiii004444007777ee7777ee77770044vv00pppppppppppppppppppppppppppppppp
pppppp2222222244ppppppppppppppppii44444444vvvvvvvvvvvv444444iiii004444007777ee7777ee77770044vv00pppppppppppppppppppppppppppppppp
442222224444pppppppppppppppppppp22vv44ii4444ii44444444ii4444iivvvv440000mm777777777777mm0044vv00pppppppppppppppppppppppppppppppp
442222224444pppppppppppppppppppp22vv44ii4444ii44444444ii4444iivvvv440000mm777777777777mm0044vv00pppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppp0044vvii4444ii44444444ii44mm77vvvviiii0000mmmmmmmmmmmm00000000vv00pppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppp0044vvii4444ii44444444ii44mm77vvvviiii0000mmmmmmmmmmmm00000000vv00pppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppppii44vvvv44ii44444444vvmm77mmvv44iiii000000mmmmmmmm00000000vvvv00pppppppppppppppppppppppppppppp
ppppppppppppppppppppppppppppppppppii44vvvv44ii44444444vvmm77mmvv44iiii000000mmmmmmmm00000000vvvv00pppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppp00iiii44vvvvvvvvvvvvii77mm00pp00000000000000000000000000000000pppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppp00iiii44vvvvvvvvvvvvii77mm00pp00000000000000000000000000000000pppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppp442200iiiiiiii444444iiiimm00224444220000iiii00000000iiii00002244pppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppp442200iiiiiiii444444iiiimm00224444220000iiii00000000iiii00002244pppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppp4422220000iiiiiiiiiiii0000222244442222ii0000ii2222ii0000ii222244pppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppp4422220000iiiiiiiiiiii0000222244442222ii0000ii2222ii0000ii222244pppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppp4422222222222222222222222244pppp4422222222222222222222222244pppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppp4422222222222222222222222244pppp4422222222222222222222222244pppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppp44222222222222222244pppppppppppp44222222222222222244pppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppp44222222222222222244pppppppppppp44222222222222222244pppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp
pppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppppp

__map__
0000000000000000000000000000000000002223000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000024
0000000000000000000000000000000000003233000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000020210000000022230000000000000000000000000000202100000000000022232223000000000000000000000000000000002223000022230000000000002223222300000000000000000000000000000000000000000000000000000000000000000000000000002223000000000000000000001011000000000000
0000000030310000000032330000000000000000000000000000303100000000000032333233000000000000000000000000000000003233000032330000000000003233323300000000000000000000000000000000000000000000000000000000000000000000000000003233000000000000000000000000000000000000
0000000000002021000000000000202100000000202100000000000000000000000022232223000000002223202100000000000000000000000000000000000000000000000000000000000022230000000020210000000022230000000000000000000000000000000020212223000000002223202100000000000000340000
0000000000003031000000000000303100000000303100000000000000000000000032333233000000003233303100000000000000000000000000000000000000000000000000000000000032330000000030310000000032330000000000000000000000000000000030313233000000003233303100000000000000000000
0000222300000000000000000000000000000000000022230000000020210000000000000000202100000000000000000000000000000000000000002021000000002021000000000000000000000000000000000000000000002223000000002223000000000000000000000000000000000000000000000000240000000000
0000323300000000000000000000000000000000000032330000000030310000000000000000303100000000000000000000000000000000000000003031000000003031000000000000000000000000000000000000000000003233000000003233000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000222320210000000000000000000000000000000000000000000000000000000000000000000000000000222300000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000323330310000000000000000000000000000000000000000000000000000000000000000000000000000323300000000000000000000000000000000000000000000000000000000000010110000
0000202100002223000000000000000000002223202100000000202100000000000022230000000000000000222300000000000000000000000022230000000022230000000022230000202100000000000000000000000000000000000000000000000020210000000000000000000000000000000000000000000000000000
0000303100003233000000000000000000003233303100000000303100000000000032330000000000000000323300000000000000000000000032330000000032330000000032330000303100000000000000000000000000000000000000000000000030310000000000000000000000000000000000000024000000000000
0000000000000000000000000000222300000000000000002021000000000000000000002021000000002223000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000020210000000000002021000000000000000000000000
0000000000000000000000000000323300000000000000003031000000000000000000003031000000003233000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000030310000000000003031000000000000000000000034
2223000000002021000000002021000000000000000000000000000000000000000000000000000000000000000000000000000022230000000000000000202100000000000000000000000000000000000000000000000000002223202100000000000000002223000000000000000000000000000000000000000000000000
3233000000003031000000003031000000000000000000000000000000000000000000000000000000000000000000000000000032330000000000000000303100000000000000000000000000000000000000000000000000003233303100000000000000003233000000000000000000000000000000000000000000000000
0000000000000000000000000000000000002021000000000000000000000000000000000000000000000000202100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000002400000000
0000000000000000000000000000000000003031000000000000000000000000000000000000000000000000303100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000222300000000000000000000222300000000000000000000000000000000000000002223000000000000202100002223000022232021000000002223222300000000202120210000000000002223000000000000000000000000202100000000000022230000000000000000000000000000000000000000
0000000000000000323300000000000000000000323300000000000000000000000000000000000000003233000000000000303100003233000032333031000000003233323300000000303130310000000000003233000000000000000000000000303100000000000032330000000000000000000000000000000000000000
2021000022230000000000000000202100000000000000000000202100002021000000000000000000000000000000000000000000000000000000000000000000000000000000000000202120210000000000000000000000000000000000000000000020210000000022230000000000000000000000000000000000101100
3031000032330000000000000000303100000000000000000000303100003031000000000000000000000000000000000000000000000000000000000000000000000000000000000000303130310000000000000000000000000000000000000000000030310000000032330000000000000000000000000000000000000000
0000000000000000000000000000222300000000202100000000000000000000000000000000222300000000000000000000222300000000000000000000000000000000202100000000000000000000000000000000000000000000222300000000000000000000000000000000000000000000000000000000240000000000
0000000000000000000000000000323300000000303100000000000000000000000000000000323300000000000000000000323300000000000000000000000000000000303100000000000000000000000000000000000000000000323300000000000000000000000000000000000000000000000000000000000000000000
0000000020210000000000000000000022230000000000000000000000000000000000000000000000000000000000000000000000000000000000002021000000000000000000000000000020210000000000000000000000000000000000000000000000000000000000000000000000000000222300000000000000000000
0000000030310000000000000000000032330000000000000000000000000000000000000000000000000000000000000000000000000000000000003031000000000000000000000000000030310000000000000000000000000000000000000000000000000000000000000000000000000000323300000000000000340000
0000000000002223000022230000000000000000000000000000000000000000000000000000000000002021000000000000000000000000000022230000000022230000000022230000000000000000000000000000000000000000202100000000000020210000000000000000000000000000000000001011000000000000
0000000000003233000032330000000000000000000000000000000000000000000000000000000000003031000000000000000000000000000032330000000032330000000032330000000000000000000000000000000000000000303100000000000030310000000000000000000000000000000000000000000000000000
0000222300000000202100000000000000000000000000002021000000000000000022230000000000000000000000000000000000002223000000000000000000000000000000000000000000000000000000000000000000002021000000000000222300000000000000002021000000002021000000000000000000000000
0000323300000000303100000000000000000000000000003031000000000000000032330000000000000000000000000000000000003233000000000000000000000000000000000000000000000000000000000000000000003031000000000000323300000000000000003031000000003031000000000000000000002400
0000000000000000000000000000000000000000000000000000000000000000000000002021000000000000000022230000000000000000000000000000000000002021202100000000222300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000340000000000
0000000000000000000000000000000000000000000000000000000000000000000000003031000000000000000032330000000000000000000000000000000000003031303100000000323300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
94030000100501005010050100551f000220002400024000290002b0002e000330003500035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
480400002405024050240502405500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4808000028052280522b0522b05230052300523005230052300323001200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002
04090000070630f153106530961309603156030160301603016030260302603006030000300003000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003
000200000e050170411f0611a0050b0010160101601016010c0010c0010c0010d0010d0010d0010e0010f00111001130010000100001000010000100001000010000100001000010000100001000010000100001
000200000c05017041240611a005016010360101601016010c0010c0010c0010d0010d0010d0010e0010f00111001130010000100001000010000100001000010000100001000010000100001000010000100001
000200000c0501d061240511a005016010160101601016010c0010c0010c0010d0010d0010d0010e0010f00111001130010000100001000010000100001000010000100001000010000100001000010000100001
0004000013640006612a05102605026010160101601016010c0010c0010c0010d0010d0010d0010e0010f00111001130010000100001000010000100001000010000100001000010000100001000010000100001
0207000011b1011b3016b4016b501db501db4024b3024b1000b0000b001fb0000b0000b002ab0000b0000b0000b0000b0000b0000b0000b0000b0000b0009b0006b0000b0000b0000b0000b0000b0000b0000b00
02140000010440606304363026450262002630026100c7060c7000c7000c7030c703007031e703000030000300003000030000300003000030000300003000030000300003000030000300003000030000300003

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
local g_debug = {true, false, false} -- 1 is CPU usage, 2 is player / wall data, 3 is length of particle
local g_muted = false

-- magic numbers
local k_left = 0
local k_right = 1
local k_up = 2
local k_down = 3
local k_confirm = 4

local c_transparent = 9

-- constants
local g_game_states = {e_splash=0, e_menu=1, e_loading=2, e_playing=3}
local g_world_width = 1024
local g_world_height = 512
local g_tilesize = 16
local g_world_tilewidth = 64
local g_world_tileheight = 32

-- tracked values
local g_particles = {}
local g_emitters = {}

-->8
-- lifecycle
function _init()
 -- enable alt palette in editor
 --poke(0x5f2e,1)

 -- 64x64 mode!
 poke(0x5f2c, 3)

 -- set transparencies
 palt(0, false)
 palt(c_transparent, true)

 -- alter palette
 pal({[0]=0,131,2,3,4,130,134,7,8,137,10,11,138,139,14,143},1)

 -- TODO: turn back to g_game_states.e_splash before release!
 g_current_state = g_game_states.e_loading
end

local s = 8
local tx = 0
function _update60()
 if (g_current_state == g_game_states.e_splash) then
  update_splashscreen()
 elseif (g_current_state == g_game_states.e_menu) then
  update_menu()
 elseif (g_current_state == g_game_states.e_loading) then
  init_playing()
 elseif (g_current_state == g_game_states.e_playing) then
  update_playing()
 end

 update_emitters()
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
  print("a game by", 14, 23, 7)
  print("jammigans", 14, 29, 7)
  print("& fletch",  16, 35, 7)
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
 y = 0,
 xtarget = 0,
 ytarget = 0
}

local g_player = {
 tilex = 2,
 tiley = 2,
 drawx = 16,
 drawy = 16,
 width = 2,
 height = 2,
 lastdir = k_left
}

local g_walls = {}

function init_playing()
 for i=0,g_world_tilewidth-1 do
  add(g_walls, {})
  for j=0,g_world_tileheight-1 do
   local celx = i*2
   local cely = j*2 -- we multiply by two because with a tilesize of 16, each tile will take up two 8x8 map cels
   local sprite = mget(celx, cely)

   if (sprite == 32) then -- cacti
    add(g_walls[i+1], true)
   elseif (sprite == 34) then -- barrel
    add(g_walls[i+1], true)
    new_barrel(i+1, j+1)
   else
    add(g_walls[i+1], false)
   end
  end
 end

 g_current_state = g_game_states.e_playing
end

function update_playing()
 -- player movement
 if(btnp(k_left) and g_player.tilex > 1 and not g_walls[g_player.tilex-1][g_player.tiley]) then
  g_player.tilex -= 1
  g_player.lastdir = k_left
 end

 if (btnp(k_right) and g_player.tilex < g_world_tilewidth and not g_walls[g_player.tilex+1][g_player.tiley]) then
  g_player.tilex += 1
  g_player.lastdir = k_right
 end

 if (btnp(k_up) and g_player.tiley > 1 and not g_walls[g_player.tilex][g_player.tiley-1]) then
  g_player.tiley -= 1
  g_player.lastdir = k_up
 end

 if (btnp(k_down) and g_player.tiley < g_world_tileheight and not g_walls[g_player.tilex][g_player.tiley+1]) then
  g_player.tiley += 1
  g_player.lastdir = k_down
 end

 -- player shooting
 if (btnp(k_confirm)) then
  spawn_bullet(g_player.tilex, g_player.tiley, g_player.lastdir)
 end

 -- calculate player x and y
 g_player.drawx = (g_tilesize / 2) - (g_player.width * 8 / 2) + (g_tilesize * (g_player.tilex-1))
 g_player.drawy = (g_tilesize / 2) - (g_player.height * 8 / 2) + (g_tilesize * (g_player.tiley-1))

 -- camera movement
 if (g_player.drawx-g_camera.xtarget < 16 and g_camera.xtarget > 0) then
  g_camera.xtarget -= 16
 end

 if (g_player.drawx-g_camera.xtarget >= 48 and g_camera.xtarget < g_world_width-64) then
  g_camera.xtarget += 16
 end

 if (g_player.drawy-g_camera.ytarget < 16 and g_camera.ytarget > 0) then
  g_camera.ytarget -= 16
 end

 if (g_player.drawy-g_camera.ytarget >= 48 and g_camera.ytarget < g_world_height-64) then
  g_camera.ytarget += 16
 end

 -- lerp towars our target
 g_camera.x = lerp(g_camera.x, g_camera.xtarget, 0.3)
 g_camera.y = lerp(g_camera.y, g_camera.ytarget, 0.3)

 -- check for collectibles
 update_objects()
end

function draw_playing()
 camera(g_camera.x, g_camera.y)

	draw_objects()
 -- for every map row 
 for j=0,64 do
  if (g_player.tiley == (j+1)/2) then
   -- draw shadow
   shadow(g_player)
   -- draw box
   -- rect(g_player.drawx, g_player.drawy+4, g_player.drawx+15, g_player.drawy+19, 10)
   -- draw player
   spr(6, g_player.drawx, g_player.drawy, g_player.width, g_player.height)
  end
  map(0, j, 0, j*8, 128, 1)
 end

 draw_particles()

 if (g_debug[2]) then
  for i=0,g_world_tilewidth-1 do
   for j=0,g_world_tileheight-1 do
    if (g_walls[i+1][j+1]) then
     rect(i*16, j*16, i*16+15, j*16+15, 8)
     print(i..","..j, i*16+2, j*16+6, 8)
    end
   end
  end
 end

 if (g_debug[2]) then
  camera()
  print(g_player.tilex..","..g_player.tiley, 0, 0, 7)
 end
end

-->8
-- objects
local g_objects = {}

function update_objects()
 for obj in all(g_objects) do
  obj.update(obj)
 end
end

function draw_objects()
 for obj in all(g_objects) do
  obj.draw(obj)
 end
end

function check_for_collision(type, x, y, w, h)
 for obj in all(g_objects) do
  if (obj.type == type) then
   if (obj.x < x+w and obj.x+obj.w > x and obj.y < y+h and obj.y+obj.h > y) then
    return obj
   end
  end
 end

 return nil
end

function spawn_bullet(tilex, tiley, direction)
 local bullet = {}
 bullet.type = 'bullet'

 bullet.x = (g_tilesize / 2) - (4) + (g_tilesize * (tilex-1))
 bullet.y = (g_tilesize / 2) - (4) + (g_tilesize * (tiley-1))
 bullet.w = 8
 bullet.h = 8
 bullet.dir = direction

 bullet.update = function(self)
  if(self.dir == 0) then -- left
   self.x -= 5
  elseif(self.dir == 1) then -- right
   self.x += 5
  elseif(self.dir == 2) then -- up
   self.y -= 5
  elseif(self.dir == 3) then -- down
   self.y += 5
  end

  local col = check_for_collision('barrel', self.x, self.y, 8, 8)
  if (col ~= nil) then
   col.explode(col)
   del(g_objects, self)
  end
 end

 bullet.draw = function(self)
  spr(2, self.x, self.y, 1, 2)
 end

 add(g_objects, bullet)
end

function new_barrel(tilex, tiley)
 -- sprite num: 34
 local barrel = {}
 barrel.type = 'barrel'

 barrel.tilex = tilex
 barrel.tiley = tiley

 barrel.x = g_tilesize * (tilex-1)
 barrel.y = g_tilesize * (tiley-1)
 barrel.w = 16
 barrel.h = 16

 barrel.update = function(self)
 
 end

 barrel.explode = function(self)
  -- remove from the walls table
  g_walls[self.tilex][self.tiley] = false

  -- remove from the pico8 map
  mset((self.tilex-1)*2, (self.tiley-1)*2, 0)
  mset((self.tilex-1)*2, (self.tiley-1)*2+1, 0)
  mset((self.tilex-1)*2+1, (self.tiley-1)*2, 0)
  mset((self.tilex-1)*2+1, (self.tiley-1)*2+1, 0)

  -- spritesheet cel coords
  local celx = 34 % 16
  local cely = 34 \ 16
  
  -- cel coords to pixel coords
  local px = celx * 8
  local py = cely * 8

  -- explosion particles
  for dx=0,15 do
   for dy=0,15 do
    local pcolor = sget(px+dx, py+dy)
    if (pcolor ~= c_transparent) then
     add(g_particles, {
      x=((self.tilex-1)*16)+dx,
      y=((self.tiley-1)*16)+dy,
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

  del(g_objects, self)
 end

 barrel.draw = function(self)
  -- do nothing, drawn by the map
 end

 add(g_objects, barrel)
end

-->8
-- helper functions
function lerp(from, to, weight)
 local dist = to - from
 if (abs(dist) < 0.2) then return to end
 return (dist * weight) + from
end

function play_sfx(s)
 if (not g_muted) then
  sfx(s)
 end
end

function shadow(o)
 ovalfill(o.drawx, o.drawy+12, o.drawx+15, o.drawy+17, 4)
 ovalfill(o.drawx+1, o.drawy+12, o.drawx+14, o.drawy+17, 2)
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

function update_emitters()
 for emitter in all(g_emitters) do
  if (costatus(emitter.coroutine)) then
   coresume(emitter.coroutine)
  end
 end
end

__gfx__
00000000998888999988899999999999999999999999999999999677776999999999699999999999999999999999999999999999999999999999999999999999
0000000098e77e8998fff89999999999999999999999999999779766667977999995509999999999999999999999999999999999999999999999999999999999
007007008e7777e88ff7ff8999999999999999999999999997006776677600799995449999999999999999999999999999999999999999999999999999999999
000770008e7777e88ff7ff8999999999999999999999999997667077770766799967445599999999999999999999999999999999999999999999999999999999
000770008e7777e88f777f8999999999999999999999999997677e7777e776799676005599999999999999999999999999999999999999999999999999999999
00700700987ee7898f777f89999999999999999999999999907677eeee7777099760999999999999999999999999999999999999999999999999999999999999
0000000098e88e898f777f8999999999999999999999999999077777777770999609999999999999999999999999999999999999999999999999999999999999
00000000998888998f777f8999999999999999999999999999900777777009999999999999999999999999999999999999999999999999999999999999999999
99999999999999998f777f8999999999999999999999999999076000000670999999900999999999999999999999999999999999999999999999999999999999
99999999999999449ff7ff9999999999999999999999999990e7766666677e099999900999999999999999999999999999999999999999999999999999999999
999999999994449998f7f89999999999999999999999999990e0e777777e0e099999900999999999999999999999999999999999999999999999999999999999
999442222499999998f7f8999999999999999999999999999440e7e77e7e04409999045999999999999999999999999999999999999999999999999999999999
9999999222229999988f8899999999999999999999999999944002e77e2004409999045099999999999999999999999999999999999999999999999999999999
9944444994422244998f899999999999999999999999999990000022220000099999044099999999999999999999999999999999999999999999999999999999
44999999999999999988899999999999999999999999999999905500005509999999900099999999999999999999999999999999999999999999999999999999
99999999999999999998999999999999999999999999999999950050050059999999900099999999999999999999999999999999999999999999999999999999
99999999c99c999999999ffffff99999999999999999999993333999999333399999999999999999999999999999999999999999999666999999999999999999
999999913ccc1999999ff222222ff99999999999999999993bbbbb3993bbbbb39999999999999999999999999999999999999999999966669999777777779999
999999cddcccd99999f2244444422f9999999999999999993bbbbbb99bbbbbbb9999999999999999999999999999999999999999669766777977777777777999
99c9c993dccc399994f444ff22444f299992222499999999bb333b399b3333bb9999999999999999999999999999999999999999667767677777777777777799
99dcc99ddcdcdc9924f44422ff444f494222449999999999b30003399300003b9999999999999999999999999999999999999999967767666677777777777799
9ddccd933d3d39995f5ff444444ff5f099999999999999993000000cc00000039999999999999999999999999999999999999999966770777677777777777709
9dcdcd913d3d19995f445ffffff445f099999999999999993000000cc00000039999999999999999999999999999999999999999999770777666666666666670
91cdc0913d331c9944f4544544544f4099999999999999991300081bb18000319999999999999999999999999999999999999999999777776766666666666670
9131319013330999444ff445445ff44099999999999999999933081bb18033099999999999999999999999999999999999999999997777777666666666666670
913131011313199954444ffffff4444099999999999999999011003bb30003399999999999999999999999999999999999999999997777767666666666666676
90313110131309992f454454444544f094499999999999999bb0007337000bb99999999999999999999999999999999999999999999669907666666666666676
901113111313199904f5445444454f4099942499999999999b300078870003b09999999999999999999999999999999999999999999999996600066666666606
9901111013131999954ff454444ff559999992249999999907000008800907b09999999999999999999999999999999999999999999999996600000000006606
999000011311199990554ffffff54509422224999999999907709060060907709999999999999999999999999999999999999999999999990990009990090090
99999991111119999905555444555099999999999999999997799900009997709999999999999999999999999999999999999999999999966999000990096690
99999990111109999990055555500999999999999999999999799999999999799999999999999999999999999999999999999999999999966999900999996699
__map__
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0010110000002021000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000003031000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000222300000000003400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000323300240000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
2021000000002223000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
3031000000003233000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
95030000100501005010050100551f000220002400024000290002b0002e000330003500035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
490400002405024050240502405500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4908000028052280522b0522b05230052300523005230052300323001200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002

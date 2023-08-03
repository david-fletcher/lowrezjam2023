pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- game title
-- jammigans and fletch
-- made for #lowrezjam 2023

-- g_ for globals
-- k_ for keyboard keys
-- e_ for enumerated values

-- globals
local g_current_state = nil
local g_debug = {true, false} -- 1 is CPU usage, 2 is player / wall data
local g_muted = false

-- magic numbers
local k_left = 0
local k_right = 1
local k_up = 2
local k_down = 3
local k_confirm = 4

-- constants
local g_game_states = {e_splash=0, e_menu=1, e_loading=2, e_playing=3}
local g_world_width = 1024
local g_world_height = 512
local g_tilesize = 16
local g_world_tilewidth = 64
local g_world_tileheight = 32

-->8
-- lifecycle
function _init()
    -- 64x64 mode!
    poke(0x5f2c, 3)

    -- set transparencies
    palt(0, false)
    palt(2, true)

    -- TODO: turn back to g_game_states.e_splash before release!
    g_current_state = g_game_states.e_splash
end

function _update()
    if (g_current_state == g_game_states.e_splash) then
        update_splashscreen()
    elseif (g_current_state == g_game_states.e_menu) then
        update_menu()
    elseif (g_current_state == g_game_states.e_loading) then
        init_playing()
    elseif (g_current_state == g_game_states.e_playing) then
        update_playing()
    end
end

function _draw()
    cls(0)

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
end

-->8
-- splashscreen
local g_splash = {
    curFrame = 0,
    totFrame = 120,
}

function update_splashscreen()
				if g_splash.curFrame == 20 then
			     play_sfx(2)
				end
    g_splash.curFrame += 1
    
    if (g_splash.curFrame > g_splash.totFrame) then
        g_current_state = g_game_states.e_menu
        g_splash.curFrame = 0
    end
end

function draw_splashscreen()
    -- the "animation" will just be drawing things slightly different on the screen depending on what frame we're on
    local color = 0
    if (g_splash.curFrame > 0 and g_splash.curFrame < 10) or (g_splash.curFrame >= 100 and g_splash.curFrame < 110) then
        color = 5
    elseif (g_splash.curFrame >= 10 and g_splash.curFrame < 20) or (g_splash.curFrame >= 90 and g_splash.curFrame < 100) then
        color = 6
    elseif (g_splash.curFrame >= 20 and g_splash.curFrame < 90) then
        color = 7
    end

    print("a game by", 14, 23, color)
    print("jammigans", 14, 29, color)
    print("& fletch",  16, 35, color)
end

-->8
-- menu
local g_title = {
    x = 22,
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
    rectfill(20, 13, 42, 21, 8)
    print("title", g_title.x, g_title.y, 7)

    -- print the menu options
    print(g_menu.options[1], g_menu.x, g_menu.y, g_menu.selected == 1 and 7 or 5)
    print(g_menu.options[2], g_menu.x + 8 + (#g_menu.options[1]*4), g_menu.y, g_menu.selected == 2 and 7 or 5)
    print(g_menu.options[3], g_menu.x + 16 + (#g_menu.options[1]*4) + (#g_menu.options[2]*4), g_menu.y, g_menu.selected == 3 and 7 or 5)

    -- show mute state
    local color = 7
    if (g_muted) then
        color = 5
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
    height = 2
}

local g_walls = {}

function init_playing()
    for i=0,g_world_tilewidth-1 do
        add(g_walls, {})
        for j=0,g_world_tileheight-1 do
            local celx = i*2
            local cely = j*2 -- we multiply by two because with a tilesize of 16, each tile will take up two 8x8 map cels
            local sprite = mget(celx, cely)

            if (sprite == 2) then -- wall
                add(g_walls[i+1], true)
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
    end

    if (btnp(k_right) and g_player.tilex < g_world_tilewidth and not g_walls[g_player.tilex+1][g_player.tiley]) then
        g_player.tilex += 1
    end

    if (btnp(k_up) and g_player.tiley > 1 and not g_walls[g_player.tilex][g_player.tiley-1]) then
        g_player.tiley -= 1
    end

    if (btnp(k_down) and g_player.tiley < g_world_tileheight and not g_walls[g_player.tilex][g_player.tiley+1]) then
        g_player.tiley += 1
    end

    -- calculate player x and y
    -- subtract 8 from y for a nice perspective / centered in the middle of the tile
    g_player.drawx = (g_tilesize / 2) - (g_player.width * 8 / 2) + (g_tilesize * (g_player.tilex-1))
    g_player.drawy = (g_tilesize / 2) - (g_player.height * 8 / 2) + (g_tilesize * (g_player.tiley-1)) - 4

    -- camera movement
    if (g_player.drawx-g_camera.xtarget <= 16 and g_camera.xtarget > 0) then
        g_camera.xtarget -= 16
    end

    if (g_player.drawx-g_camera.xtarget >= 48 and g_camera.xtarget < g_world_width-64) then
        g_camera.xtarget += 16
    end

    if (g_player.drawy-g_camera.ytarget <= 16 and g_camera.ytarget > 0) then
        g_camera.ytarget -= 16
    end

    if (g_player.drawy-g_camera.ytarget >= 48 and g_camera.ytarget < g_world_height-64) then
        g_camera.ytarget += 16
    end

    -- lerp towars our target
    g_camera.x = lerp(g_camera.x, g_camera.xtarget, 0.3)
    g_camera.y = lerp(g_camera.y, g_camera.ytarget, 0.3)

    -- check for collectibles
end

function draw_playing()
    camera(g_camera.x, g_camera.y)

    -- for every map row
    for j=0,64 do
        if (g_player.tiley == (j+1)/2) then
            rect(g_player.drawx, g_player.drawy+4, g_player.drawx+15, g_player.drawy+19, 6)
            spr(6, g_player.drawx, g_player.drawy, g_player.width, g_player.height)
        end
        map(0, j, 0, j*8, 128, 1)
    end

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

__gfx__
00000000222222223333333313333333333333331333333322222222222222220000000000000000000000000000000000000000000000000000000000000000
00000000228228223333333313333333333333331333333322222222222222220000000000000000000000000000000000000000000000000000000000000000
0070070028822882bbbbbbbb1abbbbbb333333331333333322222222222222220000000000000000000000000000000000000000000000000000000000000000
0007700022288222333333331b333333111111111111111122222b2222b222220000000000000000000000000000000000000000000000000000000000000000
0007700022888822333333331b333333000000000000000022222b2222b222220000000000000000000000000000000000000000000000000000000000000000
0070070022288222333333331b333333000000000000000022222b2222b222220000000000000000000000000000000000000000000000000000000000000000
0000000022288222333333331b333333000000000000000022222bbbbbb222220000000000000000000000000000000000000000000000000000000000000000
00000000222222221111111111111111000000000000000022222bbb77b222220000000000000000000000000000000000000000000000000000000000000000
0000000000000000bbbb1bbbbbb1bbbb000000000000000022222bbb77b222220000000000000000000000000000000000000000000000000000000000000000
000000000000000033331b333331b3330000000000000000222bbbbbbbbbb2220000000000000000000000000000000000000000000000000000000000000000
000000000000000033331333333133330000000000000000222bbbbbbbbbb2220000000000000000000000000000000000000000000000000000000000000000
00000000000000001111111111111111000000000000000022222666666222220000000000000000000000000000000000000000000000000000000000000000
00000000000000001111111111111111000000000000000022222112211222220000000000000000000000000000000000000000000000000000000000000000
00000000000000001111110111111110000000000000000022222112211222220000000000000000000000000000000000000000000000000000000000000000
00000000000000001111110111111110000000000000000022222112211222220000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000022222112211222220000000000000000000000000000000000000000000000000000000000000000
__map__
0203020302030203020302030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
1213121312131213121312130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000040504050000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000020302030000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000121312130000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
95030000100501005010050100551f000220002400024000290002b0002e000330003500035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
490400002405024050240502405500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4908000028052280522b0522b05230052300523005230052300323001200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002

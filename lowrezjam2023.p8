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
local g_game_states = {e_splash=0, e_menu=1, e_playing=2}
local g_current_state = nil
local g_debug = false
local g_muted = false

-- magic numbers
local k_left = 0
local k_right = 1
local k_up = 2
local k_down = 3
local k_confirm = 4

local g_world_width = 1024
local g_world_height = 512

-->8
-- lifecycle
function _init()
    -- 64x64 mode!
    poke(0x5f2c, 3)

    -- TODO: turn back to g_game_states.e_splash before release!
    g_current_state = g_game_states.e_playing
end

function _update()
    if (g_current_state == g_game_states.e_splash) then
        update_splashscreen()
    elseif (g_current_state == g_game_states.e_menu) then
        update_menu()
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

    if (g_debug) then
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
        function() g_current_state = g_game_states.e_playing end, -- play
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
    x = 16,
    y = 16
}

-- TODO: have a load call to pull all of the map into objects that live in memory
-- TODO: update and draw every object in the objects list

function update_playing()
    -- player movement
    if(btnp(k_left) and g_player.x >= 16) then
        g_player.x -= 16
    end

    if (btnp(k_right) and g_player.x <= g_world_width-16) then
        g_player.x += 16
    end

    if (btnp(k_up) and g_player.y >= 16) then
        g_player.y -= 16
    end

    if (btnp(k_down) and g_player.y <= g_world_height-16) then
        g_player.y += 16
    end

    -- camera movement
    if (g_player.x - g_camera.xtarget <= 0) then
        g_camera.xtarget -= 16
    end

    if (g_player.x - g_camera.xtarget >= 48) then
        g_camera.xtarget += 16
    end

    if (g_player.y - g_camera.ytarget <= 0) then
        g_camera.ytarget -= 16
    end

    if (g_player.y - g_camera.ytarget >= 48) then
        g_camera.ytarget += 16
    end

    -- lerp towars our target
    g_camera.x = lerp(g_camera.x, g_camera.xtarget, 0.3)
    g_camera.y = lerp(g_camera.y, g_camera.ytarget, 0.3)

    -- check for collectibles
end

function draw_playing()
    camera(g_camera.x, g_camera.y)
    map(0, 0, 0, 0, 128, 32)

    spr(3, g_player.x, g_player.y, 2, 2)
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
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700004444944444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000004444944444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000004444944444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700004444944444440000000003300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000009999999999990000000033090000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000004444444494440000000033399900000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000004444444494440000000033300000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000004444444494440000000077700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000004444444494440000000044400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000009999999999990000000044400000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000004944444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000004944444444440000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__gff__
0001010000000000000000000000000000010100000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
0000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
__sfx__
95030000100501005010050100551f000220002400024000290002b0002e000330003500035000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
490400002405024050240502405500000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
4908000028052280522b0522b05230052300523005230052300323001200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002000020000200002

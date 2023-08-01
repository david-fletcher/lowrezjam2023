pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- game title
-- jammigans and fletch
-- made for #lowrezjam 2023

-- globals
local GAME_STATES = {SPLASH=0, MENU=1, PLAYING=2}
local _gameState = nil
local _debug = false
local _muted = false

-- magic numbers
local k_left = 0
local k_right = 1
local k_confirm = 4

-->8
-- lifecycle
function _init()
    -- 64x64 mode!
    poke(0x5f2c, 3)

    -- TODO: turn back to GAME_STATES.SPLASH before release!
    _gameState = GAME_STATES.MENU
end

function _update()
    if (_gameState == GAME_STATES.SPLASH) then
        updateSplashScreen()
    elseif (_gameState == GAME_STATES.MENU) then
        updateMenu()
    elseif (_gameState == GAME_STATES.PLAYING) then
        updatePlaying()
    end
end

function _draw()
    cls(0)

    if (_gameState == GAME_STATES.SPLASH) then
        drawSplashScreen()
    elseif (_gameState == GAME_STATES.MENU) then
        drawMenu()
    elseif (_gameState == GAME_STATES.PLAYING) then
        drawPlaying()
    end

    if (_debug) then
        print(_gameState, 0, 0, 7)
    end
end

-->8
-- splashscreen
local _splash = {
    curFrame = 0,
    totFrame = 120,
}

function updateSplashScreen()
    _splash.curFrame += 1
    
    if (_splash.curFrame > _splash.totFrame) then
        _gameState = GAME_STATES.MENU
        _splash.curFrame = 0
    end
end

function drawSplashScreen()
    -- the "animation" will just be drawing things slightly different on the screen depending on what frame we're on
    local color = 0
    if (_splash.curFrame > 0 and _splash.curFrame < 10) or (_splash.curFrame >= 100 and _splash.curFrame < 110) then
        color = 5
    elseif (_splash.curFrame >= 10 and _splash.curFrame < 20) or (_splash.curFrame >= 90 and _splash.curFrame < 100) then
        color = 6
    elseif (_splash.curFrame >= 20 and _splash.curFrame < 90) then
        color = 7
    end

    print("a game by", 14, 23, color)
    print("jammigans", 14, 29, color)
    print("& fletch",  16, 35, color)
end

-->8
-- menu
local _title = {
    x = 22,
    y = 15,
}

local _menu = {
    options = { "play", "toggle sfx", "quit" },
    xTarget = { 24, -12, -48 }, -- calculated x values to center each option
    actions = {
        function() _gameState = GAME_STATES.PLAYING end, -- play
        function() _muted = not _muted end, -- mute sfx
        function() run() end -- quit
    },
    selected = 1,
    x = 24,
    y = 40
}

function updateMenu()
    if (btnp(k_left) and _menu.selected > 1) then
        _menu.selected -= 1
    end

    if (btnp(k_right) and _menu.selected < #_menu.options) then
        _menu.selected += 1
    end

    if (btnp(k_confirm)) then
        _menu.actions[_menu.selected]() -- run the function
    end

    _menu.x = lerp(_menu.x, _menu.xTarget[_menu.selected], 0.25)
end

function drawMenu()
    rectfill(20, 13, 42, 21, 8)
    print("title", _title.x, _title.y, 7)

    -- print the menu options
    print(_menu.options[1], _menu.x, _menu.y, _menu.selected == 1 and 7 or 5)
    print(_menu.options[2], _menu.x + 8 + (#_menu.options[1]*4), _menu.y, _menu.selected == 2 and 7 or 5)
    print(_menu.options[3], _menu.x + 16 + (#_menu.options[1]*4) + (#_menu.options[2]*4), _menu.y, _menu.selected == 3 and 7 or 5)

    -- show mute state
    local color = 7
    if (_muted) then
        color = 5
        line(56, 57, 61, 61, color)
    end
    print(chr(141), 56, 57, color)
end

-->8
-- playing
function updatePlaying()

end

function drawPlaying()
    print("playing!", 20, 29, 8)
end

-->8
-- helper functions
function lerp(from, to, weight)
    local dist = to - from
    if (abs(dist) < 0.2) then return to end
    return (dist * weight) + from
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

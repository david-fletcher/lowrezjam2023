pico-8 cartridge // http://www.pico-8.com
version 41
__lua__
-- game title
-- jammigans and fletch
-- made for #lowrezjam 2023

-- globals
local STATES = {SPLASH=0, MENU=1}
local _gameState = nil
local _debug = true

-->8
-- lifecycle
function _init()
    -- 64x64 mode!
    poke(0x5f2c, 3)

    -- TODO: turn back to STATES.SPLASH before release!
    _gameState = STATES.MENU
end

function _update()
    if (_gameState == STATES.SPLASH) then
        updateSplashScreen()
    elseif (_gameState == STATES.MENU) then
        updateMenu()
    end
end

function _draw()
    cls(0)

    if (_gameState == STATES.SPLASH) then
        drawSplashScreen()
    elseif (_gameState == STATES.MENU) then
        drawMenu()
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
        _gameState = STATES.MENU
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

function updateMenu()

end

function drawMenu()
    rectfill(20, 13, 42, 21, 8)
    print("title", _title.x, _title.y, 7)
end

__gfx__
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00077000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000
00700700000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000000

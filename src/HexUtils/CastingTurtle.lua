local expect = require("cc.expect")
local expect, field = expect.expect, expect.field
local Defer = require("HexUtils/Defer")

local CastingTurtle = {}

CastingTurtle.runPattern = function(wand, startDir, angles)
    expect(1, wand, "table")
    field(wand, "runPattern", "function")
    expect(2, startDir, "string")
    expect(3, angles, "string")
    
    
    local timer = os.startTimer(0.1)
    Defer(function()
        while true do
            local event, tid, mhname, mhmsg = os.pullEvent()
            if (event == "timer" and tid == timer) then
                os.queueEvent("cast_done", nil)
            elseif (event == "mishap") then
                os.queueEvent("cast_done", "Mishap "..tostring(mhname)..(mhmsg and ": "..tostring(mhmsg) or ""))
            end
        end
    end)
    
    wand.runPattern(startDir, angles)
    
    while true do
        local _,mishap = os.pullEvent("cast_done")
        if (mishap) then return false, mishap else return true end
    end
end

CastingTurtle.castHex = function(wand, hex, globals, clearStack)
    expect(1, wand, "table")
    field(wand, "runPattern", "function")
    expect(2, hex, "table")
    field(hex, "globals", "table")
    field(hex, "hex", "table")
    expect(3, globals, "table", "nil")
    
    if (globals ~= "") then
        local globalList = {}
        for i,p in pairs(hex.globals) do
            if (globalValues[i] ~= nil) then
                globalList[p] = globalValues[i]
            else
                globalList[p] = nil
            end
        end
        wand.setRavenmind(globalList)
    end
    
    if (clearStack ~= false) then wand.clearStack() end
    wand.pushStack(hex.hex)
    return CastingTurtle.runPattern(wand, "SOUTH_EAST", "deaqq") -- eval
end

CastingTurtle.isFocus = function(slot)
    expect(1, slot, "number")
    
    local i = turtle.getItemDetail(slot)
    return i and (i.name == "hexcasting:focus")
end

CastingTurtle.readFocus = function(wand, slot)
    expect(1, wand, "table")
    field(wand, "runPattern", "function")
    expect(2, slot, "number")
    
    turtle.select(slot)
    wand.runPattern("EAST", "aqqqqqe") -- ?read-offhand
    if (wand.popStack()) then
        wand.runPattern("EAST", "aqqqqq") -- read-offhand
        return wand.popStack()
    end
    return nil
end

CastingTurtle.writeFocus = function(wand, slot, value)
    expect(1, wand, "table")
    field(wand, "runPattern", "function")
    expect(2, slot, "number")
    
    turtle.select(slot)
    wand.pushStack(value)
    wand.runPattern("EAST", "deeeee") -- write-offhand
end


return CastingTurtle
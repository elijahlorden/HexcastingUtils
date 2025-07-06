local expect = require("cc.expect")
local Defer = require("HexUtils/Defer")
local CastingTurtle = require("HexUtils/CastingTurtle")
local CompilerProtocol = require("HexUtils/CompilerProtocol")

print("Compiling receive hex")
local ok, receiveHex = CompilerProtocol.getHex("app-remote-receive.xth", "hextweaks")
if (not ok) then error("Failed to get receive hex: "..receiveHex) end

hexapp.readConfig("hexremoteexec.cfg", {
    poll = false,
})

local basalt = hexapp.getBasalt()
local main = basalt.createFrame():setBackground(colors.black)
main:addLabel():setText("------ Chat Casting Interface ------"):setTextAlign("center"):setSize("parent.w-1", 1):setPosition(2,1):setBackground(colors.black):setForeground(colors.white)

local tx, ty = term.getSize()

local appTerm = hexapp.createTerminal(main, 2, 2, tx-2, ty-1):setBackground(colors.black):setForeground(colors.white):focus()
_G.appterm = appTerm
Defer.onError(function(err, trace) appTerm:printError("Error: "..err); appTerm:print(trace) end)

local appCommands = nil
local cmdTrace = nil
local debugPrint = false
appCommands = {
    ["clear"] = function() appTerm:clear() end,
    ["trace"] = function() if (cmdTrace) then appTerm:print(cmdTrace) end end,
    ["test"] = function()
        local c = { "red", "green", "lightGray", "blue", "yellow", "purple", "lightBlue" }
        local s = ""
        for i=1,2000 do
            s = s.."&f:"..(c[((i-1)%#c)+1])..";"..i
        end
        appTerm:print(s)
    end,
    
    ["help_help"] = "help [cmd]",
    ["help"] = function(cmd)
        local sf = "_help"
        if (type(cmd) == "string" and appCommands[cmd..sf]) then
            appTerm:print(appCommands[cmd..sf])
            return
        end
        appTerm:print("--- Available Commands ---")
        for i,p in pairs(appCommands) do
            if (i:sub(-#sf) ~= sf) then appTerm:print(i) end
        end
    end,
    
    ["test-compile"] = function(hex)
        expect(1, hex, "string")
        local ok, result = CompilerProtocol.getHex(hex, "hextweaks")
        if (ok) then
            appTerm:print("Hex found")
        else
            appTerm:printError(result)
        end
    end,
    
    ["test-user"] = function(slot)
        
    end,
    
    ["poll"] = function(en) expect(1, en, "boolean", "nil"); if (en ~= nil) then hexapp.configBool("poll", en); hexapp.writeConfig(); appTerm:print(en and "Enabled polling" or "Disabled polling") else appTerm:print(hexapp.configBool("poll") and "Polling is enabled" or "Polling is disabled") end end,
    ["log"] = function(en) expect(1, en, "boolean"); debugPrint = en; appTerm:print(en and "Logging enabled" or "Logging disabled") end,
    ["cache"] = function(en) expect(1, en, "boolean"); end,
    
}

function topupMedia()
    local missing = 64 - turtle.getItemCount(16)
    if (missing > 32) then turtle.select(16); turtle.suckDown(missing) end
end

function receive(wand)
    local ok, err = CastingTurtle.castHex(wand, receiveHex)
    if (not ok) then return false, err end
    if not (wand.popStack()) then return true, nil end
    local caster = wand.popStack()
    local cmd = wand.popStack()
    return true, cmd, caster
end

function send(slot, hex, globals)
    
end

local Tokenizer = require("HexUtils/Tokenizer")

appTerm:onReturn(function(text)
    local tk = Tokenizer.fromString(text, "localcommand")
    if (not tk:hasNext()) then return end
    local cmdTkn = tk:next()
    if (type(cmdTkn.value) ~= "string" or not appCommands[cmdTkn.value]) then appTerm:print("Invalid command '"..tostring(cmdTkn.value).."', type 'help' to see a list of commands") return end
    
    local tArgs = {}
    while (tk:hasNext()) do
        local v = tk:next().value
        if (v == "true") then table.insert(tArgs, true)
        elseif (v == "false") then table.insert(tArgs, false)
        else table.insert(tArgs, v) end
    end
    
    appTerm:print(">"..text)
    local ok, err = xpcall(appCommands[cmdTkn.value], function(e) cmdTrace = debug.traceback(); return e end, table.unpack(tArgs))
    if (not ok) then appTerm:printError(err) end
    
    
end)


local wand = peripheral.find("wand")

Defer(function()
    while true do
        os.sleep(0.25)
        if (not hexapp.configBool("poll")) then
            os.sleep(5)
        else
            topupMedia()
            for i=1,15 do
                if (CastingTurtle.isFocus(i)) then
                    turtle.select(i)
                    local ok, result, caster = receive(wand)
                    if (ok) then
                        if (result) then
                            appTerm:print("Received '"..result.."' from "..caster)
                        end
                    else
                        if (string.find(result, "MishapNotEnoughMedia")) then
                            appTerm:printError("Out of media")
                        else
                            appTerm:printError(result)
                        end
                        appTerm:print("Disabled polling")
                        hexapp.configBool("poll", false)
                        hexapp.writeConfig()
                    end
                end
            end
            
            
            
            
            
            
        end
    end
end)

--Defer(function() while true do appTerm:print(os.pullEvent()) end end)




--[[hexapp.schedule(function()
    --hexapp.turtle.castSpell("app-turtle-test.xth", {})
    
end)--]]

parallel.waitForAll(hexapp.scheduler.autoUpdate, Defer.autoUpdate, basalt.autoUpdate)

--[[local wand = peripheral.find("wand")

wand.runPattern("EAST", "aqqqqq")

hexapp.writeFile("disk/dump.txt", textutils.serialize(wand.popStack()))--]]




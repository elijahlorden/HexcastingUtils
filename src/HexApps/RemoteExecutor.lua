hexapp.turtle.init(true, true)

hexapp.readConfig("hexremoteexec.cfg", {
    slotDesignations = "iiiimmff********",
    users = {}
})

local iotaIndex = {} -- Schema { type = "property|gate|mote|entity", slot = 0, idx = 1 }

local basalt = hexapp.getBasalt()
local main = basalt.createFrame():setBackground(colors.black)
main:addLabel():setText("---------- Remote Executor ---------"):setTextAlign("center"):setSize("parent.w-1", 1):setPosition(2,1):setBackground(colors.black):setForeground(colors.white)

local tx, ty = term.getSize()

local appTerm = hexapp.createTerminal(main, 2, 2, tx-2, ty-1):setBackground(colors.black):setForeground(colors.white):focus()

local appCommands = {
    ["test"] = function()
        local c = { "red", "green", "lightGray", "blue", "yellow", "purple", "lightBlue" }
        local s = ""
        for i=1,2000 do
            s = s.."&f:"..(c[((i-1)%#c)+1])..";"..i
        end
        appTerm:print(s)
    end,
    
    ["help"] = function()
        appTerm:print("--- Available Commands ---")
        for i,p in pairs(appCommands) do
            appTerm:print(i)
        end
    end,
    
    ["list-slots"] = function()
    
    end,
    
    ["list-slot-types"] = function()
        appTerm:print("--- Slot Types ---")
        appTerm:print("free\nmedia\nfuel\niotastore")
    end,
    
    ["set-slot"] = function(slot, slottype)
        
    end,
    
    ["list-users"] = function()
        
    end,
    
    ["create-user"] = function(name)
    
    end,
    
    ["remove-user"] = function(name)
    
    end,
    
    ["test-user-async"] = function(name)
    
    end,
    
    ["write-user-props"] = function(name, slot)
        
    end,
    
    ["create-user-cad"] = function(name, slot)
    
    end,
    
    ["create-user-cad-async"] = function(name, slot)
    
    end,
    
}

function indexIotas()
    
end

function storeTopIota(key)
    
end

function findIota(key)
    
end

function pushIota(indexObj)
    
end

function removeIota(indexObj)
    
end

local Tokenizer = require("HexUtils/Tokenizer")

appTerm:onReturn(function(text)
    local tk = Tokenizer.fromString(text, "localcommand")
    if (not tk:hasNext()) then return end
    local cmdTkn = tk:next()
    if (type(cmdTkn.value) ~= "string") then appTerm:print("Invalid command") return end
    
    while (tk:hasNext()) do
        local t = tk:next()
        appTerm:print(type(t.value)..": "..t.value)
    end
    
    
    
    
    
    
end)


local wand = peripheral.find("wand")









--[[hexapp.schedule(function()
    --hexapp.turtle.castSpell("app-turtle-test.xth", {})
    
end)--]]

parallel.waitForAll(hexapp.scheduler.autoUpdate, basalt.autoUpdate)

--[[local wand = peripheral.find("wand")

wand.runPattern("EAST", "aqqqqq")

hexapp.writeFile("disk/dump.txt", textutils.serialize(wand.popStack()))--]]




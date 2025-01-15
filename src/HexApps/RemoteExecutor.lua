hexapp.turtle.init(true, true)



function focusType(focus)
end

local basalt = hexapp.getBasalt()
local main = basalt.createFrame():setBackground(colors.black)
main:addLabel():setText("---------- Remote Executor ---------"):setTextAlign("center"):setSize("parent.w-1", 1):setPosition(2,1):setBackground(colors.black):setForeground(colors.white)

local tx, ty = term.getSize()

local appTerm = hexapp.createTerminal(main, 2, 2, tx-2, ty-1):setBackground(colors.black):setForeground(colors.white):focus()

appTerm:onReturn(function(text)
    if (text == "test") then
        hexapp.schedule(function()
            for i=1,15 do
                appTerm:print(i)
                os.sleep(0.1)
            end
        end)
    elseif (text == "test2") then
        local c = { "red", "green", "lightGray", "blue", "yellow", "purple", "lightBlue" }
        local s = ""
        for i=1,2000 do
            s = s.."&f:"..(c[((i-1)%#c)+1])..";"..i
        end
        appTerm:print(s)
    elseif (text == "clear") then
        appTerm:clear()
    else
        appTerm:print(text)
    end
    
end)

--[[for i=1,50 do
    appTerm:print("Line "..i)
end--]]












--[[hexapp.schedule(function()
    --hexapp.turtle.castSpell("app-turtle-test.xth", {})
    
end)--]]

parallel.waitForAll(hexapp.scheduler.autoUpdate, basalt.autoUpdate)

--[[local wand = peripheral.find("wand")

wand.runPattern("EAST", "aqqqqq")

hexapp.writeFile("disk/dump.txt", textutils.serialize(wand.popStack()))--]]




hexapp.turtle.init()

hexapp.schedule(function()
    hexapp.turtle.castSpell("app-turtle-test.xth", {})
    
end)

hexapp.autoUpdate()

--[[local wand = peripheral.find("wand")

wand.runPattern("EAST", "aqqqqq")

hexapp.writeFile("disk/dump.txt", textutils.serialize(wand.popStack()))--]]




local port = peripheral.find("focal_port")
if (port == nil) then error("Focal Port not found", 0) end

local impetus = peripheral.find("cleric_impetus")
if (impetus == nil) then error("Cleric Impetus not found") end

hexapp.readConfig("hexcropfarm.cfg", {
    cropItem = "minecraft:wheat",
    seedItem = "minecraft:wheat_seeds",
    cropThreshold = 64,
    seedThreshold = 0,
    dustThreshold = 256,
    checkItemInterval = 10,
    lastRunTime = 0,
    autorun = false,
    state = "idle",
    cropCount = 0,
    seedCount = 0
})

local basalt = hexapp.getBasalt()
local main = basalt.createFrame()

local btnRunFarm, btnQueryStorage, btnAutoRun

do -- Button Panel
    local offsetX = 2
    local offsetY = 4
    main:addPane():setBackground(colors.black):setPosition(offsetX, offsetY):setSize(17, 13)
    
    btnRunFarm =      hexapp.createMomentaryButton(main, offsetX + 1, offsetY + 1, 15, 3, "Run Farm")
    btnQueryStorage = hexapp.createMomentaryButton(main, offsetX + 1, offsetY + 5, 15, 3, "Query Storage")
    btnAutoRun =      main:addButton():setSize(15, 3):setPosition(offsetX + 1, offsetY + 9):setText("Auto Run"):setHorizontalAlign("center"):setVerticalAlign("center"):setBackground(hexapp.config("autorun") and colors.green or colors.red)
end

local statusLabel, mediaLabel, mediaDiffLabel, storageCropLabel, storageSeedLabel

function updateStorageLabels(cropCount, seedCount)
    storageCropLabel:setText(tostring(cropCount)):setForeground((cropCount < hexapp.configNumber("cropThreshold")) and colors.yellow or colors.white)
    storageSeedLabel:setText(tostring(seedCount)):setForeground((seedCount < hexapp.configNumber("seedThreshold")) and colors.yellow or colors.white)
end

do -- Display Panel
    local offsetX = 21
    local offsetY = 4
    local width = 30
    local labelWidth = 14
    main:addPane():setBackground(colors.black):setPosition(offsetX, offsetY):setSize(width, 13)
    
    offsetX = offsetX + 1
    offsetY = offsetY + 1
    
    main:addLabel():setText("Status"):setPosition(offsetX, offsetY):setSize(labelWidth, 1):setBackground(colors.black):setForeground(colors.white)
    statusLabel = main:addLabel():setText("Idle"):setPosition(offsetX + labelWidth, offsetY):setSize((width - 2) - labelWidth, 1):setBackground(colors.black):setForeground(colors.white)
    offsetY = offsetY + 2
    
    main:addLabel():setText("Media"):setPosition(offsetX, offsetY):setSize(labelWidth, 1):setBackground(colors.black):setForeground(colors.white)
    mediaLabel = main:addLabel():setText(""):setPosition(offsetX + labelWidth, offsetY):setSize((width - 2) - labelWidth, 1):setBackground(colors.black):setForeground(colors.white)
    offsetY = offsetY + 2
    
    --main:addLabel():setText("Media Used"):setPosition(offsetX, offsetY):setSize(labelWidth, 1):setBackground(colors.black):setForeground(colors.white)
    --offsetY = offsetY + 2
    
    main:addLabel():setText("Stored Crops"):setPosition(offsetX, offsetY):setSize(labelWidth, 1):setBackground(colors.black):setForeground(colors.white)
    storageCropLabel = main:addLabel():setPosition(offsetX + labelWidth, offsetY):setSize((width - 2) - labelWidth, 1):setBackground(colors.black):setForeground(colors.white)
    offsetY = offsetY + 2
    
    main:addLabel():setText("Stored Seeds"):setPosition(offsetX, offsetY):setSize(labelWidth, 1):setBackground(colors.black):setForeground(colors.white)
    storageSeedLabel = main:addLabel():setPosition(offsetX + labelWidth, offsetY):setSize((width - 2) - labelWidth, 1):setBackground(colors.black):setForeground(colors.white)
    
    updateStorageLabels(hexapp.configNumber("cropCount"), hexapp.configNumber("seedCount"))
end

local errLabel = main:addLabel():setPosition(1, "parent.h-2"):setSize("parent.w", 2):setForeground(colors.red):setText("")

function disableAutorun()
    if (hexapp.config("autorun")) then
        hexapp.config("autorun", false)
        btnAutoRun:setBackground(colors.red) 
    end
end

btnRunFarm:onClick(function()
    if (hexapp.config("state") ~= "idle") then return end
    hexapp.config("state", "startFarm")
    hexapp.writeConfig()
end)

btnQueryStorage:onClick(function()
    if (hexapp.config("state") ~= "idle") then return end
    hexapp.config("state", "startQuery")
    hexapp.writeConfig()
end)

btnAutoRun:onClick(function()
    local en = not hexapp.config("autorun")
    hexapp.config("autorun", en)
    hexapp.writeConfig()
    btnAutoRun:setBackground(en and colors.green or colors.red)
end)

hexapp.createHeaderLabel(main, "Hex Crop Farm Controller", colors.gray)

hexapp.createConfigFrame(main, {
    {"cropItem", "Crop Item", "string"},
    {"seedItem", "Seed Item", "string"},
    {"dustThreshold", "Media Threshold", "number"},
    {"cropThreshold", "Crop Threshold", "number"},
    {"seedThreshold", "Seed Threshold", "number"},
    {"checkItemInterval", "Query Interval", "number"},
})

function castFarmSpell()
    hexapp.castSpellCircle(
    "app-cropfarm.xth",
    {
        cropitem = hexapp.iotaHexalItemType(hexapp.config("cropItem")),
        seeditem = hexapp.iotaHexalItemType(hexapp.config("seedItem")),
        queryList = {
            hexapp.iotaHexalItemType(hexapp.config("cropItem")),
            hexapp.iotaHexalItemType(hexapp.config("seedItem"))
        }
    },
    port, impetus)
end

function castQuerySpell()
    hexapp.castSpellCircle(
    "app-nexus-querylist.xth",
    {
        queryList = {
            hexapp.iotaHexalItemType(hexapp.config("cropItem")),
            hexapp.iotaHexalItemType(hexapp.config("seedItem"))
        }
    },
    port, impetus)
end

function processQueryResult(result)
    if (type(result) == "table" and result.queryList ~= nil and type(result.queryList) == "table" and #result.queryList == 2) then
        local cropCount = result.queryList[1]
        hexapp.config("cropCount", cropCount)
        
        local seedCount = result.queryList[2]
        hexapp.config("seedCount", seedCount)
        
        updateStorageLabels(cropCount, seedCount)
    else
        errLabel:setText("Invalid query spell result")
    end
end

local queryIntervalCount = 0

main:addThread():start(function()
    while true do
        if (impetus.isCasting()) then
            statusLabel:setText("Casting"):setForeground(colors.yellow)
            os.sleep(1)
            goto continue
        end
        local state = hexapp.config("state")
        if (state == "startFarm") then
            castFarmSpell()
            hexapp.config("state", "waitFarm")
            hexapp.writeConfig()
        elseif (state == "waitFarm") then
            local result, mishap = hexapp.getCircleResult("app-cropfarm.xth", port, impetus)
            if (result == nil) then -- Display error and disable autorun
                errLabel:setText(mishap)
                disableAutorun()
            else
                errLabel:setText("")
                
                
                
                
                
                
                
                
                
                processQueryResult(result)
            end
            hexapp.configNumber("lastRunTime", os.epoch("utc"))
            hexapp.config("state", "idle")
            hexapp.writeConfig()
        elseif (state == "startQuery") then
            castQuerySpell()
            hexapp.config("state", "waitQuery")
            hexapp.writeConfig()
        elseif (state == "waitQuery") then
            local result, mishap = hexapp.getCircleResult("app-nexus-querylist.xth", port, impetus)
            if (result == nil) then -- Display error and disable autorun
                errLabel:setText(mishap)
                disableAutorun()
            else
                errLabel:setText("")
                processQueryResult(result)
            end
            hexapp.configNumber("lastRunTime", os.epoch("utc"))
            hexapp.config("state", "idle")
            hexapp.writeConfig()
        elseif (state == "idle") then
            local media = hexapp.getImpetusDust(impetus)
            local addMedia = (media < hexapp.configNumber("dustThreshold"))
            mediaLabel:setText(tostring(media)):setForeground(addMedia and colors.yellow or colors.white)
            if (hexapp.config("autorun")) then
                if (hexapp.config("cropCount") < hexapp.configNumber("cropThreshold") or hexapp.configNumber("seedCount") < hexapp.configNumber("seedThreshold")) then -- Run farm
                        hexapp.config("state", "startFarm")
                        hexapp.writeConfig()
                else -- Otherwise query
                    local lastRunTime = hexapp.configNumber("lastRunTime")
                    if (type(lastRunTime) ~= "number") then lastRunTime = 0 end
                    local delta = os.epoch("utc") - lastRunTime
                    local interval = hexapp.configNumber("checkItemInterval")
                    if (type(interval) ~= "number") then interval = 10000 end
                    if (delta > interval) then
                        hexapp.config("state", "startQuery")
                        hexapp.writeConfig()
                    else
                        statusLabel:setText("Waiting"):setForeground(colors.white)
                        os.sleep(1)
                    end
                end
            else
                statusLabel:setText("Idle"):setForeground(colors.white)
                os.sleep(1)
            end
        else
            hexapp.config("state", "idle")
            hexapp.writeConfig()
            os.sleep(2)
        end
        ::continue::
    end
end)



basalt.autoUpdate()
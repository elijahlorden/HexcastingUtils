local hexapp = { _cfg = nil, _cfgName = nil }

-- =========== File Helpers =========== --

function hexapp.getRoot() return fs.getDir(shell.getRunningProgram()) end

function hexapp.readFile(path)
    local handle = io.open(path, "r")
    local str = handle:read("a")
    handle:close()
    return str
end

function hexapp.writeFile(path, text)
    local handle = io.open(path, "w")
    local str = handle:write(text)
    handle:close()
    return str
end

function hexapp.readConfig(name, defaults)
    local cfg = {}
    if (fs.exists(name)) then
        cfg = textutils.unserialize(hexapp.readFile(name))
    else
        cfg = {}
    end
    for i,p in pairs(defaults) do if (cfg[i] == nil) then cfg[i] = p end end
    hexapp._cfg = cfg
    hexapp._cfgName = name
    return cfg
end

function hexapp.writeConfig()
    hexapp.writeFile(hexapp._cfgName, textutils.serialize(hexapp._cfg))
end

function hexapp.config(...)
    local tArgs = {...}
    if (#tArgs > 1) then
        hexapp._cfg[ tArgs[1] ] = tArgs[2]
        return hexapp._cfg[ tArgs[1] ]
    elseif (#tArgs == 1) then
        return hexapp._cfg[ tArgs[1] ]
    else
        return hexapp._cfg
    end
end

function hexapp.configNumber(...)
    local tArgs = {...}
    if (#tArgs > 1) then
        local v = (type(tArgs[2]) == "number") and tArgs[2] or 0
        hexapp._cfg[ tArgs[1] ] = v
        return v
    elseif (#tArgs == 1) then
        local v = tonumber(hexapp._cfg[ tArgs[1] ])
        return (type(v) == "number") and v or 0
    else
        return hexapp._cfg
    end
end

-- =========== Hex Helpers =========== --

function hexapp.getHex(name)
    local hex = hexapp.hexes[name]
    if (hex == nil) then error("Hex '"..name.."' not found", 0) end
    return hex
end

function hexapp.iotaType(iota)
    local t = type(iota)
    if (t == "nil" or t == "number" or t == "string") then return t end
    
    if (t == "table") then
        if (iota.null == true) then return "nil" end
        if (iota.startDir ~= nil and iota.angles ~= nil) then return "pattern" end
        if (iota.x ~= nil and iota.y ~= nil and iota.z ~= nil) then return "vector" end
        
        
        
        
        
        if (#iota > 0) then return "list" end
    end
    
    return "garbage"
end

function hexapp.iotaNull() return { null = true } end
function hexapp.iotaVector(x, y, z) return { x = x, y = y, z = z } end
function hexapp.iotaPattern(startDir, angles) return { startDir = startDir, angles = angles } end

function hexapp.iotaHexalItemType(id) return { itemType = id, isItem = true } end
function hexapp.iotaHexalBlockType(id) return { itemType = id, isItem = false } end

function hexapp.packSpell(name, globalValues)
    local hex = hexapp.getHex(name)
    local globalList = {}
    
    for i,p in pairs(hex.globals) do
        if (globalValues[i] ~= nil) then
            globalList[p] = globalValues[i]
        else
            globalList[p] = hexapp.iotaNull()
        end
    end
    
    return { hex.hex, globalList }
end

function hexapp.unpackGlobals(name, globalList)
    local hex = hexapp.getHex(name)
    local globalValues = {}
    
    for i,p in pairs(hex.globals) do
        if (#globalList >= p) then
            globalValues[i] = globalList[p]
        else
            globalValues[i] = nil
        end
    end
    
    return globalValues
end

function hexapp.castSpellCircle(name, globalValues, port, impetus) -- Cast a spell using an app spell CAD circle
    if (impetus.isCasting()) then return end
    port.writeIota(hexapp.packSpell(name, globalValues))
    impetus.activateCircle()
end

function hexapp.getCircleResult(name, port, impetus) -- Returns (nil, mishap) or {globals}
    local mishap = impetus.getLastMishap()
    if (mishap ~= "") then return nil, mishap end
    local returnIota = port.readIota()
    if (hexapp.iotaType(returnIota) ~= "list") then return nil, "Returned iota was not a list" end
    return hexapp.unpackGlobals(name, returnIota)
end

function hexapp.getImpetusDust(impetus)
    return impetus.getMedia() / 10000
end












-- =========== Basalt Helpers =========== --

function hexapp.getBasalt()
    if (not fs.exists("/basalt.lua")) then
        print("Installing Basalt")
        shell.run("wget run https://basalt.madefor.cc/install.lua packed basalt-1.7.1.lua")
        shell.run("rename basalt-1.7.1.lua basalt.lua")
    end
    return require("/basalt")
end

function hexapp.createHeaderLabel(parent, text, background)
    return parent:addLabel():setText(text):setTextAlign("center"):setSize("parent.w", 1):setBackground(background or colors.gray)
end

function hexapp.createScrollFrameWithBar(parent, width, height, posX, posY) -- Returns { container = {}, frame = {}, bar = {}, update = function() }
    local container = parent:addFrame():setSize(width, height):setPosition(posX, posY)
    local scroll = container:addScrollableFrame():setSize("parent.w-1", "parent.h")
    local bar = container:addScrollbar():setSize(1, "parent.h"):setPosition("parent.w", 1)
    
    local function updateBar()
        local maxHeight = 0
        
        for i,p in pairs(scroll:getChildrenByType("VisualObject")) do
            local child = p.element
            maxHeight = math.max(maxHeight, child:getY() + child:getHeight())
        end
        
        if (maxHeight > scroll:getHeight()) then
            bar:show()
            scroll:setSize("parent.w-1", "parent.h")
        else
            bar:hide()
            scroll:setSize("parent.w", "parent.h")
        end
        
        bar:setScrollAmount((maxHeight - scroll:getHeight()) + 1)
        local _, offset = scroll:getOffset()
        bar:setIndex(offset + 1)
    end
    
    bar:onChange(function(self, _, value)
        scroll:setOffset(0, value - 1)
    end)
    
    scroll:onScroll(function()
        updateBar()
    end)
    
    updateBar()
    
    return { container = container, frame = scroll, bar = bar, update = updateBar }
end

function hexapp.createConfigFrame(parent, fields)
    local frame = parent:addFrame():setSize("parent.w", "parent.h-1"):setForeground(colors.white):setPosition(1, parent:getHeight())
    
    local header = frame:addLabel():setSize("parent.w", 1):setBackground(colors.black):setForeground(colors.white):setText("^ Config ^"):setTextAlign("center")
    local scroll = hexapp.createScrollFrameWithBar(frame, "parent.w-1", "parent.h-1", 2, 2)
    local scrollFrame = scroll.frame
    
    local shown = false
    local animDebounce = false
    
    header:onClick(function()
        if (animDebounce) then return end
        animDebounce = true
        shown = not shown
        
        -- Ghost cursor fix
        scrollFrame:clearFocusedChild()
        scrollFrame:setCursor(false) 
        
        if (shown) then
            header:setText("v Config v")
            frame:animatePosition(1, 2, 1.5, 0, "easeOut", function() animDebounce = false end)
        else
            header:setText("^ Config ^")
            frame:animatePosition(1, parent:getHeight(), 1.5, 0, "easeOut", function() animDebounce = false end)
        end
    end)
    
    local labelWidth = 0
    for i=1,#fields do labelWidth = math.max(labelWidth, fields[i][2]:len()) end
    labelWidth = labelWidth + 1
    
    for i=1,#fields do
        local configField, labelText, fieldType = table.unpack(fields[i])
        scrollFrame:addLabel():setSize(labelWidth, 1):setText(labelText):setPosition(1, i * 2)
        if (fieldType == "string") then
            local input = scrollFrame:addInput():setInputType("text"):setSize("parent.w - "..tostring(labelWidth + 1), 1):setPosition(labelWidth + 1, i * 2)
            input:setValue(hexapp.config(configField))
            input:onChange(function()
                hexapp.config(configField, input:getValue())
                hexapp.writeConfig()
            end)
        elseif (fieldType == "number") then
            local input = scrollFrame:addInput():setInputType("number"):setSize("parent.w - "..tostring(labelWidth + 1), 1):setPosition(labelWidth + 1, i * 2)
            input:setValue(hexapp.config(configField))
            input:onChange(function()
                hexapp.configNumber(configField, input:getValue())
                hexapp.writeConfig()
            end)
        elseif (fieldType == "checkbox") then
            
        end
    end
    
    scroll.update()
end

function hexapp.createMomentaryButton(parent, x, y, w, h, text)
    return parent:addButton()
    :setSize(w, h)
    :setPosition(x, y)
    :setText(text)
    :setHorizontalAlign("center")
    :setVerticalAlign("center")
    :setBackground(colors.lightBlue)
    :onClick(function(self) self:setBackground(colors.blue) end)
    :onRelease(function(self) self:setBackground(colors.lightBlue) end)
end
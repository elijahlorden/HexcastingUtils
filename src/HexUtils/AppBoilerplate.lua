local hexapp = { _cfg = nil, _cfgName = nil }

-- =========== Scheduler =========== --

do
    hexapp.scheduler = {}
    local coroutines = {} -- Schema: { { [coroutine], filter } }
    
    hexapp.scheduler.count = function()
        return #coroutines
    end
    
    hexapp.scheduler.update = function(event, ...)
        if (#coroutines == 0) then return end
        for i=#coroutines, 1, -1 do
            local c = coroutines[i][1]
            local f = coroutines[i][2]
            if (coroutine.status(c) == "dead") then
                table.remove(coroutines, i)
            elseif (f == nil or f == event) then
                local ok, result = coroutine.resume(c, event, ...)
                if (not ok) then error("Error in scheduled coroutine: "..result) end
                coroutines[i][2] = result -- New filter
            end
        end
    end
    
    hexapp.scheduler.autoUpdate = function()
        while true do
            hexapp.scheduler.update(os.pullEvent())
        end
    end
    hexapp.autoUpdate = hexapp.scheduler.autoUpdate
    
    function hexapp.schedule(f)
        local c = coroutine.create(f)
        local ok, result = coroutine.resume(c)
        if (not ok) then error("Error in scheduled coroutine: "..result) end
        table.insert(coroutines, { c, result })
    end
    
    function hexapp.setTimeout(t, f)
        hexapp.schedule(function()
            os.sleep(t)
            f()
        end)
    end
end

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
    handle:write(text)
    handle:close()
end

function hexapp.readTable(path)
    if (not fs.exists(path)) then return {} end
    return textutils.unserialize(hexapp.readFile(path) or "{}") or {}
end

function hexapp.writeTable(path, tbl)
    hexapp.writeFile(path, textutils.serialize(tbl))
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

function hexapp.configBool(...)
    local tArgs = {...}
    if (#tArgs > 1) then
        local v = not not tArgs[2]
        hexapp._cfg[ tArgs[1] ] = v
        return v
    elseif (#tArgs == 1) then
        return not not hexapp._cfg[ tArgs[1] ]
    else
        return hexapp._cfg
    end
end

-- =========== Hex Helpers =========== --

function hexapp.getHex(name)
    local hex = hexapp.hexes[name]
    if (hex == nil) then error("Hex '"..tostring(name).."' not found", 0) end
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
    if (mishap ~= "" and mishap ~= "That pattern isn't associated with any action") then return nil, mishap end -- I use an invalid pattern to end the circle early
    local returnIota = port.readIota()
    if (hexapp.iotaType(returnIota) ~= "list") then return nil, "Returned iota was not a list" end
    return hexapp.unpackGlobals(name, returnIota)
end

function hexapp.getImpetusDust(impetus)
    return impetus.getMedia() / 10000
end

do -- Spell circle FSM
    hexapp.circleStateMachine = { _instances = {} }
    local cfsm = {}
    function cfsm:cName(name) if (self.spells[name] == nil) then error("Unknown spell name "..name, 3) end end
    
    function cfsm:addSpell(name, filename) self.spells[name] = { filename = filename, hComplete = {}, hReceived = {} }; return self end
    function cfsm:getSpell() return hexapp.config(self.cfgName) end
    
    function cfsm:cast(name, globals)
        self:cName(name)
        if (hexapp.config(self.cfgName) ~= "idle") then return false end
        hexapp.castSpellCircle(self.spells[name].filename, globals, self.port, self.impetus)
        hexapp.config(self.cfgName, name)
        hexapp.writeConfig()
        return true
    end
    
    function cfsm:onComplete(name, callback)
        self:cName(name)
        table.insert(self.spells[name].hComplete, callback)
        return self
    end
    
    function cfsm:onIota(name, callback)
        self:cName(name)
        table.insert(self.spells[name].hReceived, callback)
        return self
    end
    
    function cfsm:step(skipWrite)
        local n = hexapp.config(self.cfgName)
        if (self.impetus.isCasting() or n == "idle") then return end
        local s = self.spells[n]
        local iota = self.port.readIota()
        for i,p in pairs(s.hComplete) do p(iota) end
        hexapp.config(self.cfgName, "idle")
        if (not skipWrite) then hexapp.writeConfig() end
    end
    
    function cfsm:receiveIota(iota)
        local n = hexapp.config(self.cfgName)
        local s = self.spells[n]
        if (n == "idle" or s == nil) then return end
        for i,p in pairs(s.hReceived) do p(iota) end
    end
    
    --[[function cfsm:createThreads(frame)
        local f = self
        frame:addThread():start(function()
            while true do
                f:step()
                os.sleep(1.5)
            end
        end)
        frame:addThread():start(function()
            while true do
                os.pullEvent("new_iota", peripheral.getName(f.impetus))
                local n = hexapp.config(f.cfgName)
                local s = f.spells[n]
                if (n == "idle" or s == nil) then return end
                local iota = f.port.readIota()
                for i,p in pairs(s.hReceived) do p(iota) end
            end
        end)
    end--]]
    
    function cfsm:stop()
        if (obj.instanceIdx ~= nil) then
            table.remove(hexapp.circleStateMachine._instances, obj.instanceIdx)
        end
    end

    function hexapp.circleStateMachine.new(name, port, impetus)
        if (type(name) ~= "string") then error("Argument 1: invalid type", 2) end
        if (type(port) ~= "table") then error("Argument 2: invalid type", 2) end
        if (type(impetus) ~= "table") then error("Argument 3: invalid type", 2) end
        if (peripheral.getType(port) ~= "focal_port") then error("Argument 2: invalid peripheral type "..peripheral.getType(port), 2) end
        if (peripheral.getType(impetus) ~= "cleric_impetus") then error("Argument 3: invalid peripheral type "..peripheral.getType(port), 2) end
        local obj = { spells = {}, cfgName = "cfsm_"..name, port = port, impetus = impetus }
        local n = hexapp.config(obj.cfgName)
        if (n == nil or n == "") then hexapp.config(obj.cfgName, "idle"); hexapp.writeConfig() end
        local instance = setmetatable(obj, { __index = cfsm })
        table.insert(hexapp.circleStateMachine._instances, instance)
        obj.instanceIdx = #hexapp.circleStateMachine._instances
        return instance
    end
    
    hexapp.schedule(function()
        while true do
            local _, impetus = os.pullEvent("new_iota")
            local iota
            for i=1,#hexapp.circleStateMachine._instances do
                local instance = hexapp.circleStateMachine._instances[i]
                if (peripheral.getName(instance.impetus) == impetus) then
                    if (iota == nil) then iota = instance.port.readIota() end
                    instance:receiveIota(iota)
                end
            end
        end
    end)
    
    hexapp.schedule(function()
        while true do
            if (#hexapp.circleStateMachine._instances > 0) then
                for i=1,#hexapp.circleStateMachine._instances do
                    hexapp.circleStateMachine._instances[i]:step(true)
                end
                hexapp.writeConfig()
                os.sleep(1.5)
            else
                os.sleep(5)
            end
        end
    end)

end

do  -- Basalt datagrid
    hexapp.datagrid = {}
    local dg = {}
    
    function dg:setColumns(cols)
        
    end
    function dg:getColumns() return self.columns end
    
    
    function dg:setKey(name)
        
    end
    function dg:getKey() return self.pk end
    
    
    function dg:setData(tbl)
        
    end
    function dg:getData() return self.rows end
    
    
    function dg:update()
        
    end
    
    function dg:draw()
        
    end
    
    function dg:setWidth(v) end
    function dg:setHeight(v) end
    
    function hexapp.datagrid.new(parent)
        local obj = { parent = parent, columns = {}, pk = nil, rows = nil, scrollIdx = 0 }
        
        return setmetatable(obj, { __index = dg })
    end
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
    :onClick(function(b) b:setBackground(colors.blue); hexapp.setTimeout(0.1, function() b:setBackground(colors.lightBlue) end) end)
    --:onRelease(function(self) self:setBackground(colors.lightBlue) end)
end


-- =========== Turtle Helpers =========== --

hexapp.turtle = {}

function hexapp.turtle.init()
    -- Mishap listener
    hexapp.schedule(function()
        while true do
            local _, _, mishap = os.pullEvent("mishap")
            print("MISHAP: "..mishap.."\n")
        end
    end)
end

function hexapp.turtle.isFocus(slot)
    local item = turtle.getItemDetail(slot)
    return item and (item.name == "hexcasting:focus")
end

function hexapp.turtle.castSpell(name, globalValues)
    local wand = peripheral.find("wand")
    local hex = hexapp.getHex(name)
    local globalList = {}
    
    for i,p in pairs(hex.globals) do
        if (globalValues[i] ~= nil) then
            globalList[p] = globalValues[i]
        else
            globalList[p] = nil
        end
    end
    
    wand.setRavenmind(globalList)
    wand.clearStack()
    --print(textutils.serialize(hex.hex))
    wand.pushStack(hex.hex)
    wand.runPattern("SOUTH_EAST", "deaqq")
    --wand.runPattern("EAST", "deeeee")
    
    
end

-- =========== Misc. Helpers =========== --

function hexapp.formatNumber(n)
  return tostring(n):reverse():gsub("%d%d%d", "%1,"):reverse():gsub("^,", "")
end

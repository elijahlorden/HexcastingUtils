local port = peripheral.find("focal_port")
if (port == nil) then error("Focal Port not found", 0) end

local impetus = peripheral.find("cleric_impetus")
if (impetus == nil) then error("Cleric Impetus not found") end

hexapp.readConfig("hexmoteterm.cfg", {
    
})

local tempNexusData = {}
local nexusData = hexapp.readTable("nexusdata.tbl") -- Schema: { { itemtype, displayname, recordcount, itemcount }, ... }
function writeNexusData() hexapp.writeTable("nexusdata.tbl", nexusData) end

local basalt = hexapp.getBasalt()
local main = basalt.createFrame()

local cfsm = hexapp.circleStateMachine.new("moteterm", port, impetus)

cfsm:addSpell("queryall", "app-nexus-queryall.xth")

cfsm:onIota("queryall", function(iota)
    if (type(iota) == "table" and #iota > 0) then
        table.insert(tempNexusData, iota)
    end
end)

cfsm:onComplete("queryall", function(iota)
    nexusData = {}
    for i=1,#tempNexusData do
        local subtable = tempNexusData[i]
        for p=1,#subtable do table.insert(nexusData, subtable[p]) end
    end
    writeNexusData()
    basalt.debug("Done! "..tostring(#nexusData).." records")
end)

hexapp.schedule(function()
    os.sleep(3)
    cfsm:cast("queryall", {})
end)

--[[
local dg = hexapp.dataGrid.new(main)

dg:setColumns({
    { name = "itemtype", title = "Item Type", type = "string" },
    { name = "displayname", title = "Name", type = "string" },
    { name = "itemcount", title = "Count", type = "number" },
    { name = "recordcount", title = "# Records", type = "number" }
})

dg:setKey("itemtype")

local testtbl = {}
for i=1,50 do local s = tostring(i) table.insert(testtbl, { itemtype = "minecraft:test"..s, displayname = "Test "..s, itemcount = i, recordCount = tostring(Math.floor(i / 10)) }) end
dg:setData(testtbl)--]]



-- Write a reusable casting FSM object

-- Virtualized item list, sort by display name probably.  Search bar, refresh page button, full refresh button, defrag button, import button
-- Full mote nexus query
    -- First get the total number of records + up to the first 256 (itemtype + display name + count + # of records)
    -- If more than 256, perform up to 3 additional queries to get the full list
-- Details panel with name, unlocalized name, # of records, export button

-- Maybe look at crafting after the above is working








parallel.waitForAll(hexapp.scheduler.autoUpdate, basalt.autoUpdate)
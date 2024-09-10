local port = peripheral.find("focal_port")
if (port == nil) then error("Focal Port not found", 0) end

local impetus = peripheral.find("cleric_impetus")
if (impetus == nil) then error("Cleric Impetus not found") end

hexapp.readConfig("hexmoteterm.cfg", {
    
})

local basalt = hexapp.getBasalt()
local main = basalt.createFrame()

-- Write a reusable casting FSM object

-- Virtualized item list, sort by display name probably.  Search bar, refresh page button, full refresh button, defrag button, import button
-- Full mote nexus query
    -- First get the total number of records + up to the first 256 (itemtype + display name + count + # of records)
    -- If more than 256, perform up to 3 additional queries to get the full list
-- Details panel with name, unlocalized name, # of records, export button

-- Maybe look at crafting after the above is working




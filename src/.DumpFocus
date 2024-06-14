local fileName = ...
if (not fileName) then error("Provide a target file name", 0) end

local port = peripheral.find("focal_port")
if (not port) then error("Failed to find focal port", 0) end
if (not port.hasFocus()) then error("Focal port is empty", 0) end

local iota = port.readIota()
local str = type(iota) == "table" and textutils.serialize(iota) or tostring(iota)

local handle = io.open(fileName, "w+")
handle:write(str)
handle:close()

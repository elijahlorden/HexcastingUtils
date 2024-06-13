local fileName = ...
if (not fileName) then error("Provide a target file name", 0) end

local port = peripheral.find("focal_port")
if (not port) then error("Failed to find focal port", 0) end
if (not port.hasFocus()) then error("Focal port is empty", 0) end

local iota = port.readIota()
if (type(iota) ~= "table") then error("Iota is not a pattern or list of patterns") end

local patterns = {}

if (iota.startDir and iota.angles) then
	table.insert(patterns, ".pattern "..iota.startDir:lower().." "..iota.angles)
else if (#iota > 0 and iota[0].startDir and iota[0].angles) then
	for i=1,#iota do
		local pattern = iota[i]
		if (pattern.startDir and pattern.angles) then
			table.insert(patterns, "Iota "..tostring(i)..": .pattern "..pattern.startDir:lower().." "..pattern.angles)
		end
	end
else
	error("Iota is not a pattern or list of patterns")
end

local handle = io.open(fileName, "w+")

for i=1,#patterns do
	handle:write(pattern.."\n")
end

handle:close()
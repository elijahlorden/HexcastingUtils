--[=[
local numberDirectionMap = {
	ne = "north_east",
	e = "east",
	se = "south_east",
	sw = "south_west",
	w = "west",
	nw = "north_west"
	
}

local function splitString(inputstr, sep)
  if sep == nil then
    sep = "%s"
  end
  local t = {}
  for str in string.gmatch(inputstr, "([^"..sep.."]+)") do
    table.insert(t, str)
  end
  return t
end

local function getNumberPattern(n, token)
	if (n < -2000 or n > 2000) then tokenError(tostring(n).." is out of range for predefined number patterns (-2000 to 2000)", token) end
	local idx = n + 2000
	local handle = io.open("/HexUtils/numbers_2000.txt", "r")
	handle:seek("set", 26 * idx)
	local str = handle:read(26)
	print(str)
	local parts = splitString(str, "-")
	local startDir = numberDirectionMap[parts[1]]:gsub("%s+", "")
	return { iType = "pattern", startDir = startDir, angles = parts[2]:gsub("%s+", "") }
end

local pattern = getNumberPattern(2000)

print(textutils.serialize(pattern))

local port = peripheral.find("focal_port")

port.writeIota({ startDir = pattern.startDir:upper(), angles = pattern.angles })



--]=]

local Promise = require("HexUtils/Promise")
--[[
local p = Promise.new(function(resolve, reject)
    resolve(123)
end):next(function(v)
    print(v)
    return Promise.new(function(resolve)
        resolve(456)
    end)
end):next(function(v)
    print(v)
end):catch(function(err, trace)
    print(err)
end)

local pi = 0;
function promiseFunc()
    return Promise.new(function(resolve, reject)
        pi = pi + 1
        resolve(pi)
    end)
end

local all = Promise.all({ promiseFunc(), promiseFunc(), promiseFunc() })

print(textutils.serialize(all:await()))
--]]
print(Promise.new(function(resolve, reject) resolve(1) end):next(function(v) return v + 1 end):await())

local Tokenizer = require("HexUtils/Tokenizer")
local se = require("HexUtils/StringEnumerator")


--[[
local s = se.new("123")
print(s:inc())
print(s:inc())
print(s:inc())
print(s:remaining())
--]]


local tkn = Tokenizer.new("test.xth", { "/" })



tkn:tokenize()

while true do
	local t,e = tkn:_tkNext()
	if (e) then print("Error: "..e) end
	if (not t) then break end
	if (type(t) == "number") then
		print("Number: "..t)
	else
		print(t)
	end
end
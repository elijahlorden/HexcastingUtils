local Compiler = require("HexUtils/lib/Compiler")
--local se = require("HexUtils/StringEnumerator")
--local Queue = require("HexUtils/Queue")

--[[
local q = Queue.new()

q:insert("abc")
q:insert("123")
q:insert("456")
q:insert("def")
q:remove()
print(q:peek(1))
print(q:peek(2))
print(q:peek(3))
print(q:peek(4))
--]]



--[[
local s = se.new("123")
print(s:inc())
print(s:inc())
print(s:inc())
print(s:remaining())
--]]

--
--local tokenizer = Tokenizer.new("test.xth", { "/" })


--[[
while true do
	local t,e = tkn:_nextToken()
	if (e) then print("Error: "..e) end
	if (not t) then break end
	if (type(t.value) == "number") then
		print("Number: "..t.value)
	else
		print(t.value)
	end
end--]]

local compiler = Compiler.new()
compiler:compile("test.xth", { "/" })
compiler:emit(Compiler.EmitMode.DuckyDumpToFile, "/test.dump")
compiler:emit(Compiler.EmitMode.DuckyFocalPort, peripheral.find("focal_port"))
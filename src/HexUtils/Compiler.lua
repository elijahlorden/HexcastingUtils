local Compiler = {}

Compiler.directives - {}

function Compiler:compile(targetFile)
	
end

function Compiler:tokenize(str)
	local tokens = {}
	
	
	
	
	
	
end







local _meta = { __index = Compiler }

Compiler.new = function()
	local c = setmetatable({}, _meta)
	return c
end

return Compiler
local Tokenizer = require("HexUtils/lib/Tokenizer")
local Queue = require("HexUtils/lib/Queue")

local Compiler = {}

local directions = {
	north_east = true,
	east = true,
	south_east = true,
	south_west = true,
	west = true,
	north_west = true
}

Compiler.EmitMode = {
	DumpToFile = 1, -- Serialize output iotas and write to file
	DuckyDumpToFile = 2, -- Convert output iotas to Ducky's Peripherals format and write to file
	DuckyFocalPort = 3, -- Write output iotas to a Ducky's Peripherals focal port as a list
	DuckyFocalPortSingle = 4 -- Write first output iota to a Ducky's Peripherals focal port
}

local function tokenErr(message, token)
	error(message.." ("..token.file..", line "..token.line..")", 0)
end

local directives = {
	
	["pattern"] = function(self, dirTkn) -- .pattern DIRECTION xxxx
		-- Get and validate direction
		local tkn, err = self._tokenizer:next()
		if (err) then error(err, 0) end
		if (not tkn) then tokenErr(".pattern expected string, got nil", tkn) end
		local direction = tkn.value
		if (type(direction) ~= "string") then tokenErr(".pattern expected string, got "..type(direction), tkn) end
		direction = direction:lower()
		if (not directions[direction]) then tokenErr("Invalid start direction '"..direction.."'", tkn) end
		-- Get and validate pattern
		tkn, err = self._tokenizer:next()
		if (err) then error(err, 0) end
		if (not tkn) then tokenErr(".pattern expected string, got nil", tkn) end
		local angles = tkn.value:lower()
		if (type(angles) ~= "string") then tokenErr(".pattern expected string, got "..type(angles), tkn) end
		if (angles:find("[^qaweds]")) then tokenErr("Invalid pattern angles", tkn) end
		local iota = { iType = "pattern", startDir = direction, angles = angles, token = dirTkn }
		if (self._compilingList) then
			table.insert(self._compilingList, iota)
		else
			table.insert(self._emitList, iota)
		end
	end,
	
	["str"] = function(self, dirTkn) -- .str [string|"string with whitespace"]
		local tkn, err = self._tokenizer:next()
		if (err) then error(err, 0) end
		if (not tkn) then tokenErr(".pattern expected string or number, got nil", tkn) end
		local iota = { iType = "string", value = tostring(tkn.value), token = dirTkn }
		if (self._compilingList) then
			table.insert(self._compilingList, iota)
		else
			table.insert(self._emitList, iota)
		end
	end,
	
	["param"] = function(self, dirTkn) -- Prompt the user to enter an iota (emit with $name) : .param name prompt
		if (self._compilingList) then tokenErr(".param is not valid during word compilation", dirTkn) end
		-- Get and validate param name
		local tkn, err = self._tokenizer:next()
		if (err) then error(err, 0) end
		if (not tkn) then tokenErr(".param expected string, got nil", tkn) end
		local paramName = tkn.value
		if (type(paramName) ~= "string") then tokenErr(".param expected string, got "..type(paramName), tkn) end
		if (self._params[paramName]) then tokenErr("A parameter with the name '"..paramName.."' already exists", tkn) end
		-- Get and validate param prompt
		tkn, err = self._tokenizer:next()
		if (err) then error(err, 0) end
		if (not tkn) then tokenErr(".param expected string, got nil", tkn) end
		local paramPrompt = tkn.value
		if (type(paramPrompt) ~= "string") then tokenErr(".param expected string, got "..type(paramPrompt), tkn) end
		-- Prompt
		term.write(paramPrompt)
		local result = read()
		local num = tonumber(result)
		if (num) then
			self._params[paramName] = num
		else
			self._params[paramName] = result
		end
	end,
	
	["param-port"] = function(self) -- Read an iota from a Ducky's Peripherals focal port (emit with $name): .param-iota name promot
		error(".param-port TBI")
	end
	
}

function Compiler:compile(targetFileName, targetDirectories)
	local tokenizer = Tokenizer.new(targetFileName, targetDirectories)
	self._tokenizer = tokenizer
	
	while true do
		local nextToken, err = tokenizer:next()
		if (err) then error(err, 2) end
		if (nextToken == nil) then break end
		
		if (type(nextToken.value) == "number") then -- Number literal
			local iota = { iType = "number", value = nextToken.value }
			if (self._compilingList) then
				table.insert(self._compilingList, iota)
			else
				table.insert(self._emitList, iota)
			end
		elseif (type(nextToken.value) == "string") then
			if (nextToken.value == ":") then -- Start word definition
				if (self._compilingList) then tokenErr("Nesting word definitions is not supported", nextToken) end
				local tkn, err = tokenizer:next()
				if (err) then error(err, 2) end
				if (not tkn) then tokenErr("Expected string, got nil", tkn) end
				local wordName = tkn.value
				if (type(wordName) ~= "string") then tokenErr("Expected string, got "..type(wordName), tkn) end
				if (wordName:sub(1,1) == ".") then tokenErr("Word names may not start with '.'", tkn) end
				if (self._words[wordName]) then tokenErr("A word with the name '"..wordName.."' already exists", tkn) end
				if (wordName:find("^[:;{}]$")) then tokenErr("Invalid word name '"..wordName.."'", tkn) end
				self._wordDefName = wordName
				self._compilingList = {}
			elseif (nextToken.value == ";") then -- End word definition
				if ((not (self._compilingList and self._wordDefName)) or #self._listStack > 0) then tokenErr("Unexpected ';'", nextToken) end
				self._words[self._wordDefName] = self._compilingList
				self._wordDefName = nil
				self._compilingList = nil
			elseif (nextToken.value == "{") then -- Start list
				if (self._compilingList) then
					table.insert(self._listStack, self._compilingList)
					self._compilingList = {}
				else
					self._compilingList = {}
				end
			elseif (nextToken.value == "}") then -- End list.  Emit or add to parent list
				if (not self._compilingList or (#self._listStack == 0 and self._wordDefName ~= nil)) then tokenErr("Unexpected '}'", nextToken) end
				if (#self._listStack > 0) then
					local parentList = table.remove(self._listStack, #self._listStack)
					table.insert(parentList, { iType = "list", value = self._compilingList })
					self._compilingList = parentList
				else
					table.insert(self._emitList, { iType = "list", value = self._compilingList })
					self._compilingList = nil
				end
			elseif (nextToken.value:sub(1, 1) == "$") then -- Emit parameter or add parameter to current list
				local paramName = nextToken:sub(2)
				local param = self._params[paramName]
				if (param == nil) then tokenErr("Unknown parameter '"..paramName.."'", nextToken) end
				local iota = { iType = type(param) == "number" and "number" or "string", value = param, token = nextToken }
				if (self._compilingList) then
					table.insert(self._compilingList, iota)
				else
					table.insert(self._emitList, iota)
				end
			elseif (nextToken.value:sub(1, 1) == ".") then -- Run compiler directive
				self:_runDirective(nextToken)
			else -- Emit word or add word contents to current list
				local wordName = nextToken.value
				local word = self._words[wordName]
				if (not word) then tokenErr("Unknown word '"..wordName.."'", nextToken) end
				if (self._compilingList) then
					for i=1,#word do
						table.insert(self._compilingList, textutils.unserialize(textutils.serialize(word[i])))
					end
				else
					for i=1,#word do
						table.insert(self._emitList, textutils.unserialize(textutils.serialize(word[i])))
					end
				end
			end
		else
			error("Invalid token type: "..type(nextToken.value))
		end
		
		
	end
	
end

function Compiler:_runDirective(dirTkn)
	local dirName = dirTkn.value:sub(2)
	local dirFunc = directives[dirName]
	if (dirFunc == nil) then error("Invalid compiler directive '"..dirName.."' ("..dirTkn.file..", line "..dirTkn.line..")", 0) end
	dirFunc(self, dirTkn)
end

-- Words consist of other words, lists, and iota objects.  Iota objects and lists are directly emitted.  Inner words are expanded recursively.
function Compiler:expandWord(word)
	if (self._compilingList) then
		
	else
		self:expandWord(tokenizer:next())
	end

	
end

local function duckyEmit(iota, list)
	if (iota.iType == "list") then
		local emitList = {}
		for i=1,#iota.value do duckyEmit(iota.value[i], emitList) end
		table.insert(list, emitList)
	elseif (iota.iType == "pattern") then
		table.insert(list, { startDir = iota.startDir:upper(), angles = iota.angles })
	elseif (iota.iType == "number" or iota.iType == "string") then
		table.insert(list, iota.value)
	else
		if (iota.token) then
			tokenErr("Iota type '"..iota.iType.."' is not supported for DuckyFocalPort emit", iota.token)
		else
			error("Iota type '"..iota.iType.."' is not supported for DuckyFocalPort emit", 0)
		end
	end
end

function Compiler:emit(mode, target)
	if (mode == Compiler.EmitMode.DumpToFile) then
		local handle = io.open(target, "w+")
		handle:write(textutils.serialize(self._emitList))
		handle:close()
	elseif (mode == Compiler.EmitMode.DuckyDumpToFile) then
		local duckyList = {}
		for i=1,#self._emitList do duckyEmit(self._emitList[i], duckyList) end
		local handle = io.open(target, "w+")
		handle:write(textutils.serialize(duckyList))
		handle:close()
	elseif (mode == Compiler.EmitMode.DuckyFocalPort) then
		local duckyList = {}
		for i=1,#self._emitList do duckyEmit(self._emitList[i], duckyList) end
		if (target == nil or (not target.writeIota) or (not target.hasFocus)) then error("Provide a focal port peripheral", 2) end
		if (not target.hasFocus()) then error("Target focal port is empty", 0) end
		if (target.writeIota(duckyList)) then
			print("Iotas written to focal port")
		else
			error("Focal port write failed")
		end
	elseif (mode == Compiler.EmitMode.DuckyFocalPortSingle) then
		
	end
	
end







local _meta = { __index = Compiler }

Compiler.new = function()
	local c = setmetatable({ _emitList = {}, _words = {}, _params = {}, _tokenizer = nil, _compilingList = nil, _listStack = {}, _wordDefName = nil }, _meta)
	return c
end

return Compiler
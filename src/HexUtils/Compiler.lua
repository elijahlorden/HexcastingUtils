local Tokenizer = require("HexUtils/Tokenizer")

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

local function addIota(self, iota)
	if (self._compilingList) then
		table.insert(self._compilingList, iota)
	else
		table.insert(self._emitList, iota)
	end
end

local function autoEscape(self)
	if (self._autoEscapeWord) then
		for i=1,#self._autoEscapeWord do
			addIota(self, self._autoEscapeWord[i])
		end
	end
end

local directives = {
	
	["pattern"] = function(self, dirTkn) -- .pattern DIRECTION xxxx
		-- Get and validate direction
		local tkn, err = self._tokenizer:next()
		if (err) then error(err, 0) end
		if (not tkn) then tokenErr(".pattern expected string, got nil", dirTkn) end
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
		autoEscape(self)
		addIota(self, { iType = "pattern", startDir = direction, angles = angles, token = dirTkn })
	end,
	
	["str"] = function(self, dirTkn) -- .str [string|"string with whitespace"]
		local tkn, err = self._tokenizer:next()
		if (err) then error(err, 0) end
		if (not tkn) then tokenErr(".str expected string or number, got nil", dirTkn) end
		autoEscape(self)
		addIota(self, { iType = "string", value = tostring(tkn.value), token = dirTkn })
	end,
	
	["vector"] = function(self, dirTkn) -- .vector x y z
		local vec = {}
		for i=1,3 do
			local tkn, err = self._tokenizer:next()
			if (err) then error(err, 0) end
			if (not tkn) then tokenErr(".vector expected number, got nil", dirTkn) end
			local n = tkn.value
			if (type(n) ~= "number") then tokenErr(".vector expected number, got "..type(n), tkn) end
			vec[i] = n
		end
		autoEscape(self)
		addIota(self, { iType = "vector", value = vec, token = dirTkn })
	end,
	
	["bool"] = function(self, dirTkn) -- .bool true|false
		local tkn, err = self._tokenizer:next()
		if (err) then error(err, 0) end
		if (not tkn) then tokenErr(".bool expected string got nil", dirTkn) end
		local str = tkn.value
		if (type(str) ~= "string") then tokenErr(".bool expected string, got "..type(str), tkn) end
		str = str:lower()
		if (str ~= "true" and str ~= "false") then tokenErr("'"..str.."' is not a valid boolean", tkn) end
		autoEscape(self)
		addIota(self, { iType = "bool", value = (str == "true"), token = dirTkn })
	end,
	
	["escape-on"] = function(self, dirTkn) -- Enable auto-escaping literal iotas.  Requires the 'push-iota' word to be defined.
		if (not self._words["push-iota"]) then tokenErr(".escape-on requires the word 'push-iota' to be defined", dirTkn) end
		self._autoEscapeWord = self._words["push-iota"]
	end,
	
	["escape-off"] = function(self, dirTkn) -- Disable auto-escaping literal iotas
		self._autoEscapeWord = nil
	end,
	
	["param"] = function(self, dirTkn) -- Prompt the user to enter an iota (emit with $name) : .param name prompt
		if (self._compilingList) then tokenErr(".param is not valid during word compilation", dirTkn) end
		-- Get and validate param name
		local tkn, err = self._tokenizer:next()
		if (err) then error(err, 0) end
		if (not tkn) then tokenErr(".param expected string, got nil", dirTkn) end
		local paramName = tkn.value
		if (type(paramName) ~= "string") then tokenErr(".param expected string, got "..type(paramName), tkn) end
		if (self._params[paramName]) then tokenErr("A parameter with the name '"..paramName.."' already exists", tkn) end
		-- Get and validate param prompt
		tkn, err = self._tokenizer:next()
		if (err) then error(err, 0) end
		if (not tkn) then tokenErr(".param expected string, got nil", dirTkn) end
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
	
	["param-port"] = function(self) -- Read an iota from a Ducky's Peripherals focal port (emit with $name): .param-port name promot
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
			autoEscape(self)
			addIota(self, { iType = "number", value = nextToken.value })
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
				addIota(self, { iType = type(param) == "number" and "number" or "string", value = param, token = nextToken })
			elseif (nextToken.value:sub(1, 1) == ".") then -- Run compiler directive
				self:_runDirective(nextToken)
			else -- Emit word or add word contents to current list
				local wordName = nextToken.value
				local word = self._words[wordName]
				if (not word) then tokenErr("Unknown word '"..wordName.."'", nextToken) end
				if (self._compilingList) then
					for i=1,#word do
						table.insert(self._compilingList, textutils.unserialize(textutils.serialize(word[i]))) -- Lazy deep copy
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

local function duckyEmit(self, iota, list)
	if (iota.iType == "list") then
		local emitList = {}
		for i=1,#iota.value do duckyEmit(self, iota.value[i], emitList) end
		table.insert(list, emitList)
	elseif (iota.iType == "pattern") then
		table.insert(list, { startDir = iota.startDir:upper(), angles = iota.angles })
	elseif (iota.iType == "number" or iota.iType == "string" or iota.iType == "bool") then
		table.insert(list, iota.value)
	elseif (iota.iType == "vector") then
		table.insert(list, { x = iota.value[1], y = iota.value[2], z = iota.value[3] })
	else
		if (iota.token) then
			tokenErr("Iota type '"..iota.iType.."' is not supported for DuckyFocalPort emit", iota.token)
		else
			error("Iota type '"..iota.iType.."' is not supported for DuckyFocalPort emit", 0)
		end
	end
	self._emitCount = self._emitCount + 1
end

function Compiler:emit(mode, target)
	if (mode == Compiler.EmitMode.DumpToFile) then
		local handle = io.open(target, "w+")
		handle:write(textutils.serialize(self._emitList))
		handle:close()
	elseif (mode == Compiler.EmitMode.DuckyDumpToFile) then
		local duckyList = {}
		self._emitCount = 1
		for i=1,#self._emitList do duckyEmit(self, self._emitList[i], duckyList) end
		local handle = io.open(target, "w+")
		handle:write(textutils.serialize(duckyList))
		handle:close()
	elseif (mode == Compiler.EmitMode.DuckyFocalPort) then
		local duckyList = {}
		self._emitCount = 1
		for i=1,#self._emitList do duckyEmit(self, self._emitList[i], duckyList) end
		if (target == nil or (not target.writeIota) or (not target.hasFocus)) then error("Provide a focal port peripheral", 2) end
		if (not target.hasFocus()) then error("Target focal port is empty", 0) end
		if (target.writeIota(duckyList)) then
			print(tostring(self._emitCount).." iota"..(self._emitCount == 1 and "" or "s").." written to focal port")
		else
			error("Focal port write failed")
		end
	elseif (mode == Compiler.EmitMode.DuckyFocalPortSingle) then
		local duckyList = {}
		duckyEmit(self, self._emitList[1], duckyList)
		if (target == nil or (not target.writeIota) or (not target.hasFocus)) then error("Provide a focal port peripheral", 2) end
		if (not target.hasFocus()) then error("Target focal port is empty", 0) end
		if (target.writeIota(duckyList[1])) then
			print("Iota written to focal port")
		else
			error("Focal port write failed")
		end
	end
end

local _meta = { __index = Compiler }

Compiler.new = function()
	local c = setmetatable({ _emitList = {}, _words = {}, _params = {}, _tokenizer = nil, _compilingList = nil, _listStack = {}, _wordDefName = nil, _autoEscapeWord = nil }, _meta)
	return c
end

return Compiler
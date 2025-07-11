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
	DumpToFile = 1,                 -- Serialize output iotas and write to file
	DuckyDumpToFile = 2,            -- Convert output iotas to Ducky's Peripherals format and write to file
	DuckyFocalPort = 3,             -- Write output iotas to a Ducky's Peripherals focal port as a list
	DuckyFocalPortSingle = 4,       -- Write first output iota to a Ducky's Peripherals focal port
	DuckyLink = 5,                  -- Send the output iotas as a list over an attached focal link
	DuckyLinkCircleBuilder = 6,     -- Used in conjunction with the circle builder artifact
    DuckyList = 7,                  -- Return the list of emitted iotas
    HexTweaksList = 8               -- Return the list of emitted iotas, formatted for HexTweaks deser
}

local numberDirectionMap = {
	ne = "north_east",
	e = "east",
	se = "south_east",
	sw = "south_west",
	w = "west",
	nw = "north_west"
}

local hexalIotaTypes = {
	["hexcasting:pattern"] = true,
    ["hexcasting:double"] = true,
    ["hexcasting:null"] = true,
    ["hexcasting:list"] = true,
    ["moreiotas:string"] = true,
    ["hexcellular:property"] = true,
}

local hexalIotaTypeAliases = {
    ["pattern"] = "hexcasting:pattern",
    ["double"] = "hexcasting:double",
    ["number"] = "hexcasting:double",
    ["list"] = "hexcasting:list",
    ["null"] = "hexcasting:null",
    ["string"] = "moreiotas:string",
    ["property"] = "hexcellular:property",
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

local function tokenErr(message, token)
	error(message.." ("..token.file..", line "..token.line..")", 0)
end

local function getPredefinedIntPattern(n, token)
	if (n < -2000 or n > 2000 or math.floor(n) ~= n) then tokenErr(tostring(n).." is out of range for predefined number patterns (integers from -2000 to 2000)", token) end
	local idx = n + 2000
	local handle = io.open("/HexUtils/numbers_2000.txt", "r")
	handle:seek("set", 26 * idx)
	local str = handle:read(26)
	handle:close()
	local parts = splitString(str, "-")
	local startDir = numberDirectionMap[parts[1]]:gsub("%s+", "")
	return { iType = "pattern", startDir = startDir, angles = parts[2]:gsub("%s+", "") }
end

local function getNumberPattern(n, token) -- The intent is to have multiple methods later
	return getPredefinedIntPattern(n, token)
end

local function addIota(self, iota)
	if (self._compilingList) then
		table.insert(self._compilingList, iota)
	else
		table.insert(self._emitList, iota)
	end
end

local function addIotas(self, tbl)
	if (self._compilingList) then
		for i=1,#tbl do table.insert(self._compilingList, tbl[i]) end
	else
		for i=1,#tbl do table.insert(self._emitList, tbl[i]) end
	end
end

local function autoEscape(self, token)
	if (self._inlineEscape or self._autoEscape) then
		local escapeWord = self._words["\\"]
		if (not escapeWord) then if(token) then tokenErr("Failed to escape iota, word '\\' is not defined", token) else error("Failed to escape iota, word '\\' is not defined", 0) end end
		addIotas(self, escapeWord)
	end
end

local function getDirArg(self, argNum, argType, dirTkn)
	local tkn, err = self._tokenizer:next()
	if (err) then error(err, 0) end
	if (not tkn) then tokenErr(dirTkn.value.." argument "..tonumber(argNum).."expected string, got nil", dirTkn) end
	local tknVal = tkn.value
	if (type(tknVal) ~= argType) then tokenErr(dirTkn.value.." argument "..tonumber(argNum).." expected string, got "..type(tknVal), tkn) end
	return tkn
end

local function getWord(self, name, token)
	local word = self._words[name]
	if (word == nil) then tokenErr(tostring(token.value).." requires the '"..name.."' word to be defined", token) end
	return word
end

local function duckySelectLink(target)
	if (target.numLinked() == 1) then
		return 0
	else
		print("Select a link: ")
		for i,p in pairs(target.getLinked()) do
			print(tostring(i).." : "..p)
		end
		term.write("> ")
		local selection = tonumber(io.read())
		if (selection == nil or selection < 1 or selection > target.numLinked()) then error("Invalid selection", 0) end
		return selection - 1
	end
end

local function getGlobalIdx(self, name, tkn)
    local gIdx = self._globals[name]
    if (gIdx == nil) then tokenErr("Undefined global '"..name.."'", nextToken) end
    return gIdx - 1
end

local directives = {
	
	["pattern"] = function(self, dirTkn) -- .pattern DIRECTION xxxx
		local direction = getDirArg(self, 1, "string", dirTkn).value:lower()
		local angles = getDirArg(self, 2, "string", dirTkn).value:lower()
		if (not directions[direction]) then tokenErr("Invalid start direction '"..direction.."'", dirTkn) end
		if (angles:find("[^qaweds]")) then tokenErr("Invalid pattern angles", dirTkn) end
		autoEscape(self, dirTkn)
		addIota(self, { iType = "pattern", startDir = direction, angles = angles, token = dirTkn })
	end,
	
	["include-tbl"] = function(self, dirTkn) -- .include-tbl filename
		local fileNameTkn = getDirArg(self, 1, "string", dirTkn)
		local fileName = fileNameTkn.value
		local filePath, err = self._tokenizer:findFile(fileName)
		if (err) then tokenErr(".include-tbl: "..err, fileNameTkn) end
		if (self._tokenizer:isPathIncluded(filePath)) then return end -- Ignore if already included
		self._tokenizer:markPathIncluded(filePath)
		local handle = io.open(filePath, "r")
		local tblStr = handle:read("a")
		handle:close()
		local tbl = textutils.unserialize(tblStr)
		if (not tbl) then tokenErr("File does not contain a valid table", fileNameTkn) end
		for i=1,#tbl do
			local entry = tbl[i]
			if (entry.type == "greatSpell") then
				if (type(entry.name) ~= "string") then tokenErr("Invalid great spell 'name' parameter '"..tostring(entry.name).."'", fileNameTkn) end
				local spellName = entry.name
				if (self._greatSpells[spellName]) then tokenErr("Duplicate great spell '"..spellName.."'", fileNameTkn) end
				if (not directions[entry.startDir]) then tokenErr("Invalid great spell 'startDir' parameter '"..entry.startDir.."'", fileNameTkn) end
				if (entry.angles:find("[^qaweds]")) then tokenErr("Invalid great spell 'angles' parameter '"..entry.angles.."'", fileNameTkn) end
				self._greatSpells[spellName] = { startDir = entry.startDir, angles = entry.angles }
			elseif (entry.type == "param") then
				error("Not implemented")
			end
		end
	end,
	
	["great-spell"] = function(self, dirTkn) -- .great-spell name
		local spellNameTkn = getDirArg(self, 1, "string", dirTkn)
		autoEscape(self, dirTkn)
		addIota(self, { iType = "greatSpell", value = spellNameTkn.value }) -- These are checked during emit
	end,

	["num"] = function(self, dirTkn) -- .num [number]
		local num = getDirArg(self, 1, "number", dirTkn)
		local pattern = getNumberPattern(num.value, dirTkn)
		autoEscape(self, dirTkn)
		addIota(self, pattern)
	end,

	["str"] = function(self, dirTkn) -- .str [string|"string with whitespace"]
		local tkn, err = self._tokenizer:next()
		if (err) then error(err, 0) end
		if (not tkn) then tokenErr(".str expected string or number, got nil", dirTkn) end
		autoEscape(self, dirTkn)
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
		autoEscape(self, dirTkn)
		addIota(self, { iType = "vector", value = vec, token = dirTkn })
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
		autoEscape(self, dirTkn)
		addIota(self, { iType = "vector", value = vec, token = dirTkn })
	end,
	
	["null"] = function(self, dirTkn) -- .null
		autoEscape(self, dirTkn)
		addIota(self, { iType = "null" })
	end,
	
	["iotatype"] = function(self, dirTkn) -- .iotatype [name]
		local name = getDirArg(self, 1, "string", dirTkn)
		name = name.value:lower()
        if (hexalIotaTypeAliases[name]) then name = hexalIotaTypeAliases[name] end
		if (not hexalIotaTypes[name]) then tokenErr("Unknown iota type, see hexalIotaTypes in HexLibs/compiler.lua", dirTkn) end
		autoEscape(self, dirTkn)
		addIota(self, { iType = "moreiotas:iotatype", value = name, token = dirTkn })
	end,
	
	["entitytype"] = function(self, dirTkn) -- .entitytype [name]
		local name = getDirArg(self, 1, "string", dirTkn)
		autoEscape(self, dirTkn)
		addIota(self, { iType = "moreiotas:entitytype", value = name.value, token = dirTkn })
	end,
	
	["itemtype"] = function(self, dirTkn) -- .itemtype [name]
		local name = getDirArg(self, 1, "string", dirTkn)
		autoEscape(self, dirTkn)
		addIota(self, { iType = "moreiotas:itemtype", value = name.value, token = dirTkn })
	end,
	
	["blocktype"] = function(self, dirTkn) -- .itemtype [name]
		local name = getDirArg(self, 1, "string", dirTkn)
		autoEscape(self, dirTkn)
		addIota(self, { iType = "moreiotas:blocktype", value = name.value, token = dirTkn })
	end,
	
	["escape-on"] = function(self, dirTkn) -- Enable auto-escaping literal iotas.  Requires the 'push-iota' word to be defined.
		if (not self._words["\\"]) then tokenErr(".escape-on requires the word '\\' to be defined", dirTkn) end
		self._autoEscape = true
	end,
	
	["escape-off"] = function(self, dirTkn) -- Disable auto-escaping literal iotas
		self._autoEscape = false
	end,
	
	["global"] = function(self, dirTkn) -- .global [name]
		local nameTkn = getDirArg(self, 1, "string", dirTkn)
		local name = nameTkn.value
		if (self._globals[name] ~= nil) then tokenErr("Duplicate global definition", dirTkn) end 
		self._nGlobals = self._nGlobals + 1
		self._globals[name] = self._nGlobals
	end,
	
	["init-globals"] = function(self, dirTkn) -- Write a list of NULLs to the ravenmind, one entry for each global
		if (self._nGlobals == 0) then return end
		
		local wEscape = getWord(self, "\\", dirTkn)
		local wWriteRavenmind = getWord(self, "write-ravenmind", dirTkn)
		local wNull = getWord(self, "null", dirTkn)
		local wRep = getWord(self, "rep", dirTkn)
		local wWrapMany = getWord(self, "list-wrap-many", dirTkn)
		
		local patterns = {}
		
		local function addWord(w) for i=1,#w do table.insert(patterns, w[i]) end end
		
		-- null # rep # list-wrap-many write-ravenmind
		addWord(wNull)
		table.insert(patterns, { iType = "#globals", token = dirTkn })
		addWord(wRep)
		table.insert(patterns, { iType = "#globals", token = dirTkn })
		addWord(wWrapMany)
		addWord(wWriteRavenmind)
		
		if (self._autoEscape or self._inlineEscape) then
			addIotas(self, wEscape)
			addIota(self, { iType = "list", value = patterns, token = dirTkn })
		else
			addIotas(self, patterns)
		end
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
		
		-- This should happen in the tokenizer, but it was easier to add here.
		if (type(nextToken.value) == "string" and #nextToken.value > 1 and nextToken.value:sub(1,1) == "\\" and not nextToken.value:find("^\\[}:;]")) then -- Any words starting with \ should be escaped
			nextToken.value = nextToken.value:sub(2)
			local num = tonumber(nextToken.value)
			if (num ~= nil and nextToken.value:sub(1,1) ~= '.') then nextToken.value = num end
			self._inlineEscape = true
		else
			self._inlineEscape = false
		end
		
		
		if (type(nextToken.value) == "string" and nextToken.value:find("^g[@!]%w+")) then -- Reading and writing globals
			local gIdx = getGlobalIdx(self, nextToken.value:sub(3), nextToken)
            local idxp = getPredefinedIntPattern(gIdx, nextToken)
			
			local patterns = {}
			
			local wEscape = getWord(self, "\\", nextToken)
			local wReadRavenmind = getWord(self, "read-ravenmind", nextToken)
            for i=1,#wReadRavenmind do table.insert(patterns, wReadRavenmind[i]) end -- read-ravenmind
			
			if (nextToken.value:sub(2,2) == "@") then -- Read (read-ravenmind [index of global] read-list-item)
				local wReadList = getWord(self, "read-list-item", nextToken)
                
				table.insert(patterns, idxp) -- [index of global]
				for i=1,#wReadList do table.insert(patterns, wReadList[i]) end -- read-list-item
			else -- Write (read-ravenmind [index of global] rot write-list-item write-ravenmind)
				local wRot = getWord(self, "rot", nextToken)
				local wWriteList = getWord(self, "write-list-item", nextToken)
				local wWriteRavenmind = getWord(self, "write-ravenmind", nextToken)
                
				table.insert(patterns, idxp) -- [index of global]
				for i=1,#wRot do table.insert(patterns, wRot[i]) end -- rot
				for i=1,#wWriteList do table.insert(patterns, wWriteList[i]) end -- write-list-item
				for i=1,#wWriteRavenmind do table.insert(patterns, wWriteRavenmind[i]) end -- write-ravenmind
			end
			
			if (self._autoEscape or self._inlineEscape) then
				addIotas(self, wEscape)
				addIota(self, { iType = "list", value = patterns, token = nextToken })
			else
				addIotas(self, patterns)
			end
        elseif (type(nextToken.value) == "string" and nextToken.value:find("^g#%w+")) then -- Global indexing
            local gIdx = getGlobalIdx(self, nextToken.value:sub(3), nextToken)
            autoEscape(self, nextToken)
            addIota(self, getPredefinedIntPattern(gIdx, nextToken))
		elseif (type(nextToken.value) == "number") then -- Number literal
			autoEscape(self, nextToken)
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
				self._nWords = self._nWords + 1
			elseif (nextToken.value == ";") then -- End word definition
				if ((not (self._compilingList and self._wordDefName)) or #self._listStack > 0) then tokenErr("Unexpected ';'", nextToken) end
				self._words[self._wordDefName] = self._compilingList
				self._wordDefName = nil
				self._compilingList = nil
			elseif (nextToken.value == "{") then -- Start list
				autoEscape(self, nextToken)
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
				autoEscape(self, nextToken)
				addIota(self, { iType = type(param) == "number" and "number" or "string", value = param, token = nextToken })
			elseif (nextToken.value:sub(1, 1) == ".") then -- Run compiler directive
				self:_runDirective(nextToken)
			else -- Emit word or add word contents to current list
				local wordName = nextToken.value
				local word = self._words[wordName]
				if (not word) then tokenErr("Unknown word '"..wordName.."'", nextToken) end
				if (self._inlineEscape) then -- inline-escaped words (ex. '\wordname') should emit consideration + the word as a list
					local iota = { iType = "list", value = textutils.unserialize(textutils.serialize(word)), token = nextToken }
					local escapeWord = self._words["\\"]
					if (not escapeWord) then tokenErr("inline escape requires word '\\' to be defined", nextToken) end
					addIotas(self, escapeWord)
					addIota(self, iota)
				else
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
			end
		else
			error("Invalid token type: "..type(nextToken.value))
		end
	end
	
	print("Compile done: "..tostring(self._nWords).." words")
end

function Compiler:_runDirective(dirTkn)
	local dirName = dirTkn.value:sub(2)
	local n = tonumber(dirName)
	if (n ~= nil) then
		local pattern = getNumberPattern(n, dirTkn)
		autoEscape(self, dirTkn)
		addIota(self, pattern)
	else
		local dirFunc = directives[dirName]
		if (dirFunc == nil) then error("Invalid compiler directive '"..dirName.."' ("..dirTkn.file..", line "..dirTkn.line..")", 0) end
		dirFunc(self, dirTkn)
	end
end

function Compiler:getGlobals()
    return textutils.unserialize(textutils.serialize(self._globals)), self._nGlobals
end

local function duckyEmit(self, iota, list)
	if (iota.iType == "list") then
		local emitList = {}
		for i=1,#iota.value do duckyEmit(self, iota.value[i], emitList) end
		table.insert(list, emitList)
	elseif (iota.iType == "pattern") then
		table.insert(list, { startDir = iota.startDir:upper(), angles = iota.angles })
	elseif (iota.iType == "greatSpell") then
		local pattern = self._greatSpells[iota.value]
		if (not pattern) then error("Great spell '"..iota.value.."' not found, add it with .AddGreatSpell",0) end
		table.insert(list, { startDir = pattern.startDir:upper(), angles = pattern.angles })
	elseif (iota.iType == "number" or iota.iType == "string" or iota.iType == "bool") then
		table.insert(list, iota.value)
    elseif (iota.iType == "#globals") then
        local pattern = getNumberPattern(self._nGlobals, iota.token)
        table.insert(list, { startDir = pattern.startDir:upper(), angles = pattern.angles })
	elseif (iota.iType == "null") then
		table.insert(list, { null = true })
	elseif (iota.iType == "vector") then
		table.insert(list, { x = iota.value[1], y = iota.value[2], z = iota.value[3] })
	elseif (iota.iType == "moreiotas:iotatype") then
		table.insert(list, { iotaType = iota.value })
	elseif (iota.iType == "moreiotas:entitytype") then
		table.insert(list, { entityType = iota.value })
	elseif (iota.iType == "moreiotas:itemtype") then
		table.insert(list, { itemType = iota.value, isItem = true })
	elseif (iota.iType == "moreiotas:blocktype") then
		table.insert(list, { itemType = iota.value, isItem = false })
	else
		if (iota.token) then
			tokenErr("Iota type '"..iota.iType.."' is not supported for Ducky emit", iota.token)
		else
			error("Iota type '"..iota.iType.."' is not supported for Ducky emit", 0)
		end
	end
	self._emitCount = self._emitCount + 1
end

local htTypes = {
    null = "hextweaks:null",
    list = "hextweaks:list",
    pattern = "hextweaks:pattern",
    iotaType = "hextweaks:iotatype",
    itemType = "hextweaks:itemtype",
    entityType = "hextweaks:entitytype",
    vector3 = "hextweaks:vec3"
}

local function hexTweaksEmit(self, iota, list)
	if (iota.iType == "list") then
		local emitList = { ["iota$serde"] = htTypes.list }
		for i=1,#iota.value do hexTweaksEmit(self, iota.value[i], emitList) end
		table.insert(list, emitList)
	elseif (iota.iType == "pattern") then
		table.insert(list, { startDir = iota.startDir:upper(), angles = iota.angles, ["iota$serde"] = htTypes.pattern })
	elseif (iota.iType == "greatSpell") then
		local pattern = self._greatSpells[iota.value]
		if (not pattern) then error("Great spell '"..iota.value.."' not found, add it with .AddGreatSpell",0) end
		table.insert(list, { startDir = pattern.startDir:upper(), angles = pattern.angles, ["iota$serde"] = htTypes.pattern })
	elseif (iota.iType == "number" or iota.iType == "string" or iota.iType == "bool") then
		table.insert(list, iota.value)
    elseif (iota.iType == "#globals") then
        local pattern = getNumberPattern(self._nGlobals, iota.token)
        table.insert(list, { startDir = pattern.startDir:upper(), angles = pattern.angles, ["iota$serde"] = htTypes.pattern })
	--[[elseif (iota.iType == "null") then
		table.insert(list, { null = true })--]]
	elseif (iota.iType == "vector") then
		table.insert(list, { x = iota.value[1], y = iota.value[2], z = iota.value[3], ["iota$serde"] = htTypes.vector3 })
	elseif (iota.iType == "moreiotas:iotatype") then
		table.insert(list, { id = iota.value, ["iota$serde"] = htTypes.iotaType })
	elseif (iota.iType == "moreiotas:entitytype") then
		table.insert(list, { id = iota.value, ["iota$serde"] = htTypes.entityType })
	elseif (iota.iType == "moreiotas:itemtype") then
		table.insert(list, { id = iota.value, type = "item", ["iota$serde"] = htTypes.itemType })
	elseif (iota.iType == "moreiotas:blocktype") then
		table.insert(list, { id = iota.value, type = "block", ["iota$serde"] = htTypes.itemType })
	else
		if (iota.token) then
			tokenErr("Iota type '"..iota.iType.."' is not supported for HexTweaks emit", iota.token)
		else
			error("Iota type '"..iota.iType.."' is not supported for HexTweaks emit", 0)
		end
	end
	self._emitCount = self._emitCount + 1
end

function Compiler:emit(mode, target)
	if (#self._emitList == 0) then error("No compiled iotas to emit", 0) return end
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
		self._emitCount = 0
		duckyEmit(self, self._emitList[1], duckyList)
		if (target == nil or (not target.writeIota) or (not target.hasFocus)) then error("Provide a focal port peripheral", 2) end
		if (not target.hasFocus()) then error("Target focal port is empty", 0) end
		if (target.writeIota(duckyList[1])) then
			print("Iota written to focal port")
		else
			error("Focal port write failed")
		end
	elseif (mode == Compiler.EmitMode.DuckyLink) then
		local duckyList = {}
		self._emitCount = 1
		for i=1,#self._emitList do duckyEmit(self, self._emitList[i], duckyList) end
		if (target == nil or (not target.sendIota) or (not target.numLinked)) then error("Provide a focal link peripheral", 2) end
		if (target.numLinked() == 0) then error("Target focal link is not linked to anything", 2) end
		local idx = duckySelectLink(target)
		target.sendIota(idx, duckyList)
	elseif (mode == Compiler.EmitMode.DuckyLinkCircleBuilder) then
		-- Only patterns can be written onto slates.  Throw an error if this spell contains anything other than patterns.
		for i=1,#self._emitList do if (self._emitList[i].iType ~= "pattern") then if (self._emitList[i].token) then tokenErr("Circles don't support non-pattern iotas", self._emitList[i].token) else error("Circles don't support non-pattern iotas", 0) end end end
		
		local duckyList = {}
		self._emitCount = 1
		for i=1,#self._emitList do duckyEmit(self, self._emitList[i], duckyList) end
		
		if (target == nil or (not target.sendIota) or (not target.numLinked)) then error("Provide a focal link peripheral", 2) end
		if (target.numLinked() == 0) then error("Target focal link is not linked to anything", 2) end
		local linkIdx = duckySelectLink(target)
		local idx = 1
		local nextIotaString = "get-next-iota"
		
		target.clearReceivedIotas()
		print("Waiting for caster")
		
		while true do
			local event = os.pullEvent()
			if (event == "received_iota") then
				local promptIota = target.receiveIota()
				if (type(promptIota) == "string" and promptIota == nextIotaString) then
					print("Sending next iota")
					target.sendIota(linkIdx, duckyList[idx])
					idx = idx + 1
					if (idx > #duckyList) then print("Last iota sent") break else print("Waiting for caster") end
				end
			end
		end
    elseif (mode == Compiler.EmitMode.DuckyList) then
		local duckyList = {}
		self._emitCount = 1
		for i=1,#self._emitList do duckyEmit(self, self._emitList[i], duckyList) end
        print("Compiled "..tostring(self._emitCount).." iotas")
        return duckyList
    elseif (mode == Compiler.EmitMode.HexTweaksList) then
		local emitList = { ["iota$serde"] = htTypes.list }
		self._emitCount = 1
		for i=1,#self._emitList do hexTweaksEmit(self, self._emitList[i], emitList) end
        print("Compiled "..tostring(self._emitCount).." iotas")
        return emitList
	end
end

local _meta = { __index = Compiler }

Compiler.new = function()
	local c = setmetatable({ _emitList = {}, _words = {}, _greatSpells = {}, _nWords = 0, _params = {}, _tokenizer = nil, _compilingList = nil, _listStack = {}, _wordDefName = nil, _autoEscape = false, _nGlobals = 0, _globals = {} }, _meta)
	return c
end

return Compiler
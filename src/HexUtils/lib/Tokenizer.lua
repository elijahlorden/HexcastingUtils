local StringEnumerator = require("HexUtils/lib/StringEnumerator")
local Queue = require("HexUtils/lib/Queue")

local Tokenizer = {}

function Tokenizer:_readFile(path)
	local handle = io.open(path, "r")
	local str = handle:read("a")
	handle:close()
	return str
end

function Tokenizer:_moveNextNonWhitespace()
	local enum = self._ctx.enum
	while (enum:remaining() > 0 and enum:peek():find("%s")) do
		local c = enum:next()
		if (c == "\n") then self._ctx.line = self._ctx.line + 1 end
	end
end

local _numstartchars = "0123456789-"

function Tokenizer:_tkNext()
	local enum = self._ctx.enum
	self:_moveNextNonWhitespace()
	if (enum:remaining() == 0) then return true, nil end
	local schar = enum:peek()
	local schar2 = enum:remaining() > 1 and enum:peek(2)
	if (schar:find("[0123456789-]")) then -- Number
		return self:_tkNum()
	elseif (schar == "\"" or schar == "'") then -- String
		return self:_tkString()
	elseif (schar2 == "//" or schar2 == "/*") then -- Comment
		self:_tkComment()
		return self:_tkNext()
	else -- Word
		return self:_tkWord()
	end
end

function Tokenizer:_tkComment()
	local enum = self._ctx.enum
	if (enum:remaining() == 0) then return true end
	local start = enum:next(2)
	if (start == "//") then -- Rest-of-line comment
		while (enum:remaining() > 0 and enum:peek() ~= "\n") do enum:inc() end
	elseif (start == "/*") then -- Block comment
		while (enum:remaining() >= 0) do
			local c = enum:next()
			if (c == "\n") then self._ctx.line = self._ctx.line + 1 end
			if (c == "*" and enum:peek() == "/") then
				enum:inc()
				return true
			end
		end
	else
		error("Invalid call to _tkComment", 2)
	end
end

function Tokenizer:_tkWord()
	local enum = self._ctx.enum
	if (enum:remaining() == 0) then return false, "EOF" end
	local tbl = {}
	while (enum:remaining() > 0 and not enum:peek():find("%s")) do
		table.insert(tbl, enum:next())
	end
	return true, table.concat(tbl)
end

function Tokenizer:_tkString()
	local enum = self._ctx.enum
	if (enum:remaining() == 0) then return false, "EOF" end
	local startchar = enum:next()
	local startline = self._ctx.line
	local tbl = {}
	while true do
		if (enum:remaining() == 0) then return false, ("Incomplete string ("..self._ctx.filePath..", line "..startline..")") end
		local c = enum:next()
		if (c == "\n") then self._ctx.line = self._ctx.line + 1 end
		if (c == "\\" and enum:remaining() > 0) then
			local nc = enum:next()
			if (nc == "n") then
				table.insert(tbl, "\n")
			elseif (nc == "t") then
				table.insert(tbl, "\t")
			else
				table.insert(tbl, nc)
			end
		elseif (c == startchar) then
			break
		else
			table.insert(tbl, c)
		end
		
	end
	return true, table.concat(tbl)
end

function Tokenizer:_tkNum()
	local success, str = self:_tkWord()
	if (not success) then return false, str end
	if (str == nil) then return false, "EOF" end
	local num = tonumber(str)
	if (num == nil) then return false, ("Invalid number '"..str.."' ("..self._ctx.filePath..", line "..self._ctx.line..")") end
	return true, num
end

function Tokenizer:findFile(name)
	local files = {}
	for i=1,#self._files do
		local f = self._files[i]
		if (#f >= #name and f:sub(-#name) == name) then
			table.insert(files, f)
		end
	end
	if (#files == 0) then return nil, "File not found"
	elseif (#files == 1) then return files[1]
	elseif (#files > 1) then return nil, "Filename ambiguous"
	else return nil end
end

local _meta = { __index = Tokenizer }

Tokenizer.new = function(rootFile, rootDirs)
	if (type(rootFile) ~= "string") then error("Argument 1: expected string, got "..type(rootFile), 2) end
	local rootDirs = rootDirs or {}
	if (type(rootDirs) ~= "table") then error("Argument 2: expected table, got"..type(rootDirs), 2) end
	
	-- Recursively gets all the files of a directory
	local expand = function(rootDir, files)
		local dirStack = { rootDir }
		local files = files or {}
		while (#dirStack > 0) do
			local dir = table.remove(dirStack, #dirStack)
			if (not fs.isDir(dir)) then error("'"..dir.."' is not a valid directory", 3) end
			local list = fs.list(dir)
			for i=1,#list do
				local f = fs.combine(dir, list[i])
				if (fs.isDir(f)) then
					table.insert(dirStack, f)
				else
					table.insert(files, f)
				end
			end
		end
		return files
	end
	
	local includeFiles = {}
	
	for i=1,#rootDirs do
		expand(rootDirs[i], includeFiles)
	end
	
	-- Setup context
	local t = setmetatable({
		_rootFile = rootFile,
		_files = includeFiles,
		_ctx = nil,
		_ctxStack = {},
		_tokenQueue = Queue.new()
	}, _meta)
	
	local rootFilePath, err = t:findFile(t._rootFile)
	if (not rootFilePath) then error("Failed to find root file: "..err, 2) end
	
	table.insert(t._ctxStack, { enum =  StringEnumerator.new(t:_readFile(rootFilePath)), filePath = rootFilePath, line = 1 })
	
	return t
end

function Tokenizer:_nextToken()
	
	local foundToken = nil
	
	while (#self._ctxStack > 0 and foundToken == nil) do
		self._ctx = self._ctxStack[#self._ctxStack]
		
		while (foundToken == nil) do
			local success, token = self:_tkNext()
			if (not success) then return false, token end
			if (token == nil) then table.remove(self._ctxStack, #self._ctxStack); break end -- This file has ended.  Discard current context and move to next
			if (type(token) == "number") then -- Number tokens
				foundToken = { value = token, file = self._ctx.filePath, line = self._ctx.line }
			elseif (type(token) == "string") then -- String tokens
				if (token == ".include") then -- Include directive (.include <filename>)
					local success, fToken = self:_tkNext()
					if (not success) then return false, token end
					if (type(fToken) ~= "string") then return false, ".include expected filename ("..self._ctx.filePath..", line "..self._ctx.line..")" end
					local filePath, err = self:findFile(fToken)
					if (not filePath) then return false, "Failed to find file '"..fToken.."' ("..self._ctx.filePath..", line "..self._ctx.line..")" end
					-- Sanity check to detect .include loops
					for i=1,#self._ctxStack do
						if (self._ctxStack[i].filePath == filePath) then return false, ".include dependency loop detected ("..self._ctx.filePath..", line "..self._ctx.line..")" end
					end
					-- Create and push context for new file
					table.insert(self._ctxStack, { enum =  StringEnumerator.new(self:_readFile(filePath)), filePath = filePath, line = 1 })
					break
				else
					foundToken = { value = token, file = self._ctx.filePath, line = self._ctx.line }
				end
			else
				error("Invalid token '"..tostring(token).."'")
			end
		end
		
	end
	
	return foundToken
end

function Tokenizer:next()
	if (#self._tokenQueue > 0) then return self._tokenQueue:remove() end
	local token, err = self:_nextToken()
	if (err) then return false, err end
	return token
end

function Tokenizer:peek(idx)
	local queue = self._tokenQueue
	while (idx > #queue) do
		local token, err = self:_nextToken()
		if (err) then return false, err end
		queue:insert(token)
	end
	return queue:peek(idx)
end

function Tokenizer:hasNext()
	if (#self._tokenQueue > 0) then return true end
	local token, err = self:_nextToken()
	if (err) then return false, err end
	queue:insert(token)
	return true
end

return Tokenizer
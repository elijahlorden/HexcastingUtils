local expect = require("cc.expect")
local protocol = { name = "HexCompiler" }

local function open() if (not rednet.isOpen()) then rednet.open(peripheral.getName(peripheral.find("modem"))) end end
local function hExp(client, pos, v, ...)
    local t = {...}
    local ty = type(v)
    for i=1,#t do if (ty == t[i]) then return true end end
    rednet.send(client, { false, "Argument "..tostring(pos)..": "..table.concat(t, ", ").." expected, got "..ty }, protocol.name)
    return false
end

function protocol.host(targetDirs)
    local Compiler = require("HexUtils/Compiler")
    open()
    rednet.host(protocol.name, protocol.name.."_"..tostring(os.computerID()))
    while true do
        local client, msg = rednet.receive(protocol.name)
        if (type(msg) == "table") then
            if (msg[1] == "compile") then
                local _, target, emit, params = table.unpack(msg)
                if (hExp(client, 1, target, "string") and hExp(client, 2, emit, "string") and hExp(client, 3, params, "nil", "table")) then
                    local mode = (emit == "ducky") and Compiler.EmitMode.DuckyList or Compiler.EmitMode.HexTweaksList
                    local compiler = Compiler.new()
                    local ok, result = pcall(compiler.compile, compiler, target, targetDirs)
                    if (not ok) then
                        rednet.send(client, { false, result }, protocol.name)
                    else
                        local ok, result = pcall(compiler.emit, compiler, mode)
                        if (ok) then
                            rednet.send(client, { ok, { ["hex"] = result, ["globals"] = compiler:getGlobals() } }, protocol.name)
                        else
                            rednet.send(client, { ok, result }, protocol.name)
                        end
                    end
                end
            elseif (msg[1] == "regpattern") then
                local _, startDir, angles = table.unpack(msg)
                
            else
                rednet.send(client, {  })
            end
        end
    end
end

function protocol.call(host, msg, timeout)
    timeout = timeout or 10
    rednet.send(host, msg, protocol.name)
    local _, rec = rednet.receive(protocol.name)
    return rec
end

function protocol.getHex(name, emit, params)
    expect(1, name, "string")
    expect(2, emit, "string", "nil")
    emit = emit or "ducky"
    if (emit ~= "ducky" and emit ~= "hextweaks") then return false, "Unknown emit mode "..tostring(emit) end
    expect(3, params, "table", "nil")
    
    
    open()
    
    local hosts = {rednet.lookup(protocol.name)}
    if (#hosts == 0) then return false, "No HexCompiler hosts found" end
    local msg = { "compile", name, emit, params }
    
    for _,host in pairs(hosts) do
        local res = protocol.call(host, msg)
        if (res) then
            return table.unpack(res) -- Only return if the hex was compiled or compilation failed
        end
    end
    
    return false, "Hex not found"
end



return protocol
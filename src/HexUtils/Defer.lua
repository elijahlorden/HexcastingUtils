local expect = require("cc.expect")

local Defer = { _q = false }
local coFiltered = {} -- Schema: { ["event"] = { co1, co2, ... } }
local coUnfiltered = {}
local deferCallbacks = {}
local delayCallbacks = {} -- Schema: { [timerid] = f }
local errorHandlers = {}

local function resume(c, ...)
    local ok, result = coroutine.resume(c, ...)
    if (not ok) then
        for i=1,#errorHandlers do
            errorHandlers[i](result, debug.traceback(co))
        end
        return
    end
    if (coroutine.status(c) == "dead") then return end
    if (result == nil) then
        table.insert(coUnfiltered, c)
    else
        local e = tostring(result)
        if (not coFiltered[e]) then coFiltered[e] = {} end
        table.insert(coFiltered[e], c)
    end
end

local function add(f) resume(coroutine.create(f)) end

function Defer.onError(f) -- Defer.onError(function(error, traceback) end)
    expect(1, f, "function")
    table.insert(errorHandlers, f)
end

function Defer.update(event, arg1, ...)
    Defer._q = false
    if (event == "timer" and delayCallbacks[arg1]) then
        add(delayCallbacks[arg1])
        delayCallbacks[arg1] = nil
    elseif (coFiltered[event] ~= nil) then
        local list = coFiltered[event]
        if (#list > 0) then
            coFiltered[event] = {}
            for i=1,#list do resume(list[i], event, arg1, ...) end
        end
    end
    local unf, dc = coUnfiltered, deferCallbacks
    if (#unf > 0) then
        coUnfiltered = {}
        for i=1,#unf do resume(unf[i], event, arg1, ...) end
    end
    if (#dc > 0) then
        deferCallbacks = {}
        for i=1,#dc do add(dc[i]) end
    end
    Defer._q = false
end

function Defer.autoUpdate()
    Defer.update()
    while true do
        Defer.update(os.pullEvent())
    end
end

function Defer.defer(f)
    expect(1, f, "function")
    table.insert(deferCallbacks, f)
    if (Defer._q) then return end
    Defer._q = true
    os.queueEvent("defer")
end

function Defer.delay(s, f)
    expect(1, s, "number")
    expect(2, f, "function")
    local t = os.startTimer(s)
    delayCallbacks[t] = f
end

return setmetatable(Defer, { __call = function(_, f) Defer.defer(f) end })
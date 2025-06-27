local defer = require("HexUtils/defer")

local Promise = { _ucHandlers = {} }

local pending, resolved, rejected = 0, 1, 2
Promise.pending = pending
Promise.resolved = resolved
Promise.rejected = rejected

Promise.onUncaught = function(callback)
    table.insert(Promise._ucHandlers, callback)
end

local mt = { __index = Promise }
local function isPromise(x) return type(x) == "table" and getmetatable(x) == mt end
Promise.isPromise = isPromise

local function fireCallbacks(p)
    local v, t = p.value, p.traceback
    if (p.state == resolved) then
        local cbs = p._callbacks
        while (#cbs > 0) do
            table.remove(cbs, #cbs)(v)
        end
    elseif (p.state == rejected) then
        local cbs = p._errCallbacks
        while (#cbs > 0) do
            table.remove(cbs, #cbs)(v, t)
        end
    end
end

local function setState(p, state, val)
    p.state = state
    p.value = val
    fireCallbacks(p)
    if (p._awaited) then os.queueEvent("promise_complete", p.id) end
end

function Promise:next(callback, errCallback)  -- :next(function(...) end, [function(err) end]) -> new promise
    local p = self
    return Promise.new(function(resolve, reject)
    
        table.insert(p._callbacks, function(val)
            if (callback == nil) then resolve(val); return end
            local traceback = nil
            local ok, err = xpcall(function(val) resolve(callback(val)) end, function() traceback = debug.traceback() end, val)
            if (not ok) then reject(err, traceback) end
        end)
        
        table.insert(p._errCallbacks, function(err, traceback)
            if (errCallback == nil) then reject(err, traceback); return end
            local traceback2 = nil
            local ok, err2 = xpcall(function(err, traceback) resolve(errCallback(err, traceback)) end, function() traceback2 = debug.traceback() end, err, traceback)
            if (not ok) then reject(err2, traceback2) end
        end)
        
        fireCallbacks(p)
    end)
end

function Promise:resolve(val) -- TODO: Defer this
    if (self.state ~= pending) then return end
    if (isPromise(val)) then
        local p = self
        val:next(function(val2) p:resolve(val2) end, function(err, traceback) p:reject(err, traceback) end)
        return
    else
        setState(self, resolved, val)
    end
end

function Promise:reject(err, traceback) -- TODO: Defer this
    if (self.state ~= pending) then return end
    if (isPromise(err)) then
        local p = self
        err:next(function(val2) p:resolve(val2) end, function(err, traceback) p:reject(err, traceback) end)
        return
    else
        self.traceback = traceback or debug.traceback()
        setState(self, rejected, err)
    end
end

function Promise:catch(errCallback) return self:next(nil, errCallback) end

function Promise:finally(cb) return self:next(function(...) cb(); return ... end, function(err, traceback) cb(); error(err, traceback) end) end

function Promise:await()
    if (self.state == pending) then
        self._awaited = true
        repeat
            local e, id = os.pullEvent("promise_complete")
        until id == self.id
    end
    if (self.state == resolved) then
        return self.value
    elseif (self.state == rejected and self.traceback) then
        error(tostring(self.value).." (Promise trace: "..self.traceback..")", 2)
    elseif (self.state == rejected) then
        error(tostring(self.value))
    else error("Incorrect promise state") end
end

Promise.new = function(callback) -- .new(function(promise) end) -> promise
    local p = { _callbacks = {}, _errCallbacks = {}, _awaited = false, state = pending, value = nil }
    local s = tostring(p)
    p.id = tonumber(s:sub(s:find(" ") + 1), 16) -- Get the table ID for this promise object
    setmetatable(p, mt)
    if (type(callback) == "function") then
        local ok, err = pcall(callback, function(val) p:resolve(val) end, function(err, traceback) p:reject(err, traceback) end)
        if not ok then p:reject(err) end
    end
    return p
end

Promise.all = function(arr)
    local res = {}
    local nResolved = 0
    return Promise.new(function(resolve, reject)
        if (type(arr) ~= "table" or #arr == 0) then resolve(res); return end
        for i=1,#arr do
            local p = arr[i]
            if (isPromise(p)) then
                p:next(
                    function(val)
                        table.insert(res, val)
                        nResolved = nResolved + 1
                        if (nResolved >= #arr) then resolve(res) end
                    end, reject
                )
            else
                table.insert(res, p)
                nResolved = nResolved + 1
                if (nResolved >= #arr) then resolve(res) end
            end
        end
    end)
end

return Promise
---@class Wrapper
---@field unit ControlUnit
---@field system System
---@field stopped boolean
---@field stopOnError boolean
---@field rethrowErrorAlways boolean
---@field rethrowErrorIfStopped boolean
---@field printSameErrorOnlyOnce boolean
---@field printError boolean
---@field error function
---@field traceback function
---@field __memoryUsage number
---@field __memoryUsed number
---@field __memoryMax number
---@field __memoryIteration number
Wrapper = {}
Wrapper.__index = Wrapper

local max, ceil = math.max, math.ceil

setmetatable(Wrapper, {
  __call = function (cls, ...)
    return cls.new(...)
  end,
})

---@type {[string] : boolean}
local logs = {}

---@param unit ControlUnit
---@param system System
---@return Wrapper
function Wrapper.new(unit, system)
    local self = setmetatable({}, Wrapper)
    
    self.unit = unit
    self.system = system
    self.stopped = false
    self.stopOnError = false
    self.rethrowErrorAlways = false
    self.rethrowErrorIfStopped = true
    self.printSameErrorOnlyOnce = true
    self.printError = true
    self.error = function(a)
        if self.stopped then
            return
        end
        a = tostring(a):gsub('"%-%- |STDERROR%-EVENTHANDLER[^"]*"', 'chunk')
        local b = self.unit or self or {}
        if self.printError and self.system and self.system.print then
            if not self.printSameErrorOnlyOnce or logs[a] == nil then
                logs[a] = true
                self.system.print(a)
            end
        end
        if self.stopOnError then
            self.stopped = true
        end
        if self.stopped and b and b.exit then
            b.exit()
        end
        if self.rethrowErrorAlways or (self.stopped and self.rethrowErrorIfStopped) then
            error(a)
        end
    end
    self.traceback = traceback or (debug and debug.traceback) or function(a, b) return b or a end

    self.__memoryUsage = 0
    self.__memoryUsed = 0
    self.__memoryMax = 0
    self.__memoryIteration = 0

    return self
end

---@return number
function Wrapper:getMemoryAverage()
    return ceil(self.__memoryUsed / self.__memoryIteration * 100) / 100
end

---@return number
function Wrapper:getMemoryUsage()
    return ceil(self.__memoryUsage * 100) / 100
end

---@return number
function Wrapper:getMemoryMax()
    return ceil(self.__memoryMax * 100) / 100
end

---@param callback any
function Wrapper:execute(callback)
    if not self.stopped then
        local a, b = xpcall(callback, self.traceback, self.unit)
        if not a then
            self.error(b)
        end
    end

    self.__memoryUsage = collectgarbage("count")
    self.__memoryUsed = self.__memoryUsed + self.__memoryUsage
    self.__memoryMax = max(self.__memoryMax, self.__memoryUsage)
    self.__memoryIteration = self.__memoryIteration + 1
end
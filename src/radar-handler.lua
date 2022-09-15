---@class RadarHandler
---@field unit ControlUnit
---@field system System
---@field radar Radar
---@field isAtmospheric boolean
---@field radarRange number
---@field globalFilter? function
---@field constructs RadarConstruct[]
---@field __updating boolean
---@field __updateList number[]
---@field __updateQueue number[]
---@field __refreshing boolean
---@field __refreshList number[]
---@field __refreshCount number
---@field __widgetTimers number
---@field __widgetData string
---@field __lastIdentifiedConstructs boolean[]
---@field __lastTargetedConstruct number
RadarHandler = {}
RadarHandler.__index = RadarHandler

local sort, concat = table.sort, table.concat
local len, match = string.len, string.match
local min, random = math.min, math.random
local cresume, ccreate = coroutine.resume, coroutine.create

---@param unit ControlUnit
---@param system System
---@param radar Radar
---@param filter function?
function RadarHandler.new(unit, system, radar, filter)
    local self = setmetatable({}, RadarHandler)

    self.unit = unit
    self.system = system
    self.radar = radar
    self.isAtmospheric = match(self.radar.getClass(), "Atmospheric") ~= nil
    self.radarRange = self.radar.getRange()

    self.globalFilter = filter
    self.constructs = {}
    self.count = 0

    self.__updating = false
    self.__updateList = self.radar.getConstructIds()
    self.__updateQueue = {}
    self.__refreshing = false
    self.__refreshList = {}
    self.__refreshCount = 0

    self.__widgetTimers = 0
    self.__widgetData = self.radar.getWidgetData():gsub("\"constructsList\":%[?{?[^%]]*%]?}?,", "CONSTRUCTLIST")

    self.__lastIdentifiedConstructs = {}
    self.__lastTargetedConstruct = 0

    self:initEvent()

    return self
end

---@param count? number
---@param filter? function
---@return RadarConstruct[]
---@return number
function RadarHandler:getClosestConstructs(count, filter)
    local constructs = {}
    local isFunction = type(filter) == "function"
    for _, construct in pairs(self.constructs) do
        if not isFunction or filter(construct) then
            constructs[#constructs + 1] = construct
        end
    end
    sort(constructs, function(a, b) return a.distance < b.distance end)

    local result = {}
    local n = min(#constructs, (count or 2000000))
    for i = 1, n, 1 do
        result[#result + 1] = constructs[i]
    end
    return result, n
end

function RadarHandler:onUpdate()
    if not self.__updating then
        self.__updating = true
        cresume(ccreate(function()
            local q = self.__updateQueue
            self.__updateQueue = {}
            for i in ipairs(q) do
                self.__updateList[#self.__updateList + 1] = q[i]
            end
            local n = min(#self.__updateList, 50)
            for i = 1, n, 1 do
                local id = self.__updateList[#self.__updateList]
                self.__updateList[#self.__updateList] = nil
                if self.constructs[id] ~= nil then
                    self.constructs[id]:refresh()
                    if not self.constructs[id].isReachable then
                        self.constructs[id] = nil
                        self.count = self.count - 1
                    end
                else
                    local construct = RadarConstruct.new(self, id, self.globalFilter)
                    if construct.isReachable then
                        self.constructs[id] = construct
                        self.count = self.count + 1
                    end
                end
            end
            self.__updating = false
        end))
    end
end

function RadarHandler:onRefresh()
    if not self.__refreshing then
        self.__refreshing = true
        cresume(ccreate(function()
            self.__refreshCount = self.__refreshCount + 1
            if #self.__refreshList == 0 then
                for id in pairs(self.constructs) do
                    self.__refreshList[#self.__refreshList + 1] = id
                end
            end
            local n = min(#self.__refreshList, 50)
            for i = 1, n, 1 do
                local id = self.__refreshList[#self.__refreshList]
                self.__refreshList[#self.__refreshList] = nil
                if self.constructs[id] ~= nil then
                    self.constructs[id]:refresh(self.__refreshCount)
                    if not self.constructs[id].isReachable then
                        self.constructs[id] = nil
                        self.count = self.count - 1
                    end
                end
            end
            if self.__refreshCount % 10 == 0 then
                local identifiedConstructs = self.radar.getIdentifiedConstructIds()
                local newIdentifiedConstructs = {}
                for i = 1, #identifiedConstructs do
                    if self.constructs[identifiedConstructs[i]] ~= nil then
                        self.constructs[identifiedConstructs[i]]:setIdentified(true)
                    end
                    self.__lastIdentifiedConstructs[identifiedConstructs[i]] = nil
                    newIdentifiedConstructs[identifiedConstructs[i]] = true
                end
                for k in pairs(self.__lastIdentifiedConstructs) do
                    if self.constructs[k] ~= nil then
                        self.constructs[k]:setIdentified(false)
                    end
                end
                self.__lastIdentifiedConstructs = newIdentifiedConstructs

                local targetId = self.radar.getTargetId()
                if self.__lastTargetedConstruct ~= targetId then
                    if self.constructs[targetId] ~= nil then
                        self.constructs[targetId]:setTargeted(true)
                    end
                    if self.constructs[self.__lastTargetedConstruct] ~= nil then
                        self.constructs[self.__lastTargetedConstruct]:setTargeted(false)
                    end
                    self.__lastTargetedConstruct = targetId
                end

            end

            --- If in a crowded area, can lag and dont give the construct list at initialization
            if self.count == 0 then
                self.__updateList = self.radar.getConstructIds()
            end
            self.__refreshing = false
        end))
    end
end

function RadarHandler:initEvent()
    ---@diagnostic disable-next-line: undefined-field
    self.system:onEvent("onUpdate", function()
        self:onUpdate()
        self:onRefresh()
    end, self)
    ---@diagnostic disable-next-line: undefined-field
    self.radar:onEvent("onEnter", function(_, id)
        self.__updateQueue[#self.__updateQueue + 1] = id
    end, self)
end

---@param count? number
---@param filter? function
---@return string
function RadarHandler:getWidgetData(count, filter)
    local constructs = {}
    for _, construct in pairs(self:getClosestConstructs(count, filter)) do
        constructs[#constructs + 1] = construct:getData(self.radarRange)
    end
    local widgetData = self.__widgetData:gsub("CONSTRUCTLIST", "\"constructsList\":[" .. concat(constructs, ",") .. "],")
    return widgetData
end

---@param name string
---@param count? number
---@param filter? function
---@return string
---@return string
---@return string
function RadarHandler:createWidget(name, count, filter)
    local panelId = self.system.createWidgetPanel(name)
    local widgetId = ""
    local dataId = ""
    if len(panelId) > 0 then
        widgetId = self.system.createWidget(panelId, "radar")
        if len(widgetId) > 0 then
            dataId = self.system.createData("{}")
            if len(dataId) > 0 then
                self.system.addDataToWidget(dataId, widgetId)

                local timer = "radarWidget_" .. self.__widgetTimers
                ---@diagnostic disable-next-line: undefined-field
                self.unit:onEvent("onTimer", function(_, timerId)
                    if timer == timerId then
                        self.system.updateData(dataId, self:getWidgetData(count, filter))
                    end
                end, self)
                self.unit.setTimer(timer, 0.3 + (random() * 2 / 10))

                self.__widgetTimers = self.__widgetTimers + 1
            end
        end
    end

    return panelId, widgetId, dataId
end

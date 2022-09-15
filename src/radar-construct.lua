---@class RadarConstruct
---@field parent RadarHandler
---@field id number
---@field size string
---@field name string
---@field distance number
---@field isIdentified boolean
---@field isTargeted boolean
---@field myThreatStateToTarget string
---@field targetThreatState number
---@field isReachable boolean
---@field __lastRefresh number
RadarConstruct = {}
RadarConstruct.__index = RadarConstruct

local min, random = math.min, math.random
local upper = string.upper

---@enum
RadarConstructType = {
    Universe = 1,
    Planet = 2,
    Asteroid = 3,
    Static = 4,
    Dynamic = 5,
    Space = 6,
    Alien = 7,
}

---@enum
RadarConstructSize = {
    XS = "XS",
    S = "S",
    M = "M",
    L = "L",
    XL = "XL",
}


---@param parent RadarHandler
---@param id number
---@param filter function
---@return RadarConstruct
function RadarConstruct.new(parent, id, filter)
    local self = setmetatable({}, RadarConstruct)

    self.parent = parent

    self.id = id
    self.size = upper(self.parent.radar.getConstructCoreSize(self.id))
    self.type = self.parent.radar.getConstructKind(self.id)
    self.name = self.parent.radar.getConstructName(self.id)
    if type(filter) == "function" and not filter(self) then
        self.isReachable = false
        return self
    end
    self.distance = 0
    self.isIdentified = false
    self.myThreatStateToTarget = ""
    self.targetThreatState = 0
    self.isReachable = false
    self.isTargeted = false
    self.__lastRefresh = 0
    self.__threatRefreshLimit = random(3, 8)
    self:refresh()

    return self
end

---@param a RadarConstruct
---@param b RadarConstruct
---@return boolean
function RadarConstruct.__eq(a, b)
    return a.distance == b.distance
end

---@param a RadarConstruct
---@param b RadarConstruct
---@return boolean
function RadarConstruct.__lt(a, b)
    return (a.distance < b.distance) or (a.distance == b.distance and a.id < b.id)
end

---@param a RadarConstruct
---@param b RadarConstruct
---@return boolean
function RadarConstruct.__le(a, b)
    return (a.distance > b.distance) and (a.id > b.id)
end

---@param status boolean
function RadarConstruct:setIdentified(status)
    self.isIdentified = status
end

---@param status boolean
function RadarConstruct:setTargeted(status)
    self.isTargeted = status
end

---@param time? number
function RadarConstruct:refresh(time)
    time = (time or 0)
    local timeDiff = time - self.__lastRefresh
    if time == 0 or (timeDiff > 10) or (timeDiff > 2 and self.distance < 500) then
        self.distance = self.parent.radar.getConstructDistance(self.id)
        self.isReachable = self.distance > 0
        if not self.isReachable then
            self.name = self.parent.radar.getConstructName(self.id)
            self.isReachable = self.name ~= "unreachable"
        elseif (not self.parent.isAtmospheric) and (self.distance < self.parent.radarRange) then
            self.__threatRefreshLimit = self.__threatRefreshLimit - 1
            if self.__threatRefreshLimit == 0 then
                self.myThreatStateToTarget = self.parent.radar.getThreatRateFrom(self.id)
                self.targetThreatState = self.parent.radar.getThreatRateTo(self.id)
                self.__threatRefreshLimit = random(3, 8)
            end
        end
        self.__lastRefresh = time
    end
end

---@param maxIdentifyRange number
---@return string
function RadarConstruct:getData(maxIdentifyRange)
    return [[{]] ..
        [["constructId":]] .. self.id ..
        [[,"distance":]] .. self.distance ..
        [[,"isIdentifyRange":]] .. tostring(maxIdentifyRange >= self.distance) ..
        [[,"info":{}]] ..
        [[,"isIdentified":]] .. tostring(self.isIdentified) ..
        [[,"myThreatStateToTarget":0]] .. ---self.myThreatStateToTarget ..
        [[,"name":"]] .. self.name .. [["]] ..
        [[,"size":"]] .. self.size .. [["]] ..
        [[,"targetThreatState":0]] .. ---self.targetThreatState ..
        [[}]]
end

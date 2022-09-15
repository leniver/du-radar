require("radar-construct")
require("radar-handler")
require("wrapper")
--r equire('autoconf/custom/du-radar/radar-construct')
--r equire('autoconf/custom/du-radar/radar-handler')
--r equire('autoconf/custom/du-radar/wrapper')

local max = math.max

local wrapper = Wrapper(unit, system)
wrapper:execute(function()
  do
    local newPause = 50
    local oldPause = collectgarbage("setpause", newPause)
    if oldPause < newPause then
      collectgarbage("setpause", oldPause)
    end
  end

  local r = RadarHandler.new(unit, system, radar)
  local ceil = math.ceil
  system.showScreen(true)

  r:createWidget("Radar XS", 20,
    function(c) return c.size == RadarConstructSize.XS and c.type == RadarConstructType.Dynamic end)
  r:createWidget("Radar S", 20,
    function(c) return c.size == RadarConstructSize.S and c.type == RadarConstructType.Dynamic end)
  r:createWidget("Radar M", 20,
    function(c) return c.size == RadarConstructSize.M and c.type == RadarConstructType.Dynamic end)
  r:createWidget("Radar L", 20,
    function(c) return c.size == RadarConstructSize.L and c.type == RadarConstructType.Dynamic end)

  ---@diagnostic disable-next-line: undefined-field
  system:onEvent("onUpdate", function()
    wrapper:execute(function()
      local constructs, n = r:getClosestConstructs(45)
      local content = ""
      for i = 1, n, 1 do
        content = content ..
            "[" .. constructs[i].id .. "] " ..
            constructs[i].name ..
            " (" .. ceil(constructs[i].distance) .. ")<br/>"
      end

      content = content .. "<br/><br/>Ship count: " .. r.count
      content = content .. "<br/>Memory usage: " .. wrapper:getMemoryUsage()
      content = content .. "<br/>Memory average: " .. wrapper:getMemoryAverage()
      content = content .. "<br/>Memory max: " .. wrapper:getMemoryMax()

      system.setScreen(content)
    end)
  end)
end)

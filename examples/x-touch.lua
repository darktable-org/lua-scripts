local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("9.1.0", "x-touch")

function knob(action, element, effect, size)
  k = tonumber(action:sub(-1))

  if dt.gui.action("iop/blend/tools/show and edit mask elements") ~= 0 then
    local s = { "opacity", "size", "feather", "hardness","rotation","curvature","compression" }
    which = "lib/masks/properties/" .. s[k]

  elseif dt.gui.action("iop/colorzones", "focus") ~= 0 then
    which = "iop/colorzones/graph"
    local e = { "red", "orange", "yellow", "green", "aqua", "blue", "purple", "magenta" }
    element = e[k]

  elseif dt.gui.action("iop/toneequal", "focus") ~= 0 then
    which ="iop/toneequal/simple/"..(k-9).." EV"

  elseif dt.gui.action("iop/colorbalancergb", "focus") ~= 0 and k == 4 then
    which = "iop/colorbalancergb/contrast"

  elseif dt.gui.action("iop/channelmixerrgb", "focus") ~= 0 and k >= 5 then
    if k == 5 then
      which = "iop/channelmixerrgb/page"
      element = "CAT"
      if     effect == "up"   then effect = "next"
      elseif effect == "down" then effect = "previous"
      else                         effect = "activate"
      end
    else
      which = "iop/focus/sliders"
      local e = { "1st", "2nd", "3rd" }
      element = e[k - 5]
    end

  else
    local s = { "iop/exposure/exposure",
                "iop/filmicrgb/white relative exposure",
                "iop/filmicrgb/black relative exposure",
                "iop/filmicrgb/contrast",
                "iop/crop/left",
                "iop/crop/right",
                "iop/crop/top",
                "iop/crop/bottom" }
    which = s[k]
  end

  return dt.gui.action(which, element, effect, size)
end

for k = 1,8 do
  dt.gui.mimic("slider", "knob ".. k, knob)
end

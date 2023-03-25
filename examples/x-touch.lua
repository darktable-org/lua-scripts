--[[
    This file is part of darktable,
    copyright (c) 2023 Diederik ter Rahe

    darktable is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    darktable is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with darktable.  If not, see <http://www.gnu.org/licenses/>.
]]
--[[
X-Touch Mini flexible encoder shortcuts

This script will create virtual sliders that are mapped dynamically to 
the most relevant sliders for the currently focused processing module.
Tailored modules are color zones, tone equalizer, color calibration and
mask manager properties. The script can easily be amended for other
devices or personal preferences. Virtual "toggle" buttons can be created
as well, that dynamically change meaning depending on current status.

USAGE
* require this script from your main lua file
* restart darktable
* create shortcuts for each of the encoders on the x-touch mini 
  to a virtual slider under lua/x-touch 
  or import the following shortcutsrc file in the shortcuts dialog/preferences tab:

None;midi:CC1=lua/x-touch/knob 1
None;midi:CC2=lua/x-touch/knob 2
None;midi:CC3=lua/x-touch/knob 3
None;midi:CC4=lua/x-touch/knob 4
None;midi:CC5=lua/x-touch/knob 5
None;midi:CC6=lua/x-touch/knob 6
None;midi:CC7=lua/x-touch/knob 7
None;midi:CC8=lua/x-touch/knob 8
midi:E0=global/modifiers
midi:F0=global/modifiers;ctrl
midi:F#0=global/modifiers;alt
midi:G#-1=iop/blend/tools/show and edit mask elements
midi:A-1=iop/colorzones;focus
midi:A#-1=iop/toneequal;focus
midi:B-1=iop/colorbalancergb;focus
midi:C0=iop/channelmixerrgb;focus
]]

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

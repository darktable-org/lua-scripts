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
midi:C#0=iop/colorequal;focus
midi:D0=iop/colorequal/page;previous
midi:D#0=iop/colorequal/page;next
]]

local dt = require "darktable"
local du = require "lib/dtutils"

du.check_min_api_version("9.2.0", "x-touch")

local gettext = dt.gettext.gettext 

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("x-touch"),
  purpose = _("example of how to control an x-touch midi device"),
  author = "Diederik ter Rahe",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/examples/x-touch"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- set up 8 mimic sliders with the same function
for k = 1,8 do
  dt.gui.mimic("slider", "knob ".. k,
    function(action, element, effect, size)
      -- take the number from the mimic name
      local k = tonumber(action:sub(-1))

      -- only operate in darkroom; return NAN otherwise
      if dt.gui.current_view() ~= dt.gui.views.darkroom then
        return 0/0
      end

      local maskval = 0/0
      if k < 8 then
        -- first try if the mask slider at that position is active
        local s = { "opacity",
                    "size",
                    "feather",
                    "hardness",
                    "rotation",
                    "curvature",
                    "compression" }
        maskval = dt.gui.action("lib/masks/properties/" .. s[k], 
                                element, effect, size)
      end
      -- if a value different from NAN is returned, the slider was active
      if maskval == maskval then
        return maskval

      -- try if colorzones module is focused; if so select element of graph
      elseif dt.gui.action("iop/colorzones", "focus") ~= 0 then
        which = "iop/colorzones/graph"
        local e = { "red",
                    "orange",
                    "yellow",
                    "green",
                    "aqua",
                    "blue",
                    "purple",
                    "magenta" }
        element = e[k]
                
      -- try if colorequalizer module is focused; if so select element of graph
      elseif dt.gui.action("iop/colorequal", "focus") ~= 0 then
        local e = { "red",
                    "orange",
                    "yellow",
                    "green",
                    "cyan",
                    "blue",
                    "lavender",
                    "magenta" }
        which = "iop/colorequal/graph"
        element = e[k]
                
      -- if the sigmoid rgb primaries is focused, 
      -- check sliders
      elseif dt.gui.action("iop/sigmoid", "focus") ~= 0 and k <8 then
        local e = { "red attenuation", "red rotation", "green attenuation", "green rotation", "blue attenuation", "blue rotation", "recover purity" }
        which = "iop/sigmoid/primaries/"..e[k]

      -- if the rgb primaries is focused, 
      -- check sliders
      elseif dt.gui.action("iop/primaries", "focus") ~= 0 and k >=1 then
        local e = { "red hue", "red purity", "green hue", "green purity", "blue hue", "blue purity", "tint hue", "tint purity" }
        which = "iop/primaries/" ..e[k]
      
      -- if the tone equalizer is focused, 
      -- select one of the sliders in the "simple" tab
      elseif dt.gui.action("iop/toneequal", "focus") ~= 0 then
        which ="iop/toneequal/simple/"..(k-9).." EV"

      -- if color calibration is focused, 
      -- the last 4 knobs are sent there
      elseif dt.gui.action("iop/channelmixerrgb", "focus") ~= 0 
             and k >= 5 then
        -- knob 5 selects the active tab; pressing it resets to CAT
        if k == 5 then
          which = "iop/channelmixerrgb/page"
          element = "CAT"
          -- since the tab action is not a slider, 
          -- the effects need to be translated
          if     effect == "up"   then effect = "next"
          elseif effect == "down" then effect = "previous"
          else                         effect = "activate"
          end
        else
          -- knobs 6, 7 and 8 are for the three color sliders on each tab
          which = "iop/focus/sliders"
          local e = { "1st",
                      "2nd",
                      "3rd" }
          element = e[k - 5]
        end

      -- the 4th knob is contrast; 
      -- either colorbalance if it is focused, or filmic
      elseif dt.gui.action("iop/colorbalancergb", "focus") ~= 0 
             and k == 4 then
        which = "iop/colorbalancergb/contrast"

      -- in all other cases use a default selection
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

      -- now pass the element/effect/size to the selected slider
      return dt.gui.action(which, element, effect, size)
    end)
end

local function destroy()
  -- nothing to destroy
end

script_data.destroy = destroy

return script_data

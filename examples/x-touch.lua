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

-- Constants
local NUM_KNOBS = 8
local NAN = 0/0

-- Configuration tables
local MASK_PROPERTIES = {
  "opacity", "size", "feather", "hardness", 
  "rotation", "curvature", "compression"
}

local COLOR_ELEMENTS = {
  colorzones = {
    "red", "orange", "yellow", "green", 
    "aqua", "blue", "purple", "magenta"
  },
  colorequal = {
    "red", "orange", "yellow", "green", 
    "cyan", "blue", "lavender", "magenta"
  }
}

local MODULE_CONFIGS = {
  sigmoid = {
    "red attenuation", "red rotation", 
    "green attenuation", "green rotation", 
    "blue attenuation", "blue rotation", 
    "recover purity"
  },
  primaries = {
    "red hue", "red purity", "green hue", "green purity",
    "blue hue", "blue purity", "tint hue", "tint purity"
  },
  agx = {
    "white relative exposure",
    "black relative exposure",
    "curve/pivot input shift",
    "curve/pivot target output",
    "curve/contrast",
    "curve/toe power",
    "curve/shoulder power",
    "curve/curve y gamma"
  }
}

local DEFAULT_MAPPINGS = {
  "iop/exposure/exposure",
  "iop/filmicrgb/white relative exposure",
  "iop/filmicrgb/black relative exposure",
  "iop/filmicrgb/contrast",
  "iop/crop/left",
  "iop/crop/right",
  "iop/crop/top",
  "iop/crop/bottom"
}

-- Helper functions
local function is_in_darkroom()
  return dt.gui.current_view() == dt.gui.views.darkroom
end

local function is_valid(value)
  return value == value  -- NaN check
end

local function is_module_focused(module_name)
  return dt.gui.action("iop/" .. module_name, "focus") ~= 0
end

local function translate_tab_effect(effect)
  if effect == "up" then 
    return "next"
  elseif effect == "down" then 
    return "previous"
  else 
    return "activate"
  end
end

-- Handler functions for different module types
local function handle_mask_properties(knob_idx, element, effect, size)
  if knob_idx >= NUM_KNOBS then 
    return NAN 
  end
  
  local property = MASK_PROPERTIES[knob_idx]
  local value = dt.gui.action("lib/masks/properties/" .. property, 
                               element, effect, size)
  return value
end

local function handle_color_module(module_name, knob_idx, element, effect, size)
  local elements = COLOR_ELEMENTS[module_name]
  if not elements then 
    return nil 
  end
  
  return dt.gui.action("iop/" .. module_name .. "/graph", 
                       elements[knob_idx], effect, size)
end

local function handle_sigmoid(knob_idx, element, effect, size)
  if knob_idx >= NUM_KNOBS then 
    return nil 
  end
  
  local slider = MODULE_CONFIGS.sigmoid[knob_idx]
  return dt.gui.action("iop/sigmoid/primaries/" .. slider, 
                       element, effect, size)
end

local function handle_primaries(knob_idx, element, effect, size)
  local slider = MODULE_CONFIGS.primaries[knob_idx]
  return dt.gui.action("iop/primaries/" .. slider, 
                       element, effect, size)
end

local function handle_agx(knob_idx, element, effect, size)
  local slider = MODULE_CONFIGS.agx[knob_idx]
  return dt.gui.action("iop/agx/" .. slider, 
                       element, effect, size)
end

local function handle_tone_equalizer(knob_idx, element, effect, size)
  return dt.gui.action("iop/toneequal/simple/" .. (knob_idx - 9) .. " EV", 
                       element, effect, size)
end

local function handle_channel_mixer(knob_idx, element, effect, size)
  if knob_idx < 5 then 
    return nil 
  end
  
  if knob_idx == 5 then
    -- Tab selection
    return dt.gui.action("iop/channelmixerrgb/page", 
                        "CAT", 
                        translate_tab_effect(effect), 
                        size)
  else
    -- Color sliders
    local positions = {"1st", "2nd", "3rd"}
    return dt.gui.action("iop/focus/sliders", 
                        positions[knob_idx - 5], 
                        effect, size)
  end
end

local function handle_color_balance_contrast(knob_idx, element, effect, size)
  if knob_idx ~= 4 then 
    return nil 
  end
  return dt.gui.action("iop/colorbalancergb/contrast", 
                       element, effect, size)
end

local function handle_default_mapping(knob_idx, element, effect, size)
  local mapping = DEFAULT_MAPPINGS[knob_idx]
  return dt.gui.action(mapping, element, effect, size)
end

-- Main knob handler
local function handle_knob_action(knob_idx, element, effect, size)
  if not is_in_darkroom() then
    return NAN
  end
  
  -- Try mask properties first
  local mask_value = handle_mask_properties(knob_idx, element, effect, size)
  if is_valid(mask_value) then
    return mask_value
  end
  
  -- Try color modules
  if is_module_focused("colorzones") then
    return handle_color_module("colorzones", knob_idx, element, effect, size)
  end
  
  if is_module_focused("colorequal") then
    return handle_color_module("colorequal", knob_idx, element, effect, size)
  end
  
  -- Try sigmoid module
  if is_module_focused("sigmoid") then
    local result = handle_sigmoid(knob_idx, element, effect, size)
    if result then 
      return result 
    end
  end
  
  -- Try primaries module
  if is_module_focused("primaries") then
    local result = handle_primaries(knob_idx, element, effect, size)
    if result then 
      return result 
    end
  end
  
  -- Try agx module
  if is_module_focused("agx") then
    local result = handle_agx(knob_idx, element, effect, size)
    if result then 
      return result 
    end
  end
  
  -- Try tone equalizer
  if is_module_focused("toneequal") then
    return handle_tone_equalizer(knob_idx, element, effect, size)
  end
  
  -- Try channel mixer (color calibration)
  if is_module_focused("channelmixerrgb") then
    local result = handle_channel_mixer(knob_idx, element, effect, size)
    if result then 
      return result 
    end
  end
  
  -- Try color balance contrast
  if is_module_focused("colorbalancergb") then
    local result = handle_color_balance_contrast(knob_idx, element, effect, size)
    if result then 
      return result 
    end
  end
  
  -- Fall back to default mapping
  return handle_default_mapping(knob_idx, element, effect, size)
end

-- Setup mimic sliders
local function setup_knobs()
  for k = 1, NUM_KNOBS do
    dt.gui.mimic("slider", "knob " .. k,
      function(action, element, effect, size)
        local knob_idx = tonumber(action:sub(-1))
        return handle_knob_action(knob_idx, element, effect, size)
      end)
  end
end

-- Script metadata
local script_data = {
  metadata = {
    name = _("x-touch"),
    purpose = _("example of how to control an x-touch midi device"),
    author = "Diederik ter Rahe",
    help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/examples/x-touch"
  },
  destroy = function() end,
  destroy_method = nil,
  restart = nil,
  show = nil
}

-- Initialize
setup_knobs()

return script_data

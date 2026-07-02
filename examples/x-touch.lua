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

USAGE:
To add a new module, simply add an entry to MODULE_PROFILES below.
Get action paths from darktable's shortcut interface.
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
local darkroom_view = dt.gui.views.darkroom

-- ============================================================================
-- USER CONFIGURATION
-- ============================================================================

-- Module Profiles: Define behavior when each module has focus
-- Structure: [module_name] = { knob1_action, knob2_action, ... }
local MODULE_PROFILES = {
  
  -- Color Zones: Control individual color channels
  colorzones = {
    {"iop/colorzones/graph", "red"},
    {"iop/colorzones/graph", "orange"},
    {"iop/colorzones/graph", "yellow"},
    {"iop/colorzones/graph", "green"},
    {"iop/colorzones/graph", "aqua"},
    {"iop/colorzones/graph", "blue"},
    {"iop/colorzones/graph", "purple"},
    {"iop/colorzones/graph", "magenta"}
  },
  
  -- Color Equalizer: Control color channels
  colorequal = {
    {"iop/colorequal/graph", "red"},
    {"iop/colorequal/graph", "orange"},
    {"iop/colorequal/graph", "yellow"},
    {"iop/colorequal/graph", "green"},
    {"iop/colorequal/graph", "cyan"},
    {"iop/colorequal/graph", "blue"},
    {"iop/colorequal/graph", "lavender"},
    {"iop/colorequal/graph", "magenta"}
  },
  
  -- Sigmoid: Control primary color adjustments
  sigmoid = {
    {"iop/sigmoid/primaries/red attenuation"},
    {"iop/sigmoid/primaries/red rotation"},
    {"iop/sigmoid/primaries/green attenuation"},
    {"iop/sigmoid/primaries/green rotation"},
    {"iop/sigmoid/primaries/blue attenuation"},
    {"iop/sigmoid/primaries/blue rotation"},
    {"iop/sigmoid/primaries/recover purity"}
  },
  
  -- Color Calibration (Primaries)
  primaries = {
    {"iop/primaries/red hue"},
    {"iop/primaries/red purity"},
    {"iop/primaries/green hue"},
    {"iop/primaries/green purity"},
    {"iop/primaries/blue hue"},
    {"iop/primaries/blue purity"},
    {"iop/primaries/tint hue"},
    {"iop/primaries/tint purity"}
  },
  
  -- AgX
  agx = {
    {"iop/agx/white relative exposure"},
    {"iop/agx/black relative exposure"},
    {"iop/agx/curve/pivot relative exposure"},
    {"iop/agx/curve/pivot target output"},
    {"iop/agx/curve/contrast"},
    {"iop/agx/curve/shoulder power"},
    {"iop/agx/curve/toe power"},
    {"iop/agx/curve/curve y gamma"}
  },
  
  -- Tone Equalizer: Control EV bands 
  -- For 8 knobs, using offsets -8 to get bands
  toneequal = {
    {"iop/toneequal/simple/-8 EV"},
    {"iop/toneequal/simple/-7 EV"},
    {"iop/toneequal/simple/-6 EV"},
    {"iop/toneequal/simple/-5 EV"},
    {"iop/toneequal/simple/-4 EV"},
    {"iop/toneequal/simple/-3 EV"},
    {"iop/toneequal/simple/-2 EV"},
    {"iop/toneequal/simple/-1 EV"}
  },
  
  -- Color Balance RGB: Selected controls
  colorbalancergb = {
    nil,  -- Knob 1: unused --> default
    {"iop/colorbalancergb/global vibrance"},
    {"iop/colorbalancergb/contrast"},
    {"iop/colorbalancergb/global chroma"},
    {"iop/colorbalancergb/global saturation"},
    {"iop/colorbalancergb/global brilliance"},
    nil,  -- Knob 7: --> default
    nil   -- Knob 8: --> default
  },
  
  -- Channel Mixer RGB (Color Calibration): Tab control and sliders
  channelmixerrgb = {
    nil,  -- Knob 1-4: --> default
    nil,
    nil,
    nil,
    {"iop/channelmixerrgb/page", "CAT", "tab"},  -- Knob 5: Tab selector
    {"iop/focus/sliders", "1st"},                 -- Knob 6: First slider
    {"iop/focus/sliders", "2nd"},                 -- Knob 7: Second slider
    {"iop/focus/sliders", "3rd"}                  -- Knob 8: Third slider
  },
    
}

local DEFAULT_MAPPINGS = {
  {"iop/exposure/exposure"},
  {"iop/filmicrgb/white relative exposure"},
  {"iop/filmicrgb/black relative exposure"},
  {"iop/filmicrgb/contrast"},
  {"iop/crop/left"},
  {"iop/crop/right"},
  {"iop/crop/top"},
  {"iop/crop/bottom"}
}
-- Mask properties: Always checked first, regardless of module focus
local MASK_PROPERTIES = {
  {"lib/masks/properties/opacity"},
  {"lib/masks/properties/size"},
  {"lib/masks/properties/feather"},
  {"lib/masks/properties/hardness"},
  {"lib/masks/properties/rotation"},
  {"lib/masks/properties/curvature"},
  {"lib/masks/properties/compression"}
}

-- Priority order for checking module focus (most commonly used first)
local MODULE_CHECK_ORDER = {
  "toneequal",
  "colorequal",
  "colorbalancergb",
  "agx",
  "sigmoid",
  "primaries",
  "channelmixerrgb",
  "colorzones"
}

-- ============================================================================
-- CORE LOGIC - No need to edit below unless changing architecture
-- ============================================================================

-- Helper functions
local function is_in_darkroom()
  return dt.gui.current_view() == darkroom_view
end

local function is_valid(value)
  return value == value  -- NaN check
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

-- Execute an action configuration
local function execute_action(action_config, element, effect, size)
  if not action_config then
    return nil
  end
  
  local path = action_config[1]
  local elem = action_config[2] or element
  local action_type = action_config[3]
  
  -- Handle special action types
  if action_type == "tab" then
    effect = translate_tab_effect(effect)
  end
  
  return dt.gui.action(path, elem, effect, size)
end

-- Try mask properties first
local function try_mask_properties(knob_idx, element, effect, size)
  if knob_idx >= NUM_KNOBS then 
    return NAN 
  end
  
  local mask_action = MASK_PROPERTIES[knob_idx]
  if not mask_action then
    return NAN
  end
  
  local value = execute_action(mask_action, element, effect, size)
  return value
end

-- Main knob handler
local function handle_knob_action(knob_idx, element, effect, size)
  -- Early exit for non-darkroom view
  if not is_in_darkroom() then
    return NAN
  end
  
  -- Try mask properties first (no focus check needed)
  local mask_value = try_mask_properties(knob_idx, element, effect, size)
  if is_valid(mask_value) then
    return mask_value
  end
  
  -- Check focused modules in priority order
  for _, module_name in ipairs(MODULE_CHECK_ORDER) do
    local focus_status = dt.gui.action("iop/" .. module_name, "focus")
    
    if focus_status ~= 0 then
      -- Module has focus, get its profile
      local profile = MODULE_PROFILES[module_name]
      
      if profile then
        local action_config = profile[knob_idx]
        
        -- If profile has explicit mapping for this knob, use it
        if action_config then
          local result = execute_action(action_config, element, effect, size)
          if result then
            return result
          end
        else
          -- Profile exists but this knob is nil -> use default
          -- This avoids checking other modules when we know the focused one
          local default_action = DEFAULT_MAPPINGS[knob_idx]
          return execute_action(default_action, element, effect, size) or NAN
        end
      end
      
      -- If no profile exists for this module, continue checking others
    end
  end
  
  -- No module has focus or no profile matched, fall back to default
  local default_action = DEFAULT_MAPPINGS[knob_idx]
  return execute_action(default_action, element, effect, size) or NAN
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
    purpose = _("data-driven x-touch midi controller configuration"),
    author = "Martin Straeten",
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

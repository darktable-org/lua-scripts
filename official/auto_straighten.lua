--[[

    auto_straighten.lua - straighten an image in darkroom using image metadata

    Copyright (C) 2025 Bill Ferguson <wpferguson@gmail.com>.

    This program is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 3 of the License, or
    (at your option) any later version.

    This program is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with this program.  If not, see <http://www.gnu.org/licenses/>.
]]
--[[
    auto_straighten - straighten an image in darkroom using image metadata

    auto_straighten reads the roll and pitch angle imformation captured when
    an image is captured.  A correction is computed and applied to correct the 
    roll to the nearest vertical or horizontal axis using the rotate and 
    perspective module.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    exiftool - https://exiftool.org

    USAGE
    * add it sowewhere in your scripts directory
    * ensure exiftool is installed and accessible
    * enable it using script manager

    BUGS, COMMENTS, SUGGESTIONS
    Bill Ferguson <wpferguson@gmail.com>

    CHANGES

    LIMITATIONS
    * Roll and pitch angles are taken when an image is captured.  If you shoot
      in burst mode, the roll and pitch angles of the first image are used in
      the rest of the burst (at least for Canon).
    * If you are running multiple scripts that trigger on an image being opened
      in darkroom then the auto crop may not work.  There is a shortcut included
      that can have a key sequence assigned so that the auto crop will be reapplied.
    * Currently oply roll angle is corrected

    LIEENSE
    GPL V2
]]

local dt = require "darktable"
local du = require "lib/dtutils"
-- local da = require "lib/dtutils.action"
local df = require "lib/dtutils.file"
-- local ds = require "lib/dtutils.string"
-- local dtsys = require "lib/dtutils.system"
local log = require "lib/dtutils.log"
-- local debug = require "darktable.debug"


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local MODULE <const> = "auto_straighten"
local DEFAULT_LOG_LEVEL <const> = log.info
local TMP_DIR <const> = dt.configuration.tmp_dir

-- path separator
local PS <const> = dt.configuration.running_os == "windows" and "\\" or "/"

-- command separator
local CS <const> = dt.configuration.running_os == "windows" and "&" or ";"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A P I  C H E C K
-- - - - - - - - - - - - - - - - - - - - - - - - 

du.check_min_api_version("7.0.0", MODULE)   -- choose the minimum version that contains the features you need


-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- I 1 8 N
-- - - - - - - - - - - - - - - - - - - - - - - - - -

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end


-- - - - - - - - - - - - - - - - - - - - - - - - - -
-- S C R I P T  M A N A G E R  I N T E G R A T I O N
-- - - - - - - - - - - - - - - - - - - - - - - - - -

local script_data = {}

script_data.destroy = nil           -- function to destory the script
script_data.destroy_method = nil    -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil           -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil              -- only required for libs since the destroy_method only hides them

script_data.metadata = {
  name = _("auto_straighten"),         -- visible name of script
  purpose = _("straighten an image in darkroom using image metadata"),   -- purpose of script
  author = "Bill Ferguson <wpferguson@gmail.com>",   -- your name and optionally e-mail address
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/official/auto_straighten/"  -- URL to help/documentation
}


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - - 

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local auto_straighten = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- G L O B A L  V A R I A B L E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

auto_straighten.pixelpipe_busy = false

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- P R E F E R E N C E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.preferences.register(MODULE, "crop_area", "enum",
                        _("automatic_cropping"),
                        _("what automatic cropping to perform"),
                        _("original format"),
                        _("off"), _("largest area"), _("original format"))

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A L I A S E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local namespace = auto_straighten
local as = auto_straighten

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function determine_correction(roll_angle)

--[[
  Canon camera roll angle is as foillows
  * landscape orientation camera upright = 0
  * camera rolled to the left (shutter button up) portrait = -90
  * camera inverted landscape = +/- 180
  * camera rolled to the right (shutter button down) portrait = 90

  rotate and perspective corrections
  * rotate the image to the right is a negative correction
  * rotate the image left is a positive correction
]]

  if roll_angle == 0 or               -- landscape
     roll_angle == -90 or             -- roll left portrait
     math.abs(roll_angle) == 180 or   -- inverted landscape
     roll_angle == 90 then            -- roll right portrait
     dt.print_log("on axis, no correction required")
      return 0
  elseif roll_angle > 0 and roll_angle <= 45 then
    return (roll_angle * -1.0)
  elseif roll_angle > 45 and roll_angle < 90 then
    return (90 - roll_angle)
  elseif roll_angle > 90 and roll_angle <= 135 then
    return (roll_angle - 90) * -1.0
  elseif roll_angle > 135 and roll_angle < 180 then
    return (180 - roll_angle)
  elseif roll_angle > -180 and roll_angle <= -135 then
    return (-180 - roll_angle)
  elseif roll_angle > -135 and roll_angle <= -90 then
    return (math.abs(roll_angle) - 90)
  elseif roll_angle > -90 and roll_angle <= -45 then
    return (-90 - roll_angle)
  else
    return roll_angle * -1.0
  end
end

local function toggle_auto_crop()
  local crop = dt.preferences.read(MODULE, "crop_area", "enum")
  dt.gui.action("iop/ashift/automatic cropping", "selection", "item:off", 1.000)
  dt.control.sleep(100)
  dt.gui.action("iop/ashift/automatic cropping", "selection", "item:" .. crop, 1.000)
end

local function straighten_image(image)

  local roll = nil
  local pitch = nil

  -- Roll Angle 0 is landscape, -90 is rolled to the left in portrait, +- 180 is landscape inverted, 90 is portrait rolled to the right

  local crop = dt.preferences.read(MODULE, "crop_area", "enum")

  local pipe = io.popen(as.exiftool .. " -RollAngle -PitchAngle " .. image.path .. PS .. image.filename)
  if pipe then
    for line in pipe:lines() do
      local pr, val = string.match(line, "(.).+: (.+)")
      if pr == "R" then 
        dt.print_log("roll angle is " .. val)
        log.msg(log.debug, "roll angle is " .. val)
        roll = determine_correction(tonumber(val))
        dt.print_log("corrected roll angle is " .. roll)
        log.msg(log.debug, "corrected roll angle is " .. roll)
      elseif pr == "P" then
        pitch = tonumber(val)
      end
    end
    pipe:close()
  end

  if roll and dt.gui.action("iop/ashift", "enable", "", "") == 0.0 then
    dt.print_log("straightening image")
    dt.gui.action("iop/ashift/rotation", "value", "set", roll)
    -- dt.gui.action("iop/ashift/automatic cropping", "selection", "item:" .. crop, 1.000)
    -- da.wait_until_pixelpipe_complete()
    toggle_auto_crop()
  end

end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N  P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - 

as.exiftool = df.check_if_bin_exists("exiftool")

if not as.exiftool then
  log.msg(log.error, "exiftool not found, exiting...")
  log.msg(log.screen, _("exiftool not found, exiting..."))
  return
end

-- da.register_events(MODULE, straighten_image)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- U S E R  I N T E R F A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  dt.destroy_event(MODULE, "darkroom-image-loaded")
end

script_data.destroy = destroy

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 
---[[
dt.register_event(MODULE, "darkroom-image-loaded",
  function(event, clean, image)
    if clean then
      straighten_image(image)
    end
  end
)
--]]

dt.register_event(MODULE, "shortcut",
  function(event, shortcut)
    toggle_auto_crop()
  end, "toggle auto crop off and on"
)

return script_data

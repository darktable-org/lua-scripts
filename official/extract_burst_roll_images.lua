--[[

    extract_burst_roll_images.lua - extract burst images from a burst roll file

    Copyright (C) 2026 Bill Ferguson <wpferguson@gmail.com>.

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
    extract_burst_roll_images - extract burst images from a burst roll file

    Canon cameras are capable of shooting in burst mode.  When the shutter
    button is half pressed the camera starts "recording".  When the shutter is
    fully pressed the pervious 1/2 second of imformation is recorded as individual
    images stored in one file as well as images captured at 30 frames/sec until
    the buffer fills or the shutter button is released.  So a Canon R7 burst file
    could contain ~90 images.

    Extracting the images from this file required use of Canon proprietary software
    until recently when dnglab got the capability to extract the embedded images as
    DNG raws.

    This script can be set to run on import, scanning for burst roll containers,
    extracting the embedded images and grouping them with the burst roll container.
    The script can alsu be utilized via a short cut and applied to selected images.

    When set to on import the script scans each image after import using exiv2 or exiftool
    to check the image EXIF information to see if the file is a busrt roll container.
    Once the import images are scanned, the detected burst roll containers are processed,
    the embedded images extracted as DNSs, and grouped with the container image.

    In shortcut mode the user selects the burst roll containers manually and uses the shortcut
    to extract the embedded images as DNGs

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    - exiv2 - https://exiv2.org
    - exiftool - https://exiftool.org
    - dnglab - https://github.com/dnglab/dnglab

    USAGE
    - add the script to your lua scripts
    - enable in script manager
    - set the preferences in perferences->Lua options

    LIMITATIONS
    extract_burst_roll_images makes heavy use of external programs to identify burst roll
    containters and to extract the images.  Windows users may want to use it in shortcut mode
    to lessen the number of windows popping up.

    BUGS, COMMENTS, SUGGESTIONS
    Bill Ferguson <wpferguson@gmail.com>

    CHANGES
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local ds = require "lib/dtutils.string"
local dtsys = require "lib/dtutils.system"
local log = require "lib/dtutils.log"
-- local debug = require "darktable.debug"


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A P I  C H E C K
-- - - - - - - - - - - - - - - - - - - - - - - - 

du.check_min_api_version("9.6.0", MODULE)   -- choose the minimum version that contains the features you need


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
  name = _("extract burst roll images"),         -- visible name of script
  purpose = _("extract burst images from a burst roll file"),   -- purpose of script
  author = "Bill Ferguson <wpferguson@gmail.com>",   -- your name and optionally e-mail address
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/official/extract_burst_roll_images/"  -- URL to help/documentation
}


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local MODULE <const> = "extract_burst_roll_images"
local DEFAULT_LOG_LEVEL <const> = log.info
local TMP_DIR <const> = dt.configuration.tmp_dir

-- path separator
local PS <const> = dt.configuration.running_os == "windows" and "\\" or "/"

-- command separator
local CS <const> = dt.configuration.running_os == "windows" and "&" or ";"

local EXIFTOOL <const> = df.check_if_bin_exists("exiftool")
local EXIV2 <const> = df.check_if_bin_exists("exiv2")
local DNGLAB <const> = df.check_if_bin_exists("dnglab")

local DNGLAB_ARGS <const> = " convert --image-index all --embed-raw false "
local EXIV2_ARGS <const> = " -K Exif.Canon.RawBurstModeRoll -pt "
local EXIFTOOL_ARGS <const> = " -T -RawBurstImageCount "

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - - 

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local extract_burst_roll_images = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- G L O B A L  V A R I A B L E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

extract_burst_roll_images.preferred_tag_reader = nil
extract_burst_roll_images.on_import = true
extract_burst_roll_images.imported_images = {}
extract_burst_roll_images.log_level = DEFAULT_LOG_LEVEL

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- P R E F E R E N C E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- exiv2 or exiftool
dt.preferences.register(MODULE,        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference.
                        "tag_reader",  -- name
                        "enum",                       -- type
                        _("preferred exif tag reader"),              -- label
                        _("use exiftool or exiv2 to read exif tags"),      -- tooltip
                        "exiftool",                     -- default
                        "exiftool", "exiv2")           -- values

-- run on import
dt.preferences.register(MODULE,        -- script: This is a string used to avoid name collision in preferences (i.e namespace). Set it to something unique, usually the name of the script handling the preference. 
                        "on_import",  -- name
                        "bool",                       -- type
                        _("extract burst roll images on import"),           -- label
                        _("extract burst roll images on import"),   -- tooltip
                        true)                         -- default


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A L I A S E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local namespace = extract_burst_roll_images
local ebri = extract_burst_roll_images

local sleep = dt.control.sleep

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - 

-------------------
-- helper functions
-------------------

local function set_log_level(level)
  if not level then
    level = namespace.log_level
  end

  local old_log_level = log.log_level()
  log.log_level(level)

  return old_log_level
end

local function restore_log_level(level)
  if not level then
    level = namespace.log_level
  end

  log.log_level(level)
end

local function reset_log_level()
  log.log_level(DEFAULT_LOG_LEVEL)
  namespace.log_level = DEFAULT_LOG_LEVEL
end

local function pref_read(name, pref_type)
  local old_log_level = set_log_level(ebri.log_level)

  log.msg(log.debug, "name is " .. name .. " and type is " .. pref_type)

  local val = dt.preferences.read(MODULE, name, pref_type)

  log.msg(log.debug, "read value " .. tostring(val))

  restore_log_level(old_log_level)
  return val
end

local function pref_write(name, pref_type, value)
  local old_log_level = set_log_level(ebri.log_level)

  log.msg(log.debug, "writing value " .. tostring(value) .. " for name " .. name)

  dt.preferences.write(MODULE, name, pref_type, value)

  restore_log_level(old_log_level)
end

local function get_last_value(valuestr)
  local old_log_level = set_log_level()
  local parts = du.split(valuestr, " +")

  if parts then
    log.msg(log.debug, "last value of parts is " .. tostring(parts[#parts]))
    return parts[#parts]
  else
    log.msg(log.debug, "last part not detected, returning nil")
    return nil
  end
  restore_log_level(old_log_level)
end

local function is_burst_roll_image(image)
  local old_log_level = set_log_level()
  local result = false
  local cmd = EXIFTOOL .. EXIFTOOL_ARGS

  if ebri.preferred_tag_reader == "exiv2" then
    cmd = EXIV2 .. EXIV2_ARGS
  end

  local p = io.popen(cmd .. ds.sanitize(image.path) .. PS .. ds.sanitize(image.filename))
  if p then
    for line in p:lines() do
      if ebri.preferred_tag_reader == "exiv2" then
        line = get_last_value(line)
      end
      line = tonumber(line)
      if type(line) == "number" then
        if tonumber(line) > 0 then
          log.msg(log.info, image.filename .. " is a burst roll container image")
          result = true
        end
      end
    end
    p:close()
  end

  restore_log_level(old_log_level)
  return result
end

local function group_extracted_dngs(image)
  local old_log_level = set_log_level()
  local count = 0

  local cmd = "ls -1 " .. ds.sanitize(image.path) .. PS .. ds.sanitize(ds.get_basename(image.filename)) .. "*.dng"

  if dt.configuration.running_os == "windows" then
    cmd = "forfiles /P " .. ds.sanitize(image.path) .. " /M " .. ds.sanitize(ds.get_basename(image.filename)) .. "*.dng" .. " /C \"cmd /c echo @path\\@fname\""
  end

  local p = io.popen(cmd)
  if p then
    for line in p:lines() do
      if line:length() > 5 then -- skip blank lines created by forfiles
        local dng_image = dt.database.import(line)
        dng_image:group_with(image)
        count = count + 1
      end
    end
    p:close()
    log.msg(log.screen, string.format(_("extracted %d dng files from %s"), count, image.filename))
  end
  restore_log_level(old_log_level)
end

local function extract_burst(image)
  local old_log_level = set_log_level()
  
  local cmd = DNGLAB .. DNGLAB_ARGS .. ds.sanitize(image.path) .. PS .. ds.sanitize(image.filename) .. " " .. ds.sanitize(image.path)

  local result = dtsys.external_command(cmd)

  if result == 0 then
    group_extracted_dngs(image)
  end
  restore_log_level(old_log_level)
end

local function process_image(image)
  local old_log_level = set_log_level()
  if is_burst_roll_image(image) then
    extract_burst(image)
  end
  restore_log_level(old_log_level)
end

local function stop_job(job)
  job.valid = false
end

local function process_images(images)
  local old_log_level = set_log_level()
  local job = dt.gui.create_job(_("scanning for burst roll images"), true, stop_job)

  for i, image in ipairs(images) do
    if ebri.job.valid then
      extract_burst(image)
      ebri.job.percent = i / #images
      sleep(10)
    end
  end

  stop_job(job)

  restore_log_level(old_log_level)
end

local function process_import(images)
  local old_log_level = set_log_level()
  local burst_roll_images = {}
  local job = dt.gui.create_job(_("scanning for burst roll images"), true, stop_job)

  for i, image in ipairs(images) do
    if job.valid then
      if is_burst_roll_image(image) then
        table.insert(burst_roll_images, image)
      end
      if i % 10 == 0 then
        job.percent = i / #images
      end
      sleep(10)
    end
  end

  stop_job(job)

  if #burst_roll_images > 0 then
    job = dt.gui.create_job(_("extracting burst roll images"), true, stop_job)
    for j, image in ipairs(burst_roll_images) do
      if job.valid then
        extract_burst(image)
        job.percent = j / #burst_roll_images
        sleep(10)
      end
    end
    stop_job(job)
  end
  
  restore_log_level(old_log_level)
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N  P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - 

if not DNGLAB then
  log.msg(log.error, MODULE .. _("dnglab executable not found"))
  log.msg(log.screen, script_data.metadata.name .. _(": dnglab executable not found, exiting..."))
  return
end

if not EXIFTOOL and not EXIV2 then
  log.msg(log.error, MODULE .. _("no exif tag reader available"))
  log.msg(log.screen, script_data.metadata.name .. _(" no exif tag reader available, exiting..."))
  return
end

ebri.preferred_tag_reader = pref_read("tag_reader", "enum")

if not string.match(EXIFTOOL, ebri.preferred_tag_reader) and not string.match(EXIV2, ebri.preferred_tag_reader) then
  log.msg(log.error, MODULE .. " selected tag " .. ebri.preferred_tag_reader .." not available")
  log.msg(log.screen, script_data.metadata.name .. string.format(_(" selected tag reader %s not available"), ebri.preferred_tag_reader))
  return
end

ebri.on_import = dt.preferences.read(MODULE, "on_import", "bool")

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- U S E R  I N T E R F A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  dt.destroy_event(MODULE, "post-import-film")
  dt.destroy_event(MODULE, "post-import-image")
end

script_data.destroy = destroy

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.register_event(MODULE, "post-import-film",
  function(event, film)
    process_import(ebri.imported_images)
    ebri.imported_images = {}
  end
)

dt.register_event(MODULE, "post-import-image",
  function(event, image)
    if ebri.on_import then
      table.insert(ebri.imported_images, image)
    end
  end
)

if not dt.query_event(MODULE, "shortcut") then
  dt.register_event(MODULE, "shortcut",
    function(event, shortcut)
      if #dt.gui.action_images > 1 then
        process_images(dt.gui.action_images)
      else
        process_image(dt.gui.action_images[1])
      end
    end, "extract roll burst images"
  )
end

return script_data

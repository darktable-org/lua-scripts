--[[

    use_paired_jpg_as_mipmap.lua - Use the JPG from the RAW JPG pair as the full size mipmap

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
    use_paired_jpg_as_mipmap - Use the JPG from the RAW JPG pair as the full size mipmap

    use_paired_jpg_as_mipmap looks for RAW+JPEG image pairs as images are imported.  After
    import the JPEG image is copied to the mipmap cache as the full resolution mipmap. Requests
    for smaller mipmap sizes can be satisfied by down sampling the full resolution mipmap.  User's can
    decide whether or not to keep the paired JPEG files.  The default is to keep them.  If the 
    user doesn't want them, they are deleted after being copied to the mipmap cache.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    
    None

    USAGE
    
    - Add the script to the lua-scripts
    - Enable the script
    - Turn off the keep_jpgs preference if the JPEGS are not wanted

    BUGS, COMMENTS, SUGGESTIONS
    Bill Ferguson <wpferguson@gmail.com>

    CHANGES
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
-- local ds = require "lib/dtutils.string"
-- local dtsys = require "lib/dtutils.system"
local log = require "lib/dtutils.log"
-- local debug = require "darktable.debug"


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
  name = _("use paired jpg as mipmap"),         -- visible name of script
  purpose = _("Use the JPG from the RAW JPG pair as the full size mipmap"),   -- purpose of script
  author = "Bill Ferguson <wpferguson@gmail.com>",   -- your name and optionally e-mail address
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/official/use_paired_jpg_as_mipmap/" -- URL to help/documentation
}


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local MODULE <const> = "use_paired_jpg_as_mipmap"
local DEFAULT_LOG_LEVEL <const> = log.info
local TMP_DIR <const> = dt.configuration.tmp_dir

-- path separator
local PS <const> = dt.configuration.running_os == "windows" and "\\" or "/"

-- command separator
local CS <const> = dt.configuration.running_os == "windows" and "&" or ";"

-- max mipmap size - 5.4.x = 8, after is 10
local MAX_MIPMAP_SIZE <const> = (dt.configuration.version > "5.4.1") and "10" or "8"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - - 

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local use_paired_jpg_as_mipmap = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- G L O B A L  V A R I A B L E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

use_paired_jpg_as_mipmap.log_level = DEFAULT_LOG_LEVEL
use_paired_jpg_as_mipmap.imported_images = {}
use_paired_jpg_as_mipmap.image_count = 0
use_paired_jpg_as_mipmap.mipmap_dir = nil
use_paired_jpg_as_mipmap.keep_jpgs = true

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- P R E F E R E N C E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.preferences.register(MODULE, "keep_jpgs", "bool", script_data.metadata.name .. " - " .. _("keep JPEG files"),
                        _("don't delete JPEGs after copying them to mipmap folder"), true)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A L I A S E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local namespace = use_paired_jpg_as_mipmap
local pmj = use_paired_jpg_as_mipmap

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
  local old_log_level = set_log_level(namespace.log_level)

  log.msg(log.debug, MODULE .. ": name is " .. name .. " and type is " .. pref_type)

  local val = dt.preferences.read(MODULE, name, pref_type)

  log.msg(log.debug, MODULE .. ": read value " .. tostring(val))

  restore_log_level(old_log_level)
  return val
end

local function pref_write(name, pref_type, value)
  local old_log_level = set_log_level(namespace.log_level)

  log.msg(log.debug, MODULE .. ": writing value " .. tostring(value) .. " for name " .. name)

  dt.preferences.write(MODULE, name, pref_type, value)

  restore_log_level(old_log_level)
end

local function refresh_collection()
  local rules = dt.gui.libs.collect.filter()
  dt.gui.libs.collect.filter(rules)
end

local function get_mipmap_dir()
  local old_log_level = set_log_level(pmg.log_level)
  local mipmap_dir = nil
  local cachedir = dt.configuration.cache_dir

  local cmd = "cd " .. cachedir .. "; ls -d mip*"

  if dt.configuration.running_os == "windows" then
    cmd = "forfiles /P \"" .. cachedir .. "\" /M mip* /C \"cmd /c echo @file\""
  end

  local p = io.popen(cmd)
  if p then
    for line in p:lines() do
      if line:len() > 4 then
        mipmap_dir = cachedir .. PS .. line
        log.msg(log.info, MODULE .. ": mipmap_dir is " .. mipmap_dir)
      end
    end
    p:close()
  end

  restore_log_level(old_log_level)
  return mipmap_dir
end

local function stop_job(job)
  job.valid = false
end

local function process_images(images, count)
  local old_log_level = set_log_level(pmg.log_level)
  
  -- if dt.collection is equal to count there are no
  -- RAW+JPEG pairs

  if count == #dt.collection then
    log.msg(log.screen, _("No RAW+JPEG pairs to process"))
    return
  end

  local job = dt.gui.create_job(_("Generating cache from jpgs"), true, stop_job)
  local processed_count = 0
  local mipmap_dir = get_mipmap_dir() .. PS .. MAX_MIPMAP_SIZE .. PS

  local rc = df.mkdir(mipmap_dir)
  log.msg(log.debug, MODULE .. ": rc from mkdir is " .. rc)

  for k,v in pairs(images) do
    if job.valid then
      if v["raw"] and v["jpg"] then
        local raw_image_id = v["raw"].id
        local fname = v["jpg"].path .. PS .. v["jpg"].filename
        df.file_copy(fname, mipmap_dir .. raw_image_id .. ".jpg")
        if not pmj.keep_jpgs then
          log.msg(log.debug, MODULE .. ": removing jpg")
          v["jpg"]:delete()
          local success, msg = os.remove(v["jpg"].path .. PS .. v["jpg"].filename)
          if not success then
            log.msg(log.warn, MODULE .. ": unable to remove jpg - reason: " .. msg)
          end
          success, msg = os.remove(v["jpg"].path .. PS .. v["jpg"].filename .. ".xmp")
          if not success then
            log.msg(log.warn, MODULE .. ": unable to remove jpg xmp - reason: " .. msg)
          end
        end
        -- v["raw"]:generate_cache(true, 6, 6)
        processed_count = processed_count + 1
      end
      job.percent = processed_count / count
    end
    dt.control.sleep(5)
  end
  stop_job(job)
  if not pmj.keep_jpgs then
    refresh_collection()
  end
  dt.util.message(MODULE, "broadcast", "finished")
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N  P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - 

use_paired_jpg_as_mipmap.keep_jpgs = pref_read("keep_jpgs", "bool")

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
    process_images(pmj.imported_images, pmj.image_count)
    pmj.imported_images = {}
    pmj.image_count = 0
  end
)

dt.register_event(MODULE, "post-import-image",
  function(event, image)
    local basename = df.get_basename(image.filename)
    local extension = string.lower(df.get_filetype(image.filename))

    if not string.match(extension, "jpg") then
      extension = "raw"
    end

    if not pmj.imported_images[basename] then
      pmj.imported_images[basename] = {}
    end

    pmj.imported_images[basename][extension] = image

    if not string.match(extension, "jpg") then
      pmj.image_count = pmj.image_count + 1
    end
  end
)

return script_data

--[[

    share_raw_xmp.lua - share raw, xmp, raw + xmp files with developers

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
    share_raw_xmp - share raw, xmp, raw + xmp files with developers

    share_raw_xmp creates a zip archive of raws and their accompanying xmp
    files then appends a .txt file extension so that the archive may be 
    uploaded to an issue or pull request.  The resulting zip archive is placed
    in the Downloads directory

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    
    * zip - file compression and archive for Linux and MacOS
    * tar.exe - file compression and archive for Windows

    USAGE
    
    * configure what to export, raw, xmp, or raw + xmp
    * configure force xmp write for configurations where xmp files are not enabled
    * select images to include in the archive
    * press the share raw xmp button to create the archive
    * go to the Downloads folder to get the archive

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
  name = _("share raw xmp"),         -- visible name of script
  purpose = _("share raw, xmp, raw + xmp files with developers"),   -- purpose of script
  author = "Bill Ferguson <wpferguson@gmail.com>",   -- your name and optionally e-mail address
  help = ""                   -- URL to help/documentation
}


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local MODULE <const> = "share_raw_xmp"
local DEFAULT_LOG_LEVEL <const> = log.info
local TMP_DIR <const> = dt.configuration.tmp_dir
local HOME <const> =  dt.configuration.running_os == "windows" and os.getenv("USERPROFILE") or os.getenv("HOME")

-- path separator
local PS <const> = dt.configuration.running_os == "windows" and "\\" or "/"

-- command separator
local CS <const> = dt.configuration.running_os == "windows" and "&" or ";"

local DOWNLOAD_DIR = HOME .. PS .. "Downloads"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - - 

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local share_raw_xmp = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- G L O B A L  V A R I A B L E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

share_raw_xmp.log_level = DEFAULT_LOG_LEVEL

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- P R E F E R E N C E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.preferences.register(MODULE, "force_xmp_write", "bool", _("force XMP write if XMPs disabled"), 
                        _("create an XMP file to export if XMP files are disabled"), true)

dt.preferences.register(MODULE, "include_files", "enum", _("select which files to include"), 
                        _("include just the raw, just the xmp, or both"), "raw+xmp", "raw+xmp", "raw", "xmp")

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A L I A S E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local namespace = share_raw_xmp
local srx = share_raw_xmp

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

  log.msg(log.debug, "name is " .. name .. " and type is " .. pref_type)

  local val = dt.preferences.read(MODULE, name, pref_type)

  log.msg(log.debug, "read value " .. tostring(val))

  restore_log_level(old_log_level)
  return val
end

local function pref_write(name, pref_type, value)
  local old_log_level = set_log_level(namespace.log_level)

  log.msg(log.debug, "writing value " .. tostring(value) .. " for name " .. name)

  dt.preferences.write(MODULE, name, pref_type, value)

  restore_log_level(old_log_level)
end

-------------------
-- program functions
-------------------

-- write_sidecar_files - xmp preference

local function build_archive(images)
  local force_xmp = pref_read("force_xmp_write", "bool")
  local which_files = pref_read("include_files", "enum")
  local xmp_write_status = dt.preferences.read("darktable", "write_sidecar_files", "string")
  local file_list = {}
  local file_remove_list = {}

  if xmp_write_status ~= "on import" and force_xmp then
    dt.gui.action("lib/copy_history/write sidecar files", "", "activate", 1.000)
    dt.control.sleep(1000)
  end

  if #images > 0 then
    for _, image in ipairs(images) do
      if string.match(which_files, "raw") then
        table.insert(file_list, df.sanitize_filename(image.filename))
      end
      if string.match(which_files, "xmp") then
        table.insert(file_list, df.sanitize_filename(image.filename) .. ".xmp")
        if xmp_write_status == "never" and force_xmp then
          table.insert(file_remove_list, image.sidecar)
        end
      end
    end
  else
    log.msg(log.error, "no images selected")
    log.msg(log.screen, "ERROR: no images selected")
    return
  end

  if #file_list > 0 then
    local path = images[1].path
    local zip_filename = "dev_share_" .. df.get_basename(images[1].filename) .. ".zip"
    local zip_command = dt.configuration.running_os == "windows" and "tar.exe -a -c -f " or "zip "
    local command = "cd " .. path .. CS .. zip_command .. DOWNLOAD_DIR .. PS .. zip_filename .. " " .. table.concat(file_list, " ")
    dt.print_log(command)

    os.execute(command)
    --dt.control.sleep(2000)
    dt.print_log("renaming from " .. DOWNLOAD_DIR .. PS .. zip_filename .. " to " .. DOWNLOAD_DIR .. PS .. zip_filename .. ".txt")
    os.rename(DOWNLOAD_DIR .. PS .. zip_filename, DOWNLOAD_DIR .. PS .. zip_filename .. ".txt")
    log.msg(log.screen, #file_list .. " files written to " .. DOWNLOAD_DIR .. PS .. zip_filename .. ".txt")
    log.msg(log.info, #file_list .. " files written to " .. DOWNLOAD_DIR .. PS .. zip_filename .. ".txt")
  end

  if #file_remove_list > 0 then
    for _, file in ipairs(file_remove_list) do
      os.remove(file)
    end
  end
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N  P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - 

local button_file_label = pref_read("include_files", "enum")

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- U S E R  I N T E R F A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.gui.libs.image.register_action(
  MODULE, 
  string.format(_("create %s share"), button_file_label),
  function(event, images)
    build_archive(images) 
  end,
  _("create zip archive to share with developers")
)
if #dt.gui.selection() > 0 then
  dt.gui.libs.image.set_sensitive(MODULE, true)
else
  dt.gui.libs.image.set_sensitive(MODULE, false)
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  -- put things to destroy (events, storages, etc) here
end

script_data.destroy = destroy

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.register_event(MODULE, "selection-changed",
  function(event)
    if #dt.gui.selection() > 0 then
      dt.gui.libs.image.set_sensitive(MODULE, true)
    else
      dt.gui.libs.image.set_sensitive(MODULE, false)
    end
  end
)

return script_data

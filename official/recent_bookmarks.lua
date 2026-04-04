--[[

    recent_bookmarks.lua - add recently edited and exported images to system recent bookmarks

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
    recent_bookmarks - add recently edited and exported images to system recently used files

    recent_bookmarks adds images edited in darktable and the directory of images exported from
    darktable to the reccently-used.xbel file so that they show up in the recently used system
    shortcuts.  

    Currently recent_bookmarks only works on Linux

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    
    file - linux system file utility to get mime-type

    USAGE
    
    eanble from script manager

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
  name = _("recent_bookmarks"),         -- visible name of script
  purpose = _("add recently edited and exported images to system recent bookmarks"),   -- purpose of script
  author = "Bill Ferguson <wpferguson@gmail.com>",   -- your name and optionally e-mail address
  help = ""                   -- URL to help/documentation
}


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local MODULE <const> = "recent_bookmarks"
local DEFAULT_LOG_LEVEL <const> = log.info
local TMP_DIR <const> = dt.configuration.tmp_dir

-- path separator
local PS <const> = dt.configuration.running_os == "windows" and "\\" or "/"

-- command separator
local CS <const> = dt.configuration.running_os == "windows" and "&" or ";"

-- format strings for writing the bookmarks

local BOOKMARK_FORMAT <const> = "  <bookmark href=\"file://%s\" added=\"%s\" modified=\"%s\" visited=\"%s\">\n"
local MIME_FORMAT <const> = "        <mime:mime-type type=\"%s\"/>\n"
local EXPORT_FORMAT <const> = "          <bookmark:application name=\"xdg-open\" exec=\"&apos;xdg-open %%u&apos;\" modified=\"%s\" count=\"1\"/>\n"
local EDIT_FORMAT <const> = "          <bookmark:application name=\"darktable\" exec=\"&apos;darktable %%u&apos;\" modified=\"%s\" count=\"1\"/>\n"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - - 

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local recent_bookmarks = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- G L O B A L  V A R I A B L E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

recent_bookmarks.log_level = DEFAULT_LOG_LEVEL
recent_bookmarks.bookmark_file = nil
recent_bookmarks.current_view = nil
recent_bookmarks.in_darkroom = false
recent_bookmarks.current_image = nil

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- P R E F E R E N C E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A L I A S E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local namespace = recent_bookmarks
local rb = recent_bookmarks

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

--------------------
-- program functions
--------------------

local function zulu_timestamp()
  return os.date("!%Y-%m-%dT%H:%M:%SZ")
end

local function get_mimetype(filepath)
  local mimetype = "application/octet-stream"
  local p = io.popen("file -L --mime-type " .. df.sanitize_filename(filepath))
  if p then
    for line in p:lines() do
      local result = string.match(line, ".-: (.+)$")
      if result then
        mimetype = result
      end
    end
  end
  return mimetype
end

local function find_bookmark_file()
  local file = nil
  local home = os.getenv("HOME")
  if home then
    if df.test_file(home .. PS ..".local/share/recently-used.xbel", "e") then
      file = home .. PS ..".local/share/recently-used.xbel"
    end
  end
  return file
end

local function write_bookmark_file(bookmark, mimetype, application)
  local file = io.open(rb.bookmark_file, "r+")
  if file then
    local pos = file:seek("end", -7)
    if pos > 0 then
      file:write(bookmark)
      file:write("    <info>\n      <metadata owner=\"http://freedesktop.org\">\n")
      file:write(mimetype)
      file:write("        <bookmark:applications>\n")
      file:write(application)
      file:write("        </bookmark:applications>\n      </metadata>\n    </info>\n  </bookmark>\n</xbel>")
      file:close()
    else
      log.msg(log.screen, _("failed to open bookmark file"))
    end
  else
    log.msg(log.screen, _("failed to open bookmark file"))
  end
end

local function create_bookmark_string(filename, zulu)
  return string.format(BOOKMARK_FORMAT, filename, zulu, zulu, zulu)
end

local function create_mimetype_string(mimetype)
  return string.format(MIME_FORMAT, mimetype)
end

local function process_bookmark(image, filename)

  local zulu = zulu_timestamp()
  local filepath = filename and filename or (image.path .. PS .. image.filename)
  local format = filename and EXPORT_FORMAT or EDIT_FORMAT
  local mimetype = get_mimetype(filepath)
  local bookmark_string = create_bookmark_string(filepath, zulu)
  local mime_string = create_mimetype_string(mimetype)
  local app_string = string.format(format, zulu)
  write_bookmark_file(bookmark_string, mime_string, app_string)
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N  P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - 

if dt.configuration.running_os ~= "linux" then
  log.msg(log.screen, script_data.metadata.name .. _(" only  runs on Linux"))
  return
end

rb.bookmark_file = find_bookmark_file()
if not rb.bookmark_file then
  log.msg(log.screen, _("recent bookmarks file not found"))
  return
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- U S E R  I N T E R F A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  dt.destroy_event(MODULE, "intermediate-export-image")
  dt.destroy_event(MODULE, "darkroom-image-loaded")
  dt.destroy_event(MODULE, "darkroom-image-history-changed")
  dt.destroy_event(MODULE, "view-changed")
end

script_data.destroy = destroy

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.register_event(MODULE, "intermediate-export-image",
  function(event, image, filename, format, storage)
    process_bookmark(image, filename)
  end
)

dt.register_event(MODULE, "darkroom-image-loaded",
  function(event, clean, image)
    if clean then
      rb.in_darkroom = true
      rb.current_view = "darkroom"
      rb.current_image = image
    end
  end
)

dt.register_event(MODULE, "darkroom-image-history-changed",
  function(event, image)
    if image == rb.current_image then
      process_bookmark(image)
    end
  end
)

dt.register_event(MODULE, "view-changed",
  function(event, old_view, new_view)
    rb.current_view = new_view.id
    if rb.current_view == "darkroom" then
      rb.in_darkroom = true
    else
      if rb.in_darkroom then
        rb.in_darkroom = false
      end
    end
  end
)

return script_data

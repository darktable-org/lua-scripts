--[[

    selection2collection.lua - create a temporary collection from a selection

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
    selection2collection - create a temporary collection from a selection

    selection2collection creates a temporary collection, using functional
    tagging, from a selection. The collection lasts until darktable exits
    and then the collections are removed, but not the images.

    To create the temporary collection, a function tag (darktable|functional|s2c) 
    tag with a date and a time is applied to the selected images.  The collection
    module filters on the tag to display the connection.  More than one temporary
    collection can be created and collections can be changed by selecting the 
    appropriate tag.

    The tags are autmatically destroyed when darktable exits, thus removing the
    collections.  There is a preference in the Lua options to keep the collections
    across darktable runs.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    
    None

    USAGE
    
    * start from script_manager
    * make a selection
    * click the create temporary collection button the the actions on selected images
      module

    BUGS, COMMENTS, SUGGESTIONS

    Bill Ferguson <wpferguson@gmail.com>

    CHANGES
]]

local dt = require "darktable"
local du = require "lib/dtutils"
-- local df = require "lib/dtutils.file"
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
  name = _("selection2collection"),         -- visible name of script
  purpose = _("create a temporary collection from a selection"),   -- purpose of script
  author = "Bill Ferguson <wpferguson@gmail.com>",   -- your name and optionally e-mail address
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/official/selection2collection/" -- URL to help/documentation
}


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local MODULE <const> = "selection2collection"
local DEFAULT_LOG_LEVEL <const> = log.info
local TMP_DIR <const> = dt.configuration.tmp_dir

-- path separator
local PS <const> = dt.configuration.running_os == "windows" and "\\" or "/"

-- command separator
local CS <const> = dt.configuration.running_os == "windows" and "&" or ";"

-- script specific

local TAG_HEADER <const> = "darktable|functional|s2c|"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - - 

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local selection2collection = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- G L O B A L  V A R I A B L E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

selection2collection.log_level = DEFAULT_LOG_LEVEL
selection2collection.keep_collections = false
selection2collection.collection_rules = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- P R E F E R E N C E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.preferences.register(MODULE, "keep_collections", "bool", 
  script_data.metadata.name .. _(" keep collections created from selection"), 
  _("keep collections created from selections"), false)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A L I A S E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local namespace = selection2collection
local s2c = selection2collection

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

local function clear_collections()
  s2c.keep_collections = pref_read("keep_collections", "bool")

  if not s2c.keep_collections then
    for _, tag in ipairs(dt.tags) do
      if string.match(tag.name, TAG_HEADER) then
        tag:delete()
      end
    end
  end
end

local function create_collection_tag()
  
  local t = os.date("*t")

  local ymd = string.format("%4d:%02d:%02d", t.year, t.month, t.day)
  local hms = string.format("%02d:%02d:%02d", t.hour, t.min, t.sec)

  local tag_string = TAG_HEADER .. ymd .. "|" .. hms
  dt.print_log("tag_string is " .. tag_string)

  local tag = dt.tags.create(tag_string)
  
  return tag
end

local function display_collection(tag_name)
  local collection_rules = dt.gui.libs.collect.filter()

  local rule = dt.gui.libs.collect.new_rule()

  rule.mode = "DT_LIB_COLLECT_MODE_AND"
  rule.data = tostring(tag_name)
  rule.item = "DT_COLLECTION_PROP_TAG"

  table.insert(collection_rules, rule)

  -- dt.gui.libs.collect.filter returns the previous rule set when you install another
  s2c.collection_rules = dt.gui.libs.collect.filter(collection_rules)
end

local function create_collection()
  local images = dt.gui.selection()

  if #images > 1 then

    local tag = create_collection_tag()

    if tag then
      for _, image in ipairs(images) do
        image:attach_tag(tag)
      end
    end

    display_collection(tag.name)
  else
    log.msg(log.screen, _("not enough images to create a collection"))
  end
end

local function communications_handler(sender, receiver, message)
  if receiver == MODULE then
    if message == "create" then
      create_collection()
    end
  end
end

local function set_button_sensitive(images)
  if #images > 1 then
    dt.gui.libs.image.set_sensitive(MODULE, true)
  else
    dt.gui.libs.image.set_sensitive(MODULE, false)
  end
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N  P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - 

s2c.keep_collections = pref_read("keep_collections", "bool")

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- U S E R  I N T E R F A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.gui.libs.image.register_action(
  MODULE, _("create temporary collection"),
  function(event, images)
    create_collection()
  end,
  _("convert selection to collection")
)

set_button_sensitive(dt.gui.selection())
-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  dt.destroy_event(MODULE, "inter-script-communication")
  dt.destroy_event(MODULE, "exit")
  dt.destroy_event(MODULE, "selection_changed")
  dt.gui.libs.destroy_action(MODULE, "create_collection")
end

script_data.destroy = destroy

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.register_event(MODULE, "inter-script-communication",
  function(event, sender, receiver, message)
    communications_handler(sender, receiver, message)
  end
)

if not dt.query_event(MODULE, "shortcut") then  -- skip if shortcut already registered
  dt.register_event(MODULE, "shortcut",
    function(event, shortcut)
      create_collection()
    end, _("convert selection to collection")
  )
end

dt.register_event(MODULE, "exit",
  function(event)
    if not s2c.keep_collections then
      dt.gui.libs.collect.filter(s2c.collection_rules)
      clear_collections()
    end
  end
)

dt.register_event(MODULE, "selection-changed",
  function(event)
    set_button_sensitive(dt.gui.selection())
  end
)

return script_data

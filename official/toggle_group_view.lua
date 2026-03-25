--[[

    toggle_group_view.lua - toggle only group visible in lighttable

    Copyright (C) 2024 Bill Ferguson <wpferguson.com>.

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
    toggle_group_view - toggle only group visible in lighttable

    toggle_group_view provides a way to "separate" a group from
    the lighttable display and limit the display to just the group.
    Pressing the shortcut again returns to the full lighttable view.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    None

    USAGE
    * place the script in your lua scripts folder
    * start the script with script manager
    * assign a key sequence to the shortcut

    BUGS, COMMENTS, SUGGESTIONS
    Bill Ferguson <wpferguson.com>

    CHANGES
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local log = require "lib/dtutils.log"


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local MODULE <const> = "toggle_group_view"
local DEFAULT_LOG_LEVEL <const> = log.error
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

dt.gettext.bindtextdomain(MODULE , dt.configuration.config_dir .. "/lua/locale/")

local function _(msgid)
    return gettext(MODULE, msgid)
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
  name = "toggle_group_view",            -- name of script
  purpose = _("toggle only group visible in lighttable"),   -- purpose of script
  author = "Bill Ferguson <wpferguson.com>",          -- your name and optionally e-mail address
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/official/toggle_group_view/"  -- URL to help/documentation
}


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- L O G  L E V E L
-- - - - - - - - - - - - - - - - - - - - - - - - 

log.log_level(DEFAULT_LOG_LEVEL)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local toggle_group_view = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- G L O B A L  V A R I A B L E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local group_active = false
local filmroll = ""
local collection_rules = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function add_collection_rule(rule_string)

  local rule = dt.gui.libs.collect.new_rule()

  rule.mode = "DT_LIB_COLLECT_MODE_AND"
  rule.data = rule_string
  rule.item = "DT_COLLECTION_PROP_FILENAME"

  table.insert(collection_rules, rule)
end

local function show_group()

  local img = dt.gui.action_images[1]  -- if you hover over an image and press a keyboard shortcut, it will get returned in dt.gui.action_images

  local collection_rule_string = ""

  local first = true

  collection_rules = {}

  local group_id = img.group_leader

  local rule = dt.gui.libs.collect.new_rule()

  rule.mode = "DT_LIB_COLLECT_MODE_AND"
  rule.data = tostring(group_id.id)
  rule.item = "DT_COLLECTION_PROP_GROUP_ID"

  table.insert(collection_rules, rule)

  -- dt.gui.libs.collect.filter returns the previous rule set when you install another
  collection_rules = dt.gui.libs.collect.filter(collection_rules)
end

local function reset()
  dt.gui.libs.collect.filter(collection_rules)
end

local function set_button_sensitive(images)
  if images and #images > 0 and #dt.gui.action_images[1]:get_group_members() > 1 then
    dt.gui.libs.image.set_sensitive(MODULE, true)
  else
    dt.gui.libs.image.set_sensitive(MODULE, false)
  end
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  dt.gui.libs.destroy_action(MODULE, "toggle group view")
  dt.destroy_event(MODULE, "selection_changed")
  -- leave the shortcut so it doesn't need to be reassigned
  -- the next time this module starts
end

script_data.destroy = destroy

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.gui.libs.image.register_action(
  MODULE, "toggle group view",
  function(event, images) 
    if group_active then
      reset()
      group_active = false
    else
      show_group()
      group_active = true
    end
  end,
  "toggle group view for selected image"
)

dt.register_event(
  MODULE, "shortcut",
  function(event, shortcut) 
    if group_active then
      reset()
      group_active = false
    else
      show_group()
      group_active = true
    end
  end,
  "toggle group view for selected image"
)

dt.register_event(MODULE, "selection-changed",
  function(event)
    set_button_sensitive(dt.gui.selection())
  end
)

dt.register_event(MODULE, "image-group-information-changed",
  function(event, reason, image, other_image)
    set_button_sensitive(dt.gui.selection())
  end
)
return script_data

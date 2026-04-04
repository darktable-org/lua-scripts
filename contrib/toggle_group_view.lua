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
local hover_active = true

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function is_group_member(image)
  if image then
    if #image:get_group_members() > 1 then
      return true
    else
      return false
    end
  end
end

local function is_group_displayed()
  local rules = dt.gui.libs.collect.filter()
  if rules[1].item == "DT_COLLECTION_PROP_GROUP_ID" then
    local rule = dt.gui.libs.collect.new_rule()

    rule.mode = "DT_LIB_COLLECT_MODE_AND"
    rule.data = dt.collection[1].path
    rule.item = "DT_COLLECTION_PROP_FILMROLL"

    table.insert(collection_rules, rule)
    group_active = true
  end
end

local function set_button_sensitive(image)
  if image then
    if is_group_member(image) then
      dt.gui.libs.image.set_sensitive(MODULE, true)
    else
      dt.gui.libs.image.set_sensitive(MODULE, false)
    end
  elseif #dt.gui.action_images == 0 then
    dt.gui.libs.image.set_sensitive(MODULE, false)
  end
end

local function add_collection_rule(rule_string)

  local rule = dt.gui.libs.collect.new_rule()

  rule.mode = "DT_LIB_COLLECT_MODE_AND"
  rule.data = rule_string
  rule.item = "DT_COLLECTION_PROP_FILENAME"

  table.insert(collection_rules, rule)
end

local function show_group(image)

  local collection_rule_string = ""

  local first = true

  collection_rules = {}

  local group_id = image.group_leader

  local rule = dt.gui.libs.collect.new_rule()

  rule.mode = "DT_LIB_COLLECT_MODE_AND"
  rule.data = tostring(group_id.id)
  rule.item = "DT_COLLECTION_PROP_GROUP_ID"

  table.insert(collection_rules, rule)

  -- dt.gui.libs.collect.filter returns the previous rule set when you install another
  collection_rules = dt.gui.libs.collect.filter(collection_rules)
end

local function reset(image)
  dt.gui.libs.collect.filter(collection_rules)
  if image then
    dt.gui.views.lighttable.set_image_visible(image)
  else
    log.msg(log.screen, _("no image supplied"))
  end
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N
-- - - - - - - - - - - - - - - - - - - - - - - - 

-- check if we are starting with a group already displayed and 
-- configure appropriately

if not dt.preferences.read("darktable", "plugins/lighttable/act_on", "bool") then
  hover_active = false
end

is_group_displayed()
 
-- - - - - - - - - - - - - - - - - - - - - - - - 
-- U S E R  I N T E R F A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.gui.libs.image.register_action(
  MODULE, "toggle group view",
  function(event, images) 
    if group_active then
      reset(dt.gui.action_images[1])
      group_active = false
    else
      show_group(dt.gui.action_images[1])
      group_active = true
    end
  end,
  "toggle group view for selected image"
)

set_button_sensitive(nil)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  if hover_active then
    dt.destroy_event(MODULE, "mouse-over-image-changed")
  end
  dt.destroy_event(MODULE, "selection_changed")
  dt.gui.libs.image.destroy_action(MODULE, "toggle group view")
  -- leave the shortcut so it doesn't need to be reassigned
  -- the next time this module starts
end

script_data.destroy = destroy

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.register_event(
  MODULE, "shortcut",
  function(event, shortcut) 
    if #dt.gui.action_images > 0 then
      if group_active then
        reset(dt.gui.action_images[1])
        group_active = false
      else
        show_group(dt.gui.action_images[1])
        group_active = true
      end
    end
  end,
  _("toggle group view for selected image")
)

if hover_active then
  dt.register_event(MODULE, "mouse-over-image-changed",
    function(event, image)
      if hover_active then
        set_button_sensitive(image)
      end
    end
  )
end

dt.register_event(MODULE, "selection-changed",
  function(event)
    set_button_sensitive(dt.gui.action_images[1])
  end
)

return script_data

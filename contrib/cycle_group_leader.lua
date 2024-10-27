--[[

    cycle_group_leader.lua - change image group leader

    Copyright (C) 2024 Bill Ferguson <wpferguson@gmail.com>

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
    cycle_group_leader - change image grouip leader

    cycle_group_leader changes the group leader to the next
    image in the group.  If the end of the group is reached
    then the next image is wrapped around to the first image.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    None

    USAGE
    * enable with script_manager
    * assign a key to the shortcut

    BUGS, COMMENTS, SUGGESTIONS
    Bill Ferguson <wpferguson@gmail.com>

    CHANGES
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- C O N S T A N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local MODULE = "cycle_group_leader"

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- A P I  C H E C K
-- - - - - - - - - - - - - - - - - - - - - - - - 

du.check_min_api_version("7.0.0", MODULE) 


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

script_data.metadata = {
  name = _("cycle group leader"),
  purpose = _("change image group leader"),
  author = "Bill Ferguson <wpferguson@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/cycle_group_leader"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function toggle_global_toolbox_grouping()
  dt.gui.libs.global_toolbox.grouping = false
  dt.gui.libs.global_toolbox.grouping = true
end

local function hinter_msg(msg)
  dt.print_hinter(msg)
  dt.control.sleep(1500)
  dt.print_hinter(" ")
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N  P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function cycle_group_leader(image)
  local group_images = image:get_group_members()
  if #group_images < 2 then
    hinter_msg(_("no images to cycle through in group"))
    return
  else
    local position = nil
    for i, img in ipairs(group_images) do
      if image == img then
        position = i
      end
    end

    if position == #group_images then
      position = 1
    else
      position = position + 1
    end

    new_leader = group_images[position]
    new_leader:make_group_leader()
    dt.gui.selection({new_leader})

    if dt.gui.libs.global_toolbox.grouping then
      -- toggle the grouping to make the new leader show
      toggle_global_toolbox_grouping()
    end
  end
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  -- put things to destroy (events, storages, etc) here
  dt.destroy_event(MODULE, "shortcut")
end

script_data.destroy = destroy

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.register_event(MODULE, "shortcut",
  function(event, shortcut)
    -- ignore the film roll, it contains all the images, not just the imported
    local images = dt.gui.selection()
    if #images < 1 then
      dt.print(_("no image selected, please select an image and try again"))
    else
      cycle_group_leader(images[1])
    end
  end,
  _("cycle group leader")
)

return script_data

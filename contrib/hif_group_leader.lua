--[[

    hif_group_leader.lua - Make hif image group leader

    Copyright (C) 2024 Bill Ferguson <wpferguson@gmail.com>.

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
    hif_group_leader - Make hif image group leader

    After a film roll is imported, check for RAW-JPG image groups
    and make the JPG image the group leader.  This is on by default
    but can be disabled in preferences.

    Shortcuts are included to filter existing collections or
    selections of images and make the hif the group leader.

    ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
    None

    USAGE
    Start script from script_manager
    Assign keys to the shortcuts

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

local MODULE = "hif_group_leader"

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
  name = _("HIF group leader"),
  purpose = _("make hif image group leader"),
  author = "Bill Ferguson <wpferguson@gmail.com>",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/hif_group_leader"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them


-- - - - - - - - - - - - - - - - - - - - - - - - 
-- P R E F E R E N C E S
-- - - - - - - - - - - - - - - - - - - - - - - - 

dt.preferences.register(MODULE, "on_import", "bool", _("make hif group leader on import"), _("automatically make the hif file the group leader when raw + hif are imported"), true)

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- N A M E  S P A C E
-- - - - - - - - - - - - - - - - - - - - - - - - 

local jgloi = {}
jgloi.images = {}

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- F U N C T I O N S
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function toggle_global_toolbox_grouping()
  dt.gui.libs.global_toolbox.grouping = false
  dt.gui.libs.global_toolbox.grouping = true
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- M A I N  P R O G R A M
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function make_hif_group_leader(images)
  -- if the image is part of a group, make it the leader
  for _, image in ipairs(images) do
    if #image:get_group_members() > 1 then
      image:make_group_leader()
    end
  end
  if dt.gui.libs.global_toolbox.grouping then
    -- toggle the grouping to make the new leader show
    toggle_global_toolbox_grouping()
  end
end

local function make_existing_hif_group_leader(images)
  for _, image in ipairs(images) do
    if string.lower(df.get_filetype(image.filename)) == "hif" then
      if #image:get_group_members() > 1 then
        image:make_group_leader()
      end
    end
  end
  if dt.gui.libs.global_toolbox.grouping then
    -- toggle the grouping to make the new leader show
    toggle_global_toolbox_grouping()
  end
end

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- D A R K T A B L E  I N T E G R A T I O N 
-- - - - - - - - - - - - - - - - - - - - - - - - 

local function destroy()
  if dt.preferences.read(MODULE, "on_import", "bool") then
    dt.destroy_event(MODULE, "post-import-film")
    dt.destroy_event(MODULE, "post-import-image")
  end
  dt.destroy_event(MODULE .. "_collect", "shortcut")
  dt.destroy_event(MODULE .. "_select", "shortcut")
end

script_data.destroy = destroy

-- - - - - - - - - - - - - - - - - - - - - - - - 
-- E V E N T S
-- - - - - - - - - - - - - - - - - - - - - - - - 

if dt.preferences.read(MODULE, "on_import", "bool") then
  dt.register_event(MODULE, "post-import-film", 
    function(event, film_roll)
      -- ignore the film roll, it contains all the images, not just the imported
      local images = jgloi.images
      if #images > 0 then
        jgloi.images = {}
        make_hif_group_leader(images)
      end
    end
  )

  dt.register_event(MODULE, "post-import-image",
    function(event, image)
      if string.lower(df.get_filetype(image.filename)) == "hif" then
        table.insert(jgloi.images, image)
      end
    end
  )
end

dt.register_event(MODULE .. "_collect", "shortcut",
  function(event, shortcut)
    -- ignore the film roll, it contains all the images, not just the imported
    local images = dt.collection
    make_existing_hif_group_leader(images)
  end,
  _("make hif group leader for collection")
)

dt.register_event(MODULE .. "_select", "shortcut",
  function(event, shortcut)
    local images = dt.gui.selection()
    make_existing_hif_group_leader(images)
  end,
  _("make hif group leader for selection")
)

return script_data
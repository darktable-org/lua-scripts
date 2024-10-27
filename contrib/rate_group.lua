--[[

  Rate Group:

  Script to provide shortcuts for rating or rejecting all images within a group;
  particularly useful for RAW+JPEG shooters employing a star rating workflow
  like the below:

    http://blog.chasejarvis.com/blog/2011/03/photo-editing-101/


  Installation and usage:

    1. Copy this file into ~/.config/darktable/lua/

    2. Add `require "rate_group"` to new line in ~/.config/darktable/luarc

    3. Restart darktable

    4. Assign a keyboard shortcut to each action via settings > shortcuts > lua

       I use the following shortcuts:

       * Reject group: Ctrl+R
       * Rate group 1: Ctrl+1
       * Rate group 2: Ctrl+2
       * Rate group 3: Ctrl+3
       * Rate group 4: Ctrl+4
       * Rate group 5: Ctrl+5
       * Rate group 0: Ctrl+0


  Author:  Dom H (dom@hxy.io)
  License: GPLv2

  This script is based on Thibault Jouannic's `reject_group` script:
    http://redmine.darktable.org/issues/8968#note-20

]]

local dt = require "darktable"
local du = require "lib/dtutils"

-- added version check
du.check_min_api_version("7.0.0", "rate_group") 

local gettext = dt.gettext.gettext

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("rate group"),
  purpose = _("rate all images in a group"),
  author = "Dom H (dom@hxy.io)",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/rate_group"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local function apply_rating(rating)
  local images = dt.gui.action_images
  for _, i in ipairs(images) do
      local members = i:get_group_members()
      for _, m in ipairs(members) do
          m.rating = rating
      end
  end
  if rating < 0 then
      dt.print(_("rejecting group(s)"))
  else
      dt.print(string.format(_("applying rating %d to group(s)"), rating))
  end
end

local function destroy()
  dt.destroy_event("rg_reject", "shortcut")
  dt.destroy_event("rg0", "shortcut")
  dt.destroy_event("rg1", "shortcut")
  dt.destroy_event("rg2", "shortcut")
  dt.destroy_event("rg3", "shortcut")
  dt.destroy_event("rg4", "shortcut")
  dt.destroy_event("rg5", "shortcut")
end

dt.register_event("rg_reject", "shortcut",
  function(event, shortcut)
    apply_rating(-1)
end, _("reject group"))

dt.register_event("rg0", "shortcut",
  function(event, shortcut)
    apply_rating(0)
  end, string.format(_("rate group %d"), 0)
)

dt.register_event("rg1", "shortcut",
  function(event, shortcut)
    apply_rating(1)
end, string.format(_("rate group %d"), 1))

dt.register_event("rg2", "shortcut",
  function(event, shortcut)
    apply_rating(2)
end, string.format(_("rate group %d"), 2))

dt.register_event("rg3", "shortcut",
  function(event, shortcut)
    apply_rating(3)
end, string.format(_("rate group %d"), 3))

dt.register_event("rg4", "shortcut",
  function(event, shortcut)
    apply_rating(4)
end, string.format(_("rate group %d"), 4))

dt.register_event("rg5", "shortcut",
  function(event, shortcut)
    apply_rating(5)
end, string.format(_("rate group %d"), 5))

script_data.destroy = destroy

return script_data

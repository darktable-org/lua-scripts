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

local function apply_rating(rating)
  local images = dt.gui.action_images
  for _, i in ipairs(images) do
      local members = i:get_group_members()
      for _, m in ipairs(members) do
          m.rating = rating
      end
  end
  if rating < 0 then
      dt.print("rejecting group(s)")
  else
      dt.print("applying rating " ..rating.. " to group(s)")
  end
end

dt.register_event("shortcut",function(event, shortcut)
    apply_rating(-1)
end, "Reject group")

dt.register_event("shortcut",function(event, shortcut)
    apply_rating(0)
end, "Rate group 0")

dt.register_event("shortcut",function(event, shortcut)
    apply_rating(1)
end, "Rate group 1")

dt.register_event("shortcut",function(event, shortcut)
    apply_rating(2)
end, "Rate group 2")

dt.register_event("shortcut",function(event, shortcut)
    apply_rating(3)
end, "Rate group 3")

dt.register_event("shortcut",function(event, shortcut)
    apply_rating(4)
end, "Rate group 4")

dt.register_event("shortcut",function(event, shortcut)
    apply_rating(5)
end, "Rate group 5")
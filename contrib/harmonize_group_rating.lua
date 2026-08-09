--[[
   Harmonize group rating:

   Copy the rating among a group of images. Run darktable with `-d
   lua` to log modified images.

   Installation: deploy in ~/.config/darktable/lua. Set a keybinding
   (e.g. "shift f").

   Usage: select images without ratings you suspect should have
   some. Hit the keybinding, wait for the processing to complete. It
   should show a message at the start and end of the processing,
   including how many images were rated.

   Author: anarcat
   License: GPLv2

--]]

local dt = require "darktable"
local du = require "lib/dtutils"

local _ = dt.gettext.gettext

-- not sure we need this
du.check_min_api_version("7.0.0", "harmonize_group_rating")

local script_data = {}

script_data.metadata = {
  name = _("harmonize group rating"),
  purpose = _("copy rating within a group"),
  author = "anarcat",
  help = "TODO"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local function harmonize_rating(shortcut)
   local images = dt.gui.action_images
   dt.print_log("harmonizing ratings on " .. #images .. " selected images...")
   dt.print("harmonizing ratings on " .. #images .. " selected images...")
   local modified = 0
   local singles = 0
   local unrated_groups = 0
   local modified_groups = 0
   local rated_groups = 0
   for _, img in ipairs(images) do
      -- image rating is -1 for rejected or 1-5. zero is unset.
      local rating = 0
      local missing = 0
      local members = img:get_group_members()
      if #members <= 1 then
         dt.print_log("skipping single image " .. img.id .. " path " .. img.filename)
         singles = singles + 1
      else
         dt.print_log("checking image " .. img.id .. " named "  .. img.filename .. " member count: " .. #members)
         for _, member in ipairs(members) do
            dt.print_log("member " .. member.id .. " path " .. member.filename .. " rating " .. member.rating)
            if (member.rating ~= 0) then
               if rating == 0 then
                  -- only record rating if not already set
                  rating = member.rating
               end
            else
               missing = missing + 1
            end
         end
         if rating == 0 then
            unrated_groups = unrated_groups + 1
            dt.print_log("no rating found in group, skipping")
         elseif missing > 0 then
            modified_groups = modified_groups + 1
            dt.print_log("rating found in group, missing from " .. missing .. " image, fixing")
            for _, member in ipairs(members) do
               if member.rating == 0 then
                  dt.print_log("applying rating " .. rating .. " to image " .. member.id .. " in " .. img.filename .. ", previously: " .. member.rating)
                  member.rating = rating
                  modified = modified + 1
               end
            end
         else
            rated_groups = rated_groups + 1
            dt.print_log("all members rated in group, skipping")
         end
      end
   end
   dt.print("processed " .. #images .. " images, modified ratings on " .. modified)
   dt.print_log("processed " .. #images .. " images, modified ratings on " .. modified)
   dt.print_log("modified groups: " .. modified_groups)
   dt.print_log("singles (skipped): " .. singles)
   dt.print_log("unrated groups (skipped): " .. unrated_groups)
   dt.print_log("fully rated groups (skipped): " .. rated_groups)
end

local function destroy()
   dt.destroy_event("hgr_harmonize", "shortcut")
end

dt.register_event("hgr_harmonize", "shortcut", harmonize_rating, "harmonize group rating")

dt.print_log("harmonize_group_rating loaded")

script_data.destroy = destroy

return script_data

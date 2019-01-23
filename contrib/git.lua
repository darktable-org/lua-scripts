--[[
   git.lua - Report Git status for image files and sidecar files.
             Perform basic repo operations: add, rm

   Copyright (C) 2018 Daniel Schudel <dan.schudel@gmail.com>.

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
   Installation
     1. Copy this file into ~/.config/darktable/lua/
     2. Add `require "git"` to a new line in ~/.config/darktable/luarc
     3. Restart darktable
     4. Run your mouse cursor over images in the lighttable view - color tags will update.
     5. Use the "VCS/Git" gui box on the right to add/rm files to/from a Git repo.
     6. Lower left "Image Information" box will have two new rows for Git file status.
]]

--[[
   I use Git for the archival, backup, and distribution of my image
   files and my XMP sidecar files.

   I had two needs from the DT interface:
     1. At a glance - know the status of an image file.
        a. If it is not tracked by a Git repo - red/danger - no backup or version
           control is in place.
        b. If it is tracked by a Git repo but not committed or is modified - yellow/warning.
        c. If it is tracked, and is committed - green/good.
     2. A simple interface to add/remove the image files to/from the relevant repo.

   Notes:
     1. This is not a full-feature Git GUI. There is no commit/revert/push/pull/etc.
        You'll need to find/perform that elsewhere.
     2. There is a "hole" in that an image may be committed to the local repo, and not
        pushed to the remote. This interface does not warn about such a condition.

   What you get:
     1. Color flags Red/Yellow/Green:  On image/folder import, and on lighttable view
        mouseover, the Git status of an image file is queried and the color flags
        are updated according to this logic:

        a. Red    - local file not known to a Git repo
        b. Yellow - staged file, or modified file
        c. Green  - fully committed file

        Note that the color flags say nothing about the status of the sidecar file.

     2. Image Information box - In the "Image Information" box (bottom left of the
        DT GUI) two new info rows are added:

        a. "Git/image"   - An English string of the Git status of the image file
        b. "Git/sidecar" - An English string of the Git status of the sidecar file

     3. "VCS/Git" UI box - on the right side of the lighttable UI is a new box. This
        allows for a Git "add" or "rm" of images currently selected.

   TODO:
     1. Are there native Lua Git bindings so that io.popen() and os.execute() can be avoided?
]]

dt       = require "darktable"
dt_debug = require "darktable.debug" 

-- for a given file, determine the git status, return a descriptive string
local function git_status_of_file(path, filename)
  local result
  local cmd
  local f
  local output

--	dt.print_log(path .. " / " .. filename)
  result = os.execute("git -C " .. path .. " rev-parse --git-dir 2>&1 > /dev/null 2>&1 ")
  if result == nil then
    return "No Git repo"
  end

  cmd = "git -C " .. path .. " status --porcelain --untracked-files=all --ignored " .. filename .. " | cut -b 1-2"
--	print(" ", cmd)
  f = io.popen(cmd)

  for line in f:lines() do
    output = line
--		print(" ", path.."/"..filename, line)
  end -- for loop
  f:close()

  if output == nil then
    return "Tracked/clean"
  else
    if output == " M" then
      return "Tracked/modified"
    elseif output == "D " then
      return "Tracked/del pending"
    elseif output == "A " then
      return "Tracked/add pending"
    elseif output == "??" then
      return "Not tracked"
    elseif output == "!!" then
      return "Ignored"
    else
      return "Unknown"
    end
  end
end

-- For a given image, and descriptive git status, set the color
local function image_set_color_flag(image, gitStatus)
    if gitStatus == "Tracked/clean" then
        image.green  = true
        image.red    = false
        image.yellow = false
    elseif gitStatus == "Tracked/add pending" or gitStatus == "Tracked/modified" then
        image.green  = false
        image.red    = false
        image.yellow = true
    else
        image.green  = false
        image.red    = true
        image.yellow = false
    end
end

-- Get the Git status for an image, return descriptive string, set the color
local function image_update_git_info(image)
  local imageOutput

  if not image then
    return "No Image"
  end

  imageOutput   = git_status_of_file(image.path, image.filename)
  image_set_color_flag(image, imageOutput)

  return imageOutput
end

-- Get the Git status for a sidecar, return descriptive string
local function sidecar_update_git_info(image)
  local sidecarOutput

  if not image then
    return "No Image"
  end

  sidecarOutput = git_status_of_file(image.path, image.sidecar)

  return sidecarOutput
end

-- register functions to display Git info when mouse-over in lighttable view
dt.gui.libs.metadata_view.register_info("Git/image", image_update_git_info)
dt.gui.libs.metadata_view.register_info("Git/sidecar", sidecar_update_git_info)


-- Right sidebar GUI to add/remove images from VCS
local function vcs_action_git(action)
  dt.print_log("vcs_action_git", action)
  local sel_images = dt.gui.action_images
  local sidecarPath
  local sidecarFilename
  local result

  for _,image in ipairs(sel_images) do
    sidecarPath, sidecarFilename = string.match(image.sidecar, "(.-)([^/]-([^%.]+))$")

    dt.print_log(" ", image.path .. " / " .. image.filename)
    dt.print_log(" ", sidecarPath .. " / " .. sidecarFilename)

    result = os.execute("git -C " .. image.path .. " " .. action .. " " .. image.filename)
    if result == nil then
      print("Error with " .. action .. " of " .. image.path .. " / " .. image.filename)
    else
      local imageOutput
      imageOutput   = git_status_of_file(image.path, image.filename)
      image_set_color_flag(image, imageOutput)
    end

    result = os.execute("git -C " .. sidecarPath .. " " .. action .. " " .. sidecarFilename)
    if result == nil then
      print("Error with " .. action .. " of " .. sidecarPath .. " / " .. sidecarFilename)
    end
  end
end

local function vcs_git_add()
  dt.print_log("vcs_git_add")
  vcs_action_git("add -f ", dt.gui.action_images)
end

local function vcs_git_remove()
  dt.print_log("vcs_git_remove")
  vcs_action_git("rm --cached ", dt.gui.action_images)
end


local box1 = dt.new_widget("box"){
                  orientation = "horizontal",
                  dt.new_widget("button") {
                    label = 'Add',
                    tooltip = "Add image/sidecar to Git repository",
                    clicked_callback = vcs_git_add},
                  dt.new_widget("button") {
                    label = 'Remove',
                    tooltip = "Remove image/sidecar from Git repository",
                    clicked_callback = vcs_git_remove}
                  }

local widget_table = {}
widget_table[1] = box1


dt.register_lib("vcs_git_addon","VCS/Git",true,true,{
    [dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_RIGHT_CENTER",500}
    },
    dt.new_widget("box") {
      table.unpack(widget_table),
      },
   nil,
   nil
  )

-- post image import action to set the color flags
local function detect_vcs(event, image)
  local imageOutput
  imageOutput   = git_status_of_file(image.path, image.filename)
  image_set_color_flag(image, imageOutput)
end

dt.register_event("post-import-image", detect_vcs)



-- vim: shiftwidth=4 expandtab tabstop=4 cindent syntax=lua

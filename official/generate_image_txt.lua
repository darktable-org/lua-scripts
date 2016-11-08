--[[
    This file is part of darktable,
    copyright (c) 2014 Tobias Ellinghaus

    darktable is free software: you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation, either version 3 of the License, or
    (at your option) any later version.

    darktable is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with darktable.  If not, see <http://www.gnu.org/licenses/>.
]]
--[[
GENERATE IMAGE TEXT
A script to run a command on images to generate text metadata

The medata will be displayed as an overlay on the image in lighttable mode

USAGE
* require this script from your main lua file
* set a command to run on all image, this command should output text on stdout
* enable image file generation


]]

-- TODO:
--  * enable showing of the txt file (plugins/lighttable/draw_custom_metadata) if this script is enabled
--  * maybe allow a lua command returning text instead of a command line call? both?
--  * make filenames with double quotes (") work

local dt = require "darktable"
require "darktable.debug"
require "official/yield"

dt.configuration.check_version(...,{2,1,0},{3,0,0},{4,0,0})

dt.preferences.register("generate_image_txt",
                        "enabled",
                        "bool",
                        "create txt sidecars to display with images",
                        "the txt files created get shown when the lighttable is zoomed in to one image. also enable the txt overlay setting in the gui tab",
                        false)

dt.preferences.register("generate_image_txt",
                        "command",
                        "string",
                        "command to generate the txt sidecar",
                        "the output of this command gets written to the txt file. use $(FILE_NAME) for the image file",
                        "exiv2 $(FILE_NAME)")


local check_command = function(command)
  if not command:find("$(FILE_NAME)", 1, true) then
    dt.print("the command for txt sidecars looks bad. better check the preferences")
  end
end


local command_setting = dt.preferences.read("generate_image_txt", "command", "string")
check_command(command_setting)

dt.register_event("mouse-over-image-changed", function(event, img)
    -- no need to waste processing time if the image has a txt file already
    if not img or img.has_txt or not dt.preferences.read("generate_image_txt", "enabled", "bool") then
      return
    end

    -- there should be at least one "$(FILE_NAME)" in the command. warn if not, but only once
    local _command_setting = dt.preferences.read("generate_image_txt", "command", "string")
    if not (command_setting == _command_setting) then
      command_setting = _command_setting
      check_command(command_setting)
    end

    -- set the flag to true first so that subsequent runs don't mess with the txt
    img.has_txt = true

    -- next: create the txt

    local img_filename = img.path.."/"..img.filename
    local txt_filename = img.path.."/"..img.filename:match("^[^.]*")..".txt"

    -- better safe than sorry: check if the file maybe exists. this is for example true when shooting raw+jpg
    local file = io.open(txt_filename, "r")
    if file then
      file.close()
      return
    end

    -- we are confident now that it's safe to write the file

    -- compose the command to run
    local command = command_setting:gsub("%$%(FILE_NAME%)", '"'..img_filename..'"')..' > "'..txt_filename..'"'

    -- finally, run it
     dt.control.execute( command)
  end
)


-- vim: shiftwidth=2 expandtab tabstop=2 cindent
-- kate: tab-indents: off; indent-width 2; replace-tabs on; remove-trailing-space on;

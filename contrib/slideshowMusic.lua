--[[
    This file is part of darktable,
    Copyright 2014 by Tobias Jakobs

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
darktable Script to play music during a Slideshow

You need rhythmbox-client installed to use this script

USAGE
* require this script from your main lua file
]]

local dt = require "darktable"
local du = require "lib/dtutils"
local df = require "lib/dtutils.file"
local gettext = dt.gettext.gettext

du.check_min_api_version("7.0.0", "slideshowMusic") 

local function _(msgid)
    return gettext(msgid)
end

-- return data structure for script_manager

local script_data = {}

script_data.metadata = {
  name = _("slideshow music"),
  purpose = _("play music during a slideshow"),
  author = "Tobias Jakobs",
  help = "https://docs.darktable.org/lua/stable/lua.scripts.manual/scripts/contrib/slideshowMusic"
}

script_data.destroy = nil -- function to destory the script
script_data.destroy_method = nil -- set to hide for libs since we can't destroy them commpletely yet, otherwise leave as nil
script_data.restart = nil -- how to restart the (lib) script after it's been hidden - i.e. make it visible again
script_data.show = nil -- only required for libs since the destroy_method only hides them

local function playSlideshowMusic(_, old_view, new_view)
  local filename, playMusic

  filename = dt.preferences.read("slideshowMusic","SlideshowMusic","string")
  playMusic = dt.preferences.read("slideshowMusic","PlaySlideshowMusic","bool")

  if not df.check_if_bin_exists("rhythmbox-client") then
    dt.print_error("rhythmbox-client not found")
    return
  end

  if (playMusic) then
    local playCommand, stopCommand

    if (new_view.id == "slideshow") then
      playCommand = 'rhythmbox-client --play-uri="'..filename..'"'

      --dt.print_error(playCommand)
      dt.control.execute( playCommand)
    else
      if (old_view and old_view.id == "slideshow") then
        stopCommand = "rhythmbox-client --pause"
        --dt.print_error(stopCommand)
        dt.control.execute(stopCommand)
      end
    end
  end
end

function destroy()
  dt.destroy_event("slideshow_music", "view-changed")
  dt.preferences.destroy("slideshowMusic", "SlideshowMusic")
  dt.preferences.destroy("slideshowMusic", "PlaySlideshowMusic")
end

-- Preferences
dt.preferences.register("slideshowMusic", "SlideshowMusic", "file", _("slideshow background music file"), "", "")
dt.preferences.register("slideshowMusic",
                        "PlaySlideshowMusic",
                        "bool",
                        _("play slideshow background music"),
                        _("plays music with rhythmbox if a slideshow starts"),
                        true)
-- Register
dt.register_event("slideshow_music", "view-changed",
  playSlideshowMusic)

script_data.destroy = destroy

return script_data

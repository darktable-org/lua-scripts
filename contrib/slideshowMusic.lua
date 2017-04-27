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
local df = require "lib/dtutils.file"
require "official/yield"
local gettext = dt.gettext

dt.configuration.check_version(...,{2,0,2},{3,0,0},{4,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("slideshowMusic",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("slideshowMusic", msgid)
end

local function playSlideshowMusic(_, old_view, new_view)
  local filename, playMusic

  filename = dt.preferences.read("slideshowMusic","SlideshowMusic","string")
  playMusic = dt.preferences.read("slideshowMusic","PlaySlideshowMusic","bool")

  if not df.check_if_bin_exists("rhythmbox-client") then
    dt.print_error(_("rhythmbox-client not found"))
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
        dt.control.execute( stopCommand)
      end
    end
  end
end

-- Preferences
dt.preferences.register("slideshowMusic", "SlideshowMusic", "file", _("Slideshow background music file"), "", "")
dt.preferences.register("slideshowMusic",
                        "PlaySlideshowMusic",
                        "bool",
                        _("Play slideshow background music"),
                        _("Plays music with rhythmbox if a slideshow starts"),
                        true)
-- Register
dt.register_event("view-changed",playSlideshowMusic)

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
dt.configuration.check_version(...,{2,0,2},{3,0,0})

local function checkIfBinExists(bin)
  local handle = io.popen("which "..bin)
  local result = handle:read()
  local ret
  handle:close()
  if (not result) then
    dt.print_error(bin.." not found")
    ret = false
  end
  ret = true
  return ret
end

local function playSlideshowMusic(_, old_view, new_view)
  local filename, playMusic

  filename = dt.preferences.read("slideshowMusic","SlideshowMusic","string")
  playMusic = dt.preferences.read("slideshowMusic","PlaySlideshowMusic","bool")

  if not checkIfBinExists("rhythmbox-client") then
    return
  end

  if (playMusic) then
    local playCommand, stopCommand

    if (new_view.id == "slideshow") then
      playCommand = 'rhythmbox-client --play-uri="'..filename..'"'
		
      --dt.print_error(playCommand)
      coroutine.yield("RUN_COMMAND", playCommand) 
    else
      if (old_view and old_view.id == "slideshow") then
        stopCommand = "rhythmbox-client --pause"
        --dt.print_error(stopCommand)
        coroutine.yield("RUN_COMMAND", stopCommand) 
      end
    end
  end
end

-- Preferences
dt.preferences.register("slideshowMusic", "SlideshowMusic", "file", "Slideshow background music file", "", "")
dt.preferences.register("slideshowMusic",  
                        "PlaySlideshowMusic",
                        "bool",
                        "Play slideshow background music",
                        "Plays music with rhythmbox if a slideshow starts",
                        true)
-- Register
dt.register_event("view-changed",playSlideshowMusic)

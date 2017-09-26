--[[
    This file is part of darktable,
    Copyright 2014 by Tobias Jakobs.

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
darktable video export script

ADDITIONAL SOFTWARE NEEDED FOR THIS SCRIPT
* mencoder (MEncoder is from the MPlayer Team)
* xdg-open
* xdg-user-dir

WARNING
This script is only tested with Linux

USAGE
* require this script from your main lua file
]]

local dt = require "darktable"
local df = require "lib/dtutils.file"
require "official/yield"
local gettext = dt.gettext

dt.configuration.check_version(...,{2,0,1},{3,0,0},{4,0,0},{5,0,0})

-- Tell gettext where to find the .mo file translating messages for a particular domain
gettext.bindtextdomain("video_mencoder",dt.configuration.config_dir.."/lua/locale/")

local function _(msgid)
    return gettext.dgettext("video_mencoder", msgid)
end

local function show_status(storage, image, format, filename, number, total, high_quality, extra_data)
    dt.print("Export Image "..tostring(number).."/"..tostring(total))
end

local function create_video_mencoder(storage, image_table, extra_data)
    if not df.check_if_bin_exists("mencoder") then
        dt.print_error(_("mencoder not found"))
        return
    end
    if not df.check_if_bin_exists("xdg-open") then
        dt.print_error(_("xdg-open not found"))
        return
    end
    if not df.check_if_bin_exists("xdg-user-dir") then
        dt.print_error(_("xdg-user-dir not found"))
        return
    end

    exportDirectory = dt.preferences.read("video_mencoder","ExportDirectory","string")
    exportFilename = "output.avi"
    framsePerSecond = dt.preferences.read("video_mencoder","FramesPerSecond","integer")
    
    dt.print_error("Will try to create video now")
    -- Set the codec    
    local codec = ""
    local codecPreferences = ""
    
    codecPreferences = dt.preferences.read("video_mencoder","Codec","string")
    if (codecPreferences == "H.264 encoding") then
	codec = 'x264'
    end    
    if (codecPreferences == "XviD encoding") then
	codec = 'xvid'
    end
    if not codecPreferences then
	codec = 'x264'
    end
    
    -- Create the command
    local command = "mencoder -idx -nosound -noskip -ovc "..codec.." -lavcopts vcodec=mjpeg -o  "..exportDirectory.."/"..exportFilename.." -mf fps="..framsePerSecond .." mf://"

    for _,v in pairs(image_table) do
        command = command..v..","
    end

    dt.print_error("this is the command: "..command)
    dt.control.execute( command)

    dt.print("Video created in "..exportDirectory)
    
    if ( dt.preferences.read("video_mencoder","OpenVideo","bool") == true ) then
        local playVideoCommand = "xdg-open "..exportDirectory.."/"..exportFilename
        dt.control.execute( playVideoCommand) 
    end
end

-- Preferences
dt.preferences.register("video_mencoder", "FramesPerSecond", "float", "Video exort (MEncoder): Frames per second", "Frames per Second in the Video export", 15, 1, 99, 0.1 )
dt.preferences.register("video_mencoder", "OpenVideo", "bool", "Video exort (MEncoder): Open video after export", "Opens the Video after the export with the standard video player", false )

local handle = io.popen("xdg-user-dir VIDEOS")
local result = handle:read()
handle:close()
if (result == nil) then
	result = ""
end
dt.preferences.register("video_mencoder", "ExportDirectory", "directory", "Video exort (MEncoder): Video export directory","A directory that will be used to export a Video",result)

-- Get the MEncoder codec list with: mencoder -ovc help
dt.preferences.register("video_mencoder", "Codec", "enum", "Video exort (MEncoder): Codec","Video codec","H.264 encoding","H.264 encoding","XviD encoding") 

-- Register
dt.register_storage("video_mencoder", "Video Export (MEncoder)", show_status, create_video)

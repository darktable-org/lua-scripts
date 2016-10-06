--[[
    This file is part of darktable,
    Copyright 2016 by Christian Mandel

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
Darktable script to open nautilus on hovered or selected image's paths. Hover
has precedence if hovered image not part of selection. If only one image of
every path is marked, the image will be selected in nautilus.

USAGE
  * require this script from your main lua file
]]
   
local dt = require "darktable"
dt.configuration.check_version(...,{3,0,0})

local function filemanager_shortcut(event, shortcut)
    local images = dt.gui.action_images
    local image_paths = {}
    local multiple_images = 0
    for _,v in pairs(images) do
        if image_paths[v.path] then
            image_paths[v.path] = 0
        else
            image_paths[v.path] = v.path .. "/" .. v.filename
        end
    end
    for k,v in pairs(image_paths) do
        if v == 0 then argument = k else argument = v end
        coroutine.yield("RUN_COMMAND", "nautilus \"" .. argument .. "\"")
    end
end

dt.register_event("shortcut",filemanager_shortcut,
       "Open file manager with selected image(s)")

--[[
TODO:
  * check for nautilus' existance
  * check if this can be made to work with xdg-open, otherwise introduce it as
    fallback
  * localize shortcut string
  * make last (or other defined) file manager window active
]]

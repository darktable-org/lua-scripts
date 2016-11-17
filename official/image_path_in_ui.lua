--[[
  This file is part of darktable,
  copyright (c) 2014 Jérémy Rosen

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
IMAGE_PATH_IN_UI
Add a widget with the path of the selected images for easy copy/past
Simple shortcuts to have multiple selection bufers


USAGE
* require this file from your main lua config file:

This plugin will add a widget at the bottom of the left column in lighttable mode


]]
local dt = require "darktable"
dt.configuration.check_version(...,{2,0,0},{3,0,0},{4,0,0})

local main_label = dt.new_widget("label"){selectable = true, ellipsize = "middle", halign = "start"}

local function reset_widget()
  local selection = dt.gui.selection()
  local result = ""
  local array = {}
  for _,img in pairs(selection) do
    array[img.path] = true
  end
  for path in pairs(array) do
    if result == "" then
      result = path
    else
      result = result.."\n"..path
    end
  end
  main_label.label = result
end

main_label.reset_callback = reset_widget

dt.register_lib("image_path_no_ui","Selected Images path",true,false,{
    [dt.gui.views.lighttable] = {"DT_UI_CONTAINER_PANEL_LEFT_CENTER",300}
    }, main_label
  );

dt.register_event("mouse-over-image-changed",reset_widget);

  --
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua

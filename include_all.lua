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
INCLUDE ALL
Automatically include all scripts in the script repository

This is intended for debugging purpose


USAGE
* require this file from your main lua config file:
* go to configuration => preferences
* Enable the scripts you want to use
* restart darktable

Note that you need to restart DT for your changes to enabled scripts to take effect

]]
local dt = require "darktable"
local io = require "io"
dt.configuration.check_version(...,{3,0,0})

local output = io.popen("cd "..dt.configuration.config_dir.."/lua ;find . -name \\*.lua -print")
local my_name={...}
my_name = my_name[1]
for line in output:lines() do
  local req_name = line:sub(3,-5)
  if req_name ~= my_name then
    dt.preferences.register(my_name,req_name,"bool","enable "..req_name,
    "Should the script "..req_name.." be enabled at next startup",false)

    if dt.preferences.read(my_name,req_name,"bool") then
      require(req_name)
    end
  end
end

--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua

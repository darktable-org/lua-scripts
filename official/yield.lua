--[[
    This file is part of darktable,
    Copyright 2016 by Tobias Jakobs.

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
darktable yield compatibility script

USAGE
* require this script from your main Lua file in the first line

]]
local dt = require "darktable"
local yield_orig = coroutine.yield

-- ToDo: Test with dt master

--[[if (dt.configuration.api_version_major >= 4) then
  coroutine.yield = function(yield_type, command)
    if (yield_type == "RUN_COMMAND") then
      dt.control.execute(command)
    elseif (yield_type == "FILE_READABLE") then
      dt.control.read(command)
    elseif (yield_type == "WAIT_MS") then
      dt.control.sleep(command)
    end  
  end
end]]


if (dt.configuration.api_version_major < 4) then
  dt.control = {}
  dt.control.execute = function(command)
    yield_orig("RUN_COMMAND", command)
  end
  dt.control.read = function(command)
    yield_orig("FILE_READABLE", command)
  end
  dt.control.sleep = function(command)
    yield_orig("WAIT_MS", command)
  end
end

-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua
-- kate: hl Lua;

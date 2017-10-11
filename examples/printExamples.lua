--[[
    This file is part of darktable,
    copyright (c) 2017 Tobias Jakobs
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
Print Examples
prints "hello world when DT starts
USAGE
* require this file from your main lua config file:
]]
local dt = require "darktable"
dt.configuration.check_version(...,{5,0,0})

-- Will print a string to the darktable control log (the long
-- overlayed window that appears over the main panel).
dt.print("print")

-- This function will print its parameter if the Lua logdomain is
-- activated. Start darktable with the "-d lua" command line option
-- to enable the Lua logdomain.
dt.print_error("print error")

-- This function will print its parameter if the Lua logdomain is
-- activated. Start darktable with the "-d lua" command line option
-- to enable the Lua logdomain.
dt.print_log("print log")

--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua

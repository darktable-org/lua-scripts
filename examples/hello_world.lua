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
HELLO WORLD
prints "hello world when DT starts


USAGE
* require this file from your main lua config file:


]]
local dt = require "darktable"
dt.configuration.check_version(...,{2,0,0},{3,0,0})

dt.print("hello, world")

--
-- vim: shiftwidth=2 expandtab tabstop=2 cindent syntax=lua

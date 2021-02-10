--[[

    darktable_transition.lua - temporary library to help with API transition

    Copyright (C) 2016 Bill Ferguson <wpferguson@gmail.com>.

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
    darktable_transition - routines to maintain compatibility with new and previous API versions

]]

local dt
for k,v in pairs(package.loaded) do 
  if string.match(k, "darktable") then
    dt = v
    break
  end
end

if dt then
  dt.orig_register_event = dt.register_event

  function dt.register_event(name, event, callback, tooltip)
    if dt.configuration.api_version_string >= "6.2.1" then
      if tooltip then
        dt.orig_register_event(name, event, callback, tooltip)
      else
        dt.orig_register_event(name, event, callback)
      end
    else
      if tooltip then
        dt.orig_register_event(event, callback, tooltip)
      else
        dt.orig_register_event(event, callback)
      end
    end
  end
end

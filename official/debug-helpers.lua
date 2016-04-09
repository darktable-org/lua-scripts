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
DEBUG HELPERS
A collection of helper functions to help debugging lua scripts.

require it as

dhelpers = require "official/debug-helpers"

Each function is documented in its own header


]]


local dt = require "darktable"
local io = require "io"
local table = require "table"
require "darktable.debug"
local M = {} -- The actual content of the module

--[[
A function which prints its name and its parameters
* name : the name of the tracepoint
* ... : anything, will be dumped using dt.debug
]]
function M.tracepoint(name,...)
  print("*****  "..name.." ****")
  params = {...}
  print(dt.debug.dump(params,"parameters"))
  return ...;
end



--[[
A function that returns a tracepoint function with the given name
This is mainly used to debug callbacks,

register_event(event, dhelpers.new_tracepoint("hit callback"))

will print the following each time the callback is called

**** hit callback ****
<all the callback's parameters dumped>

]]
function M.new_tracepoint(name) 
  return function(...) return M.tracepoint(name,...) end
end


--[[
Wrapper around debug.dump, will directly print to stdout,
same calling covention
]]

function M.dprint(...)
  print(dt.debug.dump(...))
end

--[[
sets dt.debug.known to shorten all images to a single line 

if you don't need to debug the content of images, this will avoid them flooding your logs
]]
function M.terse_dump()
  for _,v in ipairs(dt.database) do
    dt.debug.known[v] = tostring(v)
  end
end



return M
-- vim: shiftwidth=2 expandtab tabstop=2 cindent
-- kate: tab-indents: off; indent-width 2; replace-tabs on; remove-trailing-space on;
